#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEMA="$ROOT/.agents/skills/implement/implement-abort.schema.json"
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

# Run one abort-contract case: write the fixture (from stdin) to a temp dir and
# assert the validator accepts or rejects it. $1 is the test description,
# $2 is the expected outcome, one of "valid" or "invalid".
assert_abort() {
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

assert_abort_valid() {
  assert_abort "$1" valid
}

assert_abort_invalid() {
  assert_abort "$1" invalid
}

test_valid_missing_dependency() {
  assert_abort_valid "a missing-dependency abort with one tool is valid" <<'EOF'
{"type": "missing-dependency", "dependencies": ["java"], "reason": "The Firebase emulators need a Java runtime."}
EOF
}

test_valid_missing_dependency_multiple() {
  assert_abort_valid "a missing-dependency abort listing several tools is valid" <<'EOF'
{"type": "missing-dependency", "dependencies": ["java", "Xvfb", "xkbcomp"], "reason": "Cypress headless e2e and the Firebase emulators need them."}
EOF
}

test_invalid_unknown_type() {
  assert_abort_invalid "an unknown abort type is rejected" <<'EOF'
{"type": "task-too-hard", "dependencies": ["java"], "reason": "nope"}
EOF
}

test_invalid_missing_type() {
  assert_abort_invalid "an abort without a type is rejected" <<'EOF'
{"dependencies": ["java"], "reason": "The Firebase emulators need a Java runtime."}
EOF
}

test_invalid_empty_dependencies() {
  assert_abort_invalid "an abort with an empty dependency list is rejected" <<'EOF'
{"type": "missing-dependency", "dependencies": [], "reason": "The Firebase emulators need a Java runtime."}
EOF
}

test_invalid_missing_dependencies() {
  assert_abort_invalid "an abort without a dependency list is rejected" <<'EOF'
{"type": "missing-dependency", "reason": "The Firebase emulators need a Java runtime."}
EOF
}

test_invalid_non_string_dependency() {
  assert_abort_invalid "a non-string dependency is rejected" <<'EOF'
{"type": "missing-dependency", "dependencies": [42], "reason": "The Firebase emulators need a Java runtime."}
EOF
}

test_invalid_missing_reason() {
  assert_abort_invalid "an abort without a reason is rejected" <<'EOF'
{"type": "missing-dependency", "dependencies": ["java"]}
EOF
}

test_invalid_empty_reason() {
  assert_abort_invalid "an abort with an empty reason is rejected" <<'EOF'
{"type": "missing-dependency", "dependencies": ["java"], "reason": ""}
EOF
}

test_invalid_extra_field() {
  assert_abort_invalid "an abort with an undeclared field is rejected" <<'EOF'
{"type": "missing-dependency", "dependencies": ["java"], "reason": "ok", "attempt": "installed"}
EOF
}

test_invalid_malformed_json() {
  assert_abort_invalid "malformed JSON is rejected" <<'EOF'
{"type": "missing-dependency", "dependencies":
EOF
}

test_schema_is_valid_json() {
  if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$SCHEMA" >/dev/null 2>&1; then
    pass "the abort schema is valid JSON"
  else
    fail "the abort schema is valid JSON"
  fi
}

test_schema_compiles() {
  if node -e '
    const fs = require("fs");
    const Ajv = require("ajv");
    const schema = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    new Ajv({ allErrors: true }).compile(schema);
  ' "$SCHEMA" >/dev/null 2>&1; then
    pass "the abort schema compiles under ajv"
  else
    fail "the abort schema compiles under ajv"
  fi
}

test_valid_missing_dependency
test_valid_missing_dependency_multiple
test_invalid_unknown_type
test_invalid_missing_type
test_invalid_empty_dependencies
test_invalid_missing_dependencies
test_invalid_non_string_dependency
test_invalid_missing_reason
test_invalid_empty_reason
test_invalid_extra_field
test_invalid_malformed_json
test_schema_is_valid_json
test_schema_compiles

printf '1..%d\n' "$tests"
if [[ $failures -gt 0 ]]; then
  printf '%d/%d tests failed\n' "$failures" "$tests"
  exit 1
fi
printf 'all %d tests passed\n' "$tests"
