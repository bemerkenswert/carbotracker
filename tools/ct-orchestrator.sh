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
ENV_ORCHESTRATOR_IMPLEMENTATION_RETRIES="${ORCHESTRATOR_IMPLEMENTATION_RETRIES-}"
ENV_ORCHESTRATOR_MERGE_RETRIES="${ORCHESTRATOR_MERGE_RETRIES-}"
ENV_ORCHESTRATOR_MODEL="${ORCHESTRATOR_MODEL-}"

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
ORCHESTRATOR_IMPLEMENTATION_RETRIES="${ENV_ORCHESTRATOR_IMPLEMENTATION_RETRIES:-${ORCHESTRATOR_IMPLEMENTATION_RETRIES:-3}}"
# The bound on agent-driven conflict-resolution merges in the merge poll. At
# the cap the daemon posts a "needs a human" comment and stops auto-merging
# the PR; only a human can unstick it.
ORCHESTRATOR_MERGE_RETRIES="${ENV_ORCHESTRATOR_MERGE_RETRIES:-${ORCHESTRATOR_MERGE_RETRIES:-3}}"
# The model every headless opencode run uses, pinned so the agent pipeline
# never drifts to opencode's default (which can be a pricier model).
ORCHESTRATOR_MODEL="${ENV_ORCHESTRATOR_MODEL:-${ORCHESTRATOR_MODEL:-opencode-go/deepseek-v4-flash}}"

orchestrator_ensure_labels() {
  gh label create suspect-diff --description "The implementation changed a feature other than the one declared by the ticket" --color D93F0B --force >/dev/null 2>&1 \
    || orchestrator_log "WARNING: could not create or update suspect-diff label"
  gh label create human-approved --description "A human has approved an orchestrator warning" --color 0E8A16 --force >/dev/null 2>&1 \
    || orchestrator_log "WARNING: could not create or update human-approved label"
}

orchestrator_log() {
  # Logs go to stderr so functions that print a value on stdout (e.g. the
  # state helpers or push_and_open_pr) never pollute it with log lines.
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
}

# Every agent-authored body carries the AI-source footer so a colleague reading
# a thread can tell the agent's reply from the human's.
ORCHESTRATOR_AI_FOOTER=$'\n---\n_Created by carbotracker\'s agent skills._'

# A regex matching the AI-source footer when it ends a body (allowing trailing
# whitespace). Unlike a bare `contains`, it only fires when the footer is the
# final line, so a human quoting an agent reply mid-body is not misread as the
# pipeline's own output.
ORCHESTRATOR_AI_FOOTER_END_RE="_Created by carbotracker's agent skills\._[[:space:]]*\$"

orchestrator_strip_ai_footer() {
  # Remove every trailing AI-source footer block (and the whitespace around it)
  # from a reply body, so a caller can append exactly one. Idempotent — if the
  # skill already embedded one (or two) footers, all are removed.
  printf '%s' "$1" | sed -zE "s/([[:space:]]*---[[:space:]]*_Created by carbotracker's agent skills\._){1,}[[:space:]]*\$//"
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
    '{ticket: $ticket, branch: $branch, worktree: $worktree, sessionId: null, prNumber: null, lastCommentAt: null, reviewFailures: 0, failureCount: 0, mergeFailures: 0, reviewNoticePosted: false, reviewNeedsHuman: false, mergeNoticePosted: false, phase: "implementing", startedAt: $started}')"
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

orchestrator_state_phase() {
  local state_file="$1" number="$2"
  orchestrator_state_load "$state_file" | jq -r --argjson n "$number" '[.[] | select(.ticket == $n) | .phase][0] // empty'
}

orchestrator_state_mark_failed() {
  local state_file="$1" number="$2"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" \
    '(.[] | select(.ticket == $n)) |= (.failureCount = ((.failureCount // 0) + 1) | .phase = "failed")')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_state_failure_count() {
  local state_file="$1" number="$2"
  orchestrator_state_load "$state_file" \
    | jq -r --argjson n "$number" '[.[] | select(.ticket == $n) | .failureCount][0] // 0'
}

