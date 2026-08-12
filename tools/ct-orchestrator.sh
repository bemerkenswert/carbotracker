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
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
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
  orchestrator_state_load "$1" | jq 'length'
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

orchestrator_claim() {
  local number="$1" title="$2"
  local slug branch worktree
  slug="$(slugify "$title")"
  branch="ticket/$number-$slug"
  worktree="$ORCHESTRATOR_WORKTREE_PARENT/$number-$slug"
  orchestrator_state_add "$ORCHESTRATOR_STATE_FILE" "$number" "$branch" "$worktree"
  orchestrator_log "claim #$number ($title): phase implementing (would create worktree $worktree on branch $branch)"
}

orchestrator_poll_once() {
  local candidates active_count count line number title
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

    orchestrator_claim "$number" "$title"
    active_count=$((active_count + 1))
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
