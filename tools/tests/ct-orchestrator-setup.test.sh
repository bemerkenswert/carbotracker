#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT
source "$ROOT/tools/ct-orchestrator-setup.sh"

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
FAKE_GIT_LOG=""
FAKE_SYSTEMCTL_LOG=""
FAKE_LOGINCTL_LOG=""
FAKE_NPM_LOG=""
FAKE_NVM_LOG=""

fake_setup() {
  FAKE_DIR="$(mktemp -d)"
  FAKE_GIT_LOG="$FAKE_DIR/git.log"
  FAKE_SYSTEMCTL_LOG="$FAKE_DIR/systemctl.log"
  FAKE_LOGINCTL_LOG="$FAKE_DIR/loginctl.log"
  FAKE_NPM_LOG="$FAKE_DIR/npm.log"
  FAKE_NVM_LOG="$FAKE_DIR/nvm.log"
  export FAKE_GIT_LOG FAKE_SYSTEMCTL_LOG FAKE_LOGINCTL_LOG FAKE_NPM_LOG FAKE_NVM_LOG
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

# Fake git that logs every invocation. On clone it materialises the target
# directory (including .git) and seeds .nvmrc plus the tools the setup script
# needs to run (both service units and ct-node-sync.sh), so the idempotent
# second run exercises the pull path.
fake_git() {
  fake_command git 'printf "%s\n" "$*" >> "$FAKE_GIT_LOG"
if [[ "$1" == "clone" ]]; then
  mkdir -p "$3/tools"
  cp "$ROOT/tools/carbotracker-orchestrator.service" "$3/tools/carbotracker-orchestrator.service"
  cp "$ROOT/tools/carbotracker-node-sync.service" "$3/tools/carbotracker-node-sync.service"
  cp "$ROOT/tools/ct-node-sync.sh" "$3/tools/ct-node-sync.sh"
  cp "$ROOT/.nvmrc" "$3/.nvmrc"
  mkdir -p "$3/.git"
fi
exit 0'
}

# Fake npm that logs every invocation (so tests can assert `npm ci` ran).
fake_npm() {
  fake_command npm 'printf "%s\n" "$*" >> "$FAKE_NPM_LOG"
exit 0'
}

# Fake nvm: writes a nvm.sh under $1 whose nvm() logs install/alias/version
# calls and returns a fixed version for `nvm version`, so the node-sync step
# runs without a real nvm install.
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

# Fake systemctl that logs every invocation; status succeeds.
fake_systemctl() {
  fake_command systemctl 'printf "%s\n" "$*" >> "$FAKE_SYSTEMCTL_LOG"
exit 0'
}

fake_loginctl() {
  fake_command loginctl 'printf "%s\n" "$*" >> "$FAKE_LOGINCTL_LOG"
exit 0'
}

fake_all_prereqs() {
  fake_command gh 'exit 0'
  fake_command git 'exit 0'
  fake_command node 'exit 0'
  fake_command npm 'exit 0'
  fake_command jq 'exit 0'
  fake_command opencode 'exit 0'
  fake_command systemctl 'exit 0'
  fake_command loginctl 'exit 0'
}

test_check_prereqs_ok() {
  fake_all_prereqs
  if check_prereqs gh git node npm jq opencode systemctl loginctl; then
    pass "prereqs pass when all tools are present"
  else
    fail "prereqs pass when all tools are present"
  fi
}

test_check_prereqs_missing() {
  fake_all_prereqs
  local output
  output=$(check_prereqs gh git node npm jq opencode systemctl definitely-not-a-tool 2>&1 || true)
  assert_contains "prereqs fail when a tool is missing" "definitely-not-a-tool" "$output"
}

test_clone_creates() {
  local sandbox
  sandbox="$(mktemp -d)"
  fake_git
  REPO_DIR="$sandbox/git/carbotracker" setup_clone >/dev/null
  assert_eq "clone makes the repo dir" "yes" "$([[ -d "$sandbox/git/carbotracker" ]] && echo yes || echo no)"
  assert_contains "clone invokes git clone" "clone https://github.com/bemerkenswert/carbotracker.git $sandbox/git/carbotracker" "$(cat "$FAKE_GIT_LOG")"
  rm -rf "$sandbox"
}

test_clone_pulls_when_exists() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/git/carbotracker/.git"
  fake_git
  REPO_DIR="$sandbox/git/carbotracker" setup_clone >/dev/null
  if grep -q '^clone ' "$FAKE_GIT_LOG"; then
    fail "existing clone is not re-cloned"
  else
    pass "existing clone is not re-cloned"
  fi
  local log
  log="$(cat "$FAKE_GIT_LOG")"
  assert_contains "existing clone reapplies the remote" "remote set-url origin https://github.com/bemerkenswert/carbotracker.git" "$log"
  assert_contains "existing clone pulls" "-C $sandbox/git/carbotracker pull --ff-only" "$log"
  rm -rf "$sandbox"
}