orchestrator_state_retry_failed() {
  local state_file="$1" number="$2"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" \
    '(.[] | select(.ticket == $n and .phase == "failed")) |= (.phase = "implementing")')"
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

orchestrator_state_set_review_needs_human() {
  local state_file="$1" number="$2" flag="$3"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" --argjson f "$flag" \
    '(.[] | select(.ticket == $n)) |= (.reviewNeedsHuman = $f)')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_state_merge_failures() {
  local state_file="$1" number="$2"
  orchestrator_state_load "$state_file" \
    | jq -r --argjson n "$number" '[.[] | select(.ticket == $n) | .mergeFailures][0] // 0'
}

orchestrator_state_set_merge_failures() {
  local state_file="$1" number="$2" count="$3"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" --argjson c "$count" \
    '(.[] | select(.ticket == $n)) |= (.mergeFailures = $c)')"
  orchestrator_state_write "$state_file" "$state"
}

orchestrator_state_merge_notice_posted() {
  local state_file="$1" number="$2"
  orchestrator_state_load "$state_file" \
    | jq -r --argjson n "$number" '[.[] | select(.ticket == $n) | .mergeNoticePosted][0] // false'
}

orchestrator_state_set_merge_notice_posted() {
  local state_file="$1" number="$2" flag="$3"
  local state
  state="$(orchestrator_state_load "$state_file")"
  state="$(printf '%s' "$state" | jq --argjson n "$number" --argjson f "$flag" \
    '(.[] | select(.ticket == $n)) |= (.mergeNoticePosted = $f)')"
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
  if [[ "$(orchestrator_state_phase "$ORCHESTRATOR_STATE_FILE" "$number")" == "failed" ]]; then
    orchestrator_state_retry_failed "$ORCHESTRATOR_STATE_FILE" "$number"
  else
    orchestrator_state_add "$ORCHESTRATOR_STATE_FILE" "$number" "$branch" "$worktree"
  fi
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

orchestrator_pr_field() {
  local pr="$1" field="$2"
  gh pr view "$pr" --json "$field" --jq ".$field" 2>/dev/null || true
}

orchestrator_pr_state() {
  orchestrator_pr_field "$1" state
}

orchestrator_pr_merge_state() {
  orchestrator_pr_field "$1" mergeStateStatus
}

# The PR's labels, one name per line, read fresh from the live GitHub state on
# every call — the auto-merge skip condition must never be cached, because a
# maintainer approving a flagged PR unblocks it on the next poll. A failed read
# propagates its non-zero exit so callers can fail closed like the merge gate.
orchestrator_pr_labels() {
  local pr="$1"
  gh pr view "$pr" --json labels --jq '.[].name' 2>/dev/null
}

# True when a newline-separated label list carries the suspect-diff label
# without human-approved — i.e. the merge gate would block this PR.
orchestrator_labels_are_suspect() {
  local labels="$1"
  printf '%s\n' "$labels" | grep -Fxq "suspect-diff" || return 1
  printf '%s\n' "$labels" | grep -Fxq "human-approved" && return 1
  return 0
}

orchestrator_pr_latest_comment_at() {
  local pr="$1" me inline reviews general latest
  # Review surfaces: inline threads (pulls/<n>/comments), top-level review
  # submissions (pulls/<n>/reviews), and general comments on the PR
  # conversation (issues/<n>/comments). The newest non-bot timestamp across
  # them is the last-known-comment watermark. A comment is the pipeline's own
  # only when the AI-source footer ends its body (a bare `contains` would also
  # match a human quote-reply that embeds a quoted footer mid-body); a review
  # submission with an empty body carries no human signal and is skipped too.
  # ISO-8601 timestamps sort lexically.
  me="$ORCHESTRATOR_AI_FOOTER_END_RE"
  inline="$(gh api "repos/{owner}/{repo}/pulls/$pr/comments" 2>/dev/null | jq -r --arg me "$me" '[.[] | select((.body // "") | test($me) | not) | .created_at] | max // empty' 2>/dev/null || true)"
  reviews="$(gh api "repos/{owner}/{repo}/pulls/$pr/reviews" 2>/dev/null | jq -r --arg me "$me" '[.[] | select(.submitted_at != null) | select((.body // "") | test($me) | not) | select((.body // "") | test("[^[:space:]]")) | .submitted_at] | max // empty' 2>/dev/null || true)"
  general="$(gh api "repos/{owner}/{repo}/issues/$pr/comments" 2>/dev/null | jq -r --arg me "$me" '[.[] | select((.body // "") | test($me) | not) | .created_at] | max // empty' 2>/dev/null || true)"
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

orchestrator_check_suspect_diff() {
  local number="$1" pr_number="$2" worktree="$3" body features declared
  body="$(ct_issue_body "$number")"
  declared="$(ct_issue_feature "$body")"
  [[ -n "$declared" && -n "$pr_number" ]] || return 0
  if ! ct_feature_diff_is_suspect "$worktree" "$body"; then
    return 0
  fi
  features="$(ct_changed_features "$worktree" | tr '\n' ',' | sed 's/,$//')"
  if gh pr edit "$pr_number" --add-label suspect-diff; then
    orchestrator_log "flagged #$number / PR #$pr_number as suspect-diff (declared $declared; changed $features)"
  else
    orchestrator_log "WARNING: failed to add suspect-diff label to PR #$pr_number"
  fi
  if ! gh pr comment "$pr_number" --body "Warning: ticket #$number declares feature \`$declared\`, but its diff changes feature folder(s) \`$features\` without touching \`$declared\`. The PR remains open for human review.
---
_Created by carbotracker's agent skills._"; then
    orchestrator_log "WARNING: failed to post suspect-diff warning on PR #$pr_number"
  fi
}

# The changed file paths of an existing open PR (its diff against the base).
orchestrator_pr_files() {
  local pr="$1"
  gh pr view "$pr" --json files --jq '.[].path' 2>/dev/null || true
}

# Compare the new PR's changed files against every open PR's and, on overlap,
# post a warning naming the overlapping PR(s) and the shared files. Overlap is
# expected during migrations, so it only warns — it never blocks or queues.
# Non-fatal: any gh/git failure leaves the PR alone for the next observer.
orchestrator_check_overlap() {
  local number="$1" pr_number="$2" worktree="$3"
  local files pr candidate shared overlaps count shared_list
  # The branch's own files are read from the worktree so the check does not
  # depend on the just-created PR's file list having propagated to the API.
  files="$(ct_changed_files "$worktree")"
  [[ -n "$files" ]] || return 0
  count=0
  overlaps=""
  while IFS= read -r pr; do
    [[ -n "$pr" && "$pr" != "$pr_number" ]] || continue
    candidate="$(orchestrator_pr_files "$pr")"
    [[ -n "$candidate" ]] || continue
    shared="$(ct_shared_files "$files" "$candidate")"
    [[ -n "$shared" ]] || continue
    count=$((count + 1))
    shared_list="$(printf '%s\n' "$shared" | awk 'NF {printf "%s`%s`", sep, $0; sep=", "}')"
    overlaps="${overlaps}
- PR #$pr: $shared_list"
  done < <(gh pr list --state open --json number --jq '.[].number' 2>/dev/null || true)
  if [[ "$count" -eq 0 ]]; then
    return 0
  fi
  if orchestrator_pr_post_comment "$pr_number" "Warning: PR #$pr_number changes files that overlap with other open PR(s), so the merges may conflict:
$overlaps
---
_Created by carbotracker's agent skills._"; then
    orchestrator_log "warned overlap on #$number / PR #$pr_number: $count other open PR(s) share changed files"
  else
    orchestrator_log "WARNING: failed to post overlap warning on PR #$pr_number"
  fi
}

orchestrator_pr_reply_to_thread() {
  local pr="$1" comment_id="$2" body="$3"
  gh api "repos/{owner}/{repo}/pulls/$pr/comments/$comment_id/replies" -f body="$body" >/dev/null 2>&1
}

# Run one headless opencode session in the worktree — the ticket's original
# session — logging the launch. Both the analyze and implement steps reuse it;
# the caller's extra env (e.g. ORCHESTRATOR_REVIEW_PLAN_FILE) is inherited.
orchestrator_review_run_session() {
  local number="$1" session_id="$2" worktree="$3" prompt="$4"
  orchestrator_log "review #$number: launching $prompt (session $session_id)"
  # Same stdin isolation as the implement run: a review run must never drain a
  # caller's pipe (review_poll streams its entries from a process substitution).
  (cd "$worktree" && opencode run --auto --model "$ORCHESTRATOR_MODEL" --session "$session_id" "$prompt" < /dev/null)
}

# Analyze phase of the review round: run the headless /review-comments skill in
# the ticket's session. The skill's entire output is the plan file it writes to
# ORCHESTRATOR_REVIEW_PLAN_FILE (set per invocation) — it never asks, never
# posts, and never implements. Success here only means opencode exited 0; the
# plan still has to be read and applied by the act phase.
orchestrator_review_analyze() {
  local number="$1" session_id="$2" pr_number="$3" worktree="$4" plan_file="$5"
  local prompt
  # The prompt names both the PR and its ticket so the resumed session's own
  # context (its original "implement issue N" history and any prior PR
  # references) cannot be misread as the review's subject.
  prompt="/review-comments on PR #$pr_number (ticket #$number) headless: do not ask, do not post, do not implement — write the plan file"
  ORCHESTRATOR_REVIEW_PLAN_FILE="$plan_file" orchestrator_review_run_session "$number" "$session_id" "$worktree" "$prompt"
}

# Act phase of the review round: read the plan file, validate it against the
# review-comments schema, and apply it. Comments classified `implement` are
# applied by resuming the original opencode session with a comment-scoped
# /implement prompt — the agent makes the change (one commit per comment),
# pushes, replies on the thread citing the commit, and resolves each inline
# thread via the resolveReviewThread GraphQL mutation (never bash); the act
# step then verifies (read-only) that every implement comment was resolved and
# replied to before the watermark can move. The remaining comments get their
# reply posted on the thread with the AI-source footer (a general comment — a
# null path — gets a plain PR-conversation reply). The watermark advances only
# here, never in analyze. When the plan needs a human (a pushback or question),
# polling is paused for the PR and a maintainer notice is posted. Analyze
# failure, an empty plan, or a malformed or schema-invalid plan returns
# non-zero and keeps the watermark, so the round falls through to the
# retry/escalate path. A failed or unverifiable implement step also keeps the
# watermark.
orchestrator_review_act() {
  local number="$1" pr_number="$2" plan_file="$3" session_id="$4" worktree="$5"
  local schema count needs_human i entry comment_id path type reply body latest posted implement_count
  schema="$SCRIPT_DIR/../.agents/skills/review-comments/review-plan.schema.json"
  if [[ ! -f "$plan_file" ]] \
    || ! node "$SCRIPT_DIR/ct-review-plan-validate.js" "$schema" "$plan_file" >/dev/null 2>&1; then
    orchestrator_log "review act #$number: plan $plan_file is missing, malformed, or schema-invalid; keeping the watermark"
    return 1
  fi
  count="$(jq '.comments | length' "$plan_file")"
  if [[ "$count" -eq 0 ]]; then
    orchestrator_log "review act #$number: plan is empty; keeping the watermark"
    return 1
  fi
  implement_count="$(jq '[.comments[] | select(.type == "implement")] | length' "$plan_file")"
  if [[ "$implement_count" -gt 0 ]]; then
    # The implement step runs before any bash reply is posted: if it fails the
    # round fails and retries, and the retry resumes the same session with its
    # own partial work visible — so a reply is never posted twice.
    if ! orchestrator_review_implement "$number" "$session_id" "$pr_number" "$worktree" "$plan_file"; then
      orchestrator_log "ERROR: implement step failed on PR #$pr_number; keeping the watermark"
      return 1
    fi
  fi
  needs_human="$(jq -r '.needsHuman' "$plan_file")"
  posted=0
  for ((i = 0; i < count; i++)); do
    entry="$(jq -c ".comments[$i]" "$plan_file")"
    comment_id="$(printf '%s' "$entry" | jq -r '.commentId')"
    path="$(printf '%s' "$entry" | jq -r '.path')"
    type="$(printf '%s' "$entry" | jq -r '.type')"
    reply="$(printf '%s' "$entry" | jq -r '.reply')"
    if [[ "$type" == "implement" ]]; then
      # The implement run already replied on the thread, citing its commit.
      continue
    fi
    reply="$(orchestrator_strip_ai_footer "$reply")"
    body="${reply}
${ORCHESTRATOR_AI_FOOTER}"
    if [[ "$path" == "null" || -z "$path" ]]; then
      if orchestrator_pr_post_comment "$pr_number" "$body"; then
        posted=$((posted + 1))
        orchestrator_log "review act #$number: replied to general comment $comment_id on PR #$pr_number ($type)"
      else
        orchestrator_log "WARNING: failed to reply to general comment $comment_id on PR #$pr_number"
      fi
    else
      if orchestrator_pr_reply_to_thread "$pr_number" "$comment_id" "$body"; then
        posted=$((posted + 1))
        orchestrator_log "review act #$number: replied to thread comment $comment_id on PR #$pr_number ($type)"
      else
        orchestrator_log "WARNING: failed to reply to thread comment $comment_id on PR #$pr_number"
      fi
    fi
  done
  if [[ "$posted" -eq 0 && "$implement_count" -eq 0 ]]; then
    orchestrator_log "ERROR: no reply posted on PR #$pr_number; keeping the watermark"
    return 1
  fi
  latest="$(orchestrator_pr_latest_comment_at "$pr_number")"
  if [[ -n "$latest" ]]; then
    orchestrator_state_mark_reviewed "$ORCHESTRATOR_STATE_FILE" "$number" "$latest"
    orchestrator_log "review act #$number: advanced watermark to $latest on PR #$pr_number"
  fi
  if [[ "$needs_human" == "true" ]]; then
    orchestrator_state_set_review_needs_human "$ORCHESTRATOR_STATE_FILE" "$number" true
    body="Some review comments on PR #$pr_number need a human decision. The orchestrator has paused automated replies on this PR; please handle the open threads.${ORCHESTRATOR_AI_FOOTER}"
    if orchestrator_pr_post_comment "$pr_number" "$body"; then
      orchestrator_log "review act #$number: needs human decision; paused polling and posted notice on PR #$pr_number"
    else
      orchestrator_log "WARNING: failed to post maintainer notice on PR #$pr_number"
    fi
  fi
  return 0
}

# The implement step of the review round: resume the ticket's original opencode
# session with a comment-scoped /implement prompt. The agent applies only the
# changes the implement comments request — one commit per comment — then pushes
# the branch, replies on each thread citing the commit that implements it, and
# resolves each inline thread via the resolveReviewThread GraphQL mutation
# (never bash). The prompt mandates the AI-source footer on every reply, so the
# agent's own replies never re-trigger the loop. The step then verifies the
# outcome before the watermark can advance: every inline implement comment must
# sit in a resolved thread AND have a footer-bearing reply, and a general
# implement comment (no thread) must have gained a new footer-bearing reply on
# the PR conversation — never a bare exit-0. Failure here keeps the watermark
# so the round retries.
orchestrator_review_implement() {
  local number="$1" session_id="$2" pr_number="$3" worktree="$4" plan_file="$5"
  local descriptions prompt before_general_ids
  descriptions="$(orchestrator_review_implement_descriptions "$plan_file")"
  prompt="/implement the review comments on PR #$pr_number (ticket #$number): $descriptions. Apply ONLY the changes these comments request — one commit per comment — then push the branch, reply on each thread citing the commit that implements it (append the AI-source footer '_Created by carbotracker's agent skills._' to every reply), and resolve each inline thread via the resolveReviewThread GraphQL mutation."
  before_general_ids="$(orchestrator_pr_agent_general_comment_ids "$worktree" "$pr_number")"
  if ! orchestrator_review_run_session "$number" "$session_id" "$worktree" "$prompt"; then
    orchestrator_log "ERROR: review implement run failed on PR #$pr_number; keeping the watermark"
    return 1
  fi
  if ! orchestrator_review_implement_verified "$worktree" "$pr_number" "$plan_file" "$before_general_ids"; then
    orchestrator_log "ERROR: implement comments not applied or resolved on PR #$pr_number; keeping the watermark"
    return 1
  fi
  orchestrator_log "review #$number: implement comments applied and threads resolved on PR #$pr_number"
  return 0
}

# A human-readable, comment-scoped description of each implement comment in the
# plan, e.g. `comment 3788850732 at apps/carbotracker/src/app/app.component.ts:42
# — "Will rename the selector."`, so the resumed session knows exactly which
# points to apply.
orchestrator_review_implement_descriptions() {
  local plan_file="$1"
  jq -r '[.comments[] | select(.type == "implement") |
    (if .path == null then "comment \(.commentId) (a general PR comment)" else "comment \(.commentId) at \(.path):\(.line)" end) as $loc |
    "\($loc) — \"\(.reply)\""] | join(" | ")' "$plan_file"
}

# Verify the implement step actually landed, never trusting the run's exit code
# alone. Every inline implement comment must sit in a resolved thread (read
# from GraphQL) and have a footer-bearing reply on it (the reply is what cites
# the commit); a general implement comment has no thread, so it must have
# gained a footer-bearing reply on the PR conversation that was not there
# before the run. Nothing here resolves anything — resolution is always the
# agent's resolveReviewThread mutation inside the implement session.
orchestrator_review_implement_verified() {
  local worktree="$1" pr="$2" plan_file="$3" before_ids="$4"
  local state replies
  state="$(orchestrator_review_threads_state "$worktree" "$pr")" || return 1
  replies="$(cd "$worktree" && gh api "repos/{owner}/{repo}/pulls/$pr/comments" 2>/dev/null || true)"
  if [[ -z "$replies" ]]; then
    return 1
  fi
  jq -e --argjson state "$state" --argjson replies "$replies" \
    --arg footer "$ORCHESTRATOR_AI_FOOTER_END_RE" '
    [.comments[] | select(.type == "implement" and .path != null) | .commentId as $cid |
      ($state[($cid | tostring)] == true) and
      any($replies[]; (.in_reply_to_id == $cid) and ((.body // "") | test($footer)))]
    | all' "$plan_file" >/dev/null 2>&1 || return 1
  if jq -e '[.comments[] | select(.type == "implement" and .path == null)] | length > 0' "$plan_file" >/dev/null 2>&1; then
    if ! orchestrator_pr_has_new_agent_general_comment "$worktree" "$pr" "$before_ids"; then
      return 1
    fi
  fi
  return 0
}

# Read the PR's inline threads and their comments via a read-only GraphQL
# query, emitting a JSON object mapping review-comment databaseId to whether
# its thread is resolved. Runs from the worktree, which is a git clone with the
# repo's remote (so gh can infer owner/repo); reads never resolve threads — the
# resolveReviewThread mutation never runs here.
orchestrator_review_threads_state() {
  local worktree="$1" pr="$2"
  local owner_repo owner repo out
  owner_repo="$(cd "$worktree" && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
  if [[ -z "$owner_repo" || "$owner_repo" == "null" ]]; then
    return 1
  fi
  owner="${owner_repo%%/*}"
  repo="${owner_repo#*/}"
  out="$(cd "$worktree" && gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){
    repository(owner:$owner,name:$repo){
      pullRequest(number:$pr){
        reviewThreads(first:100){
          nodes{ id isResolved comments(first:100){ nodes{ databaseId } } }
        }
      }
    }
  }' -f owner="$owner" -f repo="$repo" -F pr="$pr" 2>/dev/null)" || return 1
  printf '%s' "$out" | jq -c 'reduce .data.repository.pullRequest.reviewThreads.nodes[] as $t ({};
    reduce $t.comments.nodes[] as $c (.;
      .[($c.databaseId | tostring)] = $t.isResolved))' 2>/dev/null || return 1
}

# The set of agent-authored PR-conversation comment ids (a comma-joined list).
# Used to verify a general implement comment gained a reply during the run.
orchestrator_pr_agent_general_comment_ids() {
  local worktree="$1" pr="$2"
  (cd "$worktree" && gh api "repos/{owner}/{repo}/issues/$pr/comments" 2>/dev/null \
    | jq -r --arg me "$ORCHESTRATOR_AI_FOOTER_END_RE" \
        '[.[] | select((.body // "") | test($me)) | .id] | join(",")' 2>/dev/null || true)
}

# True when the run posted a new agent reply on the PR conversation: some id in
# $after that was not in $before.
orchestrator_pr_has_new_agent_general_comment() {
  local worktree="$1" pr="$2" before="$3" after new
  after="$(orchestrator_pr_agent_general_comment_ids "$worktree" "$pr")"
  new="$(comm -13 <(printf '%s\n' "$before" | tr ',' '\n' | grep -v '^$' | sort -u) \
                   <(printf '%s\n' "$after" | tr ',' '\n' | grep -v '^$' | sort -u) || true)"
  [[ -n "$new" ]]
}

orchestrator_review_round() {
  local number="$1" session_id="$2" pr_number="$3" worktree="$4"
  local failures retries latest body plan_file temp_plan
  retries="${ORCHESTRATOR_REVIEW_RETRIES:-3}"
  failures="$(orchestrator_state_review_failures "$ORCHESTRATOR_STATE_FILE" "$number")"
  if [[ "$failures" -ge "$retries" ]]; then
    # Resuming after a pause: a newer human comment starts a fresh budget.
    failures=0
    orchestrator_state_set_review_failures "$ORCHESTRATOR_STATE_FILE" "$number" 0
  fi
  plan_file="${ORCHESTRATOR_REVIEW_PLAN_FILE:-}"
  temp_plan=""
  if [[ -z "$plan_file" ]]; then
    temp_plan="$(mktemp "${TMPDIR:-/tmp}/carbotracker-review-plan.XXXXXX")"
    plan_file="$temp_plan"
  fi
  if orchestrator_review_analyze "$number" "$session_id" "$pr_number" "$worktree" "$plan_file" \
      && orchestrator_review_act "$number" "$pr_number" "$plan_file" "$session_id" "$worktree"; then
    rm -f "$temp_plan"
    orchestrator_state_set_review_failures "$ORCHESTRATOR_STATE_FILE" "$number" 0
    orchestrator_log "review #$number: round succeeded on PR #$pr_number"
    return 0
  fi
  rm -f "$temp_plan"
  failures=$((failures + 1))
  orchestrator_state_set_review_failures "$ORCHESTRATOR_STATE_FILE" "$number" "$failures"
  body="Automated review round failed (attempt $failures/$retries) on PR #$pr_number. The orchestrator will retry.${ORCHESTRATOR_AI_FOOTER}"
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
  local line number pr_number session_id worktree last_comment_at latest notice_posted needs_human
  while IFS= read -r line; do
    number="$(printf '%s' "$line" | jq -r '.ticket')"
    pr_number="$(printf '%s' "$line" | jq -r '.prNumber')"
    session_id="$(printf '%s' "$line" | jq -r '.sessionId')"
    worktree="$(printf '%s' "$line" | jq -r '.worktree')"
    last_comment_at="$(printf '%s' "$line" | jq -r '.lastCommentAt // ""')"
    needs_human="$(printf '%s' "$line" | jq -r '.reviewNeedsHuman // false')"

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
        if [[ "$needs_human" == "true" ]]; then
          orchestrator_log "review #$number: paused for human decision on PR #$pr_number"
        else
          orchestrator_log "review #$number: no new comment on PR #$pr_number (last known $last_comment_at)"
        fi
        continue
      fi
    fi
    if [[ "$needs_human" == "true" ]]; then
      orchestrator_log "review #$number: new comment resumes paused PR #$pr_number"
      orchestrator_state_set_review_needs_human "$ORCHESTRATOR_STATE_FILE" "$number" false
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

orchestrator_merge_behind_pr() {
  local pr_number="$1" branch="$2" worktree="$3"

  if [[ ! -d "$worktree" ]]; then
    orchestrator_log "WARNING: cannot update PR #$pr_number: worktree $worktree is missing"
    return 1
  fi
  if ! git -C "$worktree" fetch origin main; then
    orchestrator_log "WARNING: failed to fetch origin/main for PR #$pr_number"
    return 1
  fi
  if ! git -C "$worktree" merge --no-ff --no-edit origin/main; then
    orchestrator_log "WARNING: origin/main conflicts with branch $branch for PR #$pr_number; aborting the merge"
    git -C "$worktree" merge --abort 2>/dev/null || true
    return 1
  fi
  if ! git -C "$worktree" merge-base --is-ancestor origin/main HEAD; then
    orchestrator_log "WARNING: could not verify origin/main is an ancestor of branch $branch after merge"
    return 1
  fi
  if ! orchestrator_merge_push_and_verify "$branch" "$worktree" "$pr_number"; then
    return 1
  fi
  orchestrator_log "merge #$pr_number: merged origin/main into $branch and verified ancestry against the remote"
  return 0
}

# Push $branch from $worktree and verify the push landed against the remote:
# the push proves nothing about the remote's current main, so re-fetch
# origin/main and re-confirm it is still an ancestor of the branch tip. An
# unverified push is never trusted.
orchestrator_merge_push_and_verify() {
  local branch="$1" worktree="$2" pr_number="$3"
  if ! git -C "$worktree" push origin "$branch"; then
    orchestrator_log "WARNING: failed to push merged branch $branch for PR #$pr_number"
    return 1
  fi
  if ! git -C "$worktree" fetch origin main; then
    orchestrator_log "WARNING: failed to re-fetch origin/main to verify the push of PR #$pr_number"
    return 1
  fi
  if ! git -C "$worktree" merge-base --is-ancestor origin/main HEAD; then
    orchestrator_log "WARNING: could not verify origin/main is an ancestor of branch $branch after push"
    return 1
  fi
  return 0
}

# Resolve a genuinely conflicting PR by delegating to the ticket's original
# opencode session. The agent merges origin/main into the branch, resolves the
# conflicts, and commits — but never pushes. The daemon then verifies that
# origin/main became an ancestor of the branch tip (never trusting the agent's
# exit 0), pushes, and re-verifies against the re-fetched remote. Any failure
# returns non-zero so the caller counts the attempt and keeps the entry.
orchestrator_merge_via_agent() {
  local number="$1" session_id="$2" pr_number="$3" branch="$4" worktree="$5"
  local prompt
  if [[ -z "$session_id" || "$session_id" == "null" ]]; then
    orchestrator_log "ERROR: no opencode session recorded for #$number; cannot delegate conflict resolution of PR #$pr_number"
    return 1
  fi
  if [[ ! -d "$worktree" ]]; then
    orchestrator_log "WARNING: cannot resolve conflicts on PR #$pr_number: worktree $worktree is missing"
    return 1
  fi
  if ! git -C "$worktree" fetch origin main; then
    orchestrator_log "WARNING: failed to fetch origin/main for PR #$pr_number"
    return 1
  fi
  orchestrator_log "merge #$number: resuming session $session_id to resolve conflicts on PR #$pr_number"
  prompt="/implement resolve the merge conflicts on PR #$pr_number (ticket #$number): merge origin/main into the current branch, resolve any conflicts, and commit the resolution. Do NOT push — the daemon pushes and verifies."
  if ! (cd "$worktree" && opencode run --auto --model "$ORCHESTRATOR_MODEL" --session "$session_id" "$prompt" < /dev/null); then
    orchestrator_log "ERROR: opencode conflict-resolution run failed for PR #$pr_number"
    return 1
  fi
  if ! git -C "$worktree" merge-base --is-ancestor origin/main HEAD; then
    orchestrator_log "WARNING: origin/main is not an ancestor of branch $branch for PR #$pr_number after the agent run; not trusting exit 0"
    return 1
  fi
  if ! orchestrator_merge_push_and_verify "$branch" "$worktree" "$pr_number"; then
    return 1
  fi
  return 0
}

# The bounded wrapper around the agent-driven conflict resolution. Failed
# attempts count toward ORCHESTRATOR_MERGE_RETRIES; at the cap a "needs a
# human" comment is posted (retried on later polls until it lands) and the PR
# is left alone. The caller has already applied the live-label skip check.
orchestrator_merge_conflict_pr() {
  local number="$1" pr_number="$2" branch="$3" worktree="$4" session_id="$5"
  local cap failures
  cap="$ORCHESTRATOR_MERGE_RETRIES"
  failures="$(orchestrator_state_merge_failures "$ORCHESTRATOR_STATE_FILE" "$number")"

  if [[ "$failures" -ge "$cap" ]]; then
    if [[ "$(orchestrator_state_merge_notice_posted "$ORCHESTRATOR_STATE_FILE" "$number")" != "true" ]]; then
      if orchestrator_pr_post_comment "$pr_number" "Automated conflict resolution failed $failures/$cap times on PR #$pr_number. This PR needs a human to resolve the merge conflicts.${ORCHESTRATOR_AI_FOOTER}"; then
        orchestrator_state_set_merge_notice_posted "$ORCHESTRATOR_STATE_FILE" "$number" true
        orchestrator_log "merge #$number: posted needs-human comment on PR #$pr_number"
      else
        orchestrator_log "WARNING: failed to post needs-human comment on PR #$pr_number; retrying next poll"
      fi
    fi
    orchestrator_log "merge #$number: PR #$pr_number exhausted $cap agent-merge attempts; leaving for a human"
    return 0
  fi

  if ! orchestrator_merge_via_agent "$number" "$session_id" "$pr_number" "$branch" "$worktree"; then
    failures=$((failures + 1))
    orchestrator_state_set_merge_failures "$ORCHESTRATOR_STATE_FILE" "$number" "$failures"
    orchestrator_log "WARNING: agent merge failed for PR #$pr_number (attempt $failures/$cap); keeping entry to retry next poll"
    return 1
  fi

  orchestrator_state_set_merge_failures "$ORCHESTRATOR_STATE_FILE" "$number" 0
  orchestrator_log "merge #$number: agent resolved conflicts on PR #$pr_number; verified and pushed"
  return 0
}

orchestrator_merge_poll() {
  local line number pr_number branch worktree session_id state merge_state labels
  while IFS= read -r line; do
    number="$(printf '%s' "$line" | jq -r '.ticket')"
    pr_number="$(printf '%s' "$line" | jq -r '.prNumber')"
    branch="$(printf '%s' "$line" | jq -r '.branch')"
    worktree="$(printf '%s' "$line" | jq -r '.worktree')"
    session_id="$(printf '%s' "$line" | jq -r '.sessionId // ""')"
    if [[ "$session_id" == "null" ]]; then
      session_id=""
    fi

    if [[ -z "$pr_number" || "$pr_number" == "null" ]]; then
      orchestrator_log "skip merge #$number: no PR recorded"
      continue
    fi

    state="$(orchestrator_pr_state "$pr_number")"
    case "$state" in
      MERGED)
        orchestrator_log "merge detected: PR #$pr_number merged for #$number; closing issue"
        if gh issue edit "$number" --remove-label "$ORCHESTRATOR_IN_PROGRESS_LABEL" \
          && gh issue close "$number" --comment "PR #$pr_number merged. Issue closed.${ORCHESTRATOR_AI_FOOTER}"; then
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
        merge_state="$(orchestrator_pr_merge_state "$pr_number")"
        if [[ -z "$merge_state" ]]; then
          orchestrator_log "WARNING: could not determine the merge status of PR #$pr_number; keeping entry to retry next poll"
        elif [[ "$merge_state" == "BEHIND" || "$merge_state" == "DIRTY" ]]; then
          # Both auto-merge actions share the gate check: a flagged PR (suspect
          # without human-approved) is skipped until a maintainer approves it.
          # The labels are read live each poll, so an approval unblocks the PR
          # on the next poll; a labels read that fails (gh transiently down)
          # fails closed like the merge gate — the PR is left alone rather than
          # churned on while possibly flagged.
          if ! labels="$(orchestrator_pr_labels "$pr_number")"; then
            orchestrator_log "WARNING: could not read labels of PR #$pr_number; keeping entry to retry next poll"
          elif orchestrator_labels_are_suspect "$labels"; then
            orchestrator_log "merge skip #$number: PR #$pr_number carries suspect-diff without human-approved; skipped until approved"
          elif [[ "$merge_state" == "BEHIND" ]]; then
            orchestrator_log "merge #$number: PR #$pr_number is behind main; updating branch $branch"
            if ! orchestrator_merge_behind_pr "$pr_number" "$branch" "$worktree"; then
              orchestrator_log "WARNING: could not update behind PR #$pr_number; keeping entry to retry next poll"
            fi
          else
            # GitHub reports a PR as DIRTY when its merge into main conflicts.
            # Delegate the conflict to the ticket's session: the agent merges
            # origin/main and commits, the daemon verifies and pushes.
            orchestrator_log "merge #$number: PR #$pr_number conflicts with main; delegating resolution to the agent"
            if ! orchestrator_merge_conflict_pr "$number" "$pr_number" "$branch" "$worktree" "$session_id"; then
              orchestrator_log "WARNING: conflict resolution failed for PR #$pr_number; keeping entry to retry next poll"
            fi
          fi
        else
          orchestrator_log "merge #$number: PR #$pr_number still open (merge status $merge_state)"
        fi
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
  orchestrator_check_suspect_diff "$number" "$pr_number" "$worktree"
  orchestrator_check_overlap "$number" "$pr_number" "$worktree"
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
  # Redirect stdin from /dev/null so the run cannot drain a caller's pipe: when
  # poll_once streams candidates from a process substitution, an opencode run
  # that reads stdin would consume the remaining candidate lines and silently
  # cap the poll at one ticket.
  if (cd "$worktree" && opencode run --auto --model "$ORCHESTRATOR_MODEL" "$@" "$prompt" < /dev/null) 2>&1 | tee "$log_file"; then
    return 0
  fi
  orchestrator_log "ERROR: opencode run failed for #$number (attempt 1); retrying with --continue"
  if (cd "$worktree" && opencode run --auto --model "$ORCHESTRATOR_MODEL" --continue "$prompt" < /dev/null) 2>&1 | tee -a "$log_file"; then
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

orchestrator_restore_failed_labels() {
  local line number
  while IFS= read -r line; do
    number="$(printf '%s' "$line" | jq -r '.ticket')"
    if gh issue edit "$number" --remove-label "$ORCHESTRATOR_IN_PROGRESS_LABEL" --add-label ready-for-agent; then
      orchestrator_log "restored #$number to ready-for-agent after a transient label error"
    else
      orchestrator_log "WARNING: failed to restore ready-for-agent on failed #$number; retrying next poll"
    fi
  done < <(orchestrator_state_load "$ORCHESTRATOR_STATE_FILE" | jq -c '.[] | select(.phase == "failed")')
}

orchestrator_handle_non_opencode_failure() {
  local number="$1" branch="$2" worktree="$3" reason="$4"
  local failures retries
  retries="$ORCHESTRATOR_IMPLEMENTATION_RETRIES"
  orchestrator_state_mark_failed "$ORCHESTRATOR_STATE_FILE" "$number"
  failures="$(orchestrator_state_failure_count "$ORCHESTRATOR_STATE_FILE" "$number")"
  if [[ "$failures" -ge "$retries" ]]; then
    orchestrator_escalate_failure "$number" "$branch" "$worktree" "" \
      "non-opencode failure (attempt $failures/$retries): $reason"
    return
  fi

  if gh issue edit "$number" --remove-label "$ORCHESTRATOR_IN_PROGRESS_LABEL" --add-label ready-for-agent; then
    orchestrator_log "restored #$number to ready-for-agent after non-opencode failure (attempt $failures/$retries)"
  else
    orchestrator_log "WARNING: failed to restore ready-for-agent on #$number; it will need manual re-labelling"
  fi
  if [[ "${CT_WORKTREE_CREATED:-0}" == "1" ]]; then
    orchestrator_cleanup_worktree "$worktree" "$branch"
  else
    orchestrator_log "not cleaning up pre-existing worktree $worktree"
  fi
  orchestrator_log "kept #$number in failed phase for retry on the next poll"
}

orchestrator_state_complete_and_comment() {
  local number="$1" session_id="$2" pr_number="$3"
  orchestrator_state_complete "$ORCHESTRATOR_STATE_FILE" "$number" "$session_id" "$pr_number"
  orchestrator_log "completed #$number: session ${session_id:-<none>}, PR #${pr_number:-<none>}, phase awaiting review"
  if [[ -n "$pr_number" ]]; then
    if gh issue comment "$number" --body "Started implementation. PR #$pr_number created.${ORCHESTRATOR_AI_FOOTER}"; then
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
  CT_IMPLEMENTATION_FAILURE_KIND=non-opencode

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
    CT_IMPLEMENTATION_FAILURE_KIND=opencode
    orchestrator_escalate_failure "$number" "$branch" "$worktree" "$log_file" "opencode exited non-zero twice"
    rm -f "$log_file"
    return 1
  fi
  if ! orchestrator_branch_has_commits "$worktree" "$branch"; then
    # opencode exited 0 but the branch tip is still at origin/main: the agent
    # went off-task or committed nothing, so no PR can be opened. Escalate as an
    # opencode failure rather than letting gh pr create fail with a misleading
    # "No commits between main and ..." error.
    orchestrator_log "ERROR: implement #$number: opencode exited 0 but produced no commits (zero diff vs origin/main)"
    CT_IMPLEMENTATION_FAILURE_KIND=opencode
    orchestrator_escalate_failure "$number" "$branch" "$worktree" "$log_file" "no commits produced"
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

# True when the worktree's branch has at least one unpushed commit, i.e. the
# implement session actually produced a commit to open a PR from. A zero-count
# (branch tip still at origin/main) means the agent did nothing and a PR cannot
# be created, so the caller escalates it as an opencode failure.
orchestrator_branch_has_commits() {
  local worktree="$1" branch="$2"
  [[ "$(orchestrator_unpushed_commit_count "$worktree" "$branch")" -gt 0 ]]
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
  if ! orchestrator_branch_has_commits "$worktree" "$branch"; then
    orchestrator_log "ERROR: resume #$number: opencode exited 0 but produced no commits (zero diff vs origin/main)"
    orchestrator_escalate_failure "$number" "$branch" "$worktree" "$log_file" "no commits produced while resuming"
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
  orchestrator_check_suspect_diff "$number" "$pr_number" "$worktree"
  orchestrator_check_overlap "$number" "$pr_number" "$worktree"
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
    if [[ "$(printf '%s' "$line" | jq -r '.phase')" == "failed" ]]; then
      orchestrator_log "skip reconcile #$number: previous non-opencode failure is awaiting retry"
      continue
    fi
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
  orchestrator_restore_failed_labels
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
      if [[ "$(orchestrator_state_phase "$ORCHESTRATOR_STATE_FILE" "$number")" == "failed" ]]; then
        orchestrator_log "retrying #$number ($title) after non-opencode failure"
      else
        orchestrator_log "skip #$number ($title): already claimed"
        continue
      fi
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
      if [[ "${CT_IMPLEMENTATION_FAILURE_KIND:-non-opencode}" == "opencode" ]]; then
        orchestrator_log "#${number} opencode failure remains on the existing escalation path"
      elif orchestrator_state_has_ticket "$ORCHESTRATOR_STATE_FILE" "$number"; then
        # The opencode failure path has already escalated and pruned. Any
        # remaining entry is a non-opencode failure and gets a bounded retry.
        orchestrator_handle_non_opencode_failure "$number" "$branch" "$worktree" "worktree, dependency, push, or PR setup failed"
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
  orchestrator_log "orchestrator started: poll every ${ORCHESTRATOR_POLL_INTERVAL_SECONDS}s, concurrency cap $ORCHESTRATOR_CONCURRENCY_CAP, model $ORCHESTRATOR_MODEL, state $ORCHESTRATOR_STATE_FILE"
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
      orchestrator_ensure_labels
      orchestrator_reconcile
      orchestrator_poll_once
      ;;
    help | --help | -h)
      orchestrator_help
      ;;
    "")
      orchestrator_ensure_labels
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
