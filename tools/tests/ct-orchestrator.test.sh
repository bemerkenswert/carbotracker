#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CT_ORCHESTRATOR_CONF="$(mktemp)"
export CT_ORCHESTRATOR_CONF
source "$ROOT/tools/ct-orchestrator.sh"
rm -f "$CT_ORCHESTRATOR_CONF"

failures=0
tests=0

pass() {
  printf "ok - %s\n" "$1"
  tests=$((tests + 1))
}

fail() {
  printf "not ok - %s\n" "$1"
  tests=$((tests + 1))
  failures=$((failures + 1))
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc"
    printf "  expected: %q\n  actual:   %q\n" "$expected" "$actual"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$desc"
  else
    fail "$desc"
    printf "  missing:  %q\n  in:       %q\n" "$needle" "$haystack"
  fi
}

FAKE_DIR=""
ORIG_PATH="$PATH"

fake_setup() {
  FAKE_DIR="$(mktemp -d)"
  ORIG_PATH="$PATH"
  PATH="$FAKE_DIR:$PATH"
}

fake_command() {
  local name="$1" body="$2"
  printf '%s\n' '#!/usr/bin/env bash' "$body" > "$FAKE_DIR/$name"
  chmod +x "$FAKE_DIR/$name"
}

fake_teardown() {
  PATH="$ORIG_PATH"
  rm -rf "$FAKE_DIR"
  FAKE_DIR=""
}

STATE_DIR=""
TEST_STATE=""
WT_PARENT=""

state_setup() {
  STATE_DIR="$(mktemp -d)"
  TEST_STATE="$STATE_DIR/state.json"
  WT_PARENT="$STATE_DIR/worktrees"
}

state_teardown() {
  rm -rf "$STATE_DIR"
  STATE_DIR=""
  TEST_STATE=""
  WT_PARENT=""
}

test_state_load_missing() {
  state_setup
  assert_eq "load missing state returns empty array" "[]" "$(orchestrator_state_load "$TEST_STATE")"
  state_teardown
}

test_state_load_corrupt() {
  state_setup
  printf 'not json' > "$TEST_STATE"
  assert_eq "load corrupt state returns empty array" "[]" "$(orchestrator_state_load "$TEST_STATE")"
  state_teardown
}

test_state_add_creates_entry() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  local entry
  entry="$(jq '.[0]' "$TEST_STATE")"
  assert_eq "entry tracks ticket number" "123" "$(jq -r '.ticket' <<<"$entry")"
  assert_eq "entry tracks branch" "ticket/123-foo" "$(jq -r '.branch' <<<"$entry")"
  assert_eq "entry tracks worktree path" "$WT_PARENT/123-foo" "$(jq -r '.worktree' <<<"$entry")"
  assert_eq "entry tracks session id as null" "null" "$(jq -r '.sessionId' <<<"$entry")"
  assert_eq "entry tracks pr number as null" "null" "$(jq -r '.prNumber' <<<"$entry")"
  assert_eq "entry tracks phase" "implementing" "$(jq -r '.phase' <<<"$entry")"
  local started
  started="$(jq -r '.startedAt' <<<"$entry")"
  assert_eq "entry tracks started-at timestamp" "yes" "$([[ "$started" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] && echo yes || echo no)"
  state_teardown
}

test_state_add_is_atomic_and_accumulates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  assert_eq "adds accumulate entries" "2" "$(jq 'length' "$TEST_STATE")"
  assert_eq "state file stays valid json" "yes" "$(jq -e . "$TEST_STATE" >/dev/null 2>&1 && echo yes || echo no)"
  assert_eq "no leftover temp files" "0" "$(find "$STATE_DIR" -maxdepth 1 -name 'orchestrator.*' -type f ! -name 'state.json' | wc -l)"
  state_teardown
}

test_state_has_ticket() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  if orchestrator_state_has_ticket "$TEST_STATE" 123; then
    pass "has_ticket true for claimed ticket"
  else
    fail "has_ticket true for claimed ticket"
  fi
  if orchestrator_state_has_ticket "$TEST_STATE" 999; then
    fail "has_ticket false for unclaimed ticket"
  else
    pass "has_ticket false for unclaimed ticket"
  fi
  state_teardown
}

