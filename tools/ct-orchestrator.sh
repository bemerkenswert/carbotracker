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

CONF_FILE="${CT_ORCHESTRATOR_CONF:-$SCRIPT_DIR/ct-orchestrator.conf}"
if [[ -f "$CONF_FILE" ]]; then
  source "$CONF_FILE"
fi

ORCHESTRATOR_POLL_INTERVAL_SECONDS="${ENV_ORCHESTRATOR_POLL_INTERVAL_SECONDS:-${ORCHESTRATOR_POLL_INTERVAL_SECONDS:-300}}"
ORCHESTRATOR_CONCURRENCY_CAP="${ENV_ORCHESTRATOR_CONCURRENCY_CAP:-${ORCHESTRATOR_CONCURRENCY_CAP:-3}}"
ORCHESTRATOR_STATE_FILE="${ENV_ORCHESTRATOR_STATE_FILE:-${ORCHESTRATOR_STATE_FILE:-$HOME/.local/state/carbotracker/orchestrator.json}}"
ORCHESTRATOR_WORKTREE_PARENT="${ENV_ORCHESTRATOR_WORKTREE_PARENT:-${ORCHESTRATOR_WORKTREE_PARENT:-$HOME/git/worktrees/carbotracker}}"
ORCHESTRATOR_ISSUE_LABELS="${ENV_ORCHESTRATOR_ISSUE_LABELS:-${ORCHESTRATOR_ISSUE_LABELS:-ready-for-agent,ticket}}"

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
    '{ticket: $ticket, branch: $branch, worktree: $worktree, sessionId: null, prNumber: null, phase: "implementing", startedAt: $started}')"
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

orchestrator_claim() {
  local number="$1" branch="$2" worktree="$3"
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
    orchestrator_claim "$number" "$branch" "$worktree"
    active_count=$((active_count + 1))

    if ! orchestrator_implement "$number" "$title" "$branch" "$worktree"; then
      orchestrator_state_remove "$ORCHESTRATOR_STATE_FILE" "$number"
      orchestrator_log "removed #$number from state after failed implementation"
      orchestrator_cleanup_worktree "$worktree" "$branch"
      active_count=$((active_count - 1))
    fi
  done < <(printf '%s' "$candidates" | jq -c '.[]')
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
