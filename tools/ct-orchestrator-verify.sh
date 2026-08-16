#!/usr/bin/env bash
# ct-orchestrator-verify.sh — read-only checks for a carbotracker orchestrator
# host. Run it on the machine (e.g. the laptop ct-golden-orch) and eyeball the
# PASS/FAIL output. Exits non-zero if any check fails.
#
# Never prints secrets: it asserts GH_TOKEN presence without showing the value,
# and never reads netplan (which holds the Wi-Fi password).
#
# Override the paths below with env vars to run against a sandbox (see
# tools/tests/ct-orchestrator-verify.test.sh):
#   REPO_DIR, NVM_DIR, SYSTEMD_USER_DIR, ENV_FILE, UNATTENDED_CONF, LOGIND_CONF
set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/git/carbotracker}"
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
SYSTEMD_USER_DIR="${SYSTEMD_USER_DIR:-$HOME/.config/systemd/user}"
ENV_FILE="${ENV_FILE:-$HOME/.config/carbotracker/orchestrator.env}"
UNATTENDED_CONF="${UNATTENDED_CONF:-/etc/apt/apt.conf.d/50unattended-upgrades}"
LOGIND_CONF="${LOGIND_CONF:-/etc/systemd/logind.conf}"

PASS=0
FAIL=0
SKIP=0

say_ok() {
  printf '  [OK]   %s\n' "$1"
  PASS=$((PASS + 1))
}

say_bad() {
  printf '  [FAIL] %s\n' "$1"
  FAIL=$((FAIL + 1))
}

say_skip() {
  printf '  [SKIP] %s\n' "$1"
  SKIP=$((SKIP + 1))
}

say_info() {
  printf '  [info] %s\n' "$*"
}

assert() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    say_ok "$desc"
  else
    say_bad "$desc"
  fi
}

verify_node() {
  echo "===== node / nvm ====="
  if [ -s "$NVM_DIR/nvm.sh" ]; then
    say_ok "nvm.sh present"
  else
    say_bad "nvm.sh missing"
  fi
  if [ -L "$NVM_DIR/node-current" ]; then
    say_info "node-current -> $(readlink "$NVM_DIR/node-current")"
    say_ok "node-current symlink"
  else
    say_bad "node-current symlink missing"
  fi
  if [ -x "$NVM_DIR/node-current/bin/node" ]; then
    say_info "node: $("$NVM_DIR/node-current/bin/node" -v)"
    say_ok "node on stable path"
  else
    say_bad "node not on stable path"
  fi
  if [ -x "$NVM_DIR/node-current/bin/npm" ]; then
    say_info "npm: $("$NVM_DIR/node-current/bin/npm" -v)"
    say_ok "npm on stable path"
  else
    say_bad "npm not on stable path"
  fi
  if [ -f "$REPO_DIR/.nvmrc" ]; then
    local want got
    want="$(sed 's/^v//; s/\..*//' "$REPO_DIR/.nvmrc")"
    got="$("$NVM_DIR/node-current/bin/node" -v 2>/dev/null | sed 's/^v//; s/\..*//' || true)"
    say_info ".nvmrc major=$want  node major=$got"
    if [ "$want" = "$got" ]; then
      say_ok "node major matches .nvmrc"
    else
      say_bad "node major mismatch"
    fi
  else
    say_bad ".nvmrc missing"
  fi
}

verify_gh() {
  echo "===== gh ====="
  if command -v gh >/dev/null 2>&1; then
    say_info "gh: $(gh --version 2>/dev/null | head -1)"
    say_ok "gh on PATH"
  else
    say_bad "gh not on PATH"
  fi
  if gh api repos/bemerkenswert/carbotracker --jq .name 2>/dev/null | grep -q .; then
    say_ok "gh token works against the repo"
  else
    say_bad "gh token cannot reach the repo"
  fi
  local helper
  helper="$(git config --global --get credential.https://github.com.helper 2>/dev/null || true)"
  say_info "git credential helper: ${helper:-<unset>}"
  if [ -n "$helper" ]; then
    say_ok "gh setup-git wired"
  else
    say_bad "gh setup-git not wired"
  fi
}

verify_opencode() {
  echo "===== opencode ====="
  if [ -x "$HOME/.opencode/bin/opencode" ]; then
    say_info "opencode: $HOME/.opencode/bin/opencode"
    say_ok "opencode present"
  else
    say_bad "opencode missing at ~/.opencode/bin"
  fi
}

verify_repo() {
  echo "===== repo (convergence) ====="
  if [ -d "$REPO_DIR/.git" ]; then
    say_info "branch: $(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    say_info "HEAD:   $(git -C "$REPO_DIR" log --oneline -1 2>/dev/null)"
    say_info "status:"
    git -C "$REPO_DIR" status -sb 2>/dev/null | sed 's/^/    /'
    if git -C "$REPO_DIR" status -sb 2>/dev/null | grep -q 'behind'; then
      say_bad "repo is BEHIND origin/main"
    else
      say_ok "repo up to date with origin/main"
    fi
  else
    say_bad "repo clone missing"
  fi
  if [ -f "$REPO_DIR/.nvmrc" ]; then
    say_ok ".nvmrc present"
  else
    say_bad ".nvmrc missing"
  fi
  if [ -d "$REPO_DIR/node_modules/ajv" ]; then
    say_ok "main-repo node_modules/ajv present"
  else
    say_bad "main-repo ajv missing"
  fi
  local f
  for f in tools/ct-node-sync.sh tools/carbotracker-node-sync.service; do
    if [ -f "$REPO_DIR/$f" ]; then
      say_ok "$f present in repo"
    else
      say_bad "$f missing in repo"
    fi
  done
}

