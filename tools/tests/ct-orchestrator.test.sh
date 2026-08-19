#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CT_ORCHESTRATOR_CONF="$(mktemp)"
export CT_ORCHESTRATOR_CONF
source "$ROOT/tools/ct-orchestrator.sh"
rm -f "$CT_ORCHESTRATOR_CONF"

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

fake_setup() {
  FAKE_DIR="$(mktemp -d)"
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

# Fake a successful worktree-add (creates the dir) and npm ci. When
# FAKE_GIT_PUSH_FILE is set, the push invocation is captured to it.
fake_worktree_npm() {
  fake_command git 'full_args="$*"
if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "push" && -n "${FAKE_GIT_PUSH_FILE:-}" ]]; then
  printf "%s\n" "$full_args" > "$FAKE_GIT_PUSH_FILE"
elif [[ "$1" == "rev-parse" ]]; then
  exit 1
elif [[ "$1" == "rev-list" ]]; then
  printf "1\n"
fi
exit 0'
  fake_command npm 'exit 0'
}

# Fake git for the stalled/empty implement tests: worktree add/remove, a
# configurable `git status --porcelain` payload ($FAKE_GIT_STATUS — empty/absent
# means a clean tree), a scripted rev-list sequence ($FAKE_REVLIST_SEQ, one
# value consumed per call, default 0), and optional push capture. The rev-list
# value is the unpushed-commit count, so a resumed run "commits" by putting a 1
# in the sequence at the point it should be observed. Fake bodies run at top
# level (no `local`).
fake_stalled_git() {
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "worktree" && "$2" == "remove" ]]; then
  rm -rf "$3" "$4"
elif [[ "$1" == "status" ]]; then
  cat "${FAKE_GIT_STATUS:-/dev/null}" 2>/dev/null || true
elif [[ "$1" == "rev-parse" ]]; then
  exit 0
elif [[ "$1" == "rev-list" ]]; then
  v="$(head -n1 "${FAKE_REVLIST_SEQ:-/dev/null}" 2>/dev/null)"
  v="${v:-0}"
  if [[ -n "${FAKE_REVLIST_SEQ:-}" && -f "$FAKE_REVLIST_SEQ" ]]; then
    tail -n +2 "$FAKE_REVLIST_SEQ" > "$FAKE_REVLIST_SEQ.tmp" && mv "$FAKE_REVLIST_SEQ.tmp" "$FAKE_REVLIST_SEQ"
  fi
  printf "%s\n" "$v"
elif [[ "$1" == "push" && -n "${FAKE_GIT_PUSH_FILE:-}" ]]; then
  printf "%s\n" "$*" > "$FAKE_GIT_PUSH_FILE"
elif [[ "$1" == "stash" ]]; then
  printf "%s\n" "$*" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
  if [[ "${FAKE_GIT_STASH_FAIL:-0}" == "1" ]]; then exit 1; fi
elif [[ "$1" == "branch" && "$2" == "-D" ]]; then
  exit 0
fi
exit 0'
  fake_command npm 'exit 0'
}

# Fake opencode for the stalled/empty implement tests: each `opencode run`
# invocation consumes one exit code from $FAKE_OPENCODE_EXITS (default 0, so
# unset behaves as a success for every invocation) and logs its args to
# $FAKE_OPENCODE_LOG (one line per invocation); session list returns a ticket-10
# session. Fake bodies run at top level (no `local`).
fake_stalled_opencode() {
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  code="$(head -n1 "${FAKE_OPENCODE_EXITS:-/dev/null}" 2>/dev/null)"
  code="${code:-0}"
  if [[ -n "${FAKE_OPENCODE_EXITS:-}" && -f "$FAKE_OPENCODE_EXITS" ]]; then
    tail -n +2 "$FAKE_OPENCODE_EXITS" > "$FAKE_OPENCODE_EXITS.tmp" && mv "$FAKE_OPENCODE_EXITS.tmp" "$FAKE_OPENCODE_EXITS"
  fi
  printf "%s\n" "$*" >> "${FAKE_OPENCODE_LOG:-/dev/null}"
  exit "$code"
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
}

# Fake the commands the implementation pipeline invokes: git worktree add,
# npm ci, opencode run + session list, and gh pr list / issue comment. The
# gh fake delegates everything else to the caller-provided body.
fake_pipeline() {
  local gh_body="$1" pr_number="${2:-100}"
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"list\" ]]; then
  printf \"[{\\\"number\\\":$pr_number}]\n\"
elif [[ \"\$1\" == \"issue\" && \"\$2\" == \"comment\" ]]; then
  exit 0
else
  $gh_body
fi
exit 0"
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "rev-parse" ]]; then
  exit 1
elif [[ "$1" == "rev-list" ]]; then
  printf "1\n"
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_10\",\"title\":\"carbotracker-ticket-10\",\"created\":1},{\"id\":\"ses_42\",\"title\":\"carbotracker-ticket-42\",\"created\":2}]\n"
fi
exit 0'
}

# Fake gh api for the review loop: the pulls query returns one human inline
# comment at $1 plus a bot reply carrying the AI-source footer (so tests
# exercise the footer exclusion), the reviews query returns nothing, and a
# general-comment POST is captured to $FAKE_PR_COMMENT_ARGS (appended).
fake_review_gh() {
  local latest="${1:-2026-08-13T00:07:00Z}"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"$latest\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\"},{\\\"created_at\\\":\\\"2026-08-13T00:09:00Z\\\",\\\"body\\\":\\\"$footer\\\"}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[]\n\"
      ;;
  esac
fi
exit 0"
}

# Fake opencode run that exits 0, optionally capturing the args and writing a
# plan file (copied from $2) to ORCHESTRATOR_REVIEW_PLAN_FILE — the analyze
# step's output channel.
fake_review_opencode_success() {
  local capture="${1:-}" plan_src="${2:-}"
  fake_command opencode "if [[ \"\$1\" == \"run\" ]]; then
  ${capture:+printf \"%s\n\" \"\$*\" > \"$capture\"}
  ${plan_src:+cp \"$plan_src\" \"\$ORCHESTRATOR_REVIEW_PLAN_FILE\"}
  exit 0
fi
exit 1"
}

# Fake gh api for the act phase: a thread reply POST is captured to
# $FAKE_THREAD_REPLY_ARGS (appended), the pulls/reviews/general-comment GETs
# feed the watermark query, and a general-comment POST is captured to
# $FAKE_PR_COMMENT_ARGS (appended).
fake_review_act_gh() {
  local latest="${1:-2026-08-13T00:07:00Z}"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *replies*)
      printf \"%s\n\" \"\$*\" >> \"\${FAKE_THREAD_REPLY_ARGS:-/dev/null}\"
      ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"$latest\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\"},{\\\"created_at\\\":\\\"2026-08-13T00:09:00Z\\\",\\\"body\\\":\\\"$footer\\\"}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[]\n\"
      ;;
  esac
fi
exit 0"
}

# Like fake_review_act_gh, but a thread reply whose body contains $1 exits 1 —
# simulating a per-thread posting failure. The first reply to fail is skipped
# (not captured), later replies still succeed.
fake_review_act_gh_fail_reply_containing() {
  local needle="$1" latest="${2:-2026-08-13T00:07:00Z}"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *replies*)
      if [[ \"\$*\" == *\"$needle\"* ]]; then exit 1; fi
      printf \"%s\n\" \"\$*\" >> \"\${FAKE_THREAD_REPLY_ARGS:-/dev/null}\"
      ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"$latest\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\"}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[]\n\"
      ;;
  esac
fi
exit 0"
}

# Like fake_review_act_gh, but every thread reply POST fails.
fake_review_act_gh_all_replies_fail() {
  fake_command gh "if [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *replies*) exit 1 ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"2026-08-13T00:07:00Z\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\"}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[]\n\"
      ;;
  esac
fi
exit 0"
}

# Write a valid single-answer plan file for the success-path tests.
write_answer_plan() {
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 3788850731, "path": "README.md", "line": 4, "type": "answer", "reply": "The ratio is stored per meal type.", "confidence": 0.9}]}' > "$1"
}

# Like fake_review_act_gh, but also answers the implement step's verification
# queries: `repo view` returns the owner/repo, `api graphql` returns the PR's
# thread state with implement comment 3788850732 resolved ($2) or not, the
# pulls listing carries a footer-bearing reply on that comment (in_reply_to_id
# 3788850732), and the issues GET returns the agent's footer-bearing reply once
# $FAKE_IMPLEMENT_RAN (touched by the fake opencode) exists — so a general
# implement comment is only seen as replied-to after the run.
fake_review_implement_gh() {
  local latest="${1:-2026-08-13T00:07:00Z}"
  local resolved="${2:-true}"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"repo\" && \"\$2\" == \"view\" ]]; then
  printf \"{\\\"nameWithOwner\\\":\\\"bemerkenswert/carbotracker\\\"}\n\"
elif [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    graphql) printf \"{\\\"data\\\":{\\\"repository\\\":{\\\"pullRequest\\\":{\\\"reviewThreads\\\":{\\\"nodes\\\":[{\\\"id\\\":\\\"PRRT_1\\\",\\\"isResolved\\\":$resolved,\\\"comments\\\":{\\\"nodes\\\":[{\\\"databaseId\\\":3788850732}]}}]}}}}}\n\" ;;
    *reviews*) printf \"[]\n\" ;;
    *replies*)
      printf \"%s\n\" \"\$*\" >> \"\${FAKE_THREAD_REPLY_ARGS:-/dev/null}\"
      ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"$latest\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\",\\\"id\\\":1,\\\"in_reply_to_id\\\":null},{\\\"created_at\\\":\\\"2026-08-13T00:09:00Z\\\",\\\"body\\\":\\\"$footer\\\",\\\"id\\\":9001,\\\"in_reply_to_id\\\":3788850732}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      if [[ -f \"\${FAKE_IMPLEMENT_RAN:-/nonexistent}\" ]]; then
        printf \"[{\\\"id\\\":9001,\\\"body\\\":\\\"$footer\\\"}]\n\"
      else
        printf \"[]\n\"
      fi
      ;;
  esac
fi
exit 0"
}

# Like fake_review_implement_gh, but the issues GET never shows an agent reply,
# so a general implement comment can never satisfy the reply check.
fake_review_implement_gh_no_general_reply() {
  local latest="${1:-2026-08-13T00:07:00Z}"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"repo\" && \"\$2\" == \"view\" ]]; then
  printf \"{\\\"nameWithOwner\\\":\\\"bemerkenswert/carbotracker\\\"}\n\"
elif [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    graphql) printf \"{\\\"data\\\":{\\\"repository\\\":{\\\"pullRequest\\\":{\\\"reviewThreads\\\":{\\\"nodes\\\":[{\\\"id\\\":\\\"PRRT_1\\\",\\\"isResolved\\\":true,\\\"comments\\\":{\\\"nodes\\\":[{\\\"databaseId\\\":3788850732}]}}]}}}}}\n\" ;;
    *reviews*) printf \"[]\n\" ;;
    *replies*)
      printf \"%s\n\" \"\$*\" >> \"\${FAKE_THREAD_REPLY_ARGS:-/dev/null}\"
      ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"$latest\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\",\\\"id\\\":1,\\\"in_reply_to_id\\\":null}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[]\n\"
      ;;
  esac
fi
exit 0"
}

# Like fake_review_implement_gh, but the pulls listing never carries a reply on
# implement comment 3788850732, so a resolved-but-unreplied thread fails the
# verification.
fake_review_implement_gh_no_reply() {
  local latest="${1:-2026-08-13T00:07:00Z}"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"repo\" && \"\$2\" == \"view\" ]]; then
  printf \"{\\\"nameWithOwner\\\":\\\"bemerkenswert/carbotracker\\\"}\n\"
elif [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    graphql) printf \"{\\\"data\\\":{\\\"repository\\\":{\\\"pullRequest\\\":{\\\"reviewThreads\\\":{\\\"nodes\\\":[{\\\"id\\\":\\\"PRRT_1\\\",\\\"isResolved\\\":true,\\\"comments\\\":{\\\"nodes\\\":[{\\\"databaseId\\\":3788850732}]}}]}}}}}\n\" ;;
    *reviews*) printf \"[]\n\" ;;
    *replies*)
      printf \"%s\n\" \"\$*\" >> \"\${FAKE_THREAD_REPLY_ARGS:-/dev/null}\"
      ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"$latest\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\",\\\"id\\\":1,\\\"in_reply_to_id\\\":null},{\\\"created_at\\\":\\\"2026-08-13T00:09:00Z\\\",\\\"body\\\":\\\"$footer\\\",\\\"id\\\":9001,\\\"in_reply_to_id\\\":null}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[]\n\"
      ;;
  esac
fi
exit 0"
}

