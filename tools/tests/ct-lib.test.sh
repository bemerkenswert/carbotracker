#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/tools/ct-lib.sh"

rm -rf /tmp/opencode/ct-test-parent /tmp/opencode/ct-prune-repo /tmp/opencode/ct-prune-parent /tmp/opencode/ct-prune-repo-nothing /tmp/opencode/ct-prune-parent-nothing

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

test_slugify() {
  assert_eq "slugify lowercases" "hello-world" "$(slugify "Hello World")"
  assert_eq "slugify strips symbols" "the-quick-brown-fox" "$(slugify "The Quick BROWN Fox!")"
  assert_eq "slugify collapses dashes" "foo-bar" "$(slugify "Foo--Bar")"
  assert_eq "slugify trims edge dashes" "leading-and-trailing" "$(slugify "-leading and trailing-")"
  assert_eq "slugify keeps digits" "123-abc" "$(slugify "123 ABC")"
  assert_eq "slugify replaces non-ascii" "umla-ts" "$(slugify "Umlaüts")"
  assert_eq "slugify collapses spaces" "keep-double-spaces" "$(slugify "Keep  Double   Spaces")"
  assert_eq "slugify treats dash-flag text as data" "e" "$(slugify "-e")"
}

test_gh_issue_title() {
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "view" ]]; then
  echo "Fix the bug"
fi
exit 0'
  assert_eq "issue title returns title" "Fix the bug" "$(ct_issue_title 123)"
}

test_gh_issue_title_not_found() {
  fake_command gh 'exit 1'
  assert_eq "issue title empty on missing issue" "" "$(ct_issue_title 999)"
}

test_gh_merged_pr_count() {
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  echo 3
fi
exit 0'
  assert_eq "merged pr count returns count" "3" "$(ct_merged_pr_count ticket/123-fix-the-bug)"
}

test_gh_merged_pr_count_error() {
  fake_command gh 'exit 1'
  assert_eq "merged pr count zero on gh error" "0" "$(ct_merged_pr_count ticket/999-nope)"
}

test_worktree_list() {
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "list" ]]; then
  cat <<EOF
$HOME/git/carbotracker 2a47775 [main]
$HOME/git/worktrees/carbotracker/123-fix-the-bug 2a47775 [ticket/123-fix-the-bug]
$HOME/git/worktrees/carbotracker/999-other abc123 (detached HEAD)
/home/user/other/project 999999 [feature-x]
EOF
fi
exit 0'
  local output
  output=$(ct_worktree_list)
  assert_contains "list header" "Carbotracker worktrees:" "$output"
  assert_contains "list filters to parent dir" "$HOME/git/worktrees/carbotracker/123-fix-the-bug" "$output"
  assert_contains "list prints branch" "ticket/123-fix-the-bug" "$output"
  assert_contains "list includes all parent worktrees" "$HOME/git/worktrees/carbotracker/999-other" "$output"
  assert_contains "list prints detached marker" "(detached HEAD)" "$output"
}

test_worktree_list_empty() {
  fake_command git 'exit 0'
  local output
  output=$(ct_worktree_list)
  assert_contains "empty list shows (none)" "(none)" "$output"
}

test_worktree_create() {
  fake_command gh 'echo "Fix the bug"'
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
fi
exit 0'
  local out_file output
  out_file="$(mktemp)"
  ct_worktree_create 123 > "$out_file"
  output=$(cat "$out_file")
  rm -f "$out_file"
  assert_eq "create sets branch" "ticket/123-fix-the-bug" "$CT_WORKTREE_BRANCH"
  assert_eq "create sets title" "Fix the bug" "$CT_WORKTREE_TITLE"
  assert_eq "create sets dir" "$WORKTREE_PARENT/123-fix-the-bug" "$CT_WORKTREE_DIR"
  assert_eq "create makes the worktree dir" "yes" "$([[ -d "$CT_WORKTREE_DIR" ]] && echo yes)"
  assert_contains "create prints issue line" "Issue:  #123 - Fix the bug" "$output"
  assert_contains "create prints branch line" "Branch: ticket/123-fix-the-bug" "$output"
  assert_contains "create prints path line" "Path:   $WORKTREE_PARENT/123-fix-the-bug" "$output"
}

test_worktree_create_existing_dir() {
  fake_command gh 'echo "Fix the bug"'
  fake_command git 'exit 0'
  mkdir -p "$WORKTREE_PARENT/123-fix-the-bug"
  if ct_worktree_create 123 >/dev/null 2>&1; then
    fail "create fails when worktree dir exists"
  else
    pass "create fails when worktree dir exists"
  fi
}

test_worktree_create_missing_issue() {
  fake_command gh 'exit 1'
  fake_command git 'exit 0'
  if ct_worktree_create 999 >/dev/null 2>&1; then
    fail "create fails on missing issue"
  else
    pass "create fails on missing issue"
  fi
}

test_worktree_create_fetch_fails() {
  fake_command gh 'echo "Fix the bug"'
  fake_command git 'if [[ "$1" == "fetch" ]]; then
  exit 1
fi
exit 0'
  if ct_worktree_create 123 >/dev/null 2>&1; then
    fail "create fails when git fetch fails"
  else
    pass "create fails when git fetch fails"
  fi
}

