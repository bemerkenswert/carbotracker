#!/usr/bin/env bash

WORKTREE_PARENT="$HOME/git/worktrees/carbotracker"

slugify() {
  # LC_ALL=C keeps character ranges ASCII-only so output is identical under
  # any locale (UTF-8 would let non-ASCII through into branch names).
  printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]' | LC_ALL=C sed 's/[^a-z0-9]/-/g' | LC_ALL=C sed 's/--*/-/g' | LC_ALL=C sed 's/^-//;s/-$//'
}

# The deterministic branch name for a ticket — the pipeline's single source of
# truth so the orchestrator, ct-worktree.sh, and the recovery tool can never
# derive different paths for the same ticket.
ct_ticket_branch() {
  local number="$1" title="$2"
  printf 'ticket/%s-%s' "$number" "$(slugify "$title")"
}

# The deterministic worktree path for a ticket, derived from the same slug as
# the branch so the session's original directory can be recomputed after the
# orchestrator pruned it. $3 overrides the parent directory (the orchestrator
# passes its own configurable ORCHESTRATOR_WORKTREE_PARENT).
ct_ticket_worktree() {
  local number="$1" title="$2" parent="${3:-$WORKTREE_PARENT}"
  printf '%s/%s-%s' "$parent" "$number" "$(slugify "$title")"
}

# The stash-message contract between the orchestrator (which stashes on
# escalation) and the recovery tool (which greps for the entry): the fixed
# prefix naming the ticket. The orchestrator appends the timestamp and session
# id; the recovery tool greps for the prefix verbatim (grep -F), so the two
# sides can never drift apart.
ct_stash_message_prefix() {
  local number="$1"
  printf 'carbotracker: ticket %s uncommitted work at escalation (' "$number"
}

# The newest stash entry for a ticket — "ref<TAB>subject" or nothing. Stash
# list is newest-first, so the first match is the ticket's latest work. The
# shared consumer for both the recovery tool and the orchestrator's escalation
# comments, so they can never select different entries for the same ticket.
ct_ticket_stash_line() {
  local number="$1"
  git stash list --format='%gd%x09%gs' 2>/dev/null \
    | grep -F "$(ct_stash_message_prefix "$number")" \
    | head -n 1 || true
}

ct_issue_title() {
  gh issue view "$1" --json title --jq .title 2>/dev/null || true
}

ct_issue_body() {
  gh issue view "$1" --json body --jq .body 2>/dev/null || true
}

ct_issue_feature() {
  local body="$1"
  printf '%s\n' "$body" \
    | sed -nE 's/^[[:space:]]*[Ff]eature:[[:space:]]*([a-z0-9]+(-[a-z0-9]+)*)[[:space:]]*$/\1/p' \
    | head -n 1
}

ct_changed_files() {
  # The changed file paths of a branch worktree against main (non-fatal).
  local worktree="$1"
  git -C "$worktree" diff --name-only origin/main...HEAD 2>/dev/null || true
}

ct_changed_features() {
  local worktree="$1"
  ct_changed_files "$worktree" \
    | sed -nE 's#^(.*/)?features/([a-z0-9]+(-[a-z0-9]+)*)/.*#\2#p' \
    | sort -u
}

ct_feature_diff_is_suspect() {
  local worktree="$1" body="$2" declared features
  declared="$(ct_issue_feature "$body")"
  [[ -n "$declared" ]] || return 1
  features="$(ct_changed_features "$worktree")"
  [[ -n "$features" ]] || return 1
  ! printf '%s\n' "$features" | grep -Fxq "$declared" \
    && [[ "$(printf '%s\n' "$features" | wc -l)" -gt 0 ]]
}

ct_shared_files() {
  # The exact intersection of two newline-separated file lists: every path in
  # $1 that also appears verbatim in $2 (whole-line match, so a path is never
  # mistaken for one of its prefixes). Emits the matches in $1's order.
  local a="$1" b="$2" f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if printf '%s\n' "$b" | grep -Fxq "$f"; then
      printf '%s\n' "$f"
    fi
  done <<< "$a"
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

  CT_WORKTREE_CREATED=0
  git fetch origin main || return 1

  if [[ -d "$dir" ]]; then
    echo "Error: Worktree already exists at $dir" >&2
    return 1
  fi

  mkdir -p "$(dirname "$dir")" || return 1
  git worktree add "$dir" -b "$branch" origin/main || return 1
  CT_WORKTREE_CREATED=1
}

ct_worktree_create() {
  local issue_number="$1"
  local title
  title=$(ct_issue_title "$issue_number")
  if [[ -z "$title" ]]; then
    echo "Error: Could not find issue #$issue_number" >&2
    return 1
  fi

  CT_WORKTREE_TITLE="$title"
  CT_WORKTREE_BRANCH="$(ct_ticket_branch "$issue_number" "$title")"
  CT_WORKTREE_DIR="$(ct_ticket_worktree "$issue_number" "$title")"

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
