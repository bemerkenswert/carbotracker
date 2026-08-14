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
    '{ticket: $ticket, branch: $branch, worktree: $worktree, sessionId: null, prNumber: null, lastCommentAt: null, reviewFailures: 0, reviewNoticePosted: false, phase: "implementing", startedAt: $started}')"
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

orchestrator_state_mark_notice_posted() {
  local state_file="$1" number="$2"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" \
    '(.[] | select(.ticket == $n)) |= (.reviewNoticePosted = true)')"
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
        '[.[] | select(.title == $t)] | sort_by(.created) | reverse | .[0].id // empty' 2>/dev/null || true
}

orchestrator_pr_number_for_branch() {
  local branch="$1"
  # --state all so a merged or closed PR for the branch still counts: during
  # crash recovery the orchestrator must never open a duplicate PR for a
  # branch that already has one in any state.
  gh pr list --head "$branch" --state all --json number 2>/dev/null \
    | jq -r 'sort_by(.number) | reverse | .[0].number // empty' 2>/dev/null || true
}

orchestrator_pr_state() {
  local pr="$1"
  gh pr view "$pr" --json state --jq .state 2>/dev/null || true
}

orchestrator_pr_latest_comment_at() {
  local pr="$1" me inline reviews general latest
  # Review surfaces: inline threads (pulls/<n>/comments), top-level review
  # submissions (pulls/<n>/reviews), and general comments on the PR
  # conversation (issues/<n>/comments). The newest non-bot timestamp across
  # them is the last-known-comment watermark. Comments and reviews authored by
  # the pipeline carry the AI-source footer, so they are filtered out: the
  # agent's own replies never re-trigger the loop, and a review that arrives
  # mid-round stays visible. ISO-8601 timestamps sort lexically.
  me="_Created by carbotracker's agent skills._"
  inline="$(gh api "repos/{owner}/{repo}/pulls/$pr/comments" 2>/dev/null | jq -r --arg me "$me" '[.[] | select((.body // "") | contains($me) | not) | .created_at] | max // empty' 2>/dev/null || true)"
  reviews="$(gh api "repos/{owner}/{repo}/pulls/$pr/reviews" 2>/dev/null | jq -r --arg me "$me" '[.[] | select(.submitted_at != null) | select((.body // "") | contains($me) | not) | .submitted_at] | max // empty' 2>/dev/null || true)"
  general="$(gh api "repos/{owner}/{repo}/issues/$pr/comments" 2>/dev/null | jq -r --arg me "$me" '[.[] | select((.body // "") | contains($me) | not) | .created_at] | max // empty' 2>/dev/null || true)"
  latest="$inline"
  if [[ -n "$reviews" && ( -z "$latest" || "$reviews" > "$latest" ) ]]; then
    latest="$reviews"
  fi
  if [[ -n "$general" && ( -z "$latest" || "$general" > "$latest" ) ]]; then
    latest="$general"
  fi
  printf '%s' "$latest"
}

orchestrator_pr_post_comment() {
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
  if orchestrator_pr_post_comment "$pr_number" "$body"; then
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

orchestrator_awaiting_review_entries() {
  orchestrator_state_load "$ORCHESTRATOR_STATE_FILE" | jq -c '.[] | select(.phase == "awaiting review")'
}

orchestrator_review_poll() {
  local line number pr_number session_id worktree last_comment_at latest notice_posted
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
      # No session means the agent cannot resume with full context. Tell
      # Steffen once so the stale PR is visible, then stay quiet.
      notice_posted="$(printf '%s' "$line" | jq -r '.reviewNoticePosted // false')"
      if [[ "$notice_posted" != "true" ]]; then
        orchestrator_pr_post_comment "$pr_number" "Cannot auto-respond to reviews on PR #$pr_number: no opencode session was recorded for ticket #$number. A maintainer should handle this PR manually.
---
_Created by carbotracker's agent skills._"
        orchestrator_state_mark_notice_posted "$ORCHESTRATOR_STATE_FILE" "$number"
        orchestrator_log "review #$number: posted missing-session notice on PR #$pr_number"
      else
        orchestrator_log "skip review #$number: no session recorded (notice already posted)"
      fi
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
  done < <(orchestrator_awaiting_review_entries)
}

orchestrator_prune_ticket() {
  local number="$1" branch="$2" worktree="$3"
  orchestrator_cleanup_worktree "$worktree" "$branch"
  orchestrator_state_remove "$ORCHESTRATOR_STATE_FILE" "$number"
  orchestrator_log "pruned #$number: worktree removed, branch deleted, removed from state"
}

orchestrator_merge_poll() {
  local line number pr_number branch worktree state
  while IFS= read -r line; do
    number="$(printf '%s' "$line" | jq -r '.ticket')"
    pr_number="$(printf '%s' "$line" | jq -r '.prNumber')"
    branch="$(printf '%s' "$line" | jq -r '.branch')"
    worktree="$(printf '%s' "$line" | jq -r '.worktree')"

    if [[ -z "$pr_number" || "$pr_number" == "null" ]]; then
      orchestrator_log "skip merge #$number: no PR recorded"
      continue
    fi

    state="$(orchestrator_pr_state "$pr_number")"
    case "$state" in
      MERGED)
        orchestrator_log "merge detected: PR #$pr_number merged for #$number; closing issue"
        if gh issue edit "$number" --remove-label "$ORCHESTRATOR_IN_PROGRESS_LABEL" \
          && gh issue close "$number" --comment "PR #$pr_number merged. Issue closed."; then
          orchestrator_prune_ticket "$number" "$branch" "$worktree"
          orchestrator_log "closed issue #$number with merge comment"
        else
          orchestrator_log "WARNING: failed to close issue #$number; keeping entry to retry next poll"
        fi
        ;;
      CLOSED)
        # The PR was closed without merging: the work is rejected and the
        # ticket is no longer in flight. Prune the worktree/branch, then
        # escalate the issue to human triage — drop in-progress, add
        # needs-triage, and leave a comment naming the closed PR. The entry is
        # removed only once the escalation lands, so a transient gh failure
        # retries next poll instead of stranding an un-labelled issue.
        orchestrator_log "PR #$pr_number closed without merge for #$number; pruning worktree and escalating to triage"
        if gh issue edit "$number" --remove-label "$ORCHESTRATOR_IN_PROGRESS_LABEL" --add-label needs-triage \
          && gh issue comment "$number" --body "PR #$pr_number was closed without merging. Escalated to needs-triage for human review.
