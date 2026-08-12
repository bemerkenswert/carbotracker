#!/usr/bin/env bash

WORKTREE_PARENT="$HOME/git/worktrees/carbotracker"

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

ct_issue_title() {
  gh issue view "$1" --json title --jq .title 2>/dev/null || true
}

ct_merged_pr_count() {
  gh pr list --head "$1" --state merged --json number --jq 'length' 2>/dev/null || echo 0
}

ct_worktree_create() {
  local issue_number="$1"
  local title slug
  title=$(ct_issue_title "$issue_number")
  if [[ -z "$title" ]]; then
    echo "Error: Could not find issue #$issue_number" >&2
    return 1
  fi

  slug=$(slugify "$title")
  CT_WORKTREE_TITLE="$title"
  CT_WORKTREE_BRANCH="ticket/$issue_number-$slug"
  CT_WORKTREE_DIR="$WORKTREE_PARENT/$issue_number-$slug"

  echo "Issue:  #$issue_number - $title"
  echo "Branch: $CT_WORKTREE_BRANCH"
  echo "Path:   $CT_WORKTREE_DIR"
  echo ""

  git fetch origin main || return 1

  if [[ -d "$CT_WORKTREE_DIR" ]]; then
    echo "Error: Worktree already exists at $CT_WORKTREE_DIR" >&2
    return 1
  fi

  mkdir -p "$WORKTREE_PARENT" || return 1
  git worktree add "$CT_WORKTREE_DIR" -b "$CT_WORKTREE_BRANCH" origin/main || return 1
}

ct_worktree_list() {
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

ct_worktree_prune() {
  git fetch origin main 2>/dev/null || true
  local count=0

  for dir in "$WORKTREE_PARENT"/*/; do
    dir="${dir%/}"
    if [[ ! -d "$dir" ]]; then continue; fi

    local branch
    branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -z "$branch" || "$branch" == "HEAD" ]]; then continue; fi

    local pr_count
    pr_count=$(ct_merged_pr_count "$branch")
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
