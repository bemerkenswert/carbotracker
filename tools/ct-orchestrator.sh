#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ct-lib.sh"

# Snapshot environment overrides before sourcing the conf file, so that
# explicitly set variables win over the conf file (conf beats script defaults).
ENV_ORCHESTRATOR_POLL_INTERVAL_SECONDS="${ORCHESTRATOR_POLL_INTERVAL_SECONDS-}"
ENV_ORCHESTRATOR_CONCURRENCY_CAP="${ORCHESTRATOR_CONCURRENCY_CAP-}"
ENV_ORCHESTRATOR_STATE_FILE="${ORCHESTRATOR_STATE_FILE-}"
ENV_ORCHESTRATOR_WORKTREE_PARENT="${ORCHESTRATOR_WORKTREE_PARENT-}"
ENV_ORCHESTRATOR_ISSUE_LABELS="${ORCHESTRATOR_ISSUE_LABELS-}"
ENV_ORCHESTRATOR_IN_PROGRESS_LABEL="${ORCHESTRATOR_IN_PROGRESS_LABEL-}"
ENV_ORCHESTRATOR_REVIEW_RETRIES="${ORCHESTRATOR_REVIEW_RETRIES-}"

CONF_FILE="${CT_ORCHESTRATOR_CONF:-$SCRIPT_DIR/ct-orchestrator.conf}"
if [[ -f "$CONF_FILE" ]]; then
  source "$CONF_FILE"
fi

ORCHESTRATOR_POLL_INTERVAL_SECONDS="${ENV_ORCHESTRATOR_POLL_INTERVAL_SECONDS:-${ORCHESTRATOR_POLL_INTERVAL_SECONDS:-300}}"
ORCHESTRATOR_CONCURRENCY_CAP="${ENV_ORCHESTRATOR_CONCURRENCY_CAP:-${ORCHESTRATOR_CONCURRENCY_CAP:-3}}"
ORCHESTRATOR_STATE_FILE="${ENV_ORCHESTRATOR_STATE_FILE:-${ORCHESTRATOR_STATE_FILE:-$HOME/.local/state/carbotracker/orchestrator.json}}"
ORCHESTRATOR_WORKTREE_PARENT="${ENV_ORCHESTRATOR_WORKTREE_PARENT:-${ORCHESTRATOR_WORKTREE_PARENT:-$HOME/git/worktrees/carbotracker}}"
ORCHESTRATOR_ISSUE_LABELS="${ENV_ORCHESTRATOR_ISSUE_LABELS:-${ORCHESTRATOR_ISSUE_LABELS:-ready-for-agent,ticket}}"
ORCHESTRATOR_IN_PROGRESS_LABEL="${ENV_ORCHESTRATOR_IN_PROGRESS_LABEL:-${ORCHESTRATOR_IN_PROGRESS_LABEL:-in-progress}}"
ORCHESTRATOR_REVIEW_RETRIES="${ENV_ORCHESTRATOR_REVIEW_RETRIES:-${ORCHESTRATOR_REVIEW_RETRIES:-3}}"