---
_Created by carbotracker's agent skills._"; then
          orchestrator_prune_ticket "$number" "$branch" "$worktree"
          orchestrator_log "escalated #$number to needs-triage and pruned worktree"
        else
          orchestrator_log "WARNING: failed to escalate #$number; keeping entry to retry next poll"
        fi
        ;;
      OPEN)
        orchestrator_log "merge #$number: PR #$pr_number still open"
        ;;
      *)
        orchestrator_log "WARNING: could not determine state of PR #$pr_number for #$number"
        ;;
    esac
  done < <(orchestrator_awaiting_review_entries)
}

orchestrator_create_pr() {
  local number="$1" title="$2" branch="$3"
  orchestrator_log "creating PR for #$number ($title)"
  if ! gh pr create --base main --head "$branch" --title "Implement $title (#$number)" \
      --body "Automated implementation of #$number.

---
_Created by carbotracker's agent skills._" >&2; then
    orchestrator_log "ERROR: gh pr create failed for #$number"
    return 1
  fi
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
    if ! orchestrator_create_pr "$number" "$title" "$branch"; then
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

orchestrator_run_opencode() {
  local worktree="$1" number="$2" log_file="$3"
  shift 3
  local prompt="/implement the issue is $number"
  if (cd "$worktree" && opencode run --auto "$@" "$prompt") 2>&1 | tee "$log_file"; then
    return 0
  fi
  orchestrator_log "ERROR: opencode run failed for #$number (attempt 1); retrying with --continue"
  if (cd "$worktree" && opencode run --auto --continue "$prompt") 2>&1 | tee -a "$log_file"; then
    return 0
  fi
  orchestrator_log "ERROR: opencode run failed for #$number on the retry as well"
  return 1
}

orchestrator_escalate_failure() {
  local number="$1" branch="$2" worktree="$3" log_file="$4" reason="$5"
  local tail snippet body
  tail="$(tail -n 30 "$log_file" 2>/dev/null || true)"
  snippet=""
  if [[ -n "$tail" ]]; then
    snippet="$(printf '\n```\n%s\n```' "$tail")"
  fi
  body="Automated implementation of #$number failed: $reason. Escalated to needs-triage for human review.
${snippet}
---
_Created by carbotracker's agent skills._"
  if gh issue edit "$number" --remove-label "$ORCHESTRATOR_IN_PROGRESS_LABEL" --remove-label ticket --add-label needs-triage \
    && gh issue comment "$number" --body "$body"; then
    orchestrator_prune_ticket "$number" "$branch" "$worktree"
    orchestrator_log "escalated #$number to needs-triage after $reason; pruned worktree and removed from state"
    return 0
  fi
  orchestrator_log "WARNING: failed to escalate #$number; leaving entry in state for the poll loop to un-claim"
  return 1
}

orchestrator_state_complete_and_comment() {
  local number="$1" session_id="$2" pr_number="$3"
  orchestrator_state_complete "$ORCHESTRATOR_STATE_FILE" "$number" "$session_id" "$pr_number"
  orchestrator_log "completed #$number: session ${session_id:-<none>}, PR #${pr_number:-<none>}, phase awaiting review"
  if [[ -n "$pr_number" ]]; then
    if gh issue comment "$number" --body "Started implementation. PR #$pr_number created."; then
      orchestrator_log "commented on #$number: Started implementation. PR #$pr_number created."
    else
      orchestrator_log "WARNING: failed to comment on #$number"
    fi
  else
    orchestrator_log "WARNING: no PR found for #$number; skipping issue comment"
  fi
}

orchestrator_finish_implementation() {
  local number="$1" title="$2" branch="$3" worktree="$4" session_title="$5"
  local session_id pr_number
  session_id="$(orchestrator_opencode_session_id "$session_title")"
  if ! pr_number="$(orchestrator_push_and_open_pr "$number" "$title" "$branch" "$worktree")"; then
    orchestrator_log "ERROR: push or PR creation failed for #$number"
    return 1
  fi
  orchestrator_state_complete_and_comment "$number" "$session_id" "$pr_number"
}

orchestrator_implement() {
  local number="$1" title="$2" branch="$3" worktree="$4"
  local session_title session_id pr_number log_file

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
  log_file="$(mktemp "${TMPDIR:-/tmp}/carbotracker-opencode.XXXXXX")"
  orchestrator_log "launching opencode for #$number (title $session_title)"
  if ! orchestrator_run_opencode "$worktree" "$number" "$log_file" --title "$session_title"; then
    orchestrator_escalate_failure "$number" "$branch" "$worktree" "$log_file" "opencode exited non-zero twice"
    rm -f "$log_file"
    return 1
  fi
  rm -f "$log_file"

  orchestrator_finish_implementation "$number" "$title" "$branch" "$worktree" "$session_title"
}

# ---- Crash recovery ----

orchestrator_branch_pushed() {
  local branch="$1"
  git ls-remote origin "refs/heads/$branch" 2>/dev/null | grep -q .
}

orchestrator_unpushed_commit_count() {
  local worktree="$1" branch="$2"
  local base="origin/main"
  if git -C "$worktree" rev-parse --verify -q "refs/remotes/origin/$branch" >/dev/null 2>&1; then
    base="refs/remotes/origin/$branch"
  fi
  git -C "$worktree" rev-list --count "$base..HEAD" 2>/dev/null || echo 0
}

orchestrator_worktree_has_work() {
  local worktree="$1" branch="$2"
  if [[ ! -d "$worktree" ]]; then
    return 1
  fi
  if ! git -C "$worktree" rev-parse --git-dir >/dev/null 2>&1; then
    return 1
  fi
  if [[ -n "$(git -C "$worktree" status --porcelain 2>/dev/null)" ]]; then
    return 0
  fi
  if [[ "$(orchestrator_unpushed_commit_count "$worktree" "$branch")" -gt 0 ]]; then
    return 0
  fi
  return 1
}

orchestrator_resume_implementation() {
  local number="$1" title="$2" branch="$3" worktree="$4" session_id="$5"
  local session_title log_file run_flags
  session_title="carbotracker-ticket-$number"
  orchestrator_log "resuming implementation #$number in $worktree"

  if [[ -n "$session_id" ]]; then
    run_flags=(--session "$session_id")
  else
    run_flags=(--continue)
  fi
  log_file="$(mktemp "${TMPDIR:-/tmp}/carbotracker-opencode.XXXXXX")"
  if ! orchestrator_run_opencode "$worktree" "$number" "$log_file" "${run_flags[@]}"; then
    orchestrator_escalate_failure "$number" "$branch" "$worktree" "$log_file" "opencode exited non-zero twice while resuming"
    rm -f "$log_file"
    return 1
  fi
  rm -f "$log_file"

  orchestrator_finish_implementation "$number" "$title" "$branch" "$worktree" "$session_title"
}

orchestrator_recover_pushed_branch() {
  local number="$1" title="$2" branch="$3" worktree="$4" session_id="$5"
  local pr_number
  if [[ -z "$session_id" ]]; then
    session_id="$(orchestrator_opencode_session_id "carbotracker-ticket-$number")"
  fi
  pr_number="$(orchestrator_pr_number_for_branch "$branch")"
  if [[ -z "$pr_number" ]]; then
    if ! orchestrator_create_pr "$number" "$title" "$branch"; then
      return 1
    fi
    pr_number="$(orchestrator_pr_number_for_branch "$branch")"
  fi
  orchestrator_state_complete_and_comment "$number" "$session_id" "$pr_number"
}

orchestrator_drop_unrecoverable() {
  local number="$1" branch="$2" worktree="$3"
  orchestrator_cleanup_worktree "$worktree" "$branch"
  if ! gh issue comment "$number" --body "The orchestrator found no recoverable work for this ticket after a restart. It has been cleaned up and removed from the pipeline. Re-tag with ready-for-agent to retry.
---
_Created by carbotracker's agent skills._"; then
    orchestrator_log "WARNING: failed to comment on #$number; keeping entry to retry on the next restart"
    return 1
  fi
  # Un-claim on GitHub: drop in-progress so the issue is no longer marked as
  # being worked, but do not re-add ready-for-agent — the comment above is the
  # handoff to a human, and an automatic re-claim could loop on a broken ticket.
  gh issue edit "$number" --remove-label "$ORCHESTRATOR_IN_PROGRESS_LABEL" 2>/dev/null \
    || orchestrator_log "WARNING: failed to remove $ORCHESTRATOR_IN_PROGRESS_LABEL from #$number"
  orchestrator_state_remove "$ORCHESTRATOR_STATE_FILE" "$number"
  orchestrator_log "recovered #$number: nothing recoverable; cleaned up, removed from state"
}

orchestrator_reconcile() {
  local line number title branch worktree session_id pr_number
  orchestrator_log "reconciling state file against observable git facts"
  while IFS= read -r line; do
    number="$(printf '%s' "$line" | jq -r '.ticket')"
    branch="$(printf '%s' "$line" | jq -r '.branch')"
    worktree="$(printf '%s' "$line" | jq -r '.worktree')"
    session_id="$(printf '%s' "$line" | jq -r '.sessionId // ""')"
    if [[ "$session_id" == "null" ]]; then
      session_id=""
    fi
    title="$(gh issue view "$number" --json title --jq .title 2>/dev/null || true)"
    if [[ -z "$title" ]]; then
      # gh is transiently down (or the issue is gone): do not destroy state —
      # leave the entry untouched so the next restart re-inspects it.
      orchestrator_log "WARNING: could not resolve issue #$number; skipping entry until the next restart"
      continue
    fi

    pr_number="$(orchestrator_pr_number_for_branch "$branch")"
    if [[ -n "$pr_number" ]]; then
      if [[ -z "$session_id" ]]; then
        session_id="$(orchestrator_opencode_session_id "carbotracker-ticket-$number")"
      fi
      orchestrator_log "recovered #$number: PR #$pr_number exists for branch $branch; setting phase awaiting review"
      orchestrator_state_complete "$ORCHESTRATOR_STATE_FILE" "$number" "$session_id" "$pr_number"
      continue
    fi

    if orchestrator_branch_pushed "$branch"; then
      orchestrator_log "recovered #$number: branch $branch pushed but no PR; creating the PR"
      if orchestrator_recover_pushed_branch "$number" "$title" "$branch" "$worktree" "$session_id"; then
        orchestrator_log "recovered #$number: PR created for pushed branch $branch"
      else
        orchestrator_log "ERROR: could not create a PR for recovered #$number"
      fi
      continue
    fi

    if orchestrator_worktree_has_work "$worktree" "$branch"; then
      orchestrator_log "recovered #$number: worktree has unpushed work; resuming implementation"
      if ! orchestrator_resume_implementation "$number" "$title" "$branch" "$worktree" "$session_id"; then
        orchestrator_log "ERROR: could not resume implementation for #$number"
      fi
      continue
    fi

    orchestrator_log "recovered #$number: nothing recoverable; cleaning up"
    orchestrator_drop_unrecoverable "$number" "$branch" "$worktree"
  done < <(orchestrator_state_load "$ORCHESTRATOR_STATE_FILE" | jq -c '.[]')
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
      if orchestrator_state_has_ticket "$ORCHESTRATOR_STATE_FILE" "$number"; then
        # Non-opencode failure (worktree/npm/push/PR): un-claim and clean up,
        # the next poll starts the ticket over. When opencode failed twice the
        # implementation already escalated and pruned, so the entry is gone.
        orchestrator_state_remove "$ORCHESTRATOR_STATE_FILE" "$number"
        orchestrator_log "removed #$number from state after failed implementation"
        if [[ "${CT_WORKTREE_CREATED:-0}" == "1" ]]; then
          orchestrator_cleanup_worktree "$worktree" "$branch"
        else
          orchestrator_log "not cleaning up pre-existing worktree $worktree"
        fi
      else
        orchestrator_log "#$number already escalated and pruned after failed implementation"
      fi
      active_count=$((active_count - 1))
    fi
  done < <(printf '%s' "$candidates" | jq -c '.[]')

  orchestrator_merge_poll
  orchestrator_review_poll
}

orchestrator_daemon() {
  orchestrator_log "orchestrator started: poll every ${ORCHESTRATOR_POLL_INTERVAL_SECONDS}s, concurrency cap $ORCHESTRATOR_CONCURRENCY_CAP, state $ORCHESTRATOR_STATE_FILE"
  orchestrator_reconcile
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
      orchestrator_reconcile
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