# Fake opencode for a full implement round: the analyze run writes the plan
# (copied from $1, only once), every run is appended to $2 — the analyze
# prompt first, then the comment-scoped /implement prompt — and the implement
# run (recognised by /implement in its args) marks $FAKE_IMPLEMENT_RAN so the
# fake gh knows the implement session ran.
fake_review_opencode_implement_round() {
  local plan_src="$1" log="${2:-}"
  fake_command opencode "if [[ \"\$1\" == \"run\" ]]; then
  ${log:+printf \"%s\n\" \"\$*\" >> \"$log\"}
  if [[ \"\$*\" == *\"/implement\"* ]]; then
    touch \"\${FAKE_IMPLEMENT_RAN:-/dev/null}\"
  fi
  if [[ ! -f \"\${ORCHESTRATOR_REVIEW_PLAN_FILE:-}\" ]]; then
    ${plan_src:+cp \"$plan_src\" \"\$ORCHESTRATOR_REVIEW_PLAN_FILE\"}
  fi
  exit 0
fi
exit 1"
}

# Fake opencode run that exits 1, optionally appending a marker per launch.
fake_review_opencode_fail() {
  local log="${1:-}"
  fake_command opencode "if [[ \"\$1\" == \"run\" ]]; then
  ${log:+printf \"x\n\" >> \"$log\"}
  exit 1
fi
exit 1"
}

# Fake gh for the merge poll: `pr view` returns the PR state passed as $1, an
# `issue edit` (label removal) is captured to $FAKE_ISSUE_EDIT_ARGS, and an
# `issue close` invocation is captured to $FAKE_ISSUE_CLOSE_ARGS. Everything
# else exits 0 with no output.
fake_merge_gh() {
  local state="${1:-OPEN}"
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"view\" ]]; then
  printf \"$state\n\"
elif [[ \"\$1\" == \"issue\" && \"\$2\" == \"edit\" ]]; then
  printf \"%s\n\" \"\$*\" > \"\${FAKE_ISSUE_EDIT_ARGS:-/dev/null}\"
elif [[ \"\$1\" == \"issue\" && \"\$2\" == \"close\" ]]; then
  printf \"%s\n\" \"\$*\" > \"\${FAKE_ISSUE_CLOSE_ARGS:-/dev/null}\"
fi
exit 0"
}

# Fake git that removes the dir on `worktree remove`, mirroring how the
# cleanup helper is invoked by the orchestrator. `status --porcelain` reads
# $FAKE_GIT_STATUS (empty/absent means a clean tree) and every `stash`
# invocation is appended to $FAKE_GIT_STASH_ARGS (exiting 1 when
# FAKE_GIT_STASH_FAIL is set).
fake_merge_git() {
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "remove" ]]; then
  rm -rf "$3" "$4"
elif [[ "$1" == "status" ]]; then
  cat "${FAKE_GIT_STATUS:-/dev/null}" 2>/dev/null || true
elif [[ "$1" == "stash" ]]; then
  printf "%s\n" "$*" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
  if [[ "${FAKE_GIT_STASH_FAIL:-0}" == "1" ]]; then exit 1; fi
elif [[ "$1" == "branch" && "$2" == "-D" ]]; then
  exit 0
fi
exit 0'
}

fake_behind_merge_gh() {
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "$*" == *"--json mergeStateStatus"* ]]; then printf "BEHIND\n";
  elif [[ "$*" == *"--json labels"* ]]; then printf "\n";
  else printf "OPEN\n"; fi
fi
exit 0'
}

# Like fake_behind_merge_gh, but the merge status is the passed value — used to
# pin that only BEHIND triggers the update.
fake_merge_state_gh() {
  local status="$1"
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"view\" ]]; then
  if [[ \"\$*\" == *\"--json mergeStateStatus\"* ]]; then printf \"$status\n\"; else printf \"OPEN\n\"; fi
fi
exit 0"
}

fake_behind_merge_git() {
  local conflict="${1:-no}"
  fake_command git "if [[ \"\$1\" == \"-C\" ]]; then
  worktree=\"\$2\"
  shift 2
fi
printf \"%s %s\n\" \"\$worktree\" \"\$*\" >> \"\$FAKE_MERGE_GIT_ARGS\"
if [[ \"\$1\" == \"merge\" && \"\$*\" == *\"--no-ff\"* && \"$conflict\" == \"yes\" ]]; then exit 1; fi
if [[ \"\$1\" == \"merge-base\" && \"\${FAKE_MERGE_ANCESTOR:-yes}\" != \"yes\" ]]; then exit 1; fi
exit 0"
}

# Fake gh for the agent-driven conflict-resolution path: `pr view` reports an
# OPEN PR whose mergeStateStatus is $1 (default DIRTY) and whose labels are $2
# (one per line, as `--jq '.[].name'` emits), and an `api` call (the comment
# POST) is appended to $FAKE_PR_COMMENT_ARGS.
fake_conflict_merge_gh() {
  local status="${1:-DIRTY}" labels="${2:-}"
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"view\" ]]; then
  if [[ \"\$*\" == *\"--json mergeStateStatus\"* ]]; then printf \"$status\n\";
  elif [[ \"\$*\" == *\"--json labels\"* ]]; then printf \"$labels\n\";
  else printf \"OPEN\n\"; fi
elif [[ \"\$1\" == \"api\" ]]; then
  printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
fi
exit 0"
}

# Fake git for the conflict-resolution path: fetch, merge-base, and push are
# recorded to $FAKE_MERGE_GIT_ARGS; when $1 is not "yes" the ancestry check
# fails (verify-before-push).
fake_conflict_merge_git() {
  local ancestor="${1:-yes}"
  fake_command git "if [[ \"\$1\" == \"-C\" ]]; then
  worktree=\"\$2\"
  shift 2
fi
printf \"%s %s\n\" \"\$worktree\" \"\$*\" >> \"\$FAKE_MERGE_GIT_ARGS\"
if [[ \"\$1\" == \"merge-base\" && \"$ancestor\" != \"yes\" ]]; then exit 1; fi
exit 0"
}

# Fake opencode for the conflict-resolution path: the run is captured to $1
# and exits with $2 (default 0).
fake_merge_opencode() {
  local capture="$1" exit_code="${2:-0}"
  fake_command opencode "if [[ \"\$1\" == \"run\" ]]; then
  ${capture:+printf \"%s\n\" \"\$*\" > \"$capture\"}
  exit $exit_code
fi
exit 1"
}

# Fake opencode for the conflict-resolution path that appends every run to $1
# (so tests can count attempts) and exits with $2 (default 0).
fake_merge_opencode_log() {
  local log="$1" exit_code="${2:-0}"
  fake_command opencode "if [[ \"\$1\" == \"run\" ]]; then
  printf \"%s\n\" \"\$*\" >> \"$log\"
  exit $exit_code
fi
exit 1"
}

# Fake gh for a closed-without-merge PR: `pr view` reports CLOSED, and the
# escalation `issue edit` + `issue comment` invocations are captured to
# $FAKE_ESCALATE_ARGS (appended).
fake_closed_escalate_gh() {
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"view\" ]]; then
  printf \"CLOSED\n\"
elif [[ \"\$1\" == \"issue\" && ( \"\$2\" == \"edit\" || \"\$2\" == \"comment\" ) ]]; then
  printf \"%s\n\" \"\$*\" >> \"\${FAKE_ESCALATE_ARGS:-/dev/null}\"
fi
exit 0"
}

# Fake git that answers the git-fact queries the reconcile step makes.
# count: commits the worktree reports ahead of the base; dirty: whether
# `status --porcelain` is non-empty; pushed: whether `ls-remote` reports
# the branch on origin.
fake_reconcile_git() {
  local count="${1:-0}" dirty="${2:-no}" pushed="${3:-no}"
  fake_command git "if [[ \"\$1\" == \"-C\" ]]; then
  shift 2
  if [[ \"\$1\" == \"rev-parse\" ]]; then
    exit 0
  elif [[ \"\$1\" == \"status\" ]]; then
    if [[ \"$dirty\" == \"yes\" ]]; then printf \" M file.txt\n\"; fi
    exit 0
  elif [[ \"\$1\" == \"rev-list\" ]]; then
    printf \"$count\n\"
    exit 0
  elif [[ \"\$1\" == \"push\" ]]; then
    exit 0
  fi
elif [[ \"\$1\" == \"ls-remote\" ]]; then
  if [[ \"$pushed\" == \"yes\" ]]; then printf \"abc1234\trefs/heads/\${3##*/}\n\"; fi
  exit 0
elif [[ \"\$1\" == \"worktree\" ]]; then
  if [[ \"\$2\" == \"remove\" ]]; then rm -rf \"\$3\" \"\$4\"; fi
  exit 0
elif [[ \"\$1\" == \"branch\" || \"\$1\" == \"fetch\" ]]; then
  exit 0
fi
exit 0"
}

# Fake gh that answers the reconcile-step queries: `pr list` returns the
# given PR number when non-empty (otherwise an empty list), `pr create` is
# captured, and `issue view` / `issue comment` / `issue edit` are captured.
fake_reconcile_gh() {
  local pr_number="${1:-}"
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"list\" ]]; then
  if [[ -n \"$pr_number\" ]]; then printf \"[{\\\"number\\\":$pr_number}]\n\"; else printf \"[]\n\"; fi
  exit 0
elif [[ \"\$1\" == \"pr\" && \"\$2\" == \"create\" ]]; then
  printf \"%s\n\" \"\$*\" > \"\${FAKE_PR_CREATE_ARGS:-/dev/null}\"
  exit 0
elif [[ \"\$1\" == \"issue\" && \"\$2\" == \"view\" ]]; then
  printf \"Some Title\n\"
  exit 0
elif [[ \"\$1\" == \"issue\" && \"\$2\" == \"comment\" ]]; then
  printf \"%s\n\" \"\$*\" > \"\${FAKE_ISSUE_COMMENT_ARGS:-/dev/null}\"
  exit 0
elif [[ \"\$1\" == \"issue\" && \"\$2\" == \"edit\" ]]; then
  printf \"%s\n\" \"\$*\" > \"\${FAKE_ISSUE_EDIT_ARGS:-/dev/null}\"
  exit 0
fi
exit 0"
}

# Fake opencode run that exits 0 and captures the invocation; `session list`
# returns the given session id (or none).
fake_reconcile_opencode() {
  local session_id="${1:-}"
  fake_command opencode "if [[ \"\$1\" == \"run\" ]]; then
  printf \"%s\n\" \"\$*\" > \"\${FAKE_OPENCODE_ARGS:-/dev/null}\"
  exit 0
elif [[ \"\$1\" == \"session\" ]]; then
  if [[ -n \"$session_id\" ]]; then printf \"[{\\\"id\\\":\\\"$session_id\\\",\\\"title\\\":\\\"carbotracker-ticket-123\\\",\\\"created\\\":1}]\n\"; else printf \"[]\n\"; fi
  exit 0
fi
exit 0"
}

STATE_DIR=""
TEST_STATE=""
WT_PARENT=""

state_setup() {
  STATE_DIR="$(mktemp -d)"
  TEST_STATE="$STATE_DIR/state.json"
  WT_PARENT="$STATE_DIR/worktrees"
}

state_teardown() {
  rm -rf "$STATE_DIR"
  STATE_DIR=""
  TEST_STATE=""
  WT_PARENT=""
}

test_state_load_missing() {
  state_setup
  assert_eq "load missing state returns empty array" "[]" "$(orchestrator_state_load "$TEST_STATE")"
  state_teardown
}

test_state_load_corrupt() {
  state_setup
  printf 'not json' > "$TEST_STATE"
  assert_eq "load corrupt state returns empty array" "[]" "$(orchestrator_state_load "$TEST_STATE")"
  state_teardown
}

test_state_add_creates_entry() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  local entry
  entry="$(jq '.[0]' "$TEST_STATE")"
  assert_eq "entry tracks ticket number" "123" "$(jq -r '.ticket' <<<"$entry")"
  assert_eq "entry tracks branch" "ticket/123-foo" "$(jq -r '.branch' <<<"$entry")"
  assert_eq "entry tracks worktree path" "$WT_PARENT/123-foo" "$(jq -r '.worktree' <<<"$entry")"
  assert_eq "entry tracks session id as null" "null" "$(jq -r '.sessionId' <<<"$entry")"
  assert_eq "entry tracks pr number as null" "null" "$(jq -r '.prNumber' <<<"$entry")"
  assert_eq "entry tracks phase" "implementing" "$(jq -r '.phase' <<<"$entry")"
  assert_eq "entry tracks implementation failures as zero" "0" "$(jq -r '.failureCount' <<<"$entry")"
  local started
  started="$(jq -r '.startedAt' <<<"$entry")"
  assert_eq "entry tracks started-at timestamp" "yes" "$([[ "$started" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] && echo yes || echo no)"
  state_teardown
}

test_state_add_is_atomic_and_accumulates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  assert_eq "adds accumulate entries" "2" "$(jq 'length' "$TEST_STATE")"
  assert_eq "state file stays valid json" "yes" "$(jq -e . "$TEST_STATE" >/dev/null 2>&1 && echo yes || echo no)"
  assert_eq "no leftover temp files" "0" "$(find "$STATE_DIR" -maxdepth 1 -name 'orchestrator.*' -type f ! -name 'state.json' | wc -l)"
  state_teardown
}

test_state_has_ticket() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  if orchestrator_state_has_ticket "$TEST_STATE" 123; then
    pass "has_ticket true for claimed ticket"
  else
    fail "has_ticket true for claimed ticket"
  fi
  if orchestrator_state_has_ticket "$TEST_STATE" 999; then
    fail "has_ticket false for unclaimed ticket"
  else
    pass "has_ticket false for unclaimed ticket"
  fi
  state_teardown
}

test_state_complete_updates_entry() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local entry
  entry="$(jq '.[0]' "$TEST_STATE")"
  assert_eq "complete stores session id" "ses_abc" "$(jq -r '.sessionId' <<<"$entry")"
  assert_eq "complete stores pr number" "456" "$(jq -r '.prNumber' <<<"$entry")"
  assert_eq "complete transitions phase to awaiting review" "awaiting review" "$(jq -r '.phase' <<<"$entry")"
  assert_eq "complete leaves only the matching entry touched" "1" "$(jq 'length' "$TEST_STATE")"
  state_teardown
}

test_state_complete_with_missing_values() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_complete "$TEST_STATE" 123 "" ""
  local entry
  entry="$(jq '.[0]' "$TEST_STATE")"
  assert_eq "missing session id stored as null" "null" "$(jq -r '.sessionId' <<<"$entry")"
  assert_eq "missing pr number stored as null" "null" "$(jq -r '.prNumber' <<<"$entry")"
  assert_eq "phase still transitions without values" "awaiting review" "$(jq -r '.phase' <<<"$entry")"
  state_teardown
}

test_state_complete_updates_only_matching_ticket() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_complete "$TEST_STATE" 2 ses_2 22
  assert_eq "other entry keeps session null" "null" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  assert_eq "other entry keeps phase implementing" "implementing" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "matching entry gets session" "ses_2" "$(jq -r '.[1].sessionId' "$TEST_STATE")"
  assert_eq "matching entry gets pr number" "22" "$(jq -r '.[1].prNumber' "$TEST_STATE")"
  state_teardown
}

test_state_remove_removes_entry() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_remove "$TEST_STATE" 1
  assert_eq "remove drops the entry" "2" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "remove leaves the rest" "1" "$(jq 'length' "$TEST_STATE")"
  state_teardown
}

test_state_active_count_counts_implementing_only() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_complete "$TEST_STATE" 2 ses_2 22
  assert_eq "completed tickets do not count toward cap" "1" "$(orchestrator_state_active_count "$TEST_STATE")"
  state_teardown
}

test_candidate_issues_sorted_fifo() {
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":42,\"title\":\"Beta\"},{\"number\":10,\"title\":\"Alpha\"}]\n"
fi
exit 0'
  local out
  out="$(ct_candidate_issues)"
  assert_eq "candidates sorted by number ascending" "10,42" "$(jq -r '[.[].number] | join(",")' <<<"$out")"
}

test_candidate_issues_passes_both_labels() {
  state_setup
  local args_file="$STATE_DIR/args"
  fake_command gh 'printf "%s\n" "$*" > "$FAKE_ARGS_FILE"
exit 0'
  FAKE_ARGS_FILE="$args_file" ct_candidate_issues >/dev/null
  assert_contains "passes ready-for-agent label" "--label ready-for-agent" "$(cat "$args_file")"
  assert_contains "passes ticket label" "--label ticket" "$(cat "$args_file")"
  state_teardown
}

test_candidate_issues_gh_error() {
  fake_command gh 'exit 1'
  assert_eq "candidates empty on gh error" "[]" "$(ct_candidate_issues)"
}

test_issue_blocked_via_native_dependency() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "2\n"
fi
exit 0'
  if ct_issue_is_blocked 123; then
    pass "blocked when native dependency summary reports open blockers"
  else
    fail "blocked when native dependency summary reports open blockers"
  fi
}

test_issue_unblocked_via_native_dependency() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  if ct_issue_is_blocked 123; then
    fail "unblocked when native dependency summary is empty"
  else
    pass "unblocked when native dependency summary is empty"
  fi
}

test_issue_blocked_via_body_line() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "Spec here.\n\nBlocked by: #216\n" ;;
    216) printf "OPEN\n" ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    pass "blocked when body lists an open blocker"
  else
    fail "blocked when body lists an open blocker"
  fi
}

test_issue_unblocked_when_blocker_closed() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "Spec here.\n\nBlocked by: #216\n" ;;
    216) printf "CLOSED\n" ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    fail "unblocked when the only blocker is closed"
  else
    pass "unblocked when the only blocker is closed"
  fi
}

test_issue_blocked_when_blocker_state_unresolvable() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "Spec here.\n\nBlocked by: #216\n" ;;
    216) printf "no such issue\n" >&2; exit 1 ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    pass "blocked when a listed blocker cannot be resolved (fails closed)"
  else
    fail "blocked when a listed blocker cannot be resolved (fails closed)"
  fi
}

test_body_blocker_numbers_stops_at_next_section() {
  local body
  body="$(printf '## Parent\n\nparent text\n\n## Blocked by\n\n- [#216 - something](https://github.com/bemerkenswert/carbotracker/issues/216)\n\n## Fix #99\n\nmore\n')"
  assert_eq "blocker extraction stops at the next section header" "216" "$(ct_body_blocker_numbers "$body")"
}

test_issue_blocked_via_blocked_by_section() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
fi
if [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    123) printf "## Parent\n\nparent text\n\n## Blocked by\n\n- [#216 - something](https://github.com/bemerkenswert/carbotracker/issues/216)\n\n## Acceptance\n\n- [ ] do it\n" ;;
    216) printf "OPEN\n" ;;
  esac
  exit 0
fi
exit 1'
  if ct_issue_is_blocked 123; then
    pass "blocked when blocked-by section links an open issue"
  else
    fail "blocked when blocked-by section links an open issue"
  fi
}

test_poll_once_claims_candidates() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
    42) printf "Beta body\n" ;;
  esac
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "claims all unblocked candidates" "2" "$(jq 'length' "$TEST_STATE")"
  assert_eq "claims first ticket number" "10" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "claims second ticket number" "42" "$(jq -r '.[1].ticket' "$TEST_STATE")"
  assert_eq "implemented tickets transition to awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "logs discovery" "poll: 2 candidate(s)" "$output"
  assert_contains "logs claim transition" "claim #10: phase implementing" "$output"
  assert_contains "logs branch construction" "branch ticket/10-alpha" "$output"
  assert_contains "logs completed transition" "completed #10: session ses_10, PR #100" "$output"
  state_teardown
}

test_poll_once_implements_all_candidates_when_opencode_drains_stdin() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
    42) printf "Beta body\n" ;;
  esac
fi'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  cat > /dev/null
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_10\",\"title\":\"carbotracker-ticket-10\",\"created\":1},{\"id\":\"ses_42\",\"title\":\"carbotracker-ticket-42\",\"created\":2}]\n"
fi
exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "claims both candidates despite opencode draining stdin" "2" "$(jq 'length' "$TEST_STATE")"
  assert_eq "first ticket claimed" "10" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "second ticket claimed" "42" "$(jq -r '.[1].ticket' "$TEST_STATE")"
  state_teardown
}

test_poll_once_skips_claimed() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
    42) printf "Beta body\n" ;;
  esac
fi'
  orchestrator_state_add "$TEST_STATE" 10 ticket/10-alpha "$WT_PARENT/10-alpha"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "does not re-claim an active ticket" "2" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs skip of claimed ticket" "skip #10 (Alpha): already claimed" "$output"
  state_teardown
}

test_poll_once_skips_blocked() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  case "$2" in
    */10/*) printf "1\n" ;;
    */42/*) printf "0\n" ;;
  esac
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "only claims unblocked candidate" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "claims the unblocked ticket" "42" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_contains "logs skip of blocked ticket" "skip #10 (Alpha): blocked" "$output"
  state_teardown
}

test_poll_once_respects_concurrency_cap() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"},{\"number\":42,\"title\":\"Beta\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=1 orchestrator_poll_once 2>&1)"
  assert_eq "cap limits claims to first ticket" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "cap claims the FIFO-first ticket" "10" "$(jq -r '.[0].ticket' "$TEST_STATE")"
  assert_eq "implemented ticket reaches awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "logs cap reached" "concurrency cap 1 reached" "$output"
  state_teardown
}

test_poll_once_skips_when_cap_full() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-existing "$WT_PARENT/1-existing"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=1 orchestrator_poll_once 2>&1)"
  assert_eq "no new claims at full cap" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs cap reached" "concurrency cap 1 reached" "$output"
  state_teardown
}

test_opencode_session_id_filters_by_title() {
  fake_command opencode 'printf "[{\"id\":\"ses_old\",\"title\":\"carbotracker-ticket-10\",\"created\":1},{\"id\":\"ses_new\",\"title\":\"carbotracker-ticket-10\",\"created\":2},{\"id\":\"ses_other\",\"title\":\"other work\",\"created\":3}]\n"
exit 0'
  assert_eq "session id filters by title and picks newest" "ses_new" "$(orchestrator_opencode_session_id carbotracker-ticket-10)"
}

test_opencode_session_id_no_match() {
  fake_command opencode 'printf "[{\"id\":\"ses_a\",\"title\":\"other work\",\"created\":1}]\n"
exit 0'
  assert_eq "session id empty when no title matches" "" "$(orchestrator_opencode_session_id carbotracker-ticket-99)"
}

test_pr_number_for_branch() {
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":40},{\"number\":42}]\n"
fi
exit 0'
  assert_eq "pr number returns newest pr for branch" "42" "$(orchestrator_pr_number_for_branch ticket/10-alpha)"
}

test_pr_number_for_branch_missing() {
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
fi
exit 0'
  assert_eq "pr number empty when no pr exists" "" "$(orchestrator_pr_number_for_branch ticket/10-alpha)"
}

test_implement_runs_full_pipeline() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":42}]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_COMMENT_FILE"
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_COMMENT_FILE="$STATE_DIR/comment"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  export FAKE_GIT_PUSH_FILE="$STATE_DIR/git_push"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree"
  assert_eq "worktree dir created" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "opencode run invoked with title and issue prompt" "run --auto --model $ORCHESTRATOR_MODEL --title carbotracker-ticket-10 /implement the issue is 10" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_contains "branch pushed to origin" "push -u origin ticket/10-alpha" "$(cat "$FAKE_GIT_PUSH_FILE")"
  assert_eq "state session id stored" "ses_abc" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  assert_eq "state pr number stored" "42" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_eq "phase transitions to awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "issue commented with pr number" "Started implementation. PR #42 created." "$(cat "$FAKE_COMMENT_FILE")"
  unset FAKE_COMMENT_FILE FAKE_OPENCODE_ARGS FAKE_GIT_PUSH_FILE
  state_teardown
}

test_implement_opens_pr_when_none_exists() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  local n
  n="$(cat "$FAKE_PR_COUNT" 2>/dev/null || echo 0)"
  if [[ "$n" == "0" ]]; then
    printf "1\n" > "$FAKE_PR_COUNT"
    printf "[]\n"
  else
    printf "[{\"number\":50}]\n"
  fi
elif [[ "$1" == "pr" && "$2" == "create" ]]; then
  printf "%s\n" "$*" > "$FAKE_PR_CREATE_ARGS"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_1\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_PR_COUNT="$STATE_DIR/pr_count"
  export FAKE_PR_CREATE_ARGS="$STATE_DIR/pr_create"
  printf '0\n' > "$FAKE_PR_COUNT"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null
  assert_contains "creates pr with base main" "--base main" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_contains "creates pr with head branch" "--head ticket/10-alpha" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_contains "creates pr with title" "Implement Alpha (#10)" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_eq "stores created pr number" "50" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  unset FAKE_PR_COUNT FAKE_PR_CREATE_ARGS
  state_teardown
}

test_implement_fails_when_push_fails() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
fi
exit 0'
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "push" ]]; then
  exit 1
elif [[ "$1" == "rev-parse" ]]; then
  exit 1
elif [[ "$1" == "rev-list" ]]; then
  printf "1\n"
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"s\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when git push fails"
  else
    pass "implement fails when git push fails"
  fi
  state_teardown
}

test_implement_fails_when_pr_create_fails() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
elif [[ "$1" == "pr" && "$2" == "create" ]]; then
  exit 1
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"s\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when gh pr create fails"
  else
    pass "implement fails when gh pr create fails"
  fi
  state_teardown
}

test_implement_fails_when_worktree_fails() {
  state_setup
  fake_command git 'if [[ "$1" == "worktree" ]]; then
  exit 1
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when worktree creation fails"
  else
    pass "implement fails when worktree creation fails"
  fi
  state_teardown
}

test_implement_fails_when_npm_ci_fails() {
  state_setup
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
fi
exit 0'
  fake_command npm 'exit 1'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null 2>&1; then
    fail "implement fails when npm ci fails"
  else
    pass "implement fails when npm ci fails"
  fi
  state_teardown
}

test_implement_retries_opencode_with_continue() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":42}]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  local n
  n="$(cat "$FAKE_OPENCODE_COUNT" 2>/dev/null || echo 0)"
  n=$((n + 1))
  printf "%d\n" "$n" > "$FAKE_OPENCODE_COUNT"
  printf "%s\n" "$*" >> "$FAKE_OPENCODE_LOG"
  if [[ "$n" -eq 1 ]]; then exit 1; fi
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_OPENCODE_COUNT="$STATE_DIR/opencode_count"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree"
  assert_eq "first opencode attempt uses fresh title session" "run --auto --model $ORCHESTRATOR_MODEL --title carbotracker-ticket-10 /implement the issue is 10" "$(sed -n '1p' "$FAKE_OPENCODE_LOG")"
  assert_eq "retry once with --continue" "run --auto --model $ORCHESTRATOR_MODEL --continue /implement the issue is 10" "$(sed -n '2p' "$FAKE_OPENCODE_LOG")"
  assert_eq "retried run completes the ticket" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  unset FAKE_OPENCODE_COUNT FAKE_OPENCODE_LOG
  state_teardown
}

test_implement_escalates_after_two_opencode_failures() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "worktree" && "$2" == "remove" ]]; then
  rm -rf "$3" "$4"
elif [[ "$1" == "stash" ]]; then
  printf "%s\n" "$*" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
elif [[ "$1" == "branch" && "$2" == "-D" ]]; then
  exit 0
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'exit 1'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "implement fails when opencode fails twice" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_contains "escalation removes in-progress label" "--remove-label in-progress" "$(cat "$FAKE_ESCALATE_EDIT")"
  assert_contains "escalation removes ticket label" "--remove-label ticket" "$(cat "$FAKE_ESCALATE_EDIT")"
  assert_contains "escalation adds needs-triage" "--add-label needs-triage" "$(cat "$FAKE_ESCALATE_EDIT")"
  assert_contains "escalation comments with failure context" "opencode exited non-zero twice" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_eq "escalation removes the entry from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_eq "escalation prunes the worktree" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_contains "logs the escalation" "escalated #10 to needs-triage" "$output"
  assert_eq "clean-tree escalation creates no stash" "no" "$([[ -f "$FAKE_GIT_STASH_ARGS" ]] && echo yes || echo no)"
  unset FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT FAKE_GIT_STASH_ARGS
  state_teardown
}

test_implement_escalates_opencode_failure_preserves_commits() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "worktree" && "$2" == "remove" ]]; then
  rm -rf "$3" "$4"
elif [[ "$1" == "rev-parse" ]]; then
  exit 0
elif [[ "$1" == "rev-list" ]]; then
  printf "1\n"
elif [[ "$1" == "stash" ]]; then
  printf "%s\n" "$*" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
elif [[ "$1" == "branch" && "$2" == "-D" ]]; then
  exit 0
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'exit 1'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "opencode failure on a branch with commits fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "opencode failure on a branch with commits keeps the worktree" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "opencode failure on a branch with commits removes the state entry" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "opencode failure on a branch with commits names the preserved branch" "ticket/10-alpha" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_contains "opencode failure on a branch with commits says the work was preserved" "Committed work was preserved" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_contains "opencode failure on a branch with commits still adds needs-triage" "--add-label needs-triage" "$(cat "$FAKE_ESCALATE_EDIT")"
  unset FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_implement_escalates_empty_run_without_resume() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_REVLIST_SEQ="$STATE_DIR/revlist"
  printf '0\n0\n' > "$FAKE_REVLIST_SEQ"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "empty run escalates (implement fails)" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_contains "empty-run escalation adds needs-triage" "--add-label needs-triage" "$(cat "$FAKE_ESCALATE_EDIT")"
  assert_contains "empty-run escalation names the real cause" "no commits produced" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_eq "empty run escalates without any resume" "1" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "empty-run escalation removes the entry from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs the empty-run classification" "empty run, escalating without a resume" "$output"
  assert_eq "clean-tree escalation creates no stash" "no" "$([[ -f "$FAKE_GIT_STASH_ARGS" ]] && echo yes || echo no)"
  unset FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT FAKE_GIT_STASH_ARGS FAKE_OPENCODE_LOG FAKE_REVLIST_SEQ
  state_teardown
}

test_implement_resumes_stalled_run_once_and_finishes() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":42}]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_COMMENT_FILE"
fi
exit 0'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_REVLIST_SEQ="$STATE_DIR/revlist"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_GIT_PUSH_FILE="$STATE_DIR/git_push"
  export FAKE_COMMENT_FILE="$STATE_DIR/comment"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  printf '0\n1\n' > "$FAKE_REVLIST_SEQ"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree"
  assert_eq "stalled run resumes exactly once" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "first invocation is the fresh title session" "run --auto --model $ORCHESTRATOR_MODEL --title carbotracker-ticket-10 /implement the issue is 10" "$(sed -n '1p' "$FAKE_OPENCODE_LOG")"
  assert_eq "resume continues the session once" "run --auto --model $ORCHESTRATOR_MODEL --continue /implement the issue is 10" "$(sed -n '2p' "$FAKE_OPENCODE_LOG")"
  assert_contains "resumed run finishes by pushing the branch" "push -u origin ticket/10-alpha" "$(cat "$FAKE_GIT_PUSH_FILE")"
  assert_eq "resumed run completes the normal finish path" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "resumed run records the pr number" "42" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_contains "issue commented with pr number" "Started implementation. PR #42 created." "$(cat "$FAKE_COMMENT_FILE")"
  unset FAKE_GIT_STATUS FAKE_REVLIST_SEQ FAKE_OPENCODE_LOG FAKE_GIT_PUSH_FILE FAKE_COMMENT_FILE
  state_teardown
}

test_implement_escalates_when_resume_still_commitless() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_REVLIST_SEQ="$STATE_DIR/revlist"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  printf '0\n0\n' > "$FAKE_REVLIST_SEQ"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "commit-less resume escalates (implement fails)" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "the round invoked opencode exactly twice (token guard)" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_contains "the resume is the second invocation" "--continue /implement the issue is 10" "$(sed -n '2p' "$FAKE_OPENCODE_LOG")"
  assert_contains "commit-less resume escalation names the real cause" "no commits produced even after resuming the session" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_eq "commit-less resume escalation removes the entry from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs the stalled-run classification" "stalled run, resuming the session once" "$output"
  unset FAKE_GIT_STATUS FAKE_REVLIST_SEQ FAKE_OPENCODE_LOG FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_implement_escalates_when_resume_exits_nonzero() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_REVLIST_SEQ="$STATE_DIR/revlist"
  export FAKE_OPENCODE_EXITS="$STATE_DIR/opencode_exits"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  printf '0\n' > "$FAKE_REVLIST_SEQ"
  printf '0\n1\n' > "$FAKE_OPENCODE_EXITS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "non-zero resume escalates (implement fails)" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "the round invoked opencode exactly twice (token guard)" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_contains "non-zero resume escalation names the real cause" "opencode exited non-zero while resuming a no-commit run" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_eq "non-zero resume escalation removes the entry from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs the stalled-run classification" "stalled run, resuming the session once" "$output"
  unset FAKE_GIT_STATUS FAKE_REVLIST_SEQ FAKE_OPENCODE_EXITS FAKE_OPENCODE_LOG FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_implement_escalates_when_retry_already_resumed() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_REVLIST_SEQ="$STATE_DIR/revlist"
  export FAKE_OPENCODE_EXITS="$STATE_DIR/opencode_exits"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  printf '0\n' > "$FAKE_REVLIST_SEQ"
  printf '1\n0\n' > "$FAKE_OPENCODE_EXITS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "retry-exit-zero no-commit escalates (implement fails)" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "the round invoked opencode exactly twice (token guard)" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "the retry is the second invocation" "run --auto --model $ORCHESTRATOR_MODEL --continue /implement the issue is 10" "$(sed -n '2p' "$FAKE_OPENCODE_LOG")"
  assert_contains "a retry already resumed the session, so it escalates with the resume reason" "no commits produced even after resuming the session" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_eq "retry-exit-zero no-commit escalation removes the entry from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs that the retry already resumed the session" "the retry already resumed the session, escalating" "$output"
  unset FAKE_GIT_STATUS FAKE_REVLIST_SEQ FAKE_OPENCODE_EXITS FAKE_OPENCODE_LOG FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_stash_escalation_work_stashes_dirty_tree_with_contract_message() {
  state_setup
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "rev-parse" ]]; then exit 0
elif [[ "$1" == "status" ]]; then printf " M src/feature.ts\n"
elif [[ "$1" == "stash" ]]; then printf "%s\n" "$*" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  local entry
  entry="$(orchestrator_stash_escalation_work 10 "$worktree")"
  assert_contains "dirty tree stashes with untracked included" "stash push --include-untracked" "$(cat "$FAKE_GIT_STASH_ARGS")"
  local ts_re='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
  if [[ "$entry" =~ ^carbotracker:\ ticket\ 10\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_abc\)$ ]]; then
    pass "stash entry message follows the contract"
  else
    fail "stash entry message follows the contract"
    printf "  got: %q\n" "$entry"
  fi
  assert_contains "stash passes the contract message to git" "--message $entry" "$(cat "$FAKE_GIT_STASH_ARGS")"
  unset FAKE_GIT_STASH_ARGS
  state_teardown
}

test_stash_escalation_work_uses_passed_session_id() {
  state_setup
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "rev-parse" ]]; then exit 0
elif [[ "$1" == "status" ]]; then printf " M src/feature.ts\n"
elif [[ "$1" == "stash" ]]; then printf "%s\n" "$*" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
fi
exit 0'
  fake_command opencode 'exit 1'
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  local entry ts_re='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
  entry="$(orchestrator_stash_escalation_work 10 "$worktree" "ses_given")"
  if [[ "$entry" =~ ^carbotracker:\ ticket\ 10\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_given\)$ ]]; then
    pass "passed session id appears in the message"
  else
    fail "passed session id appears in the message"
    printf "  got: %q\n" "$entry"
  fi
  unset FAKE_GIT_STASH_ARGS
  state_teardown
}

test_stash_escalation_work_unknown_session_uses_none() {
  state_setup
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "rev-parse" ]]; then exit 0
elif [[ "$1" == "status" ]]; then printf " M src/feature.ts\n"
elif [[ "$1" == "stash" ]]; then printf "%s\n" "$*" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "session" ]]; then printf "[]\n"; fi
exit 0'
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  local entry ts_re='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
  entry="$(orchestrator_stash_escalation_work 10 "$worktree")"
  if [[ "$entry" =~ ^carbotracker:\ ticket\ 10\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ none\)$ ]]; then
    pass "unknown session id is recorded as none"
  else
    fail "unknown session id is recorded as none"
    printf "  got: %q\n" "$entry"
  fi
  unset FAKE_GIT_STASH_ARGS
  state_teardown
}

test_stash_escalation_work_skips_clean_tree() {
  state_setup
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "rev-parse" ]]; then exit 0
elif [[ "$1" == "status" ]]; then exit 0
elif [[ "$1" == "stash" ]]; then printf "stash called\n" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"
fi
exit 0'
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  assert_eq "clean tree produces no stash entry" "" "$(orchestrator_stash_escalation_work 10 "$worktree")"
  assert_eq "clean tree never invokes stash" "no" "$([[ -f "$FAKE_GIT_STASH_ARGS" ]] && echo yes || echo no)"
  unset FAKE_GIT_STASH_ARGS
  state_teardown
}

test_stash_escalation_work_skips_missing_worktree() {
  state_setup
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/git_calls"
  fake_command git 'printf "git called\n" >> "${FAKE_GIT_STASH_ARGS:-/dev/null}"; exit 0'
  assert_eq "missing worktree produces no stash entry" "" "$(orchestrator_stash_escalation_work 10 "$WT_PARENT/nope")"
  assert_eq "missing worktree never touches git" "no" "$([[ -f "$FAKE_GIT_STASH_ARGS" ]] && echo yes || echo no)"
  unset FAKE_GIT_STASH_ARGS
  state_teardown
}

test_stash_escalation_work_fails_closed_on_stash_error() {
  state_setup
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "rev-parse" ]]; then exit 0
elif [[ "$1" == "status" ]]; then printf " M src/feature.ts\n"
elif [[ "$1" == "stash" ]]; then exit 1
fi
exit 0'
  fake_command opencode 'if [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local entry rc log
  entry="$(orchestrator_stash_escalation_work 10 "$worktree" 2>"$STATE_DIR/stash_log")" && rc=0 || rc=$?
  assert_eq "failed stash reports no entry" "" "$entry"
  assert_eq "failed stash returns non-zero so the caller defers" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_contains "failed stash logs an error" "ERROR" "$(cat "$STATE_DIR/stash_log")"
  state_teardown
}

test_implement_escalation_stashes_uncommitted_work_and_names_entry() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  export FAKE_OPENCODE_EXITS="$STATE_DIR/opencode_exits"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  printf '1\n1\n' > "$FAKE_OPENCODE_EXITS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc ts_re='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "dirty-tree escalation fails the implement round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_contains "escalation stashes with untracked included" "stash push --include-untracked" "$(cat "$FAKE_GIT_STASH_ARGS")"
  if [[ "$(cat "$FAKE_GIT_STASH_ARGS")" =~ --message\ carbotracker:\ ticket\ 10\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_abc\)$ ]]; then
    pass "escalation stash message follows the contract"
  else
    fail "escalation stash message follows the contract"
    printf "  got: %q\n" "$(cat "$FAKE_GIT_STASH_ARGS")"
  fi
  assert_contains "escalation comment names the stash entry" "Uncommitted work was stashed before pruning" "$(cat "$FAKE_ESCALATE_COMMENT")"
  if [[ "$(cat "$FAKE_ESCALATE_COMMENT")" =~ carbotracker:\ ticket\ 10\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_abc\) ]]; then
    pass "escalation comment carries the stash message"
  else
    fail "escalation comment carries the stash message"
    printf "  got: %q\n" "$(cat "$FAKE_ESCALATE_COMMENT")"
  fi
  if [[ "$output" =~ pruned\ #10:.*stashed\ as\ carbotracker:\ ticket\ 10\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_abc\) ]]; then
    pass "prune log line names the stash entry"
  else
    fail "prune log line names the stash entry"
    printf "  got: %q\n" "$output"
  fi
  assert_eq "escalation removes the entry from state" "0" "$(jq 'length' "$TEST_STATE")"
  unset FAKE_GIT_STATUS FAKE_GIT_STASH_ARGS FAKE_OPENCODE_EXITS FAKE_OPENCODE_LOG FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_implement_escalation_keeps_worktree_when_stash_fails() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  exit 0
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  exit 0
fi
exit 1'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  export FAKE_GIT_STASH_FAIL=1
  export FAKE_OPENCODE_EXITS="$STATE_DIR/opencode_exits"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit"
  export FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  printf '1\n1\n' > "$FAKE_OPENCODE_EXITS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "failed stash fails the implement round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "failed stash keeps the entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "failed stash keeps the worktree" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "failed stash posts no escalation comment" "no" "$([[ -f "$FAKE_ESCALATE_COMMENT" ]] && echo yes || echo no)"
  assert_contains "logs that the escalation is deferred" "deferring the escalation" "$output"
  unset FAKE_GIT_STATUS FAKE_GIT_STASH_ARGS FAKE_GIT_STASH_FAIL FAKE_OPENCODE_EXITS FAKE_OPENCODE_LOG FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_implement_escalation_failure_restores_stash() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  exit 1
fi
exit 1'
  fake_stalled_git
  fake_stalled_opencode
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  export FAKE_OPENCODE_EXITS="$STATE_DIR/opencode_exits"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  printf '1\n1\n' > "$FAKE_OPENCODE_EXITS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "failed escalation keeps the entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "failed escalation stashes before the attempt" "stash push --include-untracked" "$(cat "$FAKE_GIT_STASH_ARGS")"
  assert_contains "failed escalation pops the stash back" "stash pop" "$(cat "$FAKE_GIT_STASH_ARGS")"
  assert_contains "logs the stash restore" "restored the stashed work" "$output"
  unset FAKE_GIT_STATUS FAKE_GIT_STASH_ARGS FAKE_OPENCODE_EXITS FAKE_OPENCODE_LOG
  state_teardown
}

test_implement_no_pr_skips_comment() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_COMMENT_FILE"
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_COMMENT_FILE="$STATE_DIR/comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)"
  assert_eq "pr number stored as null when no pr" "null" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_eq "no comment file written" "no" "$([[ -f "$FAKE_COMMENT_FILE" ]] && echo yes || echo no)"
  assert_contains "logs warning about missing pr" "no PR found" "$output"
  unset FAKE_COMMENT_FILE
  state_teardown
}

test_implement_no_session_stores_null() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":42}]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  fake_worktree_npm
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" >/dev/null
  assert_eq "session id stored as null when not found" "null" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  assert_eq "pr number still stored" "42" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  state_teardown
}

test_poll_once_removes_entry_on_failed_implement() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  fake_command git 'if [[ "$1" == "worktree" ]]; then
  exit 1
fi
exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "failed implementation remains in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "failed implementation records failed phase" "failed" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "failed implementation records one failure" "1" "$(jq -r '.[0].failureCount' "$TEST_STATE")"
  assert_contains "logs failed ticket retry" "kept #10 in failed phase" "$output"
  state_teardown
}

test_poll_once_restores_ready_for_agent_on_failed_implement() {
  state_setup
  local edits_file="$STATE_DIR/edits"
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" >> "$FAKE_EDITS_FILE"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  fake_command git 'if [[ "$1" == "worktree" ]]; then
  exit 1
fi
exit 0'
  export FAKE_EDITS_FILE="$edits_file"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once 2>&1)"
  assert_eq "failed implementation remains in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "restores ready-for-agent after non-opencode failure" "--add-label ready-for-agent" "$(cat "$edits_file")"
  assert_contains "drops in-progress after non-opencode failure" "--remove-label in-progress" "$(cat "$edits_file")"
  assert_contains "logs the label restore" "restored #10 to ready-for-agent" "$output"
  unset FAKE_EDITS_FILE
  state_teardown
}

test_non_opencode_failure_escalates_at_bound() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
  elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
    printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
  fi
  exit 0'
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "remove" ]]; then rm -rf "$3"; fi; exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit" FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_failed "$TEST_STATE" 10
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_IMPLEMENTATION_RETRIES=2 \
    orchestrator_handle_non_opencode_failure 10 "$branch" "$worktree" "push failed"
  assert_eq "bound failure removes state entry" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "bound failure adds triage label" "--add-label needs-triage" "$(cat "$FAKE_ESCALATE_EDIT")"
  assert_contains "bound failure posts comment" "attempt 2/2" "$(cat "$FAKE_ESCALATE_COMMENT")"
  unset FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_non_opencode_failure_preserves_worktree_below_bound() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_RETRY_EDIT"
fi
exit 0'
  fake_stalled_git
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  export FAKE_REVLIST_SEQ="$STATE_DIR/revlist"
  printf '1\n' > "$FAKE_REVLIST_SEQ"
  export FAKE_RETRY_EDIT="$STATE_DIR/retry_edit"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_IMPLEMENTATION_RETRIES=3 \
    orchestrator_handle_non_opencode_failure 10 "$branch" "$worktree" "push failed" 2>&1)"
  assert_eq "push-failure retry keeps the worktree" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "push-failure retry keeps the state entry" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "push-failure retry keeps the failed phase" "failed" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "push-failure retry restores ready-for-agent" "--add-label ready-for-agent" "$(cat "$FAKE_RETRY_EDIT")"
  assert_contains "push-failure retry logs the preserved worktree" "keeping #10 worktree and branch" "$output"
  unset FAKE_REVLIST_SEQ FAKE_RETRY_EDIT
  state_teardown
}

test_non_opencode_failure_at_bound_preserves_commits() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_EDIT"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ESCALATE_COMMENT"
fi
exit 0'
  fake_stalled_git
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  export FAKE_REVLIST_SEQ="$STATE_DIR/revlist"
  printf '1\n' > "$FAKE_REVLIST_SEQ"
  export FAKE_ESCALATE_EDIT="$STATE_DIR/escalate_edit" FAKE_ESCALATE_COMMENT="$STATE_DIR/escalate_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_IMPLEMENTATION_RETRIES=1 \
    orchestrator_handle_non_opencode_failure 10 "$branch" "$worktree" "push failed" >/dev/null 2>&1
  assert_eq "at-bound push failure removes the state entry" "0" "$(jq 'length' "$TEST_STATE")"
  assert_eq "at-bound push failure keeps the worktree" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_contains "at-bound push failure adds triage label" "--add-label needs-triage" "$(cat "$FAKE_ESCALATE_EDIT")"
  assert_contains "at-bound push failure names the preserved branch" "ticket/10-alpha" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_contains "at-bound push failure names the preserved worktree" "$worktree" "$(cat "$FAKE_ESCALATE_COMMENT")"
  assert_contains "at-bound push failure says the work was preserved" "Committed work was preserved" "$(cat "$FAKE_ESCALATE_COMMENT")"
  unset FAKE_REVLIST_SEQ FAKE_ESCALATE_EDIT FAKE_ESCALATE_COMMENT
  state_teardown
}

test_non_opencode_failure_clean_failure_still_cleans_up() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  exit 0
fi
exit 0'
  fake_command git 'if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "remove" ]]; then
  rm -rf "$3" "$4"
elif [[ "$1" == "rev-list" ]]; then
  printf "0\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  export CT_WORKTREE_CREATED=1
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_IMPLEMENTATION_RETRIES=3 \
    orchestrator_handle_non_opencode_failure 10 "$branch" "$worktree" "npm ci failed" 2>&1)"
  assert_eq "clean failure still removes the worktree" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "clean failure keeps the state entry" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "clean failure still keeps the failed phase" "kept #10 in failed phase" "$output"
  unset CT_WORKTREE_CREATED
  state_teardown
}

test_implement_reuses_existing_worktree_on_retry() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[{\"number\":42}]\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  fake_command git 'full_args="$*"
if [[ "$1" == "-C" ]]; then shift 2; fi
if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  exit 1
elif [[ "$1" == "rev-parse" ]]; then
  exit 0
elif [[ "$1" == "rev-list" ]]; then
  printf "1\n"
elif [[ "$1" == "push" && -n "${FAKE_GIT_PUSH_FILE:-}" ]]; then
  printf "%s\n" "$full_args" > "$FAKE_GIT_PUSH_FILE"
fi
exit 0'
  fake_command npm 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  exit 0
elif [[ "$1" == "session" ]]; then
  printf "[{\"id\":\"ses_abc\",\"title\":\"carbotracker-ticket-10\",\"created\":1}]\n"
fi
exit 0'
  local branch="ticket/10-alpha" worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  export FAKE_GIT_PUSH_FILE="$STATE_DIR/git_push"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 "$branch" "$worktree"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_implement 10 "Alpha" "$branch" "$worktree" 2>&1)"
  assert_contains "retry reuses the existing worktree" "reusing worktree" "$output"
  assert_eq "retry completes with a pr" "42" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_eq "retry transitions to awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "retry pushes the preserved branch" "push -u origin ticket/10-alpha" "$(cat "$FAKE_GIT_PUSH_FILE")"
  unset FAKE_GIT_PUSH_FILE
  state_teardown
}

test_reconcile_skips_failed_entry() {
  state_setup
  fake_command gh 'exit 1'
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 10 ticket/10-alpha "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_failed "$TEST_STATE" 10
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_reconcile >/dev/null 2>&1
  assert_eq "failed entry survives reconcile" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "reconcile preserves failed phase" "failed" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "reconcile preserves failure count" "1" "$(jq -r '.[0].failureCount' "$TEST_STATE")"
  state_teardown
}

test_claim_marks_issue_in_progress() {
  state_setup
  local args_file="$STATE_DIR/issue_edit_args"
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_EDIT_ARGS"
  exit 0
fi
exit 1'
  export FAKE_EDIT_ARGS="$args_file"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_claim 10 ticket/10-alpha "$WT_PARENT/10-alpha"
  assert_contains "claim removes ready-for-agent" "--remove-label ready-for-agent" "$(cat "$args_file")"
  assert_contains "claim adds in-progress" "--add-label in-progress" "$(cat "$args_file")"
  assert_eq "claim records state entry" "1" "$(orchestrator_state_active_count "$TEST_STATE")"
  assert_eq "state entry phase is implementing" "implementing" "$(jq -r '.[0].phase' "$TEST_STATE")"
  unset FAKE_EDIT_ARGS
  state_teardown
}

test_claim_failure_leaves_no_state() {
  state_setup
  fake_command gh 'exit 1'
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_claim 10 ticket/10-alpha "$WT_PARENT/10-alpha" >/dev/null 2>&1; then
    fail "claim fails when gh issue edit fails"
  else
    pass "claim fails when gh issue edit fails"
  fi
  assert_eq "failed claim leaves no state entry" "0" "$(orchestrator_state_active_count "$TEST_STATE")"
  state_teardown
}

test_poll_once_does_not_cleanup_preexisting_worktree() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  fake_command git 'exit 0'
  local worktree="$WT_PARENT/10-alpha"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once >/dev/null 2>&1
  assert_eq "pre-existing worktree survives failed implementation" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "failed implementation keeps state entry" "1" "$(jq 'length' "$TEST_STATE" 2>/dev/null || echo 0)"
  state_teardown
}

test_poll_once_cleans_up_worktree_after_failed_implement() {
  state_setup
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "0\n"
fi
exit 0'
  fake_command git 'if [[ "$1" == "worktree" && "$2" == "add" ]]; then
  mkdir -p "$3"
elif [[ "$1" == "worktree" && "$2" == "remove" ]]; then
  rm -rf "$3" "$4"
fi
exit 0'
  fake_command npm 'exit 1'
  local worktree="$WT_PARENT/10-alpha"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_CONCURRENCY_CAP=3 orchestrator_poll_once >/dev/null
  assert_eq "worktree removed after failed implementation" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  state_teardown
}

test_pr_latest_comment_at_returns_newest() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[]\n" ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:05:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"a\"},{\"created_at\":\"2026-08-13T00:07:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"b\"}]\n" ;;
    *issues/*comments*) printf "[{\"created_at\":\"2026-08-13T00:06:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"c\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "latest comment timestamp wins across surfaces" "2026-08-13T00:07:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_prefers_general_when_newer() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[]\n" ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:05:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"a\"}]\n" ;;
    *issues/*comments*) printf "[{\"created_at\":\"2026-08-13T00:09:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"b\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "newest comment across both surfaces wins" "2026-08-13T00:09:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_includes_review_submission() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[{\"submitted_at\":\"2026-08-13T00:08:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"summary review\"}]\n" ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:05:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"a\"}]\n" ;;
    *issues/*comments*) printf "[]\n" ;;
  esac
fi
exit 0'
  assert_eq "top-level review submission counts toward the watermark" "2026-08-13T00:08:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_ignores_pending_reviews() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[{\"submitted_at\":null,\"body\":\"draft review\"}]\n" ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:05:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"a\"}]\n" ;;
    *issues/*comments*) printf "[]\n" ;;
  esac
fi
exit 0'
  assert_eq "pending review does not move the watermark" "2026-08-13T00:05:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_ignores_bot_authored_comments() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[{\"submitted_at\":\"2026-08-13T00:09:00Z\",\"user\":{\"type\":\"Bot\"},\"body\":\"deployed preview\"}]\n" ;;
    *pulls/*) printf "[]\n" ;;
    *issues/*comments*) printf "[{\"created_at\":\"2026-08-13T00:10:00Z\",\"user\":{\"type\":\"Bot\"},\"body\":\"Visit the preview URL\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "bot comments and bot reviews never move the watermark" "" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_human_wins_over_bot() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[]\n" ;;
    *pulls/*) printf "[]\n" ;;
    *issues/*comments*) printf "[{\"created_at\":\"2026-08-13T00:10:00Z\",\"user\":{\"type\":\"Bot\"},\"body\":\"preview url\"},{\"created_at\":\"2026-08-13T00:07:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"please fix the name\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "a newer bot comment loses to an older human comment" "2026-08-13T00:07:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_excludes_bot_comments() {
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"2026-08-13T00:07:00Z\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human review comment\\\"},{\\\"created_at\\\":\\\"2026-08-13T00:09:00Z\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"$footer\\\"}]\n\" ;;
    *issues/*comments*) printf \"[{\\\"created_at\\\":\\\"2026-08-13T00:08:00Z\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"$footer\\\"}]\n\" ;;
  esac
fi
exit 0"
  assert_eq "agent replies and notices never move the watermark" "2026-08-13T00:07:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_none() {
  fake_command gh 'printf "[]\n"
exit 0'
  assert_eq "no comments returns empty" "" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_one_surface_empty() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[]\n" ;;
    *pulls/*) printf "[]\n" ;;
    *issues/*comments*) printf "[{\"created_at\":\"2026-08-13T00:09:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"a\"}]\n" ;;
  esac
fi
exit 0'
  assert_eq "non-empty surface still yields a timestamp" "2026-08-13T00:09:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_gh_error() {
  fake_command gh 'exit 1'
  assert_eq "gh error returns empty" "" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_counts_quote_reply_as_human() {
  local footer="_Created by carbotracker's agent skills._"
  local quote="> $footer — but remove it"
  fake_command gh "if [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *pulls/*) printf \"[]\n\" ;;
    *issues/*comments*) printf \"[{\\\"created_at\\\":\\\"2026-08-13T00:07:00Z\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"$footer\\\"},{\\\"created_at\\\":\\\"2026-08-13T00:09:00Z\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"$quote\\\"}]\n\" ;;
  esac
fi
exit 0"
  assert_eq "a quote-reply that embeds the footer mid-body still counts as human" "2026-08-13T00:09:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_pr_latest_comment_at_ignores_empty_review() {
  fake_command gh 'if [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[{\"submitted_at\":\"2026-08-13T00:09:00Z\",\"body\":\"\"}]\n" ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:05:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"human inline comment\"}]\n" ;;
    *issues/*comments*) printf "[]\n" ;;
  esac
fi
exit 0'
  assert_eq "an empty-body review submission carries no human signal" "2026-08-13T00:05:00Z" "$(orchestrator_pr_latest_comment_at 100)"
}

test_strip_ai_footer_removes_trailing_footers() {
  local marker="_Created by carbotracker's agent skills._"
  local body
  body="$(printf 'Keep this.\n\n---\n%s\n\n---\n%s' "$marker" "$marker")"
  assert_eq "all trailing footer blocks are stripped" "Keep this." "$(orchestrator_strip_ai_footer "$body")"
  assert_eq "a body without a footer is unchanged" "plain text" "$(orchestrator_strip_ai_footer "plain text")"
}

test_state_add_creates_last_comment_null() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks last comment as null" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  state_teardown
}

test_state_mark_reviewed_sets_timestamp() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  assert_eq "mark_reviewed stores the timestamp" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "mark_reviewed leaves phase untouched" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "mark_reviewed leaves session untouched" "ses_abc" "$(jq -r '.[0].sessionId' "$TEST_STATE")"
  state_teardown
}

test_state_mark_reviewed_touches_only_matching() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 1 ticket/1-a "$WT_PARENT/1-a"
  orchestrator_state_add "$TEST_STATE" 2 ticket/2-b "$WT_PARENT/2-b"
  orchestrator_state_complete "$TEST_STATE" 1 ses_1 11
  orchestrator_state_complete "$TEST_STATE" 2 ses_2 22
  orchestrator_state_mark_reviewed "$TEST_STATE" 2 "2026-08-13T00:07:00Z"
  assert_eq "matching entry gets timestamp" "2026-08-13T00:07:00Z" "$(jq -r '.[1].lastCommentAt' "$TEST_STATE")"
  assert_eq "other entry keeps timestamp null" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  state_teardown
}

test_review_round_success_updates_state() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_gh
  fake_review_opencode_success "$STATE_DIR/opencode_args" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_eq "opencode run resumes the session headless" "run --auto --model $ORCHESTRATOR_MODEL --session ses_abc /review-comments on PR #456 (ticket #123) headless: do not ask, do not post, do not implement — write the plan file" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "state last comment updated after round" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "successful round resets failure counter" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "no failure notice posted on success" "no" "$([[ -f "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  unset FAKE_OPENCODE_ARGS FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_answer_posts_reply_and_does_not_resolve() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_act_gh
  fake_review_opencode_success "$STATE_DIR/opencode_args" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  export FAKE_THREAD_REPLY_ARGS="$STATE_DIR/thread_reply"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_contains "answer reply posted to the thread" "pulls/456/comments/3788850731/replies" "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_contains "answer reply carries the plan reply text" "The ratio is stored per meal type." "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_contains "answer reply carries the AI-source footer" "_Created by carbotracker's agent skills._" "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_eq "answer round advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "answer round leaves needsHuman false" "false" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  assert_eq "answer round posts no maintainer notice" "no" "$([[ -f "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  assert_eq "answer round resets failure counter" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_OPENCODE_ARGS FAKE_THREAD_REPLY_ARGS FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_general_comment_reply_posts_on_pr() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 999, "path": null, "line": null, "type": "answer", "reply": "Covered in the PR description.", "confidence": 0.9}]}' > "$plan"
  fake_review_act_gh
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_contains "general comment reply posts on the pr conversation" "issues/456/comments" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_contains "general comment reply carries the plan text" "Covered in the PR description." "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_contains "general comment reply carries the AI-source footer" "_Created by carbotracker's agent skills._" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "general comment round advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_pushback_sets_needs_human() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": true, "comments": [{"commentId": 3788850735, "path": "apps/carbotracker/src/app/meal/meal.component.ts", "line": 12, "type": "pushback", "reply": "ngrx is already the store; a migration is out of scope.", "confidence": 0.95}]}' > "$plan"
  fake_review_act_gh
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_THREAD_REPLY_ARGS="$STATE_DIR/thread_reply"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_contains "pushback reply posted to the thread" "pulls/456/comments/3788850735/replies" "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_contains "pushback reply carries the argument" "ngrx is already the store" "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_contains "pushback reply carries the AI-source footer" "_Created by carbotracker's agent skills._" "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_eq "pushback sets needsHuman" "true" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  assert_contains "pushback posts a maintainer notice" "need a human decision" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "pushback round advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_THREAD_REPLY_ARGS FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_question_sets_needs_human() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": true, "comments": [{"commentId": 3788850734, "path": "README.md", "line": 9, "type": "question", "reply": "Should this be solved repo-wide?", "confidence": 0.9}]}' > "$plan"
  fake_review_act_gh
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_THREAD_REPLY_ARGS="$STATE_DIR/thread_reply"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_contains "question reply posted to the thread" "pulls/456/comments/3788850734/replies" "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_contains "question reply carries the question" "Should this be solved repo-wide?" "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_eq "question sets needsHuman" "true" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  assert_contains "question posts a maintainer notice" "need a human decision" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "question round advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_THREAD_REPLY_ARGS FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_implement_resumes_session_and_resolves() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 3788850732, "path": "apps/carbotracker/src/app/app.component.ts", "line": 42, "type": "implement", "reply": "Will rename the selector.", "confidence": 0.9}]}' > "$plan"
  fake_review_implement_gh
  fake_review_opencode_implement_round "$plan" "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_IMPLEMENT_RAN="$STATE_DIR/implement_ran"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_contains "implement run resumes the original session" "--session ses_abc" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "implement run is scoped to the comment" "comment 3788850732" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "implement run cites the path and line" "app.component.ts:42" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "implement run asks for one commit per comment" "one commit per comment" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "implement run mandates the AI-source footer" "_Created by carbotracker's agent skills._" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_eq "implement round advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "implement round leaves needsHuman false" "false" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  assert_eq "implement round posts no maintainer notice" "no" "$([[ -f "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  assert_eq "implement round resets failure counter" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_IMPLEMENT_RAN FAKE_OPENCODE_LOG FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_implement_unresolved_keeps_watermark() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 3788850732, "path": "apps/carbotracker/src/app/app.component.ts", "line": 42, "type": "implement", "reply": "Will rename the selector.", "confidence": 0.9}]}' > "$plan"
  fake_review_implement_gh "2026-08-13T00:07:00Z" false
  fake_review_opencode_implement_round "$plan" "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_IMPLEMENT_RAN="$STATE_DIR/implement_ran"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "unresolved implement fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "unresolved implement keeps the watermark" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "unresolved implement increments the failure counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_contains "unresolved implement posts a failure notice" "attempt 1/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  unset FAKE_IMPLEMENT_RAN FAKE_OPENCODE_LOG FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_implement_with_answer_posts_reply_and_resolves() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [
    {"commentId": 3788850731, "path": "README.md", "line": 4, "type": "answer", "reply": "The ratio is stored per meal type.", "confidence": 0.9},
    {"commentId": 3788850732, "path": "apps/carbotracker/src/app/app.component.ts", "line": 42, "type": "implement", "reply": "Will rename the selector.", "confidence": 0.9}
  ]}' > "$plan"
  fake_review_implement_gh
  fake_review_opencode_implement_round "$plan" "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_IMPLEMENT_RAN="$STATE_DIR/implement_ran"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_THREAD_REPLY_ARGS="$STATE_DIR/thread_reply"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_contains "mixed round launches the implement run" "comment 3788850732" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "answer reply still posted on the thread" "The ratio is stored per meal type." "$(cat "$FAKE_THREAD_REPLY_ARGS")"
  assert_contains "implement comment gets no bash reply" "no" "$([[ -f "$FAKE_THREAD_REPLY_ARGS" ]] && grep -q 'Will rename' "$FAKE_THREAD_REPLY_ARGS" && echo yes || echo no)"
  assert_eq "mixed round advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "mixed round leaves needsHuman false" "false" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  unset FAKE_IMPLEMENT_RAN FAKE_OPENCODE_LOG FAKE_THREAD_REPLY_ARGS FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_implement_general_comment_resolves_without_thread() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 3788850749, "path": null, "line": null, "type": "implement", "reply": "Will fix the login flow.", "confidence": 0.9}]}' > "$plan"
  fake_review_implement_gh
  fake_review_opencode_implement_round "$plan" "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_IMPLEMENT_RAN="$STATE_DIR/implement_ran"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_contains "general implement run is scoped to the comment" "comment 3788850749" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_contains "general implement run names the general comment" "general PR comment" "$(cat "$FAKE_OPENCODE_LOG")"
  assert_eq "general implement round advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_IMPLEMENT_RAN FAKE_OPENCODE_LOG
  state_teardown
}

# A general implement comment whose run posts no reply must fail the round —
# never a bare exit-0 trust.
test_review_round_implement_general_comment_without_reply_keeps_watermark() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 3788850749, "path": null, "line": null, "type": "implement", "reply": "Will fix the login flow.", "confidence": 0.9}]}' > "$plan"
  fake_review_implement_gh_no_general_reply
  fake_review_opencode_implement_round "$plan" "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_IMPLEMENT_RAN="$STATE_DIR/implement_ran"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "general implement without a reply fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "general implement without a reply keeps the watermark" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "general implement without a reply increments failures" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_IMPLEMENT_RAN FAKE_PR_COMMENT_ARGS
  state_teardown
}

# An inline implement comment that is resolved but never got a footer-bearing
# reply must fail the round too.
test_review_round_implement_resolved_without_reply_keeps_watermark() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 3788850732, "path": "apps/carbotracker/src/app/app.component.ts", "line": 42, "type": "implement", "reply": "Will rename the selector.", "confidence": 0.9}]}' > "$plan"
  fake_review_implement_gh_no_reply
  fake_review_opencode_implement_round "$plan" "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_IMPLEMENT_RAN="$STATE_DIR/implement_ran"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "resolved implement without a reply fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "resolved implement without a reply keeps the watermark" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "resolved implement without a reply increments failures" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_IMPLEMENT_RAN FAKE_PR_COMMENT_ARGS
  state_teardown
}

# An empty plan while human review content exists means the analyze run failed
# to classify the very comment that triggered the round — fail and retry.
test_review_round_empty_plan_with_human_content_fails() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": []}' > "$plan"
  fake_review_act_gh
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "empty plan with human content fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "empty plan with human content increments the failure counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "empty plan with human content keeps the watermark" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "empty plan with human content posts a failure notice" "attempt 1/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

# A valid empty plan while no human review content exists (the incident's bot
# preview comment scenario) is a successful no-op: the round succeeds, nothing
# is posted, and the failure counter resets.
test_review_round_empty_plan_without_human_content_succeeds() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": []}' > "$plan"
  fake_command gh "if [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *pulls/*) printf \"[]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[{\\\"created_at\\\":\\\"2026-08-13T00:09:00Z\\\",\\\"user\\\":{\\\"type\\\":\\\"Bot\\\"},\\\"body\\\":\\\"Visit the preview URL\\\"}]\n\"
      ;;
  esac
fi
exit 0"
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "empty plan without human content succeeds" "yes" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "empty plan without human content resets the failure counter" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "empty plan without human content posts nothing" "no" "$([[ -f "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  assert_eq "empty plan without human content leaves the watermark untouched" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

# The daemon execs the plan validator by a filename baked into
# ct-orchestrator.sh at load time; a rename on disk that forgets to update the
# reference broke every review round in production (PR #314 incident). The
# referenced file must exist alongside the orchestrator script.
test_review_plan_validator_reference_resolves() {
  local referenced validator_path
  referenced="$(sed -nE 's/.*node "\$SCRIPT_DIR\/([A-Za-z0-9-]+\.js)".*/\1/p' "$ROOT/tools/ct-orchestrator.sh" | head -n1)"
  validator_path="$ROOT/tools/$referenced"
  if [[ -n "$referenced" && -f "$validator_path" ]]; then
    pass "the validator referenced by the orchestrator exists ($validator_path)"
  else
    fail "the orchestrator references a missing validator script ($validator_path)"
  fi
}

# The self-refresh must re-exec when the on-disk script hash differs from the
# one recorded at load, and stay put otherwise. The exec target is overridden
# with `exit 42` so the re-exec is observable without launching a daemon.
test_self_refresh_re_execs_on_hash_change() {
  local rc
  (ORCHESTRATOR_SELF_HASH=stale ORCHESTRATOR_SELF_EXEC='exit 42' orchestrator_self_refresh >/dev/null 2>&1) && rc=0 || rc=$?
  assert_eq "changed hash re-execs" "42" "$rc"
}

test_self_refresh_passes_on_matching_hash() {
  local current rc
  current="$(sha256sum "$ROOT/tools/ct-orchestrator.sh" | cut -d' ' -f1)"
  (ORCHESTRATOR_SELF_HASH="$current" ORCHESTRATOR_SELF_EXEC='exit 42' orchestrator_self_refresh >/dev/null 2>&1) && rc=0 || rc=$?
  assert_eq "matching hash does not re-exec" "0" "$rc"
}

test_self_refresh_skips_without_hash() {
  local rc
  (ORCHESTRATOR_SELF_HASH="" ORCHESTRATOR_SELF_EXEC='exit 42' orchestrator_self_refresh >/dev/null 2>&1) && rc=0 || rc=$?
  assert_eq "missing recorded hash does not re-exec" "0" "$rc"
}

test_review_round_malformed_plan_keeps_watermark_and_retries() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments":' > "$plan"
  fake_review_act_gh
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "malformed plan fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "malformed plan increments the failure counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "malformed plan keeps the watermark" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "malformed plan posts a failure notice" "attempt 1/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_schema_invalid_plan_keeps_watermark() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 1, "path": "README.md", "line": 4, "type": "bogus", "reply": "x", "confidence": 0.9}]}' > "$plan"
  fake_review_act_gh
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "schema-invalid plan fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "schema-invalid plan keeps the watermark" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  state_teardown
}

test_review_round_partial_reply_failure_does_not_duplicate() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [
    {"commentId": 3788850731, "path": "README.md", "line": 4, "type": "answer", "reply": "First reply.", "confidence": 0.9},
    {"commentId": 3788850732, "path": "README.md", "line": 7, "type": "answer", "reply": "Second reply that fails.", "confidence": 0.9}
  ]}' > "$plan"
  fake_review_act_gh_fail_reply_containing "Second reply that fails."
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_THREAD_REPLY_ARGS="$STATE_DIR/thread_reply"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "partial reply failure still completes the round" "yes" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "only the successful reply is posted" "1" "$(grep -c -- 'First reply.' "$FAKE_THREAD_REPLY_ARGS")"
  assert_eq "failed reply is never posted" "0" "$(grep -c -- 'Second reply that fails.' "$FAKE_THREAD_REPLY_ARGS")"
  assert_eq "watermark advances on partial success" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "failure counter stays zero (no retry, no duplicate)" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_THREAD_REPLY_ARGS
  state_teardown
}

test_review_round_all_replies_fail_keeps_watermark_and_retries() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_act_gh_all_replies_fail
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "zero replies posted fails the round" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "zero replies increments the failure counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "zero replies keeps the watermark" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "zero replies posts a failure notice" "attempt 1/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_failure_increments_and_posts_notice() {
  state_setup
  fake_review_gh
  fake_review_opencode_fail
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    fail "review round fails when opencode run fails"
  else
    pass "review round fails when opencode run fails"
  fi
  assert_eq "failure increments the counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_contains "failure notice posted on the PR" "attempt 1/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "watermark stays put below the retry cap" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_third_failure_pauses_and_consumes() {
  state_setup
  fake_review_gh
  fake_review_opencode_fail
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "third failure returns failure" "no" "$([[ "$rc" -eq 0 ]] && echo yes || echo no)"
  assert_eq "third failure caps the counter" "3" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_contains "third failure notice posted" "attempt 3/3" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "third failure consumes the comment watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "logs the pause" "pausing until a human intervenes" "$output"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_after_pause_starts_fresh_budget() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_gh "2026-08-13T01:00:00Z"
  fake_review_opencode_success "" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 3
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree"
  assert_eq "resumed round resets the failure budget" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  state_teardown
}

# Fake gh for the review-round PR gate: `pr view` returns the given state ($1,
# or "FAIL" to simulate a gh outage) and the api surfaces mirror fake_review_act_gh
# with one human inline comment at $2.
fake_review_round_gh() {
  local state="${1:-OPEN}" latest="${2:-2026-08-13T00:07:00Z}"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh "if [[ \"\$1\" == \"pr\" && \"\$2\" == \"view\" ]]; then
  if [[ \"$state\" == \"FAIL\" ]]; then
    echo \"HTTP 503: no server\" >&2
    exit 1
  fi
  printf \"$state\n\"
  exit 0
elif [[ \"\$1\" == \"api\" ]]; then
  case \"\$2\" in
    *reviews*) printf \"[]\n\" ;;
    *replies*)
      printf \"%s\n\" \"\$*\" >> \"\${FAKE_THREAD_REPLY_ARGS:-/dev/null}\"
      ;;
    *pulls/*) printf \"[{\\\"created_at\\\":\\\"$latest\\\",\\\"user\\\":{\\\"type\\\":\\\"User\\\"},\\\"body\\\":\\\"human inline comment\\\",\\\"id\\\":1,\\\"in_reply_to_id\\\":null}]\n\" ;;
    *issues/*comments*)
      if [[ \"\$*\" == *\"-f body=\"* ]]; then
        printf \"%s\n\" \"\$*\" >> \"\${FAKE_PR_COMMENT_ARGS:-/dev/null}\"
        exit 0
      fi
      printf \"[]\n\"
      ;;
  esac
fi
exit 0"
}

# Like fake_review_round_gh, but every general-comment POST exits 1 (simulating
# a posting outage) so the act step fails.
fake_review_round_gh_fail_post() {
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "OPEN\n"
  exit 0
elif [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[]\n" ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"human comment\",\"id\":1,\"in_reply_to_id\":null}]\n" ;;
    *issues/*comments*)
      if [[ "$*" == *"-f body="* ]]; then
        echo "boom 503 from gh" >&2
        exit 1
      fi
      printf "[]\n"
      ;;
  esac
fi
exit 0'
}

# Fake opencode that appends every `run` invocation to $FAKE_OPENCODE_LOG, so a
# test can assert that no analyze was launched.
fake_opencode_recorder() {
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" >> "${FAKE_OPENCODE_LOG:-/dev/null}"
  exit 0
fi
exit 0'
}

test_review_round_skips_merged_pr() {
  state_setup
  fake_review_round_gh "MERGED"
  fake_opencode_recorder
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 1
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)"
  assert_eq "merged pr launches no analyze" "" "$(cat "$FAKE_OPENCODE_LOG" 2>/dev/null || true)"
  assert_eq "merged pr leaves the failure counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "merged pr posts no notice" "no" "$([[ -f "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  assert_contains "merged pr logs the skip" "PR #456 is MERGED" "$output"
  unset FAKE_OPENCODE_LOG FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_skips_closed_pr() {
  state_setup
  fake_review_round_gh "CLOSED"
  fake_opencode_recorder
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)"
  assert_eq "closed pr launches no analyze" "" "$(cat "$FAKE_OPENCODE_LOG" 2>/dev/null || true)"
  assert_contains "closed pr logs the skip" "PR #456 is CLOSED" "$output"
  unset FAKE_OPENCODE_LOG
  state_teardown
}

test_review_round_defers_when_state_unreadable() {
  state_setup
  fake_review_round_gh "FAIL"
  fake_opencode_recorder
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 1
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)"
  assert_eq "unreadable state launches no analyze" "" "$(cat "$FAKE_OPENCODE_LOG" 2>/dev/null || true)"
  assert_eq "unreadable state leaves the failure counter" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "unreadable state posts no notice" "no" "$([[ -f "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  assert_contains "unreadable state defers" "could not determine state of PR #456" "$output"
  assert_contains "unreadable state logs the gh error" "HTTP 503" "$output"
  unset FAKE_OPENCODE_LOG FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_resumes_from_persisted_plan() {
  state_setup
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 999, "path": null, "line": null, "type": "answer", "reply": "Covered in the PR description.", "confidence": 0.9}]}' > "$STATE_DIR/review-plan-123.json"
  fake_review_round_gh "OPEN"
  fake_opencode_recorder
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)"
  assert_eq "resume skips the analyze step" "" "$(cat "$FAKE_OPENCODE_LOG" 2>/dev/null || true)"
  assert_contains "resume replies from the persisted plan" "Covered in the PR description." "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "plan deleted on success" "no" "$([[ -f "$STATE_DIR/review-plan-123.json" ]] && echo yes || echo no)"
  assert_contains "resume logged" "resuming from persisted plan" "$output"
  assert_eq "resume advances the watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_OPENCODE_LOG FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_round_keeps_plan_on_act_failure() {
  state_setup
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 999, "path": null, "line": null, "type": "answer", "reply": "Covered in the PR description.", "confidence": 0.9}]}' > "$STATE_DIR/review-plan-123.json"
  fake_review_round_gh_fail_post
  fake_opencode_recorder
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "failed round keeps the persisted plan" "yes" "$([[ -f "$STATE_DIR/review-plan-123.json" ]] && echo yes || echo no)"
  assert_eq "failed round increments failures" "1" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_OPENCODE_LOG
  state_teardown
}

test_review_round_deletes_plan_at_retry_cap() {
  state_setup
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 999, "path": null, "line": null, "type": "answer", "reply": "Covered in the PR description.", "confidence": 0.9}]}' > "$STATE_DIR/review-plan-123.json"
  fake_review_round_gh_fail_post
  fake_opencode_recorder
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  local output rc
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>&1)" && rc=0 || rc=$?
  assert_eq "abandoned round deletes the plan" "no" "$([[ -f "$STATE_DIR/review-plan-123.json" ]] && echo yes || echo no)"
  assert_eq "abandoned round hits the cap" "3" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  state_teardown
}

test_review_act_dedups_thread_reply() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "OPEN\n"
  exit 0
elif [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[]\n" ;;
    *replies*)
      printf "%s\n" "$*" >> "${FAKE_THREAD_REPLY_ARGS:-/dev/null}"
      ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:09:00Z\",\"body\":\"_Created by carbotracker'"'"'s agent skills._\",\"id\":9001,\"in_reply_to_id\":3788850731}]\n" ;;
    *issues/*comments*) printf "[]\n" ;;
  esac
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_THREAD_REPLY_ARGS="$STATE_DIR/thread_reply"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>/dev/null
  assert_eq "already-replied thread comment is not re-posted" "" "$(cat "$FAKE_THREAD_REPLY_ARGS" 2>/dev/null || true)"
  unset FAKE_THREAD_REPLY_ARGS
  state_teardown
}

test_review_act_dedups_general_reply() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  printf '%s\n' '{"needsHuman": false, "comments": [{"commentId": 999, "path": null, "line": null, "type": "answer", "reply": "Covered in the PR description.", "confidence": 0.9}]}' > "$plan"
  local footer="_Created by carbotracker's agent skills._"
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "OPEN\n"
  exit 0
elif [[ "$1" == "api" ]]; then
  case "$2" in
    *reviews*) printf "[]\n" ;;
    *pulls/*) printf "[{\"created_at\":\"2026-08-13T00:07:00Z\",\"user\":{\"type\":\"User\"},\"body\":\"human comment\",\"id\":1,\"in_reply_to_id\":null}]\n" ;;
    *issues/*comments*)
      if [[ "$*" == *"-f body="* ]]; then
        printf "%s\n" "$*" >> "${FAKE_PR_COMMENT_ARGS:-/dev/null}"
        exit 0
      fi
      printf "[{\"id\":9001,\"body\":\"Covered in the PR description. _Created by carbotracker'"'"'s agent skills._\"}]\n"
      ;;
  esac
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_round 123 ses_abc 456 "$worktree" 2>/dev/null
  assert_eq "already-replied general comment is not re-posted" "" "$(cat "$FAKE_PR_COMMENT_ARGS" 2>/dev/null || true)"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_gh_failure_logged() {
  state_setup
  fake_command gh 'echo "boom 503 from gh" >&2; exit 1'
  local output rc
  output="$(orchestrator_pr_post_comment 456 "hi" 2>&1)" && rc=0 || rc=$?
  assert_contains "post failure logs the gh error" "boom 503 from gh" "$output"
  assert_eq "post failure returns non-zero" "1" "$rc"
  state_teardown
}

test_reconcile_defers_when_pr_lookup_fails() {
  state_setup
  fake_reconcile_git 0 no no
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  echo "HTTP 503: no server" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  printf "Some Title\n"
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc ""
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>&1)"
  assert_eq "entry kept when pr lookup fails" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "deferral logged" "could not determine PR for branch" "$output"
  assert_contains "gh error visible in the journal" "HTTP 503" "$output"
  state_teardown
}

test_reconcile_retries_failed_recovery_next_poll() {
  state_setup
  fake_reconcile_git 0 no yes
  fake_command npm 'exit 0'
  fake_reconcile_opencode ses_old
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  if [[ -f "$FAKE_GH_UP" ]]; then
    printf "[{\"number\":50}]\n"
  else
    echo "HTTP 503" >&2
    exit 1
  fi
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  printf "Some Title\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_GH_UP="$STATE_DIR/gh_up"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_old ""
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>/dev/null
  assert_eq "first poll defers on the outage" "" "$(jq -r '.[0].prNumber // ""' "$TEST_STATE")"
  touch "$FAKE_GH_UP"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>/dev/null
  assert_eq "next poll recovers the branch" "50" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_eq "recovered branch reaches awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  unset FAKE_GH_UP
  state_teardown
}

test_reconcile_sweeps_orphaned_plan() {
  state_setup
  printf '{}' > "$STATE_DIR/review-plan-999.json"
  fake_command gh 'exit 0'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>&1)"
  assert_eq "orphaned plan removed" "no" "$([[ -f "$STATE_DIR/review-plan-999.json" ]] && echo yes || echo no)"
  assert_contains "orphan sweep logged" "removed orphaned review plan" "$output"
  state_teardown
}

test_state_add_creates_review_failures_zero() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks review failures as zero" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  state_teardown
}

test_state_set_review_failures_updates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_set_review_failures "$TEST_STATE" 123 2
  assert_eq "set failures stores the count" "2" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "read failures returns the count" "2" "$(orchestrator_state_review_failures "$TEST_STATE" 123)"
  assert_eq "read failures defaults to zero for unknown ticket" "0" "$(orchestrator_state_review_failures "$TEST_STATE" 999)"
  state_teardown
}

test_state_add_creates_review_needs_human_false() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks needsHuman as false" "false" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  state_teardown
}

test_state_set_review_needs_human_updates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_set_review_needs_human "$TEST_STATE" 123 true
  assert_eq "set needsHuman stores true" "true" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  orchestrator_state_set_review_needs_human "$TEST_STATE" 123 false
  assert_eq "set needsHuman stores false" "false" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  orchestrator_state_set_review_needs_human "$TEST_STATE" 999 true
  assert_eq "unknown ticket is untouched" "false" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  state_teardown
}

test_review_poll_skips_pr_paused_for_human() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_gh
  fake_review_opencode_success "$STATE_DIR/opencode_args" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_needs_human "$TEST_STATE" 123 true
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_poll 2>&1)"
  assert_eq "paused pr does not launch a round" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_eq "paused pr stays paused" "true" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  assert_contains "logs the human pause" "paused for human decision" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_resumes_paused_pr_on_new_comment() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_gh "2026-08-13T01:00:00Z"
  fake_review_opencode_success "$STATE_DIR/opencode_args" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_needs_human "$TEST_STATE" 123 true
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_poll 2>&1)"
  assert_eq "new comment resumes a paused round" "run --auto --model $ORCHESTRATOR_MODEL --session ses_abc /review-comments on PR #456 (ticket #123) headless: do not ask, do not post, do not implement — write the plan file" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "resumed pr clears needsHuman" "false" "$(jq -r '.[0].reviewNeedsHuman' "$TEST_STATE")"
  assert_contains "logs the resume" "resumes paused PR #456" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_launches_round_on_new_comment() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_gh
  fake_review_opencode_success "$STATE_DIR/opencode_args" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_poll 2>&1)"
  assert_eq "poll launches review round on new comment" "run --auto --model $ORCHESTRATOR_MODEL --session ses_abc /review-comments on PR #456 (ticket #123) headless: do not ask, do not post, do not implement — write the plan file" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "poll updates last comment in state" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "logs new comment detection" "new comment on PR #456" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_skips_when_no_new_comment() {
  state_setup
  fake_review_gh
  fake_review_opencode_success "$STATE_DIR/opencode_args"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll does not launch without newer comment" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_contains "logs no-new-comment skip" "no new comment" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_skips_entry_without_session() {
  state_setup
  fake_command gh 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 "" 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll does not launch without a session" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_contains "logs missing-session handling" "missing-session notice" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_skips_entry_without_pr() {
  state_setup
  fake_command gh 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc ""
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll does not launch without a pr number" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_contains "logs skip for missing pr" "no PR" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_ignores_implementing_phase() {
  state_setup
  fake_command gh 'exit 0'
  fake_command opencode 'if [[ "$1" == "run" ]]; then
  printf "%s\n" "$*" > "$FAKE_OPENCODE_ARGS"
  exit 0
fi
exit 1'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_eq "poll ignores implementing entries" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_review_poll_retries_failed_round() {
  state_setup
  fake_review_gh
  fake_review_opencode_fail "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  assert_eq "failed round is retried on the next poll" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "two failures recorded in state" "2" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "watermark still unconsumed below the cap" "null" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  unset FAKE_OPENCODE_LOG
  state_teardown
}

test_review_poll_pauses_after_three_failures() {
  state_setup
  fake_review_gh
  fake_review_opencode_fail "$STATE_DIR/opencode_log"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  assert_eq "three failed rounds run before pausing" "3" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "failure counter caps at three" "3" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  assert_eq "third failure consumes the comment watermark" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_eq "one failure notice per failed round" "3" "$(grep -c -- '-f body=' "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "notice names attempt one" "1" "$(grep -c 'attempt 1/3' "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "notice names attempt two" "1" "$(grep -c 'attempt 2/3' "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "notice names attempt three" "1" "$(grep -c 'attempt 3/3' "$FAKE_PR_COMMENT_ARGS")"
  unset FAKE_OPENCODE_LOG FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_poll_resumes_after_pause_on_new_comment() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_gh "2026-08-13T01:00:00Z"
  fake_review_opencode_success "$STATE_DIR/opencode_log" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_set_review_failures "$TEST_STATE" 123 3
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_mark_reviewed "$TEST_STATE" 123 "2026-08-13T00:07:00Z"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_review_poll 2>/dev/null
  assert_eq "new comment after pause resumes the round" "1" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "resumed round resets the failure budget" "0" "$(jq -r '.[0].reviewFailures' "$TEST_STATE")"
  unset FAKE_OPENCODE_LOG
  state_teardown
}

test_poll_once_runs_review_loop() {
  state_setup
  local plan="$STATE_DIR/plan.json"
  write_answer_plan "$plan"
  fake_review_gh
  fake_review_opencode_success "$STATE_DIR/opencode_args" "$plan"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" ORCHESTRATOR_REVIEW_PLAN_FILE="$plan" orchestrator_poll_once 2>&1)"
  assert_eq "poll once runs review round for awaiting-review pr" "run --auto --model $ORCHESTRATOR_MODEL --session ses_abc /review-comments on PR #456 (ticket #123) headless: do not ask, do not post, do not implement — write the plan file" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "poll once updates last comment in state" "2026-08-13T00:07:00Z" "$(jq -r '.[0].lastCommentAt' "$TEST_STATE")"
  assert_contains "logs review round" "review #123: launching /review-comments" "$output"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_pr_state_returns_merged() {
  fake_merge_gh "MERGED"
  assert_eq "pr state returns MERGED" "MERGED" "$(orchestrator_pr_state 456)"
}

test_pr_state_returns_closed() {
  fake_merge_gh "CLOSED"
  assert_eq "pr state returns CLOSED" "CLOSED" "$(orchestrator_pr_state 456)"
}

test_pr_state_returns_open() {
  fake_merge_gh "OPEN"
  assert_eq "pr state returns OPEN" "OPEN" "$(orchestrator_pr_state 456)"
}

test_pr_state_gh_error() {
  fake_command gh 'exit 1'
  assert_eq "pr state empty on gh error" "" "$(orchestrator_pr_state 456)"
}

test_pr_merge_state_returns_behind() {
  fake_merge_gh "BEHIND"
  assert_eq "pr merge state returns BEHIND" "BEHIND" "$(orchestrator_pr_merge_state 456)"
}

test_pr_merge_state_gh_error() {
  fake_command gh 'exit 1'
  assert_eq "pr merge state empty on gh error" "" "$(orchestrator_pr_merge_state 456)"
}

test_merge_poll_prunes_merged_pr() {
  state_setup
  fake_merge_gh "MERGED"
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_ISSUE_CLOSE_ARGS="$STATE_DIR/issue_close"
  export FAKE_ISSUE_EDIT_ARGS="$STATE_DIR/issue_edit"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "merged pr removed from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_eq "merged pr worktree removed" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_contains "merged pr removes in-progress label" "--remove-label in-progress" "$(cat "$FAKE_ISSUE_EDIT_ARGS")"
  assert_contains "merged pr closes issue with comment" "PR #456 merged. Issue closed." "$(cat "$FAKE_ISSUE_CLOSE_ARGS")"
  assert_contains "logs merge detected" "PR #456 merged" "$output"
  unset FAKE_ISSUE_CLOSE_ARGS FAKE_ISSUE_EDIT_ARGS
  state_teardown
}

test_merge_poll_prunes_closed_pr() {
  state_setup
  fake_closed_escalate_gh
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_ESCALATE_ARGS="$STATE_DIR/escalate"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>/dev/null
  assert_eq "closed without merge removed from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_eq "closed without merge worktree removed" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_contains "closed without merge drops in-progress label" "--remove-label in-progress" "$(cat "$FAKE_ESCALATE_ARGS")"
  assert_contains "closed without merge adds needs-triage label" "--add-label needs-triage" "$(cat "$FAKE_ESCALATE_ARGS")"
  assert_contains "closed without merge comments naming the pr" "PR #456 was closed without merging" "$(cat "$FAKE_ESCALATE_ARGS")"
  assert_eq "clean-tree closed escalation creates no stash" "no" "$([[ -f "$FAKE_GIT_STASH_ARGS" ]] && echo yes || echo no)"
  unset FAKE_ESCALATE_ARGS FAKE_GIT_STASH_ARGS
  state_teardown
}

test_merge_poll_closed_stashes_uncommitted_work_and_names_entry() {
  state_setup
  fake_closed_escalate_gh
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_ESCALATE_ARGS="$STATE_DIR/escalate"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output ts_re='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_contains "closed escalation stashes with untracked included" "stash push --include-untracked" "$(cat "$FAKE_GIT_STASH_ARGS")"
  if [[ "$(cat "$FAKE_GIT_STASH_ARGS")" =~ --message\ carbotracker:\ ticket\ 123\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_abc\)$ ]]; then
    pass "closed escalation stash message follows the contract"
  else
    fail "closed escalation stash message follows the contract"
    printf "  got: %q\n" "$(cat "$FAKE_GIT_STASH_ARGS")"
  fi
  assert_contains "closed escalation comment names the stash" "Uncommitted work was stashed before pruning" "$(cat "$FAKE_ESCALATE_ARGS")"
  if [[ "$(cat "$FAKE_ESCALATE_ARGS")" =~ carbotracker:\ ticket\ 123\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_abc\) ]]; then
    pass "closed escalation comment carries the stash message"
  else
    fail "closed escalation comment carries the stash message"
    printf "  got: %q\n" "$(cat "$FAKE_ESCALATE_ARGS")"
  fi
  if [[ "$output" =~ pruned\ #123:.*stashed\ as\ carbotracker:\ ticket\ 123\ uncommitted\ work\ at\ escalation\ \($ts_re,\ session\ ses_abc\) ]]; then
    pass "closed escalation prune log line names the stash entry"
  else
    fail "closed escalation prune log line names the stash entry"
    printf "  got: %q\n" "$output"
  fi
  assert_eq "closed escalation removes the entry from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_eq "closed escalation removes the worktree" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  unset FAKE_ESCALATE_ARGS FAKE_GIT_STATUS FAKE_GIT_STASH_ARGS
  state_teardown
}

test_merge_poll_closed_keeps_worktree_when_stash_fails() {
  state_setup
  fake_closed_escalate_gh
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_ESCALATE_ARGS="$STATE_DIR/escalate"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  export FAKE_GIT_STASH_FAIL=1
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "failed stash keeps entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "failed stash keeps the worktree" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_eq "failed stash posts no escalation" "no" "$([[ -s "$FAKE_ESCALATE_ARGS" ]] && echo yes || echo no)"
  assert_contains "logs that the escalation is deferred" "keeping the entry and worktree to retry the escalation" "$output"
  unset FAKE_ESCALATE_ARGS FAKE_GIT_STATUS FAKE_GIT_STASH_ARGS FAKE_GIT_STASH_FAIL
  state_teardown
}

test_merge_poll_closed_escalation_failure_restores_stash() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "CLOSED\n"
elif [[ "$1" == "issue" && "$2" == "edit" ]]; then
  exit 1
fi
exit 0'
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_GIT_STATUS="$STATE_DIR/git_status"
  export FAKE_GIT_STASH_ARGS="$STATE_DIR/stash_args"
  printf ' M src/feature.ts\n' > "$FAKE_GIT_STATUS"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "failed escalation keeps entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "failed escalation stashes before the attempt" "stash push --include-untracked" "$(cat "$FAKE_GIT_STASH_ARGS")"
  assert_contains "failed escalation pops the stash back" "stash pop" "$(cat "$FAKE_GIT_STASH_ARGS")"
  assert_contains "logs the stash restore" "restored the stashed work" "$output"
  assert_contains "logs escalation retry warning" "keeping entry to retry next poll" "$output"
  unset FAKE_GIT_STATUS FAKE_GIT_STASH_ARGS
  state_teardown
}

test_merge_poll_keeps_entry_when_escalate_fails() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "CLOSED\n"
elif [[ "$1" == "issue" && "$2" == "edit" ]]; then
  exit 1
fi
exit 0'
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "failed escalation keeps entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "failed escalation keeps worktree" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_contains "logs escalation retry warning" "keeping entry to retry next poll" "$output"
  state_teardown
}

test_merge_poll_keeps_entry_when_close_fails() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "MERGED\n"
elif [[ "$1" == "issue" && "$2" == "close" ]]; then
  exit 1
fi
exit 0'
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "failed issue close keeps entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "failed issue close keeps worktree" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_contains "logs close retry warning" "keeping entry to retry next poll" "$output"
  state_teardown
}

test_merge_poll_keeps_open_pr() {
  state_setup
  fake_merge_gh "OPEN"
  fake_command git 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>/dev/null
  assert_eq "open pr kept in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "open pr worktree kept" "yes" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  state_teardown
}

test_merge_poll_updates_behind_pr() {
  state_setup
  fake_behind_merge_gh
  fake_behind_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_contains "behind pr fetches origin main" "fetch origin main" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  assert_contains "behind pr creates a merge commit" "merge --no-ff --no-edit origin/main" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  assert_contains "behind pr uses a normal push" "push origin ticket/123-foo" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  assert_eq "behind pr is verified twice" "2" "$(grep -c 'merge-base --is-ancestor origin/main HEAD' "$FAKE_MERGE_GIT_ARGS")"
  assert_eq "behind pr re-fetches origin main after the push" "2" "$(grep -c 'fetch origin main' "$FAKE_MERGE_GIT_ARGS")"
  assert_contains "behind pr logs verified update" "merged origin/main into ticket/123-foo and verified ancestry against the remote" "$output"
  assert_eq "behind pr remains in state" "1" "$(jq 'length' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS
  state_teardown
}

test_merge_poll_leaves_clean_open_pr_alone() {
  state_setup
  fake_merge_state_gh "CLEAN"
  fake_behind_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "clean open pr is not merged" "0" "$(cat "$FAKE_MERGE_GIT_ARGS" 2>/dev/null | wc -l)"
  assert_contains "clean open pr logs its merge status" "merge status CLEAN" "$output"
  assert_eq "clean open pr remains in state" "1" "$(jq 'length' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS
  state_teardown
}

test_merge_poll_aborts_conflicted_merge() {
  state_setup
  fake_behind_merge_gh
  fake_behind_merge_git yes
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_contains "conflicted merge is aborted" "merge --abort" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  assert_eq "conflicted merge is not pushed" "0" "$(grep -c 'push origin' "$FAKE_MERGE_GIT_ARGS" || true)"
  assert_contains "conflicted merge is retained for retry" "keeping entry to retry next poll" "$output"
  assert_eq "conflicted merge remains in state" "1" "$(jq 'length' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS
  state_teardown
}

test_merge_poll_does_not_push_unverified_behind_pr() {
  state_setup
  fake_behind_merge_gh
  fake_behind_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_MERGE_ANCESTOR=no
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "unverified behind pr is not pushed" "0" "$(grep -c 'push origin' "$FAKE_MERGE_GIT_ARGS" || true)"
  assert_contains "unverified behind pr is retained for retry" "keeping entry to retry next poll" "$output"
  assert_eq "unverified behind pr remains in state" "1" "$(jq 'length' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS FAKE_MERGE_ANCESTOR
  state_teardown
}

test_merge_poll_delegates_conflict_to_agent() {
  state_setup
  fake_conflict_merge_gh DIRTY ""
  fake_conflict_merge_git
  fake_merge_opencode "$STATE_DIR/opencode_args"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_contains "conflict resumes the ticket session" "--session ses_abc" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_contains "conflict run carries a merge prompt" "resolve the merge conflicts" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_contains "conflict run tells the agent not to push" "Do NOT push" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_contains "conflict resolution fetches origin main" "fetch origin main" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  assert_contains "conflict resolution verifies ancestry before pushing" "merge-base --is-ancestor origin/main HEAD" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  assert_contains "conflict resolution pushes the branch" "push origin ticket/123-foo" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  assert_eq "conflict resolution verifies again after the push" "2" "$(grep -c 'merge-base --is-ancestor origin/main HEAD' "$FAKE_MERGE_GIT_ARGS")"
  assert_eq "successful conflict resolution resets failures" "0" "$(jq -r '.[0].mergeFailures' "$TEST_STATE")"
  assert_contains "conflict resolution logs the verified push" "agent resolved conflicts" "$output"
  assert_eq "entry remains in state after conflict resolution" "1" "$(jq 'length' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS FAKE_OPENCODE_ARGS
  state_teardown
}

test_merge_poll_does_not_trust_exit_zero() {
  state_setup
  fake_conflict_merge_gh DIRTY ""
  fake_conflict_merge_git no
  fake_merge_opencode "$STATE_DIR/opencode_args"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "an exit-0 run without ancestry is not pushed" "0" "$(grep -c 'push origin' "$FAKE_MERGE_GIT_ARGS" || true)"
  assert_contains "an exit-0 run without ancestry is not trusted" "not trusting exit 0" "$output"
  assert_eq "an exit-0 run without ancestry counts a failure" "1" "$(jq -r '.[0].mergeFailures' "$TEST_STATE")"
  assert_contains "an exit-0 run without ancestry is retained" "keeping entry to retry next poll" "$output"
  unset FAKE_MERGE_GIT_ARGS FAKE_OPENCODE_ARGS
  state_teardown
}

test_merge_poll_bounds_agent_merges() {
  state_setup
  fake_conflict_merge_gh DIRTY ""
  fake_conflict_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  fake_merge_opencode_log "$STATE_DIR/opencode_log" 1
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_MERGE_RETRIES=2 orchestrator_merge_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_MERGE_RETRIES=2 orchestrator_merge_poll 2>/dev/null
  assert_eq "each failed agent merge is counted" "2" "$(jq -r '.[0].mergeFailures' "$TEST_STATE")"
  assert_eq "one agent run per failed attempt" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_eq "no needs-human comment below the cap" "no" "$([[ -s "$FAKE_PR_COMMENT_ARGS" ]] && echo yes || echo no)"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_MERGE_RETRIES=2 orchestrator_merge_poll 2>&1)"
  assert_eq "at the cap the agent is not run again" "2" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_contains "at the cap a needs-human comment is posted" "needs a human" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_contains "the needs-human comment names the attempts" "2/2" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "the needs-human comment is posted once" "1" "$(grep -c -- '-f body=' "$FAKE_PR_COMMENT_ARGS" || true)"
  assert_contains "at the cap the pr is left for a human" "leaving for a human" "$output"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_MERGE_RETRIES=2 orchestrator_merge_poll 2>/dev/null
  assert_eq "the needs-human comment is not repeated" "1" "$(grep -c -- '-f body=' "$FAKE_PR_COMMENT_ARGS" || true)"
  unset FAKE_MERGE_GIT_ARGS FAKE_PR_COMMENT_ARGS FAKE_OPENCODE_LOG
  state_teardown
}

test_merge_poll_retries_needs_human_comment() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "$*" == *"--json mergeStateStatus"* ]]; then printf "DIRTY\n";
  elif [[ "$*" == *"--json labels"* ]]; then printf "\n";
  else printf "OPEN\n"; fi
elif [[ "$1" == "api" ]]; then
  if [[ ! -f "$FAKE_COMMENT_FAILED" ]]; then
    touch "$FAKE_COMMENT_FAILED"
    exit 1
  fi
  printf "%s\n" "$*" >> "$FAKE_PR_COMMENT_ARGS"
fi
exit 0'
  fake_conflict_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  export FAKE_COMMENT_FAILED="$STATE_DIR/comment_failed"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  fake_merge_opencode_log "$STATE_DIR/opencode_log" 1
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_MERGE_RETRIES=1 orchestrator_merge_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_MERGE_RETRIES=1 orchestrator_merge_poll 2>/dev/null
  assert_eq "a failed comment post is not recorded as posted" "0" "$(cat "$FAKE_PR_COMMENT_ARGS" 2>/dev/null | grep -c -- '-f body=' || true)"
  assert_eq "the notice flag stays false after a failed post" "false" "$(jq -r '.[0].mergeNoticePosted' "$TEST_STATE")"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_MERGE_RETRIES=1 orchestrator_merge_poll 2>/dev/null
  assert_eq "the needs-human comment lands on a later poll" "1" "$(grep -c -- '-f body=' "$FAKE_PR_COMMENT_ARGS" || true)"
  assert_eq "the notice flag is set once it lands" "true" "$(jq -r '.[0].mergeNoticePosted' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS FAKE_PR_COMMENT_ARGS FAKE_COMMENT_FAILED
  state_teardown
}

test_merge_poll_skips_suspect_behind_pr() {
  state_setup
  fake_conflict_merge_gh BEHIND "suspect-diff"
  fake_conflict_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "a suspect behind pr is not merged" "0" "$(cat "$FAKE_MERGE_GIT_ARGS" 2>/dev/null | wc -l)"
  assert_contains "a suspect behind pr logs the skip" "skipped until approved" "$output"
  unset FAKE_MERGE_GIT_ARGS
  state_teardown
}

test_merge_poll_skips_suspect_pr() {
  state_setup
  fake_conflict_merge_gh DIRTY "suspect-diff"
  fake_conflict_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  fake_merge_opencode_log "$STATE_DIR/opencode_log"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "suspect pr without approval does not run the agent" "0" "$(cat "$FAKE_OPENCODE_LOG" 2>/dev/null | wc -l)"
  assert_eq "suspect pr without approval does not fetch" "0" "$(cat "$FAKE_MERGE_GIT_ARGS" 2>/dev/null | wc -l)"
  assert_contains "suspect pr logs the skip" "suspect-diff without human-approved" "$output"
  assert_eq "suspect pr is not counted as a failure" "0" "$(jq -r '.[0].mergeFailures' "$TEST_STATE")"
  fake_conflict_merge_gh DIRTY $'suspect-diff\nhuman-approved'
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>/dev/null
  assert_eq "approved suspect pr is attempted" "1" "$(wc -l < "$FAKE_OPENCODE_LOG")"
  assert_contains "approved suspect pr fetches origin main" "fetch origin main" "$(cat "$FAKE_MERGE_GIT_ARGS")"
  unset FAKE_MERGE_GIT_ARGS FAKE_OPENCODE_LOG
  state_teardown
}

test_merge_poll_fails_closed_when_labels_unreadable() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "$*" == *"--json mergeStateStatus"* ]]; then printf "DIRTY\n";
  elif [[ "$*" == *"--json labels"* ]]; then exit 1;
  else printf "OPEN\n"; fi
fi
exit 0'
  fake_conflict_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_OPENCODE_LOG="$STATE_DIR/opencode_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  fake_merge_opencode_log "$STATE_DIR/opencode_log"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "unreadable labels do not run the agent" "0" "$(cat "$FAKE_OPENCODE_LOG" 2>/dev/null | wc -l)"
  assert_contains "unreadable labels are retained for the next poll" "could not read labels" "$output"
  assert_eq "unreadable labels are not counted as a failure" "0" "$(jq -r '.[0].mergeFailures' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS FAKE_OPENCODE_LOG
  state_teardown
}

test_labels_are_suspect_pure_helper() {
  if orchestrator_labels_are_suspect "suspect-diff"; then
    pass "suspect-diff without approval is suspect"
  else
    fail "suspect-diff without approval is suspect"
  fi
  if orchestrator_labels_are_suspect $'suspect-diff\nhuman-approved'; then
    fail "suspect-diff with approval is not suspect"
  else
    pass "suspect-diff with approval is not suspect"
  fi
  if orchestrator_labels_are_suspect "human-approved"; then
    fail "approval without suspect-diff is not suspect"
  else
    pass "approval without suspect-diff is not suspect"
  fi
  if orchestrator_labels_are_suspect ""; then
    fail "empty labels are not suspect"
  else
    pass "empty labels are not suspect"
  fi
}

test_merge_poll_delegation_requires_a_session() {
  state_setup
  fake_conflict_merge_gh DIRTY ""
  fake_conflict_merge_git
  fake_merge_opencode "$STATE_DIR/opencode_args"
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_MERGE_GIT_ARGS="$STATE_DIR/git_args"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 "" 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "missing session means no agent run" "no" "$([[ -f "$FAKE_OPENCODE_ARGS" ]] && echo yes || echo no)"
  assert_contains "missing session logs the block" "no opencode session" "$output"
  assert_eq "missing session counts a failure" "1" "$(jq -r '.[0].mergeFailures' "$TEST_STATE")"
  unset FAKE_MERGE_GIT_ARGS FAKE_OPENCODE_ARGS
  state_teardown
}

test_state_merge_failures_updates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks merge failures as zero" "0" "$(jq -r '.[0].mergeFailures' "$TEST_STATE")"
  assert_eq "read merge failures defaults to zero" "0" "$(orchestrator_state_merge_failures "$TEST_STATE" 123)"
  orchestrator_state_set_merge_failures "$TEST_STATE" 123 2
  assert_eq "set merge failures stores the count" "2" "$(orchestrator_state_merge_failures "$TEST_STATE" 123)"
  orchestrator_state_set_merge_failures "$TEST_STATE" 123 0
  assert_eq "set merge failures resets to zero" "0" "$(orchestrator_state_merge_failures "$TEST_STATE" 123)"
  assert_eq "unknown ticket reads zero" "0" "$(orchestrator_state_merge_failures "$TEST_STATE" 999)"
  state_teardown
}

test_state_merge_notice_posted_updates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks merge notice as false" "false" "$(jq -r '.[0].mergeNoticePosted' "$TEST_STATE")"
  assert_eq "read merge notice defaults to false" "false" "$(orchestrator_state_merge_notice_posted "$TEST_STATE" 123)"
  orchestrator_state_set_merge_notice_posted "$TEST_STATE" 123 true
  assert_eq "set merge notice stores true" "true" "$(orchestrator_state_merge_notice_posted "$TEST_STATE" 123)"
  orchestrator_state_set_merge_notice_posted "$TEST_STATE" 999 true
  assert_eq "unknown ticket reads false" "false" "$(orchestrator_state_merge_notice_posted "$TEST_STATE" 999)"
  assert_eq "unknown ticket leaves other entries untouched" "true" "$(orchestrator_state_merge_notice_posted "$TEST_STATE" 123)"
  state_teardown
}

test_merge_poll_skips_entry_without_pr() {
  state_setup
  fake_command gh 'exit 0'
  fake_command git 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc ""
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>&1)"
  assert_eq "entry without pr stays in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs skip for missing pr" "no PR recorded" "$output"
  state_teardown
}

test_merge_poll_gh_error_keeps_entry() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  exit 1
fi
exit 0'
  fake_command git 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  # Called directly (not via a command substitution): a set -e abort on the
  # fail-closed state read would kill the whole suite here.
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll >"$STATE_DIR/out" 2>&1; then
    pass "merge poll survives a gh state-read error"
  else
    fail "merge poll survives a gh state-read error"
  fi
  local output
  output="$(cat "$STATE_DIR/out")"
  assert_eq "gh error keeps entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs gh error handling" "could not determine state" "$output"
  state_teardown
}

test_merge_poll_merge_status_error_keeps_entry() {
  state_setup
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "$*" == *"mergeStateStatus"* ]]; then
    exit 1
  fi
  printf "OPEN\n"
fi
exit 0'
  fake_command git 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll >"$STATE_DIR/out" 2>&1; then
    pass "merge poll survives a gh merge-status error"
  else
    fail "merge poll survives a gh merge-status error"
  fi
  local output
  output="$(cat "$STATE_DIR/out")"
  assert_eq "merge-status error keeps entry in state" "1" "$(jq 'length' "$TEST_STATE")"
  assert_contains "logs the merge-status deferral" "could not determine the merge status" "$output"
  state_teardown
}

test_review_poll_notice_post_failure_survives() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  exit 1
fi
exit 0'
  fake_command opencode 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 "" 456
  if ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll >"$STATE_DIR/out" 2>&1; then
    pass "review poll survives a notice-post failure"
  else
    fail "review poll survives a notice-post failure"
  fi
  local output
  output="$(cat "$STATE_DIR/out")"
  assert_eq "failed notice post is not marked posted" "false" "$(jq -r '.[0].reviewNoticePosted' "$TEST_STATE")"
  assert_contains "logs the failed notice post" "failed to post missing-session notice" "$output"
  state_teardown
}

test_merge_poll_ignores_implementing_phase() {
  state_setup
  fake_merge_gh "MERGED"
  fake_command git 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_merge_poll 2>/dev/null
  assert_eq "implementing entry untouched" "1" "$(jq 'length' "$TEST_STATE")"
  state_teardown
}

test_poll_once_runs_merge_poll() {
  state_setup
  fake_merge_gh "MERGED"
  fake_merge_git
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_ISSUE_CLOSE_ARGS="$STATE_DIR/issue_close"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_poll_once 2>&1)"
  assert_eq "poll once prunes merged pr" "0" "$(jq 'length' "$TEST_STATE")"
  assert_contains "poll once closes issue on merge" "PR #456 merged. Issue closed." "$(cat "$FAKE_ISSUE_CLOSE_ARGS")"
  assert_contains "logs merge poll" "PR #456 merged" "$output"
  unset FAKE_ISSUE_CLOSE_ARGS
  state_teardown
}

test_state_add_creates_review_notice_false() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  assert_eq "new entry tracks notice flag as false" "false" "$(jq -r '.[0].reviewNoticePosted' "$TEST_STATE")"
  state_teardown
}

test_state_mark_notice_posted_updates() {
  state_setup
  orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$WT_PARENT/123-foo"
  orchestrator_state_mark_notice_posted "$TEST_STATE" 123
  assert_eq "mark notice sets the flag" "true" "$(jq -r '.[0].reviewNoticePosted' "$TEST_STATE")"
  state_teardown
}

test_review_poll_posts_notice_when_no_session() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "%s\n" "$*" > "$FAKE_PR_COMMENT_ARGS"
fi
exit 0'
  fake_command opencode 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_ARGS="$STATE_DIR/pr_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 "" 456
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>&1)"
  assert_contains "missing-session notice posted on the PR" "no opencode session" "$(cat "$FAKE_PR_COMMENT_ARGS")"
  assert_eq "notice posted flag stored" "true" "$(jq -r '.[0].reviewNoticePosted' "$TEST_STATE")"
  assert_contains "logs the notice" "posted missing-session notice" "$output"
  unset FAKE_PR_COMMENT_ARGS
  state_teardown
}

test_review_poll_posts_notice_only_once() {
  state_setup
  fake_command gh 'if [[ "$1" == "api" ]]; then
  printf "%s\n" "$*" >> "$FAKE_PR_COMMENT_LOG"
fi
exit 0'
  fake_command opencode 'exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_COMMENT_LOG="$STATE_DIR/pr_comment_log"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 "" 456
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_review_poll 2>/dev/null
  assert_eq "notice posted exactly once" "1" "$(grep -c -- '-f body=' "$FAKE_PR_COMMENT_LOG")"
  unset FAKE_PR_COMMENT_LOG
  state_teardown
}

test_config_defaults() {
  local out
  out="$(env CT_ORCHESTRATOR_CONF=/nonexistent bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s %s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS" "$ORCHESTRATOR_REVIEW_RETRIES" "$ORCHESTRATOR_MERGE_RETRIES"' _ "$ROOT")"
  assert_eq "defaults apply when no conf exists" "3 300 3 3" "$out"
}

test_config_file_parsing() {
  state_setup
  local conf="$STATE_DIR/custom.conf"
  printf 'ORCHESTRATOR_CONCURRENCY_CAP=1\nORCHESTRATOR_POLL_INTERVAL_SECONDS=7\nORCHESTRATOR_REVIEW_RETRIES=5\nORCHESTRATOR_MERGE_RETRIES=2\n' > "$conf"
  local out
  out="$(env CT_ORCHESTRATOR_CONF="$conf" bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s %s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS" "$ORCHESTRATOR_REVIEW_RETRIES" "$ORCHESTRATOR_MERGE_RETRIES"' _ "$ROOT")"
  assert_eq "conf overrides cap interval and retries" "1 7 5 2" "$out"
  state_teardown
}

test_config_env_beats_conf() {
  state_setup
  local conf="$STATE_DIR/custom.conf"
  printf 'ORCHESTRATOR_CONCURRENCY_CAP=1\nORCHESTRATOR_POLL_INTERVAL_SECONDS=7\nORCHESTRATOR_REVIEW_RETRIES=5\nORCHESTRATOR_MERGE_RETRIES=2\n' > "$conf"
  local out
  out="$(env CT_ORCHESTRATOR_CONF="$conf" ORCHESTRATOR_CONCURRENCY_CAP=9 ORCHESTRATOR_POLL_INTERVAL_SECONDS=11 ORCHESTRATOR_REVIEW_RETRIES=1 ORCHESTRATOR_MERGE_RETRIES=8 \
    bash -c 'source "$1/tools/ct-orchestrator.sh"; printf "%s %s %s %s\n" "$ORCHESTRATOR_CONCURRENCY_CAP" "$ORCHESTRATOR_POLL_INTERVAL_SECONDS" "$ORCHESTRATOR_REVIEW_RETRIES" "$ORCHESTRATOR_MERGE_RETRIES"' _ "$ROOT")"
  assert_eq "environment beats conf file" "9 11 1 8" "$out"
  state_teardown
}

test_issue_feature_parses_valid_declaration() {
  assert_eq "parses Feature declaration" "current-meal" "$(ct_issue_feature $'Summary\n\nFeature: current-meal\n')"
}

test_issue_feature_rejects_invalid_declaration() {
  assert_eq "rejects invalid feature name" "" "$(ct_issue_feature 'Feature: current meal')"
}

test_changed_features_maps_feature_folders() {
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts" "apps/carbotracker/src/features/current-meal/b.ts" "README.md"; fi'
  assert_eq "maps changed files to unique feature folders" $'current-meal\nproducts' "$(ct_changed_features /tmp/worktree)"
}

test_suspect_diff_requires_declared_feature_to_be_untouched() {
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts"; fi'
  if ct_feature_diff_is_suspect /tmp/worktree "Feature: current-meal"; then
    pass "flags a diff in a different feature"
  else
    fail "flags a diff in a different feature"
  fi
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts" "apps/carbotracker/src/features/current-meal/b.ts"; fi'
  if ct_feature_diff_is_suspect /tmp/worktree "Feature: current-meal"; then
    fail "does not flag legitimate cross-feature edit"
  else
    pass "does not flag legitimate cross-feature edit"
  fi
}

test_suspect_diff_skips_undeclared_ticket() {
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts"; fi'
  if ct_feature_diff_is_suspect /tmp/worktree "No feature declared"; then
    fail "skips suspect diff check when feature is undeclared"
  else
    pass "skips suspect diff check when feature is undeclared"
  fi
}

test_suspect_diff_flags_pr_without_failing_pipeline() {
  state_setup
  local args_file="$STATE_DIR/suspect_args"
  fake_command gh 'if [[ "$1" == "issue" && "$2" == "view" ]]; then
  printf "Feature: current-meal\n"
elif [[ "$1" == "pr" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" >> "$FAKE_SUSPECT_ARGS"
elif [[ "$1" == "pr" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" >> "$FAKE_SUSPECT_ARGS"
fi
exit 0'
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts"; fi'
  export FAKE_SUSPECT_ARGS="$args_file"
  if orchestrator_check_suspect_diff 279 456 /tmp/worktree; then
    pass "suspect diff check is non-fatal"
  else
    fail "suspect diff check is non-fatal"
  fi
  assert_contains "suspect diff adds pr label" "pr edit 456 --add-label suspect-diff" "$(sed -n '1p' "$args_file")"
  assert_contains "suspect diff posts warning comment" "pr comment 456" "$(sed -n '2p' "$args_file")"
  unset FAKE_SUSPECT_ARGS
  state_teardown
}

test_shared_files_returns_intersection() {
  local a b
  a=$'apps/carbotracker/src/features/products/a.ts\napps/carbotracker/src/features/current-meal/b.ts'
  b=$'apps/carbotracker/src/features/products/a.ts\nREADME.md'
  assert_eq "shared files are the exact intersection" "apps/carbotracker/src/features/products/a.ts" "$(ct_shared_files "$a" "$b")"
}

test_shared_files_empty_without_overlap() {
  local a b
  a=$'apps/carbotracker/src/features/products/a.ts'
  b=$'apps/carbotracker/src/features/current-meal/b.ts'
  assert_eq "no overlap yields no shared files" "" "$(ct_shared_files "$a" "$b")"
}

test_shared_files_matches_whole_paths_only() {
  local a b
  a=$'libs/foo/bar.ts'
  b=$'libs/foo/bar.tsx'
  assert_eq "a path prefix is not a match" "" "$(ct_shared_files "$a" "$b")"
}

test_overlap_warns_on_shared_files() {
  state_setup
  local args_file="$STATE_DIR/overlap_args"
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "456\n789\n"
elif [[ "$1" == "pr" && "$2" == "view" ]]; then
  if [[ "$3" == "789" ]]; then
    printf "apps/carbotracker/src/features/products/a.ts\nREADME.md\n"
  else
    printf "apps/carbotracker/src/features/current-meal/b.ts\n"
  fi
elif [[ "$1" == "api" ]]; then
  printf "%s\n" "$*" >> "$FAKE_OVERLAP_ARGS"
fi
exit 0'
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts" "apps/carbotracker/src/features/current-meal/b.ts"; fi'
  export FAKE_OVERLAP_ARGS="$args_file"
  if orchestrator_check_overlap 280 456 /tmp/worktree; then
    pass "overlap check is non-fatal"
  else
    fail "overlap check is non-fatal"
  fi
  assert_contains "overlap warning posts a comment on the new PR" "issues/456/comments" "$(cat "$args_file")"
  assert_contains "overlap warning names the overlapping PR" "PR #789" "$(cat "$args_file")"
  assert_contains "overlap warning names the shared file" "products/a.ts" "$(cat "$args_file")"
  unset FAKE_OVERLAP_ARGS
  state_teardown
}

test_overlap_no_warning_without_overlap() {
  state_setup
  local args_file="$STATE_DIR/overlap_args"
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "456\n789\n"
elif [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "apps/carbotracker/src/features/products/a.ts\n"
elif [[ "$1" == "api" ]]; then
  printf "%s\n" "$*" >> "$FAKE_OVERLAP_ARGS"
fi
exit 0'
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/current-meal/b.ts"; fi'
  export FAKE_OVERLAP_ARGS="$args_file"
  orchestrator_check_overlap 280 456 /tmp/worktree
  assert_eq "no overlap posts no warning" "" "$(cat "$args_file" 2>/dev/null || true)"
  unset FAKE_OVERLAP_ARGS
  state_teardown
}

test_overlap_excludes_own_pr() {
  state_setup
  local args_file="$STATE_DIR/overlap_args"
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "456\n"
elif [[ "$1" == "pr" && "$2" == "view" ]]; then
  printf "apps/carbotracker/src/features/products/a.ts\n"
elif [[ "$1" == "api" ]]; then
  printf "%s\n" "$*" >> "$FAKE_OVERLAP_ARGS"
fi
exit 0'
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts"; fi'
  export FAKE_OVERLAP_ARGS="$args_file"
  orchestrator_check_overlap 280 456 /tmp/worktree
  assert_eq "own pr never overlaps itself" "" "$(cat "$args_file" 2>/dev/null || true)"
  unset FAKE_OVERLAP_ARGS
  state_teardown
}

test_overlap_survives_gh_error() {
  state_setup
  local args_file="$STATE_DIR/overlap_args"
  fake_command gh 'exit 1'
  fake_command git 'if [[ "$1" == "-C" ]]; then printf "%s\n" "apps/carbotracker/src/features/products/a.ts"; fi'
  export FAKE_OVERLAP_ARGS="$args_file"
  if orchestrator_check_overlap 280 456 /tmp/worktree; then
    pass "overlap check survives a gh failure"
  else
    fail "overlap check survives a gh failure"
  fi
  assert_eq "no warning posted after gh failure" "" "$(cat "$args_file" 2>/dev/null || true)"
  unset FAKE_OVERLAP_ARGS
  state_teardown
}

test_cli_help() {
  local output
  output="$(bash "$ROOT/tools/ct-orchestrator.sh" help)"
  assert_contains "help mentions single poll mode" "once" "$output"
  assert_contains "help mentions daemon mode" "daemon" "$output"
}

test_cli_once() {
  state_setup
  fake_pipeline 'if [[ "$1" == "issue" && "$2" == "list" ]]; then
  printf "[{\"number\":10,\"title\":\"Alpha\"}]\n"
elif [[ "$1" == "api" ]]; then
  printf "no native dependencies\n" >&2
  exit 1
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  case "$3" in
    10) printf "Alpha body\n" ;;
  esac
fi'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" bash "$ROOT/tools/ct-orchestrator.sh" once 2>&1)"
  assert_eq "once mode claims the ticket" "1" "$(jq 'length' "$TEST_STATE")"
  assert_eq "once mode completes the ticket" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "once mode logs discovery" "poll:" "$output"
  state_teardown
}

test_cli_invalid_command() {
  if bash "$ROOT/tools/ct-orchestrator.sh" bogus >/dev/null 2>&1; then
    fail "invalid command exits non-zero"
  else
    pass "invalid command exits non-zero"
  fi
}

test_state_loaded_but_empty_file() {
  state_setup
  touch "$TEST_STATE"
  assert_eq "empty state file loads as empty array" "[]" "$(orchestrator_state_load "$TEST_STATE")"
  state_teardown
}

test_reconcile_empty_state_is_noop() {
  state_setup
  fake_command gh 'exit 99'
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>&1)"
  assert_eq "reconcile leaves empty state alone" "0" "$(jq 'length' "$TEST_STATE" 2>/dev/null || echo 0)"
  assert_contains "logs reconciliation" "reconciling" "$output"
  state_teardown
}

test_reconcile_pr_exists_sets_awaiting_review() {
  state_setup
  fake_reconcile_gh 456
  fake_reconcile_git 0 no no
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_abc ""
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>&1)"
  assert_eq "existing pr moves phase to awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "existing pr number recorded" "456" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_contains "logs pr recovery" "PR #456 exists" "$output"
  state_teardown
}

test_reconcile_pushed_branch_creates_pr() {
  state_setup
  fake_reconcile_git 0 no yes
  fake_command npm 'exit 0'
  fake_reconcile_opencode ses_old
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  if [[ -f "$FAKE_PR_CREATED" ]]; then
    printf "[{\"number\":50}]\n"
  else
    printf "[]\n"
  fi
elif [[ "$1" == "pr" && "$2" == "create" ]]; then
  printf "%s\n" "$*" > "$FAKE_PR_CREATE_ARGS"
  touch "$FAKE_PR_CREATED"
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  printf "Some Title\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ISSUE_COMMENT_ARGS"
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_CREATED="$STATE_DIR/pr_created"
  export FAKE_PR_CREATE_ARGS="$STATE_DIR/pr_create"
  export FAKE_ISSUE_COMMENT_ARGS="$STATE_DIR/issue_comment"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_old ""
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>/dev/null
  assert_contains "pushed branch creates pr for the branch" "--head ticket/123-foo" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_contains "pushed branch creates pr with base main" "--base main" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_eq "recovered pr number stored" "50" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  assert_eq "recovered entry moves to awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_contains "issue commented with created pr" "Started implementation. PR #50 created." "$(cat "$FAKE_ISSUE_COMMENT_ARGS")"
  unset FAKE_PR_COUNT FAKE_PR_CREATE_ARGS FAKE_ISSUE_COMMENT_ARGS
  state_teardown
}

test_reconcile_resumes_with_continue_when_no_session() {
  state_setup
  fake_reconcile_git 3 no no
  fake_command npm 'exit 0'
  fake_reconcile_opencode ses_r
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  if [[ -f "$FAKE_PR_CREATED" ]]; then
    printf "[{\"number\":70}]\n"
  else
    printf "[]\n"
  fi
elif [[ "$1" == "pr" && "$2" == "create" ]]; then
  printf "%s\n" "$*" > "$FAKE_PR_CREATE_ARGS"
  touch "$FAKE_PR_CREATED"
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  printf "Some Title\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_CREATED="$STATE_DIR/pr_created"
  export FAKE_PR_CREATE_ARGS="$STATE_DIR/pr_create"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>/dev/null
  assert_contains "unpushed work resumes opencode with --continue" "--continue" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_contains "resumed opencode targets the issue" "/implement the issue is 123" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_contains "resumed work opens a pr" "--head ticket/123-foo" "$(cat "$FAKE_PR_CREATE_ARGS")"
  assert_eq "resumed work reaches awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  assert_eq "resumed work records pr number" "70" "$(jq -r '.[0].prNumber' "$TEST_STATE")"
  unset FAKE_PR_CREATED FAKE_OPENCODE_ARGS FAKE_PR_CREATE_ARGS
  state_teardown
}

test_reconcile_resumes_with_recorded_session() {
  state_setup
  fake_reconcile_git 2 yes no
  fake_command npm 'exit 0'
  fake_reconcile_opencode ses_old
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  if [[ -f "$FAKE_PR_CREATED" ]]; then
    printf "[{\"number\":71}]\n"
  else
    printf "[]\n"
  fi
elif [[ "$1" == "pr" && "$2" == "create" ]]; then
  touch "$FAKE_PR_CREATED"
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  printf "Some Title\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  exit 0
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_PR_CREATED="$STATE_DIR/pr_created"
  export FAKE_OPENCODE_ARGS="$STATE_DIR/opencode_args"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_complete "$TEST_STATE" 123 ses_old ""
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>/dev/null
  assert_contains "recorded session is resumed" "--session ses_old" "$(cat "$FAKE_OPENCODE_ARGS")"
  assert_eq "dirty worktree reaches awaiting review" "awaiting review" "$(jq -r '.[0].phase' "$TEST_STATE")"
  unset FAKE_OPENCODE_ARGS
  state_teardown
}

test_reconcile_nothing_recoverable_cleans_up() {
  state_setup
  fake_reconcile_git 0 no no
  fake_command gh 'if [[ "$1" == "pr" && "$2" == "list" ]]; then
  printf "[]\n"
elif [[ "$1" == "issue" && "$2" == "view" ]]; then
  printf "Some Title\n"
elif [[ "$1" == "issue" && "$2" == "comment" ]]; then
  printf "%s\n" "$*" > "$FAKE_ISSUE_COMMENT_ARGS"
elif [[ "$1" == "issue" && "$2" == "edit" ]]; then
  printf "%s\n" "$*" > "$FAKE_ISSUE_EDIT_ARGS"
fi
exit 0'
  local worktree="$WT_PARENT/123-foo"
  mkdir -p "$worktree"
  export FAKE_ISSUE_COMMENT_ARGS="$STATE_DIR/issue_comment"
  export FAKE_ISSUE_EDIT_ARGS="$STATE_DIR/issue_edit"
  ORCHESTRATOR_STATE_FILE="$TEST_STATE" orchestrator_state_add "$TEST_STATE" 123 ticket/123-foo "$worktree"
  local output
  output="$(ORCHESTRATOR_STATE_FILE="$TEST_STATE" ORCHESTRATOR_WORKTREE_PARENT="$WT_PARENT" orchestrator_reconcile 2>&1)"
  assert_eq "unrecoverable entry removed from state" "0" "$(jq 'length' "$TEST_STATE")"
  assert_eq "unrecoverable worktree removed" "no" "$([[ -d "$worktree" ]] && echo yes || echo no)"
  assert_contains "unrecoverable issue commented" "no recoverable work" "$(cat "$FAKE_ISSUE_COMMENT_ARGS")"
  assert_contains "unrecoverable issue drops in-progress" "--remove-label in-progress" "$(cat "$FAKE_ISSUE_EDIT_ARGS")"
  assert_eq "unrecoverable issue is not re-queued" "0" "$(grep -c -- '--add-label ready-for-agent' "$FAKE_ISSUE_EDIT_ARGS")"
  assert_contains "logs the cleanup" "nothing recoverable" "$output"
  unset FAKE_ISSUE_COMMENT_ARGS FAKE_ISSUE_EDIT_ARGS
  state_teardown
}

test_state_load_missing
test_state_load_corrupt
test_state_add_creates_entry
test_state_add_is_atomic_and_accumulates
test_state_has_ticket
test_state_loaded_but_empty_file
test_state_complete_updates_entry
test_state_complete_with_missing_values
test_state_complete_updates_only_matching_ticket
test_state_remove_removes_entry
test_state_active_count_counts_implementing_only
test_state_add_creates_last_comment_null
test_state_add_creates_review_failures_zero
test_state_add_creates_review_notice_false
test_state_mark_reviewed_sets_timestamp
test_state_mark_reviewed_touches_only_matching
test_state_set_review_failures_updates
test_state_mark_notice_posted_updates

test_config_defaults
test_config_file_parsing
test_config_env_beats_conf

fake_setup
test_issue_feature_parses_valid_declaration
test_issue_feature_rejects_invalid_declaration
test_changed_features_maps_feature_folders
test_suspect_diff_requires_declared_feature_to_be_untouched
test_suspect_diff_skips_undeclared_ticket
test_suspect_diff_flags_pr_without_failing_pipeline
test_shared_files_returns_intersection
test_shared_files_empty_without_overlap
test_shared_files_matches_whole_paths_only
test_overlap_warns_on_shared_files
test_overlap_no_warning_without_overlap
test_overlap_excludes_own_pr
test_overlap_survives_gh_error
test_candidate_issues_sorted_fifo
test_candidate_issues_passes_both_labels
test_candidate_issues_gh_error
test_issue_blocked_via_native_dependency
test_issue_unblocked_via_native_dependency
test_issue_blocked_via_body_line
test_issue_unblocked_when_blocker_closed
test_issue_blocked_when_blocker_state_unresolvable
test_issue_blocked_via_blocked_by_section
test_body_blocker_numbers_stops_at_next_section
test_opencode_session_id_filters_by_title
test_opencode_session_id_no_match
test_reconcile_empty_state_is_noop
test_reconcile_pr_exists_sets_awaiting_review
test_reconcile_pushed_branch_creates_pr
test_reconcile_resumes_with_continue_when_no_session
test_reconcile_resumes_with_recorded_session
test_reconcile_nothing_recoverable_cleans_up
test_pr_number_for_branch
test_pr_number_for_branch_missing
test_pr_latest_comment_at_returns_newest
test_pr_latest_comment_at_prefers_general_when_newer
test_pr_latest_comment_at_includes_review_submission
test_pr_latest_comment_at_ignores_pending_reviews
test_pr_latest_comment_at_ignores_bot_authored_comments
test_pr_latest_comment_at_human_wins_over_bot
test_pr_latest_comment_at_excludes_bot_comments
test_pr_latest_comment_at_none
test_pr_latest_comment_at_one_surface_empty
test_pr_latest_comment_at_gh_error
test_pr_latest_comment_at_counts_quote_reply_as_human
test_pr_latest_comment_at_ignores_empty_review
test_strip_ai_footer_removes_trailing_footers
test_review_round_success_updates_state
test_review_round_answer_posts_reply_and_does_not_resolve
test_review_round_general_comment_reply_posts_on_pr
test_review_round_pushback_sets_needs_human
test_review_round_question_sets_needs_human
test_review_round_implement_resumes_session_and_resolves
test_review_round_implement_unresolved_keeps_watermark
test_review_round_implement_with_answer_posts_reply_and_resolves
test_review_round_implement_general_comment_resolves_without_thread
test_review_round_implement_general_comment_without_reply_keeps_watermark
test_review_round_implement_resolved_without_reply_keeps_watermark
test_review_round_empty_plan_with_human_content_fails
test_review_round_empty_plan_without_human_content_succeeds
test_review_round_malformed_plan_keeps_watermark_and_retries
test_review_round_schema_invalid_plan_keeps_watermark
test_review_round_partial_reply_failure_does_not_duplicate
test_review_round_all_replies_fail_keeps_watermark_and_retries
test_review_round_failure_increments_and_posts_notice
test_review_round_third_failure_pauses_and_consumes
test_review_round_after_pause_starts_fresh_budget
test_review_round_skips_merged_pr
test_review_round_skips_closed_pr
test_review_round_defers_when_state_unreadable
test_review_round_resumes_from_persisted_plan
test_review_round_keeps_plan_on_act_failure
test_review_round_deletes_plan_at_retry_cap
test_review_act_dedups_thread_reply
test_review_act_dedups_general_reply
test_gh_failure_logged
test_reconcile_defers_when_pr_lookup_fails
test_reconcile_retries_failed_recovery_next_poll
test_reconcile_sweeps_orphaned_plan
test_review_plan_validator_reference_resolves
test_self_refresh_re_execs_on_hash_change
test_self_refresh_passes_on_matching_hash
test_self_refresh_skips_without_hash
test_state_add_creates_review_needs_human_false
test_state_set_review_needs_human_updates
test_review_poll_launches_round_on_new_comment
test_review_poll_skips_when_no_new_comment
test_review_poll_skips_entry_without_session
test_review_poll_posts_notice_when_no_session
test_review_poll_posts_notice_only_once
test_review_poll_skips_entry_without_pr
test_review_poll_ignores_implementing_phase
test_review_poll_retries_failed_round
test_review_poll_pauses_after_three_failures
test_review_poll_resumes_after_pause_on_new_comment
test_review_poll_skips_pr_paused_for_human
test_review_poll_resumes_paused_pr_on_new_comment
test_pr_state_returns_merged
test_pr_state_returns_closed
test_pr_state_returns_open
test_pr_state_gh_error
test_pr_merge_state_returns_behind
test_pr_merge_state_gh_error
test_merge_poll_prunes_merged_pr
test_merge_poll_prunes_closed_pr
test_merge_poll_closed_stashes_uncommitted_work_and_names_entry
test_merge_poll_closed_keeps_worktree_when_stash_fails
test_merge_poll_closed_escalation_failure_restores_stash
test_merge_poll_keeps_entry_when_escalate_fails
test_merge_poll_keeps_entry_when_close_fails
test_merge_poll_keeps_open_pr
test_merge_poll_updates_behind_pr
test_merge_poll_leaves_clean_open_pr_alone
test_merge_poll_aborts_conflicted_merge
test_merge_poll_does_not_push_unverified_behind_pr
test_merge_poll_delegates_conflict_to_agent
test_merge_poll_does_not_trust_exit_zero
test_merge_poll_bounds_agent_merges
test_merge_poll_skips_suspect_pr
test_merge_poll_skips_suspect_behind_pr
test_merge_poll_fails_closed_when_labels_unreadable
test_labels_are_suspect_pure_helper
test_merge_poll_delegation_requires_a_session
test_merge_poll_retries_needs_human_comment
test_state_merge_failures_updates
test_state_merge_notice_posted_updates
test_merge_poll_skips_entry_without_pr
test_merge_poll_gh_error_keeps_entry
test_merge_poll_merge_status_error_keeps_entry
test_review_poll_notice_post_failure_survives
test_merge_poll_ignores_implementing_phase
test_poll_once_runs_merge_poll
test_implement_runs_full_pipeline
test_implement_fails_when_worktree_fails
test_implement_fails_when_npm_ci_fails
test_implement_retries_opencode_with_continue
test_implement_escalates_after_two_opencode_failures
test_implement_escalates_opencode_failure_preserves_commits
test_implement_escalates_empty_run_without_resume
test_implement_resumes_stalled_run_once_and_finishes
test_implement_escalates_when_resume_still_commitless
test_implement_escalates_when_resume_exits_nonzero
test_implement_escalates_when_retry_already_resumed
test_stash_escalation_work_stashes_dirty_tree_with_contract_message
test_stash_escalation_work_uses_passed_session_id
test_stash_escalation_work_unknown_session_uses_none
test_stash_escalation_work_skips_clean_tree
test_stash_escalation_work_skips_missing_worktree
test_stash_escalation_work_fails_closed_on_stash_error
test_implement_escalation_stashes_uncommitted_work_and_names_entry
test_implement_escalation_keeps_worktree_when_stash_fails
test_implement_escalation_failure_restores_stash
test_implement_no_pr_skips_comment
test_implement_no_session_stores_null
test_implement_opens_pr_when_none_exists
test_implement_fails_when_push_fails
test_implement_fails_when_pr_create_fails
test_poll_once_claims_candidates
test_poll_once_implements_all_candidates_when_opencode_drains_stdin
test_poll_once_skips_claimed
test_poll_once_skips_blocked
test_poll_once_respects_concurrency_cap
test_poll_once_skips_when_cap_full
test_poll_once_removes_entry_on_failed_implement
test_poll_once_restores_ready_for_agent_on_failed_implement
test_non_opencode_failure_escalates_at_bound
test_non_opencode_failure_preserves_worktree_below_bound
test_non_opencode_failure_at_bound_preserves_commits
test_non_opencode_failure_clean_failure_still_cleans_up
test_implement_reuses_existing_worktree_on_retry
test_reconcile_skips_failed_entry
test_poll_once_cleans_up_worktree_after_failed_implement
test_poll_once_does_not_cleanup_preexisting_worktree
test_claim_marks_issue_in_progress
test_claim_failure_leaves_no_state
test_poll_once_runs_review_loop
test_cli_once
fake_teardown

fake_setup
test_cli_help
test_cli_invalid_command
fake_teardown

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
