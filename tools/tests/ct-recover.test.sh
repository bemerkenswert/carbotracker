#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tools/ct-recover-stalled.sh"

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
TEST_PARENT=""

state_setup() {
  STATE_DIR="$(mktemp -d)"
  TEST_PARENT="$STATE_DIR/worktrees"
}

state_teardown() {
  rm -rf "$STATE_DIR"
  STATE_DIR=""
  TEST_PARENT=""
}

# Fake git for the recovery flow: `stash list` reads $FAKE_STASH_LIST (one
# `ref<TAB>subject` per line, newest first), `stash apply` logs to
# $FAKE_STASH_LOG and fails when $FAKE_STASH_APPLY_FAIL is set, `worktree add`
# creates the directory, `rev-parse --verify refs/heads/<b>` reports the branch
# existing only when $FAKE_BRANCH_EXISTS is set, and `fetch` succeeds.
fake_recover_git() {
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
case "$1" in
  stash)
    if [[ "$2" == "list" ]]; then
      cat "${FAKE_STASH_LIST:-/dev/null}" 2>/dev/null || true
    elif [[ "$2" == "apply" ]]; then
      printf "%s\n" "$*" >> "${FAKE_STASH_LOG:-/dev/null}"
      [[ -n "${FAKE_STASH_APPLY_FAIL:-}" ]] && exit 1
    fi
    ;;
  fetch)
    exit 0
    ;;
  rev-parse)
    [[ -n "${FAKE_BRANCH_EXISTS:-}" ]] && exit 0
    exit 1
    ;;
  worktree)
    if [[ "$2" == "add" ]]; then
      dir="$3"
      mkdir -p "$dir"
      printf "%s\n" "$*" >> "${FAKE_GIT_LOG:-/dev/null}"
    fi
    ;;
esac
exit 0'
}

# Fake gh: `issue view` returns the given title.
fake_recover_gh() {
  local title="$1"
  fake_command gh "if [[ \"\$1\" == \"issue\" && \"\$2\" == \"view\" ]]; then
  printf \"$title\n\"
fi
exit 0"
}

# Fake opencode: `session list` reads $FAKE_OPENCODE_SESSIONS (a file with a
# JSON array of sessions, defaulting to none); any other invocation (the
# interactive launch) is logged to $FAKE_OPENCODE_LOG and exits.
fake_recover_opencode() {
  fake_command opencode 'if [[ "$1" == "session" && "$2" == "list" ]]; then
  cat "${FAKE_OPENCODE_SESSIONS:-/dev/null}" 2>/dev/null || true
  exit 0
fi
printf "%s\n" "opencode $*" >> "${FAKE_OPENCODE_LOG:-/dev/null}"
exit 0'
}

test_recover_usage_help() {
  local output
  output="$(recover_usage)"
  assert_contains "help names the tool" "ct-recover-stalled.sh <ticket>" "$output"
  assert_contains "help mentions reopening the session" "reopen the" "$output"
}

test_recover_invalid_ticket() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  local output rc
  output="$(recover_run "not-a-number" 2>&1)" && rc=0 || rc=$?
  assert_eq "non-numeric ticket errors" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_contains "non-numeric ticket names the requirement" "ticket must be an issue number" "$output"
  state_teardown
}

test_recover_no_stash_errors() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 999 other work at escalation (2026-08-17T12:00:00Z, session ses_other)\n' > "$FAKE_STASH_LIST"
  local output rc
  output="$(recover_run 311 2>&1)" && rc=0 || rc=$?
  assert_eq "no stash for the ticket fails" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_contains "no-stash error names the ticket" "no stash entry found for ticket #311" "$output"
  assert_contains "no-stash error points at the stash source" "when the orchestrator stashed" "$output"
  unset FAKE_STASH_LIST
  state_teardown
}

