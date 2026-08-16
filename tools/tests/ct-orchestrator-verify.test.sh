#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export ROOT
source "$ROOT/tools/ct-orchestrator-verify.sh"

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
    printf "  missing:  %q\n" "$needle"
  fi
}

FAKE_DIR=""
ORIG_PATH="$PATH"

fake_setup() {
  FAKE_DIR="$(mktemp -d)"
  ORIG_PATH="$PATH"
  PATH="$FAKE_DIR:$PATH"
}

fake_teardown() {
  PATH="$ORIG_PATH"
  rm -rf "$FAKE_DIR"
  FAKE_DIR=""
}

fake_command() {
  local name="$1" body="$2"
  printf '%s\n' '#!/usr/bin/env bash' "$body" > "$FAKE_DIR/$name"
  chmod +x "$FAKE_DIR/$name"
}

install_fakes() {
  fake_command gh 'echo carbotracker'
  fake_command rg 'echo ripgrep 15.2.0'
  fake_command systemctl 'exit 0'
  fake_command loginctl 'echo Linger=yes'
  fake_command sudo 'echo "Status: active"
echo "OpenSSH ALLOW Anywhere"'
  fake_command dpkg 'echo "ii  unattended-upgrades  2.8.1  all  automatic upgrades"'
  fake_command ip 'echo "default via 192.168.178.1 dev enp0s31f6"'
  fake_command journalctl 'echo "Aug 16 13:46:28 host ct-orchestrator.sh[1525]: sleeping 300s"'
  fake_command git 'case "$*" in
  *"config --global --get credential"*) echo "!/usr/bin/gh auth git-credential";;
  *"rev-parse"*) echo "main";;
  *"log --oneline"*) echo "64a838a codify setup errors and gaps";;
  *"status -sb"*) echo "## main...origin/main";;
esac
exit 0'
}

SB_DIR=""
SB_HOME=""

# Build a fully green orchestrator host under a temp dir and point the verify
# script's globals at it. node/npm live on the nvm stable path (not PATH), so
# they are materialised as real executables rather than faked.
make_sandbox() {
  SB_DIR="$(mktemp -d)"
  SB_HOME="$SB_DIR/home"
  mkdir -p "$SB_HOME"

  local vdir="$SB_HOME/.nvm/versions/node/v22.23.2/bin"
  mkdir -p "$vdir"
  printf '%s\n' '#!/usr/bin/env bash' 'echo v22.23.2' > "$vdir/node"
  printf '%s\n' '#!/usr/bin/env bash' 'echo 10.9.8' > "$vdir/npm"
  chmod +x "$vdir/node" "$vdir/npm"
  ln -s "$SB_HOME/.nvm/versions/node/v22.23.2" "$SB_HOME/.nvm/node-current"
  printf '%s\n' 'nvm() { :; }' > "$SB_HOME/.nvm/nvm.sh"

  mkdir -p "$SB_HOME/.opencode/bin"
  : > "$SB_HOME/.opencode/bin/opencode"
  chmod +x "$SB_HOME/.opencode/bin/opencode"

  mkdir -p "$SB_HOME/git/carbotracker/tools" "$SB_HOME/git/carbotracker/node_modules/ajv" "$SB_HOME/git/carbotracker/.git"
  printf 'v22.21.1\n' > "$SB_HOME/git/carbotracker/.nvmrc"
  : > "$SB_HOME/git/carbotracker/tools/ct-node-sync.sh"
  : > "$SB_HOME/git/carbotracker/tools/carbotracker-node-sync.service"

  mkdir -p "$SB_HOME/.config/systemd/user"
  cat > "$SB_HOME/.config/systemd/user/carbotracker-orchestrator.service" <<'UNIT'
[Service]
Environment=PATH=%h/.nvm/node-current/bin:%h/.opencode/bin:%h/.local/bin:/usr/local/bin:/usr/bin:/bin
EnvironmentFile=-%h/.config/carbotracker/orchestrator.env
UNIT
  cat > "$SB_HOME/.config/systemd/user/carbotracker-node-sync.service" <<'UNIT'
[Unit]
Before=carbotracker-orchestrator.service
UNIT

  mkdir -p "$SB_HOME/.config/carbotracker"
  printf 'GH_TOKEN=not-a-real-token\n' > "$SB_HOME/.config/carbotracker/orchestrator.env"
  chmod 600 "$SB_HOME/.config/carbotracker/orchestrator.env"

  cat > "$SB_DIR/unattended.conf" <<'CONF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::OnlyOnACPower "false";
CONF
  cat > "$SB_DIR/logind.conf" <<'CONF'
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
CONF

  REPO_DIR="$SB_HOME/git/carbotracker"
  NVM_DIR="$SB_HOME/.nvm"
  SYSTEMD_USER_DIR="$SB_HOME/.config/systemd/user"
  ENV_FILE="$SB_HOME/.config/carbotracker/orchestrator.env"
  UNATTENDED_CONF="$SB_DIR/unattended.conf"
  LOGIND_CONF="$SB_DIR/logind.conf"
}

cleanup_sandbox() {
  rm -rf "$SB_DIR"
  SB_DIR=""
  SB_HOME=""
}

# Run main in a subshell with the sandbox HOME (verify_opencode reads $HOME).
run_main() {
  (HOME="$SB_HOME" main) 2>&1
}

test_helpers() {
  PASS=0
  FAIL=0
  SKIP=0
  say_ok "a" >/dev/null
  say_ok "b" >/dev/null
  say_bad "c" >/dev/null
  say_skip "d" >/dev/null
  assert_eq "say_ok increments PASS" 2 "$PASS"
  assert_eq "say_bad increments FAIL" 1 "$FAIL"
  assert_eq "say_skip increments SKIP" 1 "$SKIP"

  PASS=0
  FAIL=0
  assert "assert passes on success" true >/dev/null 2>&1
  assert "assert fails on failure" false >/dev/null 2>&1
  assert_eq "assert ok counted" 1 "$PASS"
  assert_eq "assert fail counted" 1 "$FAIL"
}

test_green_main() {
  make_sandbox
  PASS=0
  FAIL=0
  SKIP=0
  local out rc
  rc=0
  if out="$(run_main)"; then
    rc=0
  else
    rc=$?
  fi
  assert_eq "green main exits 0" 0 "$rc"
  assert_contains "green summary has no failures" "SUMMARY: 32 ok, 0 fail, 0 skip" "$out"
  cleanup_sandbox
}

test_gap_main() {
  make_sandbox
  rm -f "$REPO_DIR/tools/carbotracker-node-sync.service"
  PASS=0
  FAIL=0
  SKIP=0
  local out rc
  rc=0
  if out="$(run_main)"; then
    rc=0
  else
    rc=$?
  fi
  assert_eq "gap main exits non-zero" 1 "$rc"
  assert_contains "gap summary reports one failure" "SUMMARY: 31 ok, 1 fail, 0 skip" "$out"
  cleanup_sandbox
}

run_test() {
  fake_setup
  install_fakes
  "$1"
  fake_teardown
}

run_test test_helpers
run_test test_green_main
run_test test_gap_main

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
