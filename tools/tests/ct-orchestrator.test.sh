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

# Fake a successful worktree-add (creates the dir) and npm ci. When
# FAKE_GIT_PUSH_FILE is set, the push invocation is captured to it.
fake_worktree_npm() {
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "push" && -n "${FAKE_GIT_PUSH_FILE:-}" ]]; then
  printf "%s\n" "$*" > "$FAKE_GIT_PUSH_FILE"
fi
exit 0'
  fake_command npm 'exit 0'
}

# Fake the commands the implementation pipeline invokes: git worktree add,
# npm ci, opencode run + session list, and gh pr list / issue comment. The
# gh fake delegates everything else to the caller-provided body.
fake_pipeline() {
  local gh_body="$1" pr_number="${2:-100}"
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"list\" ]]; then
  printf \"[{\\\"number\\\":$pr_number}]\n\"
elif [[ \"\$1\" == \"issue\" && \"\$2\" == \"comment\" ]]; then
  exit 0
else
  $gh_body
fi
exit 0"
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_10\",\"title\":\"carbotracker-ticket-10\",\"created\":1},{\"id\":\"ses_42\",\"title\":\"carbotracker-ticket-42\",\"created\":2}]\n"
fi
exit 0'
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

test_state_complete_updates_entry() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local entry
  entry="$(jq '.[0]' "$TEST_STATE")"
  assert_eq "complete stores session id" "ses_abc" "$(jq -r '.sessionId' <<<"$entry")"
  assert_eq "complete stores pr number" "456" "$(jq -r '.prNumber' <<<"$entry")"
  assert_eq "complete transitions phase to awaiting review" "awaiting review" "$(jq -r '.phase' <<<"$entry")"
  assert_eq "complete leaves only the matching entry touched" "1" "$(jq 'length' "$TEST_STATE")"
  state_teardown
}

test_state_complete_with_missing_values() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_complete "$TEST_STATE" 123 "" ""
  local entry
  entry="$(jq '.[0]' "$TEST_STATE")"
  assert_eq "missing session id stored as null" "null" "$(jq -r '.sessionId' <<<"$entry")"
  assert_eq "missing pr number stored as null" "null" "$(jq -r '.prNumber' <<<"$entry")"
  assert_eq "phase still transitions without values" "awaiting review" "$(jq -r '.phase' <<<"$entry")"
  state_teardown
}

test_state_complete_updates_only_matching_ticket() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_complete "$TEST_STATE" 2 ses_2 22
  assert_eq "other entry keeps session null" "null" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  assert_eq "other entry keeps phase implementing" "implementing" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "matching entry gets session" "ses_2" "$(jq -r '.[1].sessionId' "$TEST_STATE")"
  assert_eq "matching entry gets pr number" "22" "$(jq -r '.[1].prNumber' "$TEST_STATE")"
  state_teardown
}

test_state_remove_removes_entry() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_remove "$TEST_STATE" 1
  assert_eq "remove drops the entry" "2" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "remove leaves the rest" "1" "$(jq 'length' "$TEST_STATE")"
  state_teardown
}

test_state_active_count_counts_implementing_only() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_complete "$TEST_STATE" 2 ses_2 22
  assert_eq "completed tickets do not count toward cap" "1" "$(orchestrator_state_active_count "$TEST_STATE")"
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
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
    42) printf "Beta body\n" ;;
  esac
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "claims all unblocked candidates" "2" "$(jq 'length' "$TEST_STATE")"
  assert_eq "claims first ticket number" "10" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "claims second ticket number" "42" "$(jq -r '.[1].ticket' "$TEST_STATE")"
  assert_eq "implemented tickets transition to awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "logs discovery" "poll: 2 candidate(s)" "$output"
  assert_contains "logs claim transition" "claim #10: phase implementing" "$output"
  assert_contains "logs branch construction" "branch ticket/10-alpha" "$output"
  assert_contains "logs completed transition" "completed #10: session ses_10, PR #100" "$output"
  state_teardown
}