test_recover_picks_newest_stash() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_STASH_LOG="$STATE_DIR/stash_log"
  export FAKE_OPENCODE_SESSIONS="$STATE_DIR/sessions.json"
  printf '[{"id":"ses_newest","title":"carbotracker-ticket-311","created":1}]\n' > "$FAKE_OPENCODE_SESSIONS"
  mkdir -p "$TEST_PARENT/311-alpha"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T13:00:00Z, session ses_newest)\n' > "$FAKE_STASH_LIST"
  printf 'stash@{1}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T11:00:00Z, session ses_older)\n' >> "$FAKE_STASH_LIST"
  printf 'stash@{2}\tOn feat: carbotracker: ticket 999 uncommitted work at escalation (2026-08-17T10:00:00Z, session ses_other)\n' >> "$FAKE_STASH_LIST"
  (RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311) >/dev/null 2>&1
  assert_contains "applies the newest stash" "stash apply stash@{0}" "$(cat "$FAKE_STASH_LOG")"
  assert_contains "resumes the newest session" "--session ses_newest" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "status names the newest stash" "stash:    stash@{0}" "$(RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311 2>&1)"
  unset FAKE_STASH_LIST FAKE_OPENCODE_LOG FAKE_STASH_LOG FAKE_OPENCODE_SESSIONS
  state_teardown
}

test_recover_happy_path_existing_worktree() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_STASH_LOG="$STATE_DIR/stash_log"
  export FAKE_OPENCODE_SESSIONS="$STATE_DIR/sessions.json"
  printf '[{"id":"ses_abc","title":"carbotracker-ticket-311","created":1}]\n' > "$FAKE_OPENCODE_SESSIONS"
  mkdir -p "$TEST_PARENT/311-alpha"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T12:00:00Z, session ses_abc)\n' > "$FAKE_STASH_LIST"
  local output
  output="$(RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311 2>&1)"
  assert_contains "keeps the existing worktree (no recreate message)" "no" "$([[ "$output" == *"is missing"* ]] && echo yes || echo no)"
  assert_contains "applies the stash" "stash apply stash@{0}" "$(cat "$FAKE_STASH_LOG")"
  assert_contains "prints the ticket in the status block" "Recovered ticket #311" "$output"
  assert_contains "status block names the stash ref" "stash:    stash@{0}" "$output"
  assert_contains "status block names the session id" "session:  ses_abc" "$output"
  assert_contains "status block names the worktree path" "worktree: $TEST_PARENT/311-alpha" "$output"
  assert_contains "reminds to drop the stash after the PR lands" "Once the PR lands, drop the stash entry: git stash drop stash@{0}" "$output"
  assert_contains "reopens the interactive session in the worktree" "opencode --session ses_abc" "$(cat "$FAKE_OPENCODE_LOG")"
  unset FAKE_STASH_LIST FAKE_OPENCODE_LOG FAKE_STASH_LOG FAKE_OPENCODE_SESSIONS
  state_teardown
}

test_recover_recreates_missing_worktree() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_command npm 'printf "%s\n" "$*" >> "${FAKE_NPM_LOG:-/dev/null}"
exit 0'
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_STASH_LOG="$STATE_DIR/stash_log"
  export FAKE_NPM_LOG="$STATE_DIR/npm_log"
  export FAKE_GIT_LOG="$STATE_DIR/git_log"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T12:00:00Z, session ses_abc)\n' > "$FAKE_STASH_LIST"
  local output
  output="$(RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311 2>&1)"
  assert_contains "announces the missing worktree" "Worktree $TEST_PARENT/311-alpha is missing" "$output"
  assert_contains "recreates the worktree from origin/main" "worktree add $TEST_PARENT/311-alpha -b ticket/311-alpha origin/main" "$(cat "$FAKE_GIT_LOG")"
  assert_contains "installs dependencies in the recreated worktree" "ci --prefer-offline --no-audit --no-fund" "$(cat "$FAKE_NPM_LOG")"
  assert_eq "recreated worktree exists on disk" "yes" "$([[ -d "$TEST_PARENT/311-alpha" ]] && echo yes || echo no)"
  assert_contains "applies the stash after recreating" "stash apply stash@{0}" "$(cat "$FAKE_STASH_LOG")"
  unset FAKE_STASH_LIST FAKE_OPENCODE_LOG FAKE_STASH_LOG FAKE_NPM_LOG FAKE_GIT_LOG
  state_teardown
}