test_candidate_issues_sorted_fifo() {
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":42,\"title\":\"Beta\"},{\"number\":10,\"title\":\"Alpha\"}]\n"
fi
exit 0'
  local out
  out="$(ct_candidate_issues)"
  assert_eq "candidates sorted by number ascending" "10,42" "$(jq -r '[.[].number] | join(",")' <<<"$out")"
}

test_candidate_issues_passes_both_labels() {
  state_setup
  local args_file="$STATE_DIR/args"
  fake_command gh 'printf "%s\n" "$*" > "$FAKE_ARGS_FILE"
exit 0'
  FAKE_ARGS_FILE="$args_file" ct_candidate_issues >/dev/null
  assert_contains "passes ready-for-agent label" "--label ready-for-agent" "$(cat "$args_file")"
  assert_contains "passes ticket label" "--label ticket" "$(cat "$args_file")"
  state_teardown
}

test_candidate_issues_gh_error() {
  fake_command gh 'exit 1'
  assert_eq "candidates empty on gh error" "[]" "$(ct_candidate_issues)"
}

test_issue_blocked_via_native_dependency() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "2\n"
fi
exit 0'
  if ct_issue_is_blocked 123; then
    pass "blocked when native dependency summary reports open blockers"
  else
    fail "blocked when native dependency summary reports open blockers"
  fi
}

test_issue_unblocked_via_native_dependency() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  if ct_issue_is_blocked 123; then
    fail "unblocked when native dependency summary is empty"
  else
    pass "unblocked when native dependency summary is empty"
  fi
}

test_issue_blocked_via_body_line() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "Spec here.\n\nBlocked by: #216\n" ;;
    216) printf "OPEN\n" ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    pass "blocked when body lists an open blocker"
  else
    fail "blocked when body lists an open blocker"
  fi
}

test_issue_unblocked_when_blocker_closed() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "Spec here.\n\nBlocked by: #216\n" ;;
    216) printf "CLOSED\n" ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    fail "unblocked when the only blocker is closed"
  else
    pass "unblocked when the only blocker is closed"
  fi
}

test_issue_blocked_when_blocker_state_unresolvable() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "Spec here.\n\nBlocked by: #216\n" ;;
    216) printf "no such issue\n" >&2; exit 1 ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    pass "blocked when a listed blocker cannot be resolved (fails closed)"
  else
    fail "blocked when a listed blocker cannot be resolved (fails closed)"
  fi
}

test_body_blocker_numbers_stops_at_next_section() {
  local body
  body="$(printf '## Parent\n\nparent text\n\n## Blocked by\n\n- [#216 - something](https://github.com/bemerkenswert/carbotracker/issues/216)\n\n## Fix #99\n\nmore\n')"
  assert_eq "blocker extraction stops at the next section header" "216" "$(ct_body_blocker_numbers "$body")"
}

test_issue_blocked_via_blocked_by_section() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "## Parent\n\nparent text\n\n## Blocked by\n\n- [#216 - something](https://github.com/bemerkenswert/carbotracker/issues/216)\n\n## Acceptance\n\n- [ ] do it\n" ;;
    216) printf "OPEN\n" ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    pass "blocked when blocked-by section links an open issue"
  else
    fail "blocked when blocked-by section links an open issue"
  fi
}

test_poll_once_claims_candidates() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
    42) printf "Beta body\n" ;;
  esac
fi
exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once)"
  assert_eq "claims all unblocked candidates" "2" "$(jq 'length' "$TEST_STATE")"
  assert_eq "claims first ticket number" "10" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "claims second ticket number" "42" "$(jq -r '.[1].ticket' "$TEST_STATE")"
  assert_contains "logs discovery" "poll: 2 candidate(s)" "$output"
  assert_contains "logs claim transition" "claim #10 (Alpha): phase implementing" "$output"
  assert_contains "logs branch construction" "branch ticket/10-alpha" "$output"
  state_teardown
}

test_poll_once_skips_claimed() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
    42) printf "Beta body\n" ;;
  esac
fi
exit 0'
  orchestrator_state_add "$TEST_STATE" 10 ticket/10-alpha "$WT_PARENT/10-alpha"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once)"
  assert_eq "does not re-claim an active ticket" "2" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs skip of claimed ticket" "skip #10 (Alpha): already claimed" "$output"
  state_teardown
}