test_poll_once_skips_claimed() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
    42) printf "Beta body\n" ;;
  esac
fi'
  orchestrator_state_add "$TEST_STATE" 10 ticket/10-alpha "$WT_PARENT/10-alpha"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "does not re-claim an active ticket" "2" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs skip of claimed ticket" "skip #10 (Alpha): already claimed" "$output"
  state_teardown
}

test_poll_once_skips_blocked() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  case "$2" in
    */10/*) printf "1\n" ;;
    */42/*) printf "0\n" ;;
  esac
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "only claims unblocked candidate" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "claims the unblocked ticket" "42" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_contains "logs skip of blocked ticket" "skip #10 (Alpha): blocked" "$output"
  state_teardown
}

test_poll_once_respects_concurrency_cap() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=1 orchestrator_poll_once 2>&1)"
  assert_eq "cap limits claims to first ticket" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "cap claims the FIFO-first ticket" "10" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "implemented ticket reaches awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
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
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=1 orchestrator_poll_once 2>&1)"
  assert_eq "no new claims at full cap" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs cap reached" "concurrency cap 1 reached" "$output"
  state_teardown
}

test_opencode_session_id_filters_by_title() {
  fake_command opencode 'printf "[{\"id\":\"ses_old\",\"title\":\"carbotracker-ticket-10\",\"created\":1},{\"id\":\"ses_new\",\"title\":\"carbotracker-ticket-10\",\"created\":2},{\"id\":\"ses_other\",\"title\":\"other work\",\"created\":3}]\n"
exit 0'
  assert_eq "session id filters by title and picks newest" "ses_new" "$(orchestrator_opencode_session_id carbotracker-ticket-10)"
}

test_opencode_session_id_no_match() {
  fake_command opencode 'printf "[{\"id\":\"ses_a\",\"title\":\"other work\",\"created\":1}]\n"
exit 0'
  assert_eq "session id empty when no title matches" "" "$(orchestrator_opencode_session_id carbotracker-ticket-99)"
}

test_pr_number_for_branch() {
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":40},{\"number\":42}]\n"
fi
exit 0'
  assert_eq "pr number returns newest pr for branch" "42" "$(orchestrator_pr_number_for_branch ticket/10-alpha)"
}

test_pr_number_for_branch_missing() {
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
fi
exit 0'
  assert_eq "pr number empty when no pr exists" "" "$(orchestrator_pr_number_for_branch ticket/10-alpha)"
}

test_implement_runs_full_pipeline() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":42}]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_COMMENT_FILE"
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_COMMENT_FILE="$STATE_DIR/comment"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  export FAKE_GIT_PUSH_FILE="$STATE_DIR/git_push"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree"
  assert_eq "worktree dir created" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "opencode run invoked with title and issue prompt" "run --auto --title carbotracker-ticket-10 /implement the issue is 10" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_contains "branch pushed to origin" "push -u origin ticket/10-alpha" "$(cat "$FAKE_GIT_PUSH_FILE")"
  assert_eq "state session id stored" "ses_abc" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  assert_eq "state pr number stored" "42" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_eq "phase transitions to awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "issue commented with pr number" "Started implementation. PR #42 created." "$(cat "$FAKE_COMMENT_FILE")"
  unset FAKE_COMMENT_FILE FAKE_OPENCODE_ARGS FAKE_GIT_PUSH_FILE
  state_teardown
}

test_implement_opens_pr_when_none_exists() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  local n
  n="$(cat "$FAKE_PR_COUNT" 2>/dev/null || echo 0)"
  if [[ "$n" == "0" ]]; then
    printf "1\n" > "$FAKE_PR_COUNT"
    printf "[]\n"
  else
    printf "[{\"number\":50}]\n"
  fi
elif [[ "$1" == "pr" && "$2" == "create" ]]; then
  printf "%s\n" "$*" > "$FAKE_PR_CREATE_ARGS"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_1\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_PR_COUNT="$STATE_DIR/pr_count"
  export FAKE_PR_CREATE_ARGS="$STATE_DIR/pr_create"
  printf '0\n' > "$FAKE_PR_COUNT"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null
  assert_contains "creates pr with base main" "--base main" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_contains "creates pr with head branch" "--head ticket/10-alpha" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_contains "creates pr with title" "Implement Alpha (#10)" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_eq "stores created pr number" "50" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  unset FAKE_PR_COUNT FAKE_PR_CREATE_ARGS
  state_teardown
}

test_implement_fails_when_push_fails() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
fi
exit 0'
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "push" ]]; then
  exit 1
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"s\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when git push fails"
  else
    pass "implement fails when git push fails"
  fi
  state_teardown
}

test_implement_fails_when_pr_create_fails() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
elif [[ "$1" == "pr" && "$2" == "create" ]]; then
  exit 1
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"s\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when gh pr create fails"
  else
    pass "implement fails when gh pr create fails"
  fi
  state_teardown
}

test_implement_fails_when_worktree_fails() {
  state_setup
  fake_command git 'if [[ "$1" == "worktree" ]]; then
  exit 1
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when worktree creation fails"
  else
    pass "implement fails when worktree creation fails"
  fi
  state_teardown
}

test_implement_fails_when_npm_ci_fails() {
  state_setup
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
fi
exit 0'
  fake_command npm 'exit 1'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when npm ci fails"
  else
    pass "implement fails when npm ci fails"
  fi
  state_teardown
}

test_implement_fails_when_opencode_fails() {
  state_setup
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'exit 1'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when opencode run fails"
  else
    pass "implement fails when opencode run fails"
  fi
  state_teardown
}

test_implement_no_pr_skips_comment() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_COMMENT_FILE"
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_COMMENT_FILE="$STATE_DIR/comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)"
  assert_eq "pr number stored as null when no pr" "null" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_eq "no comment file written" "no" "$([[ -f "$FAKE_COMMENT_FILE" ]] && echo yes || echo no)"
  assert_contains "logs warning about missing pr" "no PR found" "$output"
  unset FAKE_COMMENT_FILE
  state_teardown
}

test_implement_no_session_stores_null() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":42}]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null
  assert_eq "session id stored as null when not found" "null" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  assert_eq "pr number still stored" "42" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  state_teardown
}

test_poll_once_removes_entry_on_failed_implement() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  fake_command git 'if [[ "$1" == "worktree" ]]; then
  exit 1
fi
exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "failed implementation leaves no state entry" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs removal of failed ticket" "removed #10 from state" "$output"
  state_teardown
}

test_claim_marks_issue_in_progress() {
  state_setup
  local args_file="$STATE_DIR/issue_edit_args"
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_EDIT_ARGS"
  exit 0
fi
exit 1'
  export FAKE_EDIT_ARGS="$args_file"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_claim 10 ticket/10-alpha "$WT_PARENT/10-alpha"
  assert_contains "claim removes ready-for-agent" "--remove-label ready-for-agent" "$(cat "$args_file")"
  assert_contains "claim adds in-progress" "--add-label in-progress" "$(cat "$args_file")"
  assert_eq "claim records state entry" "1" "$(orchestrator_state_active_count "$TEST_STATE")"
  assert_eq "state entry phase is implementing" "implementing" "$(jq -r '.[0].phase' "$TEST_STATE")"
  unset FAKE_EDIT_ARGS
  state_teardown
}

test_claim_failure_leaves_no_state() {
  state_setup
  fake_command gh 'exit 1'
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_claim 10 ticket/10-alpha "$WT_PARENT/10-alpha" >/dev/null 2>&1; then
    fail "claim fails when gh issue edit fails"
  else
    pass "claim fails when gh issue edit fails"
  fi
  assert_eq "failed claim leaves no state entry" "0" "$(orchestrator_state_active_count "$TEST_STATE")"
  state_teardown
}

test_poll_once_does_not_cleanup_preexisting_worktree() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  fake_command git 'exit 0'
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once >/dev/null 2>&1
  assert_eq "pre-existing worktree survives failed implementation" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "failed claim leaves no state entry" "0" "$(jq 'length' "$TEST_STATE" 2>/dev/null || echo 0)"
  state_teardown
}

test_poll_once_cleans_up_worktree_after_failed_implement() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "worktree" && "$2" == "remove" ]]; then
  rm -rf "$3" "$4"
fi
exit 0'
  fake_command npm 'exit 1'
  local worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once >/dev/null
  assert_eq "worktree removed after failed implementation" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  state_teardown
}

test_pr_latest_comment_at_returns_newest() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:05:00Z\"},{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*) printf "[{\"created_at\":\"2026-08-13T00:06:00Z\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "latest comment timestamp wins across surfaces" "2026-08-13T00:07:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_prefers_general_when_newer() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:05:00Z\"}]\n" ;;
    *issues/*) printf "[{\"created_at\":\"2026-08-13T00:09:00Z\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "newest comment across both surfaces wins" "2026-08-13T00:09:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_none() {
  fake_command gh 'printf "[]\n"
exit 0'
  assert_eq "no comments returns empty" "" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_one_surface_empty() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[]\n" ;;
    *issues/*) printf "[{\"created_at\":\"2026-08-13T00:09:00Z\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "non-empty surface still yields a timestamp" "2026-08-13T00:09:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_gh_error() {
  fake_command gh 'exit 1'
  assert_eq "gh error returns empty" "" "$(orchestrator_pr_latest_comment_at 100)"
}

test_state_add_creates_last_comment_null() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks last comment as null" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  state_teardown
}

test_state_mark_reviewed_sets_timestamp() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  assert_eq "mark_reviewed stores the timestamp" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "mark_reviewed leaves phase untouched" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "mark_reviewed leaves session untouched" "ses_abc" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  state_teardown
}

test_state_mark_reviewed_touches_only_matching() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_complete "$TEST_STATE" 1 ses_1 11
  orchestrator_state_complete "$TEST_STATE" 2 ses_2 22
  orchestrator_state_mark_reviewed "$TEST_STATE" 2 "2026-08-13T00:07:00Z"
  assert_eq "matching entry gets timestamp" "2026-08-13T00:07:00Z" "$(jq -r '.[1].lastCommentAt' "$TEST_STATE")"
  assert_eq "other entry keeps timestamp null" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  state_teardown
}

test_review_round_success_updates_state() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*comments*)
      if [[ "$*" == *"-f body="* ]]; then
        printf "%s\n" "$*" > "$FAKE_PR_COMMENT_ARGS"
      else
        printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n"
      fi
      ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_eq "opencode run resumes the session" "run --auto --session ses_abc /review-comments on PR #456" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "state last comment updated after round" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "successful round resets failure counter" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "no failure notice posted on success" "no" "$([[ -f "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  unset FAKE_OPENCODE_ARGS FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_failure_increments_and_posts_notice() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*comments*)
      if [[ "$*" == *"-f body="* ]]; then
        printf "%s\n" "$*" > "$FAKE_PR_COMMENT_ARGS"
      else
        printf "[]\n"
      fi
      ;;
  esac
fi
exit 0'
  fake_command opencode 'exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    fail "review round fails when opencode run fails"
  else
    pass "review round fails when opencode run fails"
  fi
  assert_eq "failure increments the counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_contains "failure notice posted on the PR" "attempt 1/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "watermark stays put below the retry cap" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_third_failure_pauses_and_consumes() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*comments*)
      if [[ "$*" == *"-f body="* ]]; then
        printf "%s\n" "$*" > "$FAKE_PR_COMMENT_ARGS"
      else
        printf "[]\n"
      fi
      ;;
  esac
fi
exit 0'
  fake_command opencode 'exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "third failure returns failure" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "third failure caps the counter" "3" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_contains "third failure notice posted" "attempt 3/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "third failure consumes the comment watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "logs the pause" "pausing until a human intervenes" "$output"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_after_pause_starts_fresh_budget() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T01:00:00Z\"}]\n" ;;
    *issues/*comments*) printf "[]\n" ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 3
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_eq "resumed round resets the failure budget" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  state_teardown
}

test_state_add_creates_review_failures_zero() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks review failures as zero" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  state_teardown
}

test_state_set_review_failures_updates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  assert_eq "set failures stores the count" "2" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "read failures returns the count" "2" "$(orchestrator_state_review_failures "$TEST_STATE" 123)"
  assert_eq "read failures defaults to zero for unknown ticket" "0" "$(orchestrator_state_review_failures "$TEST_STATE" 999)"
  state_teardown
}

test_review_poll_launches_round_on_new_comment() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*) printf "[]\n" ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll launches review round on new comment" "run --auto --session ses_abc /review-comments on PR #456" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "poll updates last comment in state" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "logs new comment detection" "new comment on PR #456" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_skips_when_no_new_comment() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*) printf "[]\n" ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll does not launch without newer comment" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_contains "logs no-new-comment skip" "no new comment" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_skips_entry_without_session() {
  state_setup
  fake_command gh 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 "" 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll does not launch without a session" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_contains "logs skip for missing session" "no session" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_skips_entry_without_pr() {
  state_setup
  fake_command gh 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc ""
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll does not launch without a pr number" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_contains "logs skip for missing pr" "no PR" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_ignores_implementing_phase() {
  state_setup
  fake_command gh 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll ignores implementing entries" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_retries_failed_round() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*comments*)
      if [[ "$*" == *"-f body="* ]]; then
        exit 0
      fi
      printf "[]\n"
      ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "x\n" >> "$FAKE_OPENCODE_LOG"
  exit 1
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  assert_eq "failed round is retried on the next poll" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "two failures recorded in state" "2" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "watermark still unconsumed below the cap" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_OPENCODE_LOG
  state_teardown
}

test_review_poll_pauses_after_three_failures() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*comments*)
      if [[ "$*" == *"-f body="* ]]; then
        exit 0
      fi
      printf "[]\n"
      ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "x\n" >> "$FAKE_OPENCODE_LOG"
  exit 1
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  assert_eq "three failed rounds run before pausing" "3" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "failure counter caps at three" "3" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "third failure consumes the comment watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_OPENCODE_LOG
  state_teardown
}

test_review_poll_resumes_after_pause_on_new_comment() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T01:00:00Z\"}]\n" ;;
    *issues/*) printf "[]\n" ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "x\n" >> "$FAKE_OPENCODE_LOG"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 3
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  assert_eq "new comment after pause resumes the round" "1" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "resumed round resets the failure budget" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_OPENCODE_LOG
  state_teardown
}

test_poll_once_runs_review_loop() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[]\n"
elif [[ "$1" == "api" ]]; then
  case "$2" in
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\"}]\n" ;;
    *issues/*) printf "[]\n" ;;
    *) printf "0\n" ;;
  esac
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_poll_once 2>&1)"
  assert_eq "poll once runs review round for awaiting-review pr" "run --auto --session ses_abc /review-comments on PR #456" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "poll once updates last comment in state" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "logs review round" "review #123: launching /review-comments" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_config_defaults() {
  local out
  out="$(env CT_ORCHESTRATOR_CONF=/nonexistent bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS" "$ORCHESTRATOR_REVIEW_RETRIES"' _ "$ROOT")"
  assert_eq "defaults apply when no conf exists" "3 300 3" "$out"
}

test_config_file_parsing() {
  state_setup
  local conf="$STATE_DIR/custom.conf"
  printf 'ORCHESTRATOR_CONCURRENCY_CAP=1\nORCHESTRATOR_POLL_INTERVAL_SECONDS=7\nORCHESTRATOR_REVIEW_RETRIES=5\n' > "$conf"
  local out
  out="$(env CT_ORCHESTRATOR_CONF="$conf" bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS" "$ORCHESTRATOR_REVIEW_RETRIES"' _ "$ROOT")"
  assert_eq "conf overrides cap interval and retries" "1 7 5" "$out"
  state_teardown
}

test_config_env_beats_conf() {
  state_setup
  local conf="$STATE_DIR/custom.conf"
  printf 'ORCHESTRATOR_CONCURRENCY_CAP=1\nORCHESTRATOR_POLL_INTERVAL_SECONDS=7\nORCHESTRATOR_REVIEW_RETRIES=5\n' > "$conf"
  local out
  out="$(env CT_ORCHESTRATOR_CONF="$conf" ORCHESTRATOR_CONCURRENCY_CAP=9 ORCHESTRATOR_POLL_INTERVAL_SECONDS=11 ORCHESTRATOR_REVIEW_RETRIES=1 \
    bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS" "$ORCHESTRATOR_REVIEW_RETRIES"' _ "$ROOT")"
  assert_eq "environment beats conf file" "9 11 1" "$out"
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
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
  esac
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" bash "$ROOT/tools/ct-orchestrator.sh" once 2>&1)"
  assert_eq "once mode claims the ticket" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "once mode completes the ticket" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
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
test_state_complete_updates_entry
test_state_complete_with_missing_values
test_state_complete_updates_only_matching_ticket
test_state_remove_removes_entry
test_state_active_count_counts_implementing_only
test_state_add_creates_last_comment_null
test_state_add_creates_review_failures_zero
test_state_mark_reviewed_sets_timestamp
test_state_mark_reviewed_touches_only_matching
test_state_set_review_failures_updates

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
test_opencode_session_id_filters_by_title
test_opencode_session_id_no_match
test_pr_number_for_branch
test_pr_number_for_branch_missing
test_pr_latest_comment_at_returns_newest
test_pr_latest_comment_at_prefers_general_when_newer
test_pr_latest_comment_at_none
test_pr_latest_comment_at_one_surface_empty
test_pr_latest_comment_at_gh_error
test_review_round_success_updates_state
test_review_round_failure_increments_and_posts_notice
test_review_round_third_failure_pauses_and_consumes
test_review_round_after_pause_starts_fresh_budget
test_review_poll_launches_round_on_new_comment
test_review_poll_skips_when_no_new_comment
test_review_poll_skips_entry_without_session
test_review_poll_skips_entry_without_pr
test_review_poll_ignores_implementing_phase
test_review_poll_retries_failed_round
test_review_poll_pauses_after_three_failures
test_review_poll_resumes_after_pause_on_new_comment
test_implement_runs_full_pipeline
test_implement_fails_when_worktree_fails
test_implement_fails_when_npm_ci_fails
test_implement_fails_when_opencode_fails
test_implement_no_pr_skips_comment
test_implement_no_session_stores_null
test_implement_opens_pr_when_none_exists
test_implement_fails_when_push_fails
test_implement_fails_when_pr_create_fails
test_poll_once_claims_candidates
test_poll_once_skips_claimed
test_poll_once_skips_blocked
test_poll_once_respects_concurrency_cap
test_poll_once_skips_when_cap_full
test_poll_once_removes_entry_on_failed_implement
test_poll_once_cleans_up_worktree_after_failed_implement
test_poll_once_does_not_cleanup_preexisting_worktree
test_claim_marks_issue_in_progress
test_claim_failure_leaves_no_state
test_poll_once_runs_review_loop
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
