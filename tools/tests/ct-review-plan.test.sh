#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEMA="$ROOT/.agents/skills/review-comments/review-plan.schema.json"
VALIDATOR="$ROOT/tools/ct-json-validate.js"

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

# Run one plan-contract case: write the fixture (from stdin) to a temp dir and
# assert the validator accepts or rejects it. $1 is the test description,
# $2 is the expected outcome, one of "valid" or "invalid".
assert_plan() {
  local desc="$1" expected="$2"
  local fixture
  fixture="$(mktemp)"
  cat > "$fixture"
  local rc=0
  node "$VALIDATOR" "$SCHEMA" "$fixture" >/dev/null 2>&1 || rc=$?
  rm -f "$fixture"
  if [[ "$expected" == "valid" && "$rc" -eq 0 ]] || [[ "$expected" == "invalid" && "$rc" -ne 0 ]]; then
    pass "$desc"
  else
    fail "$desc"
    printf "  validator exited %s, expected %s\n" "$rc" "$expected"
  fi
}

assert_plan_valid() {
  assert_plan "$1" valid
}

assert_plan_invalid() {
  assert_plan "$1" invalid
}

test_valid_answer_plan() {
  assert_plan_valid "an answer plan with needsHuman false is valid" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850731, "path": "README.md", "line": 4, "type": "answer", "reply": "The ratio is stored per meal type.", "confidence": 0.9}]}
EOF
}

test_valid_implement_plan() {
  assert_plan_valid "an implement plan at confidence 0.9 is valid" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850732, "path": "apps/carbotracker/src/app/app.component.ts", "line": 42, "type": "implement", "reply": "Will rename the selector.", "confidence": 0.9}]}
EOF
}

test_valid_implement_at_confidence_gate() {
  assert_plan_valid "an implement plan at exactly confidence 0.8 is valid" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850733, "path": "README.md", "line": 7, "type": "implement", "reply": "Will fix.", "confidence": 0.8}]}
EOF
}

test_valid_question_plan() {
  assert_plan_valid "a question plan with needsHuman true is valid" <<'EOF'
{"needsHuman": true, "comments": [{"commentId": 3788850734, "path": "README.md", "line": 9, "type": "question", "reply": "Should this be solved repo-wide?", "confidence": 0.9}]}
EOF
}

test_valid_pushback_plan() {
  assert_plan_valid "a pushback plan with needsHuman true is valid" <<'EOF'
{"needsHuman": true, "comments": [{"commentId": 3788850735, "path": "apps/carbotracker/src/app/meal/meal.component.ts", "line": 12, "type": "pushback", "reply": "ngrx is already the store; a migration is out of scope.", "confidence": 0.95}]}
EOF
}

test_valid_mixed_plan() {
  assert_plan_valid "a mixed plan with one needsHuman-triggering comment is valid" <<'EOF'
{"needsHuman": true, "comments": [
  {"commentId": 3788850736, "path": "README.md", "line": 4, "type": "answer", "reply": "Done.", "confidence": 0.95},
  {"commentId": 3788850737, "path": "libs/meal/src/lib/meal.ts", "line": 3, "type": "question", "reply": "What is a saved meal?", "confidence": 0.85},
  {"commentId": 3788850738, "path": "apps/carbotracker/src/app/app.component.ts", "line": 42, "type": "implement", "reply": "Will rename.", "confidence": 0.9}
]}
EOF
}

test_valid_empty_plan() {
  assert_plan_valid "an empty plan with needsHuman false is valid" <<'EOF'
{"needsHuman": false, "comments": []}
EOF
}

test_valid_general_comment_plan() {
  assert_plan_valid "a general comment with null path and line is valid" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850739, "path": null, "line": null, "type": "answer", "reply": "Covered in the PR description.", "confidence": 0.9}]}
EOF
}

test_invalid_implement_below_confidence_gate() {
  assert_plan_invalid "an implement comment below 0.8 confidence is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850740, "path": "README.md", "line": 4, "type": "implement", "reply": "Will fix.", "confidence": 0.79}]}
EOF
}