orchestrator_log() {
  # Logs go to stderr so functions that print a value on stdout (e.g. the
  # state helpers or push_and_open_pr) never pollute it with log lines.
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

orchestrator_state_load() {
  local state_file="$1"
  if [[ ! -f "$state_file" ]]; then
    printf '[]'
    return 0
  fi
  local state
  state="$(cat "$state_file")"
  if ! printf '%s' "$state" | jq -e 'type == "array"' >/dev/null 2>&1; then
    orchestrator_log "WARNING: state file $state_file is corrupt; starting fresh" >&2
    printf '[]'
    return 0
  fi
  printf '%s' "$state"
}

orchestrator_state_write() {
  local state_file="$1" json="$2"
  local dir tmp
  dir="$(dirname "$state_file")"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/orchestrator.XXXXXX")"
  printf '%s\n' "$json" > "$tmp"
  mv "$tmp" "$state_file"
}

orchestrator_state_active_count() {
  orchestrator_state_load "$1" | jq '[.[] | select(.phase == "implementing")] | length'
}

orchestrator_state_has_ticket() {
  local state_file="$1" number="$2"
  if orchestrator_state_load "$state_file" | jq -e --argjson n "$number" 'any(.[]; .ticket == $n)' >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

orchestrator_state_add() {
  local state_file="$1" number="$2" branch="$3" worktree="$4"
  local state entry now
  state="$(orchestrator_state_load "$state_file")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  entry="$(jq -n --argjson ticket "$number" --arg branch "$branch" --arg worktree "$worktree" --arg started "$now" \
    '{ticket: $ticket, branch: $branch, worktree: $worktree, sessionId: null, prNumber: null, lastCommentAt: null, reviewFailures: 0, phase: "implementing", startedAt: $started}')"
  state="$(printf '%s' "$state" | jq --argjson entry "$entry" '. + [$entry]')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_state_complete() {
  local state_file="$1" number="$2" session_id="$3" pr_number="$4"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" --arg sid "$session_id" --arg prn "$pr_number" \
    '(.[] | select(.ticket == $n)) |= (.sessionId = (if $sid == "" then null else $sid end) | .prNumber = (if $prn == "" then null else ($prn | tonumber) end) | .phase = "awaiting review")')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_state_remove() {
  local state_file="$1" number="$2"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" 'map(select(.ticket != $n))')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_state_mark_reviewed() {
  local state_file="$1" number="$2" timestamp="$3"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" --arg ts "$timestamp" \
    '(.[] | select(.ticket == $n)) |= (.lastCommentAt = $ts)')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_state_review_failures() {
  local state_file="$1" number="$2"
  orchestrator_state_load "$state_file" \
    | jq -r --argjson n "$number" '[.[] | select(.ticket == $n) | .reviewFailures][0] // 0'
}

orchestrator_state_set_review_failures() {
  local state_file="$1" number="$2" count="$3"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" --argjson c "$count" \
    '(.[] | select(.ticket == $n)) |= (.reviewFailures = $c)')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_claim() {
  local number="$1" branch="$2" worktree="$3"
  # The claim is the GitHub-side label flip: dropping ready-for-agent takes
  # the issue out of every orchestrator's candidate query, so parallel
  # daemons cannot double-claim it. The state file entry is the local record.
  if ! gh issue edit "$number" --remove-label ready-for-agent --add-label "$ORCHESTRATOR_IN_PROGRESS_LABEL"; then
    orchestrator_log "ERROR: failed to mark #$number as $ORCHESTRATOR_IN_PROGRESS_LABEL on GitHub"
    return 1
  fi
  orchestrator_state_add "$ORCHESTRATOR_STATE_FILE" "$number" "$branch" "$worktree"
  orchestrator_log "claim #$number: phase implementing, worktree $worktree on branch $branch"
}

orchestrator_opencode_session_id() {
  local title="$1"
  opencode session list --format json 2>/dev/null \
    | jq -r --arg t "$title" \
        '[.[] | select(.title == $t)] | sort_by(.created) | reverse | .[0].id // empty'
}

orchestrator_pr_number_for_branch() {
  local branch="$1"
  gh pr list --head "$branch" --json number 2>/dev/null \
    | jq -r 'sort_by(.number) | reverse | .[0].number // empty' 2>/dev/null || true
}

orchestrator_pr_latest_comment_at() {
  local pr="$1" review general latest
  # Inline diff threads live under pulls/<n>/comments, general comments on the
  # PR conversation under issues/<n>/comments. Both are review surfaces; the
  # newest timestamp across them is the last-known-comment watermark. ISO-8601
  # timestamps sort lexically, so a plain > comparison works.
  review="$(gh api "repos/{owner}/{repo}/pulls/$pr/comments" 2>/dev/null | jq -r '[.[].created_at] | max // empty' 2>/dev/null || true)"
  general="$(gh api "repos/{owner}/{repo}/issues/$pr/comments" 2>/dev/null | jq -r '[.[].created_at] | max // empty' 2>/dev/null || true)"
  latest="$review"
  if [[ -n "$general" && ( -z "$latest" || "$general" > "$latest" ) ]]; then
    latest="$general"
  fi
  printf '%s' "$latest"
}

orchestrator_pr_comment() {
  local pr="$1" body="$2"
  gh api "repos/{owner}/{repo}/issues/$pr/comments" -f body="$body" >/dev/null 2>&1
}

orchestrator_review_round() {
  local number="$1" session_id="$2" pr_number="$3" worktree="$4"
  local failures retries latest body
  retries="${ORCHESTRATOR_REVIEW_RETRIES:-3}"
  failures="$(orchestrator_state_review_failures "$ORCHESTRATOR_STATE_FILE" "$number")"
  if [[ "$failures" -ge "$retries" ]]; then
    # Resuming after a pause: a newer human comment starts a fresh budget.
    failures=0
    orchestrator_state_set_review_failures "$ORCHESTRATOR_STATE_FILE" "$number" 0
  fi
  orchestrator_log "review #$number: launching /review-comments on PR #$pr_number (session $session_id)"
  if (cd "$worktree" && opencode run --auto --session "$session_id" "/review-comments on PR #$pr_number"); then
    latest="$(orchestrator_pr_latest_comment_at "$pr_number")"
    if [[ -n "$latest" ]]; then
      orchestrator_state_mark_reviewed "$ORCHESTRATOR_STATE_FILE" "$number" "$latest"
    fi
    orchestrator_state_set_review_failures "$ORCHESTRATOR_STATE_FILE" "$number" 0
    orchestrator_log "review #$number: round succeeded; last comment timestamp ${latest:-<unknown>}"
    return 0
  fi
  failures=$((failures + 1))
  orchestrator_state_set_review_failures "$ORCHESTRATOR_STATE_FILE" "$number" "$failures"
  body="Automated review round failed (attempt $failures/$retries) on PR #$pr_number. The orchestrator will retry.
---
_Created by carbotracker's agent skills._"
  if orchestrator_pr_comment "$pr_number" "$body"; then
    orchestrator_log "review #$number: posted failure notice (attempt $failures/$retries) on PR #$pr_number"
  else
    orchestrator_log "WARNING: failed to post failure notice on PR #$pr_number"
  fi
  if [[ "$failures" -ge "$retries" ]]; then
    latest="$(orchestrator_pr_latest_comment_at "$pr_number")"
    if [[ -n "$latest" ]]; then
      orchestrator_state_mark_reviewed "$ORCHESTRATOR_STATE_FILE" "$number" "$latest"
    fi
    orchestrator_log "ERROR: /review-comments failed $failures times for #$number on PR #$pr_number; pausing until a human intervenes"
  else
    orchestrator_log "ERROR: /review-comments failed for #$number on PR #$pr_number (attempt $failures/$retries)"
  fi
  return 1
}

orchestrator_review_poll() {
  local line number pr_number session_id worktree last_comment_at latest
  while IFS= read -r line; do
    number="$(printf '%s' "$line" | jq -r '.ticket')"
    pr_number="$(printf '%s' "$line" | jq -r '.prNumber')"
    session_id="$(printf '%s' "$line" | jq -r '.sessionId')"
    worktree="$(printf '%s' "$line" | jq -r '.worktree')"
    last_comment_at="$(printf '%s' "$line" | jq -r '.lastCommentAt // ""')"

    if [[ -z "$pr_number" || "$pr_number" == "null" ]]; then
      orchestrator_log "skip review #$number: no PR recorded"
      continue
    fi
    if [[ -z "$session_id" || "$session_id" == "null" ]]; then
      orchestrator_log "skip review #$number: no session recorded"
      continue
    fi

    latest="$(orchestrator_pr_latest_comment_at "$pr_number")"
    if [[ -z "$latest" ]]; then
      orchestrator_log "review #$number: no comments on PR #$pr_number"
      continue
    fi
    if [[ -n "$last_comment_at" ]]; then
      if [[ "$latest" == "$last_comment_at" || "$latest" < "$last_comment_at" ]]; then
        orchestrator_log "review #$number: no new comment on PR #$pr_number (last known $last_comment_at)"
        continue
      fi
    fi
    orchestrator_log "review #$number: new comment on PR #$pr_number (latest $latest, last known ${last_comment_at:-<none>})"
    orchestrator_review_round "$number" "$session_id" "$pr_number" "$worktree" || true
  done < <(orchestrator_state_load "$ORCHESTRATOR_STATE_FILE" | jq -c '.[] | select(.phase == "awaiting review")')
}

orchestrator_push_and_open_pr() {
  local number="$1" title="$2" branch="$3" worktree="$4"
  local pr_number
  orchestrator_log "pushing branch $branch for #$number"
  # git push / gh pr create write progress and the PR url to stdout; this
  # function's stdout is its return value, so route them to stderr.
  if ! (cd "$worktree" && git push -u origin "$branch" >&2); then
    orchestrator_log "ERROR: git push failed for #$number"
    return 1
  fi
  pr_number="$(orchestrator_pr_number_for_branch "$branch")"
  if [[ -z "$pr_number" ]]; then
    orchestrator_log "creating PR for #$number ($title)"
    if ! gh pr create --base main --head "$branch" --title "Implement $title (#$number)" \
        --body "Automated implementation of #$number.

---
_Created by carbotracker's agent skills._" >&2; then
      orchestrator_log "ERROR: gh pr create failed for #$number"
      return 1
    fi
    pr_number="$(orchestrator_pr_number_for_branch "$branch")"
  fi
  printf '%s' "$pr_number"
}

orchestrator_cleanup_worktree() {
  local worktree="$1" branch="$2"
  git worktree remove --force "$worktree" 2>/dev/null || rm -rf "$worktree"
  git branch -D "$branch" 2>/dev/null || true
}

orchestrator_implement() {
  local number="$1" title="$2" branch="$3" worktree="$4"
  local session_title session_id pr_number

  orchestrator_log "implementing #$number: creating worktree $worktree (branch $branch)"
  if ! ct_worktree_add "$worktree" "$branch"; then
    orchestrator_log "ERROR: worktree creation failed for #$number"
    return 1
  fi

  orchestrator_log "installing dependencies in $worktree"
  if ! (cd "$worktree" && npm ci --prefer-offline --no-audit --no-fund); then
    orchestrator_log "ERROR: npm ci failed for #$number"
    return 1
  fi

  session_title="carbotracker-ticket-$number"
  orchestrator_log "launching opencode for #$number (title $session_title)"
  if ! (cd "$worktree" && opencode run --auto --title "$session_title" "/implement the issue is $number"); then
    orchestrator_log "ERROR: opencode run failed for #$number"
    return 1
  fi

  session_id="$(orchestrator_opencode_session_id "$session_title")"
  if ! pr_number="$(orchestrator_push_and_open_pr "$number" "$title" "$branch" "$worktree")"; then
    orchestrator_log "ERROR: push or PR creation failed for #$number"
    return 1
  fi
  orchestrator_state_complete "$ORCHESTRATOR_STATE_FILE" "$number" "$session_id" "$pr_number"

  orchestrator_log "completed #$number: session ${session_id:-<none>}, PR #${pr_number:-<none>}, phase awaiting review"
  if [[ -n "$pr_number" ]]; then
    if gh issue comment "$number" --body "Started implementation. PR #$pr_number created."; then
      orchestrator_log "commented on #$number: Started implementation. PR #$pr_number created."
    else
      orchestrator_log "WARNING: failed to comment on #$number"
    fi
  else
    orchestrator_log "WARNING: no PR found for branch $branch on #$number; skipping issue comment"
  fi
}

orchestrator_poll_once() {
  local candidates active_count count line number title slug branch worktree
  candidates="$(ct_candidate_issues)"
  active_count="$(orchestrator_state_active_count "$ORCHESTRATOR_STATE_FILE")"
  count="$(printf '%s' "$candidates" | jq 'length')"

  orchestrator_log "poll: $count candidate(s), $active_count active, cap $ORCHESTRATOR_CONCURRENCY_CAP"

  while IFS= read -r line; do
    number="$(printf '%s' "$line" | jq -r '.number')"
    title="$(printf '%s' "$line" | jq -r '.title')"

    if [[ "$active_count" -ge "$ORCHESTRATOR_CONCURRENCY_CAP" ]]; then
      orchestrator_log "concurrency cap $ORCHESTRATOR_CONCURRENCY_CAP reached; leaving remaining tickets for the next poll"
      break
    fi

    if orchestrator_state_has_ticket "$ORCHESTRATOR_STATE_FILE" "$number"; then
      orchestrator_log "skip #$number ($title): already claimed"
      continue
    fi

    if ct_issue_is_blocked "$number"; then
      orchestrator_log "skip #$number ($title): blocked"
      continue
    fi

    slug="$(slugify "$title")"
    branch="ticket/$number-$slug"
    worktree="$ORCHESTRATOR_WORKTREE_PARENT/$number-$slug"
    if ! orchestrator_claim "$number" "$branch" "$worktree"; then
      orchestrator_state_remove "$ORCHESTRATOR_STATE_FILE" "$number"
      orchestrator_log "claim failed for #$number; removed from state"
      continue
    fi
    active_count=$((active_count + 1))

    if ! orchestrator_implement "$number" "$title" "$branch" "$worktree"; then
      orchestrator_state_remove "$ORCHESTRATOR_STATE_FILE" "$number"
      orchestrator_log "removed #$number from state after failed implementation"
      if [[ "${CT_WORKTREE_CREATED:-0}" == "1" ]]; then
        orchestrator_cleanup_worktree "$worktree" "$branch"
      else
        orchestrator_log "not cleaning up pre-existing worktree $worktree"
      fi
      active_count=$((active_count - 1))
    fi
  done < <(printf '%s' "$candidates" | jq -c '.[]')

  orchestrator_review_poll
}

orchestrator_daemon() {
  orchestrator_log "orchestrator started: poll every ${ORCHESTRATOR_POLL_INTERVAL_SECONDS}s, concurrency cap $ORCHESTRATOR_CONCURRENCY_CAP, state $ORCHESTRATOR_STATE_FILE"
  while true; do
    orchestrator_poll_once
    orchestrator_log "sleeping ${ORCHESTRATOR_POLL_INTERVAL_SECONDS}s until the next poll"
    sleep "$ORCHESTRATOR_POLL_INTERVAL_SECONDS"
  done
}

orchestrator_help() {
  echo "Usage:"
  echo "  ct-orchestrator.sh                 Run the daemon (systemd user service)"
  echo "  ct-orchestrator.sh once            Run a single poll cycle and exit"
  echo "  ct-orchestrator.sh help            Show this help"
}

main() {
  if ! command -v gh &>/dev/null; then
    echo "Error: gh (GitHub CLI) is not installed." >&2
    exit 1
  fi
  case "${1:-}" in
    once | --once)
      orchestrator_poll_once
      ;;
    help | --help | -h)
      orchestrator_help
      ;;
    "")
      orchestrator_daemon
      ;;
    *)
      orchestrator_help >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
