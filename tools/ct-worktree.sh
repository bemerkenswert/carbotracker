#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/ct-lib.sh"

cmd_start() {
  if ! command -v gh &>/dev/null; then
    echo "Error: gh (GitHub CLI) is not installed."
    exit 1
  fi

  local issue_number="$1"

  read -r -p "Have you opened a new terminal? [Y/n] " answer
  if [[ "$answer" =~ ^[Nn] ]]; then
    echo "Open a new terminal first, then run this command."
    exit 1
  fi

  if ! ct_worktree_create "$issue_number"; then
    exit 1
  fi

  echo "Installing dependencies..."
  cd "$CT_WORKTREE_DIR"
  npm ci --prefer-offline --no-audit --no-fund

  echo "Starting opencode..."
  exec opencode --agent build --model opencode-go/deepseek-v4-flash --prompt "/implement the issue is $issue_number"
}

cmd_help() {
  echo "Usage:"
  echo "  npm run worktree:start -- <issue-number>"
  echo "  npm run worktree:list"
  echo "  npm run worktree:prune"
}

case "${1:-}" in
  start)
    if [[ -z "${2:-}" ]]; then
      echo "Error: Issue number required."
      echo "Usage: npm run worktree:start -- <issue-number>"
      exit 1
    fi
    cmd_start "$2"
    ;;
  list | ls)
    ct_worktree_list
    ;;
  prune)
    ct_worktree_prune
    ;;
  help | --help | -h)
    cmd_help
    ;;
  *)
    cmd_help
    ;;
esac
