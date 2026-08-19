#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ct-lib.sh"

# The parent the tool recreates worktrees under. Defaults to the shared ct-lib
# path — the same default the orchestrator uses, so recovery lands exactly where
# the original session ran. Override when the orchestrator was configured with a
# different ORCHESTRATOR_WORKTREE_PARENT.
RECOVER_WORKTREE_PARENT="${RECOVER_WORKTREE_PARENT:-$WORKTREE_PARENT}"

recover_usage() {
  echo "Usage: ct-recover-stalled.sh <ticket>"
  echo ""
  echo "Recover a stalled implement run in place: find the ticket's newest stash"
  echo "entry, recreate the worktree at its deterministic path if it is missing,"
  echo "install dependencies, apply the stash (never pop it), and reopen the"
  echo "interactive opencode session in the worktree."
}

# The newest stash entry for the ticket: "ref<TAB>subject" or nothing — the
# same selection the orchestrator uses when it names the stash in escalation
# comments, so recovery always starts from the entry the escalation pointed at.
recover_latest_stash() {
  ct_ticket_stash_line "$1"
}

# The session id recorded in a stash subject, empty when the message has none.
recover_stash_session_id() {
  local subject="$1"
  sed -nE 's/.*, session ([^)]*)\)$/\1/p' <<<"$subject"
}

# True when the session id still exists in opencode's session list.
recover_session_exists() {
  local session_id="$1"
  opencode session list --format json 2>/dev/null \
    | jq -e --arg id "$session_id" 'any(.[]; .id == $id)' >/dev/null 2>&1
}

# Recreate a missing worktree at the deterministic path. The branch may still
# exist locally if an earlier prune was interrupted, so attach it instead of
# creating a duplicate.
recover_create_worktree() {
  local worktree="$1" branch="$2"
  git fetch origin main || return 1
  mkdir -p "$(dirname "$worktree")" || return 1
  if git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
    git worktree add "$worktree" "$branch" || return 1
  else
    git worktree add "$worktree" -b "$branch" origin/main || return 1
  fi
}

recover_run() {
  local number="$1"
  local stash_line stash_ref subject session_id title branch worktree created

  if [[ ! "$number" =~ ^[0-9]+$ ]]; then
    echo "Error: ticket must be an issue number." >&2
    return 2
  fi

  stash_line="$(recover_latest_stash "$number")"
  if [[ -z "$stash_line" ]]; then
    echo "Error: no stash entry found for ticket #$number." >&2
    echo "Recoverable work exists only when the orchestrator stashed uncommitted changes" >&2
    echo "before pruning this ticket's worktree at escalation." >&2
    return 1
  fi

  stash_ref="$(printf '%s' "$stash_line" | cut -f1)"
  subject="$(printf '%s' "$stash_line" | cut -f2-)"
  session_id="$(recover_stash_session_id "$subject")"
  if [[ -z "$session_id" || "$session_id" == "none" ]]; then
    session_id=""
  fi

  title="$(ct_issue_title "$number")"
  if [[ -z "$title" ]]; then
    echo "Error: could not fetch issue #$number; cannot derive the deterministic worktree path." >&2
    return 1
  fi
  branch="$(ct_ticket_branch "$number" "$title")"
  worktree="$(ct_ticket_worktree "$number" "$title" "$RECOVER_WORKTREE_PARENT")"

  created=0
  if [[ ! -d "$worktree" ]]; then
    echo "Worktree $worktree is missing; recreating it from origin/main."
    if ! recover_create_worktree "$worktree" "$branch"; then
      echo "Error: could not recreate the worktree at $worktree." >&2
      return 1
    fi
    created=1
  fi

  if [[ "$created" -eq 1 ]]; then
    echo "Installing dependencies in $worktree."
    if ! (cd "$worktree" && npm ci --prefer-offline --no-audit --no-fund); then
      echo "Error: npm ci failed in $worktree." >&2
      return 1
    fi
  fi

  echo "Applying $stash_ref in $worktree (the stash entry is kept until the work is committed)."
  if ! git -C "$worktree" stash apply "$stash_ref" 2>&1; then
    echo "Error: could not apply $stash_ref in $worktree — it conflicts with origin/main." >&2
    echo "Resolve the conflicts in $worktree (git status), then continue manually. The stash" >&2
    echo "entry was NOT removed, so no work is lost:" >&2
    echo "  git -C $worktree stash apply $stash_ref   # once conflicts are resolved" >&2
    echo "  git -C $worktree stash drop $stash_ref    # only after the PR lands" >&2
    return 1
  fi

  if [[ -n "$session_id" ]]; then
    if recover_session_exists "$session_id"; then
      echo "Session $session_id still exists; reopening it in the worktree."
    else
      echo "Warning: session $session_id no longer exists; starting a fresh session with the restored files." >&2
      session_id=""
    fi
  else
    echo "Warning: no session id recorded in $stash_ref; starting a fresh session with the restored files." >&2
  fi

  echo ""
  echo "Recovered ticket #$number"
  echo "  stash:    $stash_ref"
  echo "  session:  ${session_id:-<new session>}"
  echo "  worktree: $worktree"
  echo ""
  echo "Once the PR lands, drop the stash entry: git stash drop $stash_ref"

  cd "$worktree"
  if [[ -n "$session_id" ]]; then
    exec opencode --session "$session_id"
  else
    exec opencode
  fi
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "help" ]]; then
    recover_usage
    return 0
  fi
  if [[ $# -ne 1 ]]; then
    recover_usage >&2
    return 2
  fi
  recover_run "$1"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
