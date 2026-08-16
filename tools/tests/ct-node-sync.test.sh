#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT
SCRIPT="$ROOT/tools/ct-node-sync.sh"

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

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$desc"
  else
    fail "$desc"
    printf "  missing:  %q\n  in:       %q\n" "$needle" "$haystack"
  fi
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

FAKE_DIR=""
ORIG_PATH="$PATH"
FAKE_GIT_LOG=""
FAKE_NVM_LOG=""

fake_setup() {
  FAKE_DIR="$(mktemp -d)"
  FAKE_GIT_LOG="$FAKE_DIR/git.log"
  FAKE_NVM_LOG="$FAKE_DIR/nvm.log"
  export FAKE_GIT_LOG FAKE_NVM_LOG
  ORIG_PATH="$PATH"
  PATH="$FAKE_DIR:$PATH"
}

fake_teardown() {
  PATH="$ORIG_PATH"
  rm -rf "$FAKE_DIR"
  FAKE_DIR=""
}

fake_git() {
  printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "$FAKE_GIT_LOG"' 'exit 0' > "$FAKE_DIR/git"
  chmod +x "$FAKE_DIR/git"
}

# A fake nvm.sh whose nvm() logs install/alias/version calls and returns a
# fixed version for `nvm version`, so the script runs without a real nvm.
fake_nvm() {
  local nvm_dir="$1"
  mkdir -p "$nvm_dir/versions/node"
  cat > "$nvm_dir/nvm.sh" <<'EOF'
nvm() {
  printf "nvm %s\n" "$*" >> "$FAKE_NVM_LOG"
  case "$1" in
    version) printf 'v22.23.2\n';;
  esac
}
EOF
}

test_follow_major_symlink() {
  local sandbox
  sandbox="$(mktemp -d)"
  fake_git
  mkdir -p "$sandbox/repo"
  printf 'v22.21.1\n' > "$sandbox/repo/.nvmrc"
  fake_nvm "$sandbox/nvm"

  CARBOTRACKER_REPO_DIR="$sandbox/repo" NVM_DIR="$sandbox/nvm" bash "$SCRIPT" >/dev/null

  local log
  log="$(cat "$FAKE_NVM_LOG")"
  assert_contains "installs the major, not the pin" "install 22" "$log"
  assert_contains "default alias set to the major" "alias default 22" "$log"
  assert_eq "node-current points at the installed version" "$sandbox/nvm/versions/node/v22.23.2" "$(readlink "$sandbox/nvm/node-current")"
  rm -rf "$sandbox"
}

test_git_operations() {
  local sandbox
  sandbox="$(mktemp -d)"
  fake_git
  mkdir -p "$sandbox/repo"
  printf 'v22.21.1\n' > "$sandbox/repo/.nvmrc"
  fake_nvm "$sandbox/nvm"

  CARBOTRACKER_REPO_DIR="$sandbox/repo" NVM_DIR="$sandbox/nvm" bash "$SCRIPT" >/dev/null

  local gitlog
  gitlog="$(cat "$FAKE_GIT_LOG")"
  assert_contains "checks out main" "checkout main" "$gitlog"
  assert_contains "pulls main" "pull --ff-only" "$gitlog"
  rm -rf "$sandbox"
}

run_test() {
  fake_setup
  "$1"
  fake_teardown
}

run_test test_follow_major_symlink
run_test test_git_operations

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