test_worktree_prune() {
  local repo parent pruned_dir branch
  repo="/tmp/opencode/ct-prune-repo"
  parent="/tmp/opencode/ct-prune-parent"
  pruned_dir="$parent/999-merged-work"
  branch="ticket/999-merged-work"

  rm -rf "$repo" "$parent"
  mkdir -p "$repo" "$parent"

  git -C "$repo" init -q -b main
  git -C "$repo" config user.email test@test
  git -C "$repo" config user.name test
  echo "x" > "$repo/file.txt"
  git -C "$repo" add .
  git -C "$repo" commit -qm "initial"
  git -C "$repo" checkout -qb "$branch"
  echo "y" >> "$repo/file.txt"
  git -C "$repo" commit -qam "feature work"
  git -C "$repo" checkout -q main
  git -C "$repo" worktree add -q "$pruned_dir" -b "$branch" 2>/dev/null || git -C "$repo" worktree add -q "$pruned_dir" "$branch"

  fake_command gh 'echo 3'

  local original_parent="$WORKTREE_PARENT"
  local original_dir="$PWD"
  WORKTREE_PARENT="$parent"
  cd "$repo"

  local output
  output=$(ct_worktree_prune)

  WORKTREE_PARENT="$original_parent"
  cd "$original_dir"

  assert_eq "prune removes merged worktree dir" "no" "$([[ -d "$pruned_dir" ]] && echo yes || echo no)"
  assert_contains "prune reports removed worktree" "Removing: $pruned_dir" "$output"
  assert_eq "prune deletes the branch" "no" "$(git -C "$repo" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null && echo yes || echo no)"
}

test_worktree_prune_nothing() {
  local repo parent pruned_dir
  repo="/tmp/opencode/ct-prune-repo-nothing"
  parent="/tmp/opencode/ct-prune-parent-nothing"
  pruned_dir="$parent/999-open-work"
  branch="ticket/999-open-work"

  rm -rf "$repo" "$parent"
  mkdir -p "$repo" "$parent"

  git -C "$repo" init -q -b main
  git -C "$repo" config user.email test@test
  git -C "$repo" config user.name test
  echo "x" > "$repo/file.txt"
  git -C "$repo" add .
  git -C "$repo" commit -qm "initial"
  git -C "$repo" worktree add -q "$pruned_dir" -b "$branch"

  fake_command gh 'echo 0'

  local original_parent="$WORKTREE_PARENT"
  local original_dir="$PWD"
  WORKTREE_PARENT="$parent"
  cd "$repo"

  local output
  output=$(ct_worktree_prune)

  WORKTREE_PARENT="$original_parent"
  cd "$original_dir"

  assert_eq "prune keeps non-merged worktree" "yes" "$([[ -d "$pruned_dir" ]] && echo yes || echo no)"
  assert_contains "prune reports nothing to do" "No worktrees to prune." "$output"
}

test_cli_help() {
  local output
  output=$(bash "$ROOT/tools/ct-worktree.sh" help)
  assert_contains "help lists worktree:start" "worktree:start" "$output"
  assert_contains "help lists worktree:list" "worktree:list" "$output"
  assert_contains "help lists worktree:prune" "worktree:prune" "$output"
}

test_cli_no_command() {
  local output
  output=$(bash "$ROOT/tools/ct-worktree.sh")
  assert_contains "no command shows usage" "Usage:" "$output"
}

test_cli_start_requires_issue() {
  if bash "$ROOT/tools/ct-worktree.sh" start >/dev/null 2>&1; then
    fail "start without issue exits non-zero"
  else
    pass "start without issue exits non-zero"
  fi
}

test_cli_list() {
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "list" ]]; then
  cat <<EOF
$HOME/git/worktrees/carbotracker/123-fix-the-bug 2a47775 [ticket/123-fix-the-bug]
EOF
fi
exit 0'
  local output
  output=$(bash "$ROOT/tools/ct-worktree.sh" list)
  assert_contains "cli list dispatches to lib" "Carbotracker worktrees:" "$output"
  assert_contains "cli list shows branch" "ticket/123-fix-the-bug" "$output"
}

run_test() {
  fake_setup
  "$1"
  fake_teardown
}

test_slugify
test_cli_help
test_cli_no_command
test_cli_start_requires_issue

run_test test_gh_issue_title
run_test test_gh_issue_title_not_found
run_test test_gh_merged_pr_count
run_test test_gh_merged_pr_count_error
run_test test_worktree_list
run_test test_worktree_list_empty

WORKTREE_PARENT=/tmp/opencode/ct-test-parent run_test test_worktree_create
WORKTREE_PARENT=/tmp/opencode/ct-test-parent run_test test_worktree_create_existing_dir
WORKTREE_PARENT=/tmp/opencode/ct-test-parent run_test test_worktree_create_missing_issue
WORKTREE_PARENT=/tmp/opencode/ct-test-parent run_test test_worktree_create_fetch_fails

run_test test_worktree_prune
run_test test_worktree_prune_nothing

fake_setup
test_cli_list
fake_teardown

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