verify_systemd() {
  echo "===== systemd ====="
  local u
  for u in carbotracker-orchestrator carbotracker-node-sync; do
    if [ -f "$SYSTEMD_USER_DIR/$u.service" ]; then
      say_ok "$u.service installed"
    else
      say_bad "$u.service missing"
    fi
  done
  assert "orchestrator enabled" systemctl --user is-enabled --quiet carbotracker-orchestrator
  assert "node-sync enabled" systemctl --user is-enabled --quiet carbotracker-node-sync
  assert "orchestrator active" systemctl --user is-active --quiet carbotracker-orchestrator
  local linger
  linger="$(loginctl show-user "$USER" -p Linger 2>/dev/null | cut -d= -f2 || true)"
  say_info "linger: ${linger:-<unknown>}"
  if [ "$linger" = yes ]; then
    say_ok "lingering enabled"
  else
    say_bad "lingering not enabled"
  fi
  say_info "orchestrator unit env lines:"
  grep -E '^(Environment|EnvironmentFile)' "$SYSTEMD_USER_DIR/carbotracker-orchestrator.service" 2>/dev/null | sed 's/^/    /' || true
  if grep -q '^Environment=PATH=' "$SYSTEMD_USER_DIR/carbotracker-orchestrator.service" 2>/dev/null; then
    say_ok "unit has Environment=PATH"
  else
    say_bad "unit missing Environment=PATH"
  fi
  if grep -q '^EnvironmentFile=-' "$SYSTEMD_USER_DIR/carbotracker-orchestrator.service" 2>/dev/null; then
    say_ok "unit EnvironmentFile is optional (-)"
  else
    say_bad "unit EnvironmentFile missing the - prefix"
  fi
  if grep -q '^Before=carbotracker-orchestrator.service' "$SYSTEMD_USER_DIR/carbotracker-node-sync.service" 2>/dev/null; then
    say_ok "node-sync Before= orchestrator"
  else
    say_bad "node-sync Before= missing"
  fi
}

verify_secrets() {
  echo "===== secrets (presence only) ====="
  if [ -f "$ENV_FILE" ]; then
    local mode
    mode="$(stat -c '%a' "$ENV_FILE")"
    say_info "orchestrator.env mode: $mode"
    if [ "$mode" = 600 ]; then
      say_ok "orchestrator.env mode 600"
    else
      say_bad "orchestrator.env mode not 600"
    fi
    if grep -q '^GH_TOKEN=.\+' "$ENV_FILE"; then
      say_ok "GH_TOKEN present"
    else
      say_bad "GH_TOKEN missing"
    fi
  else
    say_bad "orchestrator.env missing"
  fi
}

verify_network() {
  echo "===== network ====="
  ip -4 -brief addr show 2>/dev/null | grep -v '^lo ' || true
  ip -4 route show default 2>/dev/null || true
  if ip -4 route show default 2>/dev/null | grep -q .; then
    say_ok "default route present"
  else
    say_bad "no default route"
  fi
}

verify_hardening() {
  echo "===== hardening ====="
  if dpkg -l unattended-upgrades 2>/dev/null | grep -q '^ii'; then
    say_ok "unattended-upgrades installed"
  else
    say_bad "unattended-upgrades not installed"
  fi
  say_info "unattended config:"
  grep -E 'Automatic-Reboot|OnlyOnACPower' "$UNATTENDED_CONF" 2>/dev/null | sed 's/^/    /' || true
  if grep -qE '^Unattended-Upgrade::Automatic-Reboot "true";' "$UNATTENDED_CONF" 2>/dev/null; then
    say_ok "automatic reboot enabled (true)"
  else
    say_bad "automatic reboot still false/commented"
  fi
  say_info "ufw:"
  local ufw_out
  ufw_out="$(sudo ufw status 2>/dev/null || true)"
  printf '%s\n' "$ufw_out" | sed 's/^/    /'
  if printf '%s\n' "$ufw_out" | grep -q 'Status: active'; then
    say_ok "ufw active"
  else
    say_bad "ufw not active"
  fi
  if printf '%s\n' "$ufw_out" | grep -q 'OpenSSH'; then
    say_ok "ufw allows OpenSSH"
  else
    say_bad "ufw missing OpenSSH rule"
  fi
  say_info "lid switch:"
  grep -E 'HandleLidSwitch' "$LOGIND_CONF" 2>/dev/null | grep -v '^#' | sed 's/^/    /' || true
  if grep -qE '^HandleLidSwitch=ignore' "$LOGIND_CONF" 2>/dev/null \
    && grep -qE '^HandleLidSwitchExternalPower=ignore' "$LOGIND_CONF" 2>/dev/null; then
    say_ok "lid close ignored"
  else
    say_bad "lid close not ignored"
  fi
}

verify_journal() {
  echo "===== journal (last lines) ====="
  journalctl --user -u carbotracker-orchestrator -n 12 --no-pager 2>/dev/null | sed 's/^/    /' || true
}

main() {
  verify_node
  verify_gh
  verify_opencode
  verify_repo
  verify_systemd
  verify_secrets
  verify_network
  verify_hardening
  verify_journal
  echo
  printf 'SUMMARY: %d ok, %d fail, %d skip\n' "$PASS" "$FAIL" "$SKIP"
  if [ "$FAIL" -gt 0 ]; then
    return 1
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main || exit $?
fi
