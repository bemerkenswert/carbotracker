#!/usr/bin/env bash

WORKTREE_PARENT="$HOME/git/worktrees/carbotracker"

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//'
}

ct_issue_title() {
  gh issue view "$1" --json title --jq .title 2>/dev/null || true
}

ct_issue_body() {
  gh issue view "$1" --json body --jq .body 2>/dev/null || true
}

ct_body_blocker_numbers() {
  local body="$1"
  {
    printf '%s' "$body" | sed -n '/^[#* -]*[Bb]locked [Bb]y:/p' | grep -oE '#[0-9]+' | tr -d '#' || true
    printf '%s' "$body" | awk '
      /^## *[Bb]locked [Bb]y:*/ { in_section = 1; next }
      /^## / { in_section = 0 }
      in_section { print }
    ' | grep -oE '#[0-9]+' | tr -d '#' || true
  } | sort -un
}

ct_issue_is_blocked() {
  local number="$1" summary
  if summary="$(gh api "repos/{owner}/{repo}/issues/$number/issue_dependencies_summary" --jq '.blocked_by | length' 2>/dev/null)"; then
    if [[ "$summary" -gt 0 ]]; then
      return 0
    fi
    return 1
  fi
  # Native dependencies unavailable: fall back to the "Blocked by" line/section
  # in the body. Unresolvable blockers fail closed (treated as blocked) so a
  # transient gh failure never causes blocked work to be claimed.
  local body blocker state
  body="$(ct_issue_body "$number")"
  for blocker in $(ct_body_blocker_numbers "$body"); do
    state="$(gh issue view "$blocker" --json state --jq .state 2>/dev/null)"
    if [[ "$state" == "OPEN" ]]; then
      return 0
    fi
    if [[ "$state" != "CLOSED" ]]; then
      return 0
    fi
  done
  return 1
}

ct_candidate_issues() {
  local labels="${ORCHESTRATOR_ISSUE_LABELS:-ready-for-agent,ticket}" label
  local labels_array=() args=()
  IFS=',' read -ra labels_array <<< "$labels"
  for label in "${labels_array[@]}"; do
    args+=(--label "$label")
  done
  gh issue list --state open --json number,title "${args[@]}" 2>/dev/null \
    | jq '[.[] | {number, title}] | sort_by(.number)' 2>/dev/null || printf '[]'
}

ct_merged_pr_count() {
  gh pr list --head "$1" --state merged --json number --jq 'length' 2>/dev/null || echo 0
}

ct_worktree_add() {
  local dir="$1" branch="$2"

  git fetch origin main || return 1

  if [[ -d "$dir" ]]; then
    echo "Error: Worktree already exists at $dir" >&2
    return 1
  fi

  mkdir -p "$(dirname "$dir")" || return 1
  git worktree add "$dir" -b "$branch" origin/main || return 1
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

  ct_worktree_add "$CT_WORKTREE_DIR" "$CT_WORKTREE_BRANCH" || return 1
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