test_poll_once_skips_blocked() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  case "$2" in
    */10/*) printf "1\n" ;;
    */42/*) printf "0\n" ;;
  esac
fi
exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once)"
  assert_eq "only claims unblocked candidate" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "claims the unblocked ticket" "42" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_contains "logs skip of blocked ticket" "skip #10 (Alpha): blocked" "$output"
  state_teardown
}

test_poll_once_respects_concurrency_cap() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=1 orchestrator_poll_once)"
  assert_eq "cap limits claims to first ticket" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "cap claims the FIFO-first ticket" "10" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_contains "logs cap reached" "concurrency cap 1 reached" "$output"
  state_teardown
}

test_poll_once_skips_when_cap_full() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-existing "$WT_PARENT/1-existing"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=1 orchestrator_poll_once)"
  assert_eq "no new claims at full cap" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs cap reached" "concurrency cap 1 reached" "$output"
  state_teardown
}

test_config_defaults() {
  local out
  out="$(env CT_ORCHESTRATOR_CONF=/nonexistent bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS"' _ "$ROOT")"
  assert_eq "defaults apply when no conf exists" "3 300" "$out"
}

test_config_file_parsing() {
  state_setup
  local conf="$STATE_DIR/custom.conf"
  printf 'ORCHESTRATOR_CONCURRENCY_CAP=1\nORCHESTRATOR_POLL_INTERVAL_SECONDS=7\n' > "$conf"
  local out
  out="$(env CT_ORCHESTRATOR_CONF="$conf" bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS"' _ "$ROOT")"
  assert_eq "conf overrides cap and interval" "1 7" "$out"
  state_teardown
}

test_config_env_beats_conf() {
  state_setup
  local conf="$STATE_DIR/custom.conf"
  printf 'ORCHESTRATOR_CONCURRENCY_CAP=1\nORCHESTRATOR_POLL_INTERVAL_SECONDS=7\n' > "$conf"
  local out
  out="$(env CT_ORCHESTRATOR_CONF="$conf" ORCHESTRATOR_CONCURRENCY_CAP=9 ORCHESTRATOR_POLL_INTERVAL_SECONDS=11 \
    bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS"' _ "$ROOT")"
  assert_eq "environment beats conf file" "9 11" "$out"
  state_teardown
}

test_cli_help() {
  local output
  output="$(bash "$ROOT/tools/ct-orchestrator.sh" help)"
  assert_contains "help mentions single poll mode" "once" "$output"
  assert_contains "help mentions daemon mode" "daemon" "$output"
}

test_cli_once() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
  esac
fi
exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" bash "$ROOT/tools/ct-orchestrator.sh" once)"
  assert_eq "once mode claims the ticket" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "once mode logs discovery" "poll:" "$output"
  state_teardown
}

test_cli_invalid_command() {
  if bash "$ROOT/tools/ct-orchestrator.sh" bogus >/dev/null 2>&1; then
    fail "invalid command exits non-zero"
  else
    pass "invalid command exits non-zero"
  fi
}

test_state_loaded_but_empty_file() {
  state_setup
  touch "$TEST_STATE"
  assert_eq "empty state file loads as empty array" "[]" "$(orchestrator_state_load "$TEST_STATE")"
  state_teardown
}

test_state_load_missing
test_state_loaded_but_empty_file

test_config_defaults
test_config_file_parsing
test_config_env_beats_conf

fake_setup
test_candidate_issues_sorted_fifo
test_candidate_issues_passes_both_labels
test_candidate_issues_gh_error
test_issue_blocked_via_native_dependency
test_issue_unblocked_via_native_dependency
test_issue_blocked_via_body_line
test_issue_unblocked_when_blocker_closed
test_issue_blocked_when_blocker_state_unresolvable
test_issue_blocked_via_blocked_by_section
test_body_blocker_numbers_stops_at_next_section
test_poll_once_claims_candidates
test_poll_once_skips_claimed
test_poll_once_skips_blocked
test_poll_once_respects_concurrency_cap
test_poll_once_skips_when_cap_full
test_cli_once
fake_teardown

fake_setup
test_cli_help
test_cli_invalid_command
fake_teardown

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