test_invalid_unknown_type() {
  assert_plan_invalid "an unknown comment type is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850741, "path": "README.md", "line": 4, "type": "fix", "reply": "ok", "confidence": 0.9}]}
EOF
}

test_invalid_missing_confidence() {
  assert_plan_invalid "a comment without confidence is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850742, "path": "README.md", "line": 4, "type": "answer", "reply": "ok"}]}
EOF
}

test_invalid_missing_reply() {
  assert_plan_invalid "a comment without a reply is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850743, "path": "README.md", "line": 4, "type": "answer", "confidence": 0.9}]}
EOF
}

test_invalid_missing_comment_id() {
  assert_plan_invalid "a comment without a commentId is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"path": "README.md", "line": 4, "type": "answer", "reply": "ok", "confidence": 0.9}]}
EOF
}

test_invalid_missing_needs_human() {
  assert_plan_invalid "a plan without needsHuman is rejected" <<'EOF'
{"comments": [{"commentId": 3788850744, "path": "README.md", "line": 4, "type": "answer", "reply": "ok", "confidence": 0.9}]}
EOF
}

test_invalid_question_with_needs_human_false() {
  assert_plan_invalid "a question plan with needsHuman false is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850745, "path": "README.md", "line": 9, "type": "question", "reply": "Should this be solved repo-wide?", "confidence": 0.9}]}
EOF
}

test_invalid_needs_human_without_trigger() {
  assert_plan_invalid "needsHuman true with only answer comments is rejected" <<'EOF'
{"needsHuman": true, "comments": [{"commentId": 3788850746, "path": "README.md", "line": 4, "type": "answer", "reply": "Done.", "confidence": 0.95}]}
EOF
}

test_invalid_extra_comment_field() {
  assert_plan_invalid "a comment with an undeclared field is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850747, "path": "README.md", "line": 4, "type": "answer", "reply": "ok", "confidence": 0.9, "reason": "justified"}]}
EOF
}

test_invalid_missing_path() {
  assert_plan_invalid "a comment without a path is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850748, "line": 4, "type": "answer", "reply": "ok", "confidence": 0.9}]}
EOF
}

test_invalid_confidence_out_of_range() {
  assert_plan_invalid "a confidence above 1 is rejected" <<'EOF'
{"needsHuman": false, "comments": [{"commentId": 3788850749, "path": "README.md", "line": 4, "type": "answer", "reply": "ok", "confidence": 1.5}]}
EOF
}

test_invalid_malformed_json() {
  assert_plan_invalid "malformed JSON is rejected" <<'EOF'
{"needsHuman": false, "comments":
EOF
}

test_schema_is_valid_json() {
  if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$SCHEMA" >/dev/null 2>&1; then
    pass "the plan schema is valid JSON"
  else
    fail "the plan schema is valid JSON"
  fi
}

test_schema_compiles() {
  if node -e '
    const fs = require("fs");
    const Ajv = require("ajv");
    const schema = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    new Ajv({ allErrors: true }).compile(schema);
  ' "$SCHEMA" >/dev/null 2>&1; then
    pass "the plan schema compiles under ajv"
  else
    fail "the plan schema compiles under ajv"
  fi
}

test_valid_answer_plan
test_valid_implement_plan
test_valid_implement_at_confidence_gate
test_valid_question_plan
test_valid_pushback_plan
test_valid_mixed_plan
test_valid_empty_plan
test_valid_general_comment_plan
test_invalid_implement_below_confidence_gate
test_invalid_unknown_type
test_invalid_missing_confidence
test_invalid_missing_reply
test_invalid_missing_comment_id
test_invalid_missing_needs_human
test_invalid_question_with_needs_human_false
test_invalid_needs_human_without_trigger
test_invalid_extra_comment_field
test_invalid_missing_path
test_invalid_confidence_out_of_range
test_invalid_malformed_json
test_schema_is_valid_json
test_schema_compiles

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
