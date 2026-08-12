#!/usr/bin/env bash
set -euo pipefail

WORKTREE_PARENT="$HOME/git/worktrees/carbotracker"

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

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

  local title
  title=$(gh issue view "$issue_number" --json title --jq .title 2>/dev/null) || true
  if [[ -z "$title" ]]; then
    echo "Error: Could not find issue #$issue_number"
    exit 1
  fi

  local slug branch target_dir
  slug=$(slugify "$title")
  branch="ticket/$issue_number-$slug"
  target_dir="$WORKTREE_PARENT/$issue_number-$slug"

  echo "Issue:  #$issue_number - $title"
  echo "Branch: $branch"
  echo "Path:   $target_dir"
  echo ""

  git fetch origin main

  if [[ -d "$target_dir" ]]; then
    echo "Error: Worktree already exists at $target_dir"
    exit 1
  fi

  mkdir -p "$WORKTREE_PARENT"
  git worktree add "$target_dir" -b "$branch" origin/main

  echo "Installing dependencies..."
  cd "$target_dir"
  npm ci --prefer-offline --no-audit --no-fund

  echo "Starting opencode..."
  exec opencode --agent build --model opencode-go/deepseek-v4-flash --prompt "/implement the issue is $issue_number"
}

cmd_list() {
  echo "Carbotracker worktrees:"
  echo ""

  local found=0
  while IFS= read -r line; do
    local path
    path=$(echo "$line" | awk '{print $1}')
    if [[ "$path" == "$WORKTREE_PARENT"* ]]; then
      local branch rest
      branch=$(echo "$line" | awk '{print $2}')
      rest=$(echo "$line" | awk '{$1=$2=""; sub(/^[ \t]+/, ""); print}')
      printf "  %-70s %s\n" "$path" "$branch ($rest)"
      found=1
    fi
  done < <(git worktree list)

  if [[ $found -eq 0 ]]; then
    echo "  (none)"
  fi
}

cmd_prune() {
  git fetch origin main 2>/dev/null || true
  local count=0

  for dir in "$WORKTREE_PARENT"/*/; do
    dir="${dir%/}"
    if [[ ! -d "$dir" ]]; then continue; fi

    local branch
    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then continue; fi

    local pr_count
    pr_count=$(gh pr list --head "$branch" --state merged --json number --jq 'length' 2>/dev/null || echo 0)
    if [[ "$pr_count" -gt 0 ]]; then
      echo "Removing: $dir ($branch)"
      git worktree remove "$dir" 2>/dev/null || git worktree remove --force "$dir"
      git branch -D "$branch" 2>/dev/null || true
      count=$((count + 1))
    fi
  done

  if [[ $count -eq 0 ]]; then
    echo "No worktrees to prune."
  else
    echo "Pruned $count worktree(s)."
  fi
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
    cmd_list
    ;;
  prune)
    cmd_prune
    ;;
  help | --help | -h)
    cmd_help
    ;;
  *)
    cmd_help
    ;;
esac