test_recover_recreates_attaches_existing_branch() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  export FAKE_BRANCH_EXISTS=1
  export FAKE_GIT_LOG="$STATE_DIR/git_log"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T12:00:00Z, session ses_abc)\n' > "$FAKE_STASH_LIST"
  local output
  output="$(RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311 2>&1)"
  assert_contains "recreates without -b when the branch exists" "worktree add $TEST_PARENT/311-alpha ticket/311-alpha" "$(cat "$FAKE_GIT_LOG")"
  assert_eq "recreated worktree exists on disk" "yes" "$([[ -d "$TEST_PARENT/311-alpha" ]] && echo yes || echo no)"
  assert_contains "still applies the stash" "Applying stash@{0}" "$output"
  unset FAKE_STASH_LIST FAKE_BRANCH_EXISTS FAKE_GIT_LOG
  state_teardown
}

test_recover_apply_conflict_aborts() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  export FAKE_STASH_LOG="$STATE_DIR/stash_log"
  export FAKE_STASH_APPLY_FAIL=1
  mkdir -p "$TEST_PARENT/311-alpha"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T12:00:00Z, session ses_abc)\n' > "$FAKE_STASH_LIST"
  local output rc
  output="$(RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311 2>&1)" && rc=0 || rc=$?
  assert_eq "conflict aborts the command" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_contains "conflict error names the apply" "Error: could not apply stash@{0}" "$output"
  assert_contains "conflict leaves the stash intact" "entry was NOT removed" "$output"
  assert_contains "conflict gives the apply instruction" "git -C $TEST_PARENT/311-alpha stash apply stash@{0}" "$output"
  assert_contains "conflict gives the drop reminder" "git -C $TEST_PARENT/311-alpha stash drop stash@{0}" "$output"
  unset FAKE_STASH_LIST FAKE_STASH_LOG FAKE_STASH_APPLY_FAIL
  state_teardown
}

test_recover_warns_session_missing_from_message() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_STASH_LOG="$STATE_DIR/stash_log"
  mkdir -p "$TEST_PARENT/311-alpha"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T12:00:00Z, session none)\n' > "$FAKE_STASH_LIST"
  local output
  output="$(RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311 2>&1)"
  assert_contains "warns when the message has no session id" "no session id recorded in stash@{0}" "$output"
  assert_contains "still applies the stash" "stash apply stash@{0}" "$(cat "$FAKE_STASH_LOG")"
  assert_contains "launches a fresh interactive session" "opencode" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "fresh session is not resumed with --session" "no" "$([[ "$(cat "$FAKE_OPENCODE_LOG")" == *"--session"* ]] && echo yes || echo no)"
  unset FAKE_STASH_LIST FAKE_OPENCODE_LOG FAKE_STASH_LOG
  state_teardown
}

test_recover_warns_session_gone() {
  state_setup
  fake_recover_git
  fake_recover_gh "Alpha"
  fake_recover_opencode
  export FAKE_STASH_LIST="$STATE_DIR/stash_list"
  export FAKE_OPENCODE_SESSIONS="$STATE_DIR/sessions.json"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_STASH_LOG="$STATE_DIR/stash_log"
  printf '[{"id":"ses_other","title":"other","created":1}]\n' > "$FAKE_OPENCODE_SESSIONS"
  mkdir -p "$TEST_PARENT/311-alpha"
  printf 'stash@{0}\tOn feat: carbotracker: ticket 311 uncommitted work at escalation (2026-08-17T12:00:00Z, session ses_abc)\n' > "$FAKE_STASH_LIST"
  local output
  output="$(RECOVER_WORKTREE_PARENT="$TEST_PARENT" recover_run 311 2>&1)"
  assert_contains "warns when the session no longer exists" "session ses_abc no longer exists" "$output"
  assert_contains "still applies the stash" "stash apply stash@{0}" "$(cat "$FAKE_STASH_LOG")"
  assert_contains "launches a fresh interactive session" "opencode" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "does not resume the dead session" "no" "$([[ "$(cat "$FAKE_OPENCODE_LOG")" == *"--session"* ]] && echo yes || echo no)"
  unset FAKE_STASH_LIST FAKE_OPENCODE_LOG FAKE_STASH_LOG FAKE_OPENCODE_SESSIONS
  state_teardown
}

fake_setup
test_recover_usage_help
fake_teardown

fake_setup
test_recover_invalid_ticket
test_recover_no_stash_errors
test_recover_picks_newest_stash
test_recover_happy_path_existing_worktree
test_recover_recreates_missing_worktree
test_recover_recreates_attaches_existing_branch
test_recover_apply_conflict_aborts
test_recover_warns_session_missing_from_message
test_recover_warns_session_gone
fake_teardown

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