test_clone_override() {
  local sandbox
  sandbox="$(mktemp -d)"
  fake_git
  REPO_DIR="$sandbox/git/carbotracker" REPO_URL="https://example.com/fork.git" setup_clone >/dev/null
  assert_contains "clone honors the URL override" "clone https://example.com/fork.git $sandbox/git/carbotracker" "$(cat "$FAKE_GIT_LOG")"
  rm -rf "$sandbox"
}

test_install_unit() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/git/carbotracker/tools"
  cp "$ROOT/tools/carbotracker-orchestrator.service" "$sandbox/git/carbotracker/tools/"
  cp "$ROOT/tools/carbotracker-node-sync.service" "$sandbox/git/carbotracker/tools/"
  REPO_DIR="$sandbox/git/carbotracker" SYSTEMD_USER_DIR="$sandbox/systemd/user" setup_install_unit >/dev/null
  assert_eq "orchestrator unit installed into systemd user dir" "yes" "$([[ -f "$sandbox/systemd/user/carbotracker-orchestrator.service" ]] && echo yes || echo no)"
  assert_eq "node-sync unit installed into systemd user dir" "yes" "$([[ -f "$sandbox/systemd/user/carbotracker-node-sync.service" ]] && echo yes || echo no)"
  rm -rf "$sandbox"
}

test_enable_start() {
  fake_systemctl
  setup_enable_start >/dev/null
  local log
  log="$(cat "$FAKE_SYSTEMCTL_LOG")"
  assert_contains "daemon reload invoked" "--user daemon-reload" "$log"
  assert_contains "node-sync service enabled" "--user enable carbotracker-node-sync" "$log"
  assert_contains "orchestrator service enabled and started" "--user enable --now carbotracker-orchestrator" "$log"
}

test_verify() {
  fake_systemctl
  setup_verify >/dev/null
  assert_contains "status invoked for the service" "--user status carbotracker-orchestrator" "$(cat "$FAKE_SYSTEMCTL_LOG")"
}

test_whole_script_idempotent() {
  local sandbox
  sandbox="$(mktemp -d)"
  fake_command gh 'exit 0'
  fake_git
  fake_command node 'exit 0'
  fake_npm
  fake_command jq 'exit 0'
  fake_command opencode 'exit 0'
  fake_systemctl
  fake_loginctl

  local home="$sandbox/home"
  mkdir -p "$home"
  fake_nvm "$home/.nvm"

  if HOME="$home" NVM_DIR="$home/.nvm" CARBOTRACKER_REPO_URL="https://example.com/fork.git" bash "$ROOT/tools/ct-orchestrator-setup.sh" >/dev/null 2>&1; then
    pass "first run succeeds"
  else
    fail "first run succeeds"
  fi

  assert_eq "first run cloned the repo" "yes" "$([[ -d "$home/git/carbotracker" ]] && echo yes || echo no)"
  assert_eq "first run installed the orchestrator unit" "yes" "$([[ -f "$home/.config/systemd/user/carbotracker-orchestrator.service" ]] && echo yes || echo no)"
  assert_eq "first run installed the node-sync unit" "yes" "$([[ -f "$home/.config/systemd/user/carbotracker-node-sync.service" ]] && echo yes || echo no)"
  assert_contains "first run clones with the URL override" "clone https://example.com/fork.git $home/git/carbotracker" "$(cat "$FAKE_GIT_LOG")"
  assert_contains "first run installs main-repo deps" "ci --prefer-offline --no-audit --no-fund" "$(cat "$FAKE_NPM_LOG")"
  assert_contains "first run re-points node-current" "$home/.nvm/versions/node/v22.23.2" "$(readlink "$home/.nvm/node-current")"

  if HOME="$home" NVM_DIR="$home/.nvm" CARBOTRACKER_REPO_URL="https://example.com/fork.git" bash "$ROOT/tools/ct-orchestrator-setup.sh" >/dev/null 2>&1; then
    pass "second run succeeds"
  else
    fail "second run succeeds"
  fi

  local git_log
  git_log="$(cat "$FAKE_GIT_LOG")"
  assert_contains "second run does not re-clone" "pull --ff-only" "$git_log"
  assert_contains "second run reapplies the URL override" "remote set-url origin https://example.com/fork.git" "$git_log"
  rm -rf "$sandbox"
}

run_test() {
  fake_setup
  "$1"
  fake_teardown
}

run_test test_check_prereqs_ok
run_test test_check_prereqs_missing
run_test test_clone_creates
run_test test_clone_pulls_when_exists
run_test test_clone_override
run_test test_install_unit
run_test test_enable_start
run_test test_verify
run_test test_whole_script_idempotent

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
