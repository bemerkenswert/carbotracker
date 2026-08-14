#!/usr/bin/env bash
# ct-orchestrator-setup.sh — bootstrap a VPS for the carbotracker orchestrator.
#
# Running this on a fresh VPS clones the repo, installs the systemd user
# service unit, enables lingering, and starts the daemon. Idempotent: safe to
# run repeatedly (an existing clone is pulled, the unit is overwritten, and
# systemctl enable/start are no-ops when the service is already active).
#
# Prerequisites (all must be installed and on PATH):
#   - gh          GitHub CLI, authenticated with `gh auth login` (repo scope)
#   - node/npm    Node.js toolchain (used inside ticket worktrees)
#   - jq          JSON processor used by the daemon scripts
#   - opencode    The agent that implements tickets
#   - git, systemctl, loginctl (systemd user session)
#
# The repo is cloned over HTTPS by default; gh acts as the git credential
# helper for later pushes. Override with CARBOTRACKER_REPO_URL.

set -euo pipefail

REPO_URL="${CARBOTRACKER_REPO_URL:-https://github.com/bemerkenswert/carbotracker.git}"
REPO_DIR="${CARBOTRACKER_REPO_DIR:-$HOME/git/carbotracker}"
SERVICE_UNIT="carbotracker-orchestrator.service"
SERVICE_NAME="carbotracker-orchestrator"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

# Prerequisites that must be installed and on PATH (also documented above).
PREREQ_TOOLS=(gh git node npm jq opencode systemctl loginctl)

setup_log() {
  printf '[ct-orchestrator-setup] %s\n' "$*"
}

check_prereqs() {
  local missing=0 tool
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Error: required tool '$tool' is not installed or not on PATH." >&2
      missing=1
    fi
  done
  if [[ $missing -eq 1 ]]; then
    return 1
  fi
}

setup_clone() {
  if [[ -d "$REPO_DIR/.git" ]]; then
    setup_log "updating existing clone at $REPO_DIR"
    git -C "$REPO_DIR" remote set-url origin "$REPO_URL"
    git -C "$REPO_DIR" pull --ff-only
  else
    setup_log "cloning $REPO_URL into $REPO_DIR"
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

setup_install_unit() {
  setup_log "installing systemd user unit $SERVICE_UNIT"
  mkdir -p "$SYSTEMD_USER_DIR"
  cp "$REPO_DIR/tools/$SERVICE_UNIT" "$SYSTEMD_USER_DIR/$SERVICE_UNIT"
}

setup_enable_linger() {
  setup_log "enabling lingering so the daemon survives logout"
  loginctl enable-linger
}

setup_enable_start() {
  setup_log "reloading the systemd user daemon"
  systemctl --user daemon-reload
  setup_log "enabling and starting $SERVICE_NAME"
  systemctl --user enable --now "$SERVICE_NAME"
}

setup_verify() {
  setup_log "verifying $SERVICE_NAME is running"
  systemctl --user status "$SERVICE_NAME"
}

setup_help() {
  echo "Usage:"
  echo "  ct-orchestrator-setup.sh                Bootstrap the orchestrator on a VPS"
  echo "  ct-orchestrator-setup.sh help           Show this help"
}

main() {
  case "${1:-}" in
    help | --help | -h)
      setup_help
      ;;
    "")
      check_prereqs "${PREREQ_TOOLS[@]}"
      setup_clone
      setup_install_unit
      setup_enable_linger
      setup_enable_start
      setup_verify
      ;;
    *)
      setup_help >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
