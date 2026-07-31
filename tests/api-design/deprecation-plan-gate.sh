#!/usr/bin/env bash
# Self-contained test suite for deprecation-plan-gate/hooks/gate.sh.
# No bats. Builds a throwaway git repo, invokes gate.sh with JSON payloads
# on stdin, and asserts exit codes.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." >/dev/null 2>&1 && pwd -P)"
GATE="$REPO_ROOT/api-design/plugins/deprecation-plan-gate/hooks/gate.sh"

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/deprecation-plan-gate-test.XXXXXX")"
cleanup() { rm -rf "$TMPROOT"; }
trap cleanup EXIT

REPO="$TMPROOT/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"

pass=0
fail=0

run_case() {
  local name="$1" expected="$2" payload="$3"
  local actual_out rc
  actual_out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$REPO" bash "$GATE" 2>&1)"
  rc=$?
  if [ "$rc" -eq "$expected" ]; then
    echo "PASS: $name (exit $rc)"
    pass=$((pass + 1))
  else
    echo "FAIL: $name (expected exit $expected, got $rc)"
    echo "  output: $actual_out"
    fail=$((fail + 1))
  fi
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# ---------------------------------------------------------------------------
# Case 1: Write with full deprecation-plan (Sunset + Deprecation + date) -> 0
mkdir -p "$REPO/docs/issue-9/reports"
content1='# api-design

deprecation-plan: Sunset: 2027-01-01, Deprecation header set from 2026-06-01, migration path documented at /docs/migrate
'
content1_json="$(printf '%s' "$content1" | json_escape)"
payload1=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content1_json}}}
EOF
)
run_case "1: full deprecation-plan -> allow" 0 "$payload1"

# ---------------------------------------------------------------------------
# Case 2: Write to unrelated path -> 0
content2_json="$(printf 'irrelevant content, no deprecation-plan here' | json_escape)"
payload2=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/other.md","content":${content2_json}}}
EOF
)
run_case "2: unrelated path -> allow" 0 "$payload2"

# ---------------------------------------------------------------------------
# Case 3: Edit whose old_string matches, result still has label+headers+date -> 0
target3="$REPO/docs/issue-9/reports/api-design.md"
cat > "$target3" <<'EOF'
# api-design

deprecation-plan: TBD

other section
EOF
old3_json="$(printf 'deprecation-plan: TBD' | json_escape)"
new3_json="$(printf 'deprecation-plan: Sunset: 2027-03-01, Deprecation: 2026-09-01' | json_escape)"
payload3=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old3_json},"new_string":${new3_json}}}
EOF
)
run_case "3: edit matching old_string, valid result -> allow" 0 "$payload3"

# ---------------------------------------------------------------------------
# Case 4: kill switch on, content missing headers -> 0
content4_json="$(printf 'deprecation-plan: some prose without header names' | json_escape)"
payload4=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content4_json}}}
EOF
)
actual_out="$(printf '%s' "$payload4" | CLAUDE_PROJECT_DIR="$REPO" DEPRECATION_PLAN_GATE_OFF=1 bash "$GATE" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "PASS: 4: kill switch bypasses gate (exit 0)"
  pass=$((pass + 1))
else
  echo "FAIL: 4: kill switch bypasses gate (expected exit 0, got $rc)"
  echo "  output: $actual_out"
  fail=$((fail + 1))
fi

# ---------------------------------------------------------------------------
# Case 5: label present, prose describing window without naming header tokens -> 2
content5_json="$(printf 'deprecation-plan: this endpoint will stop working one year after the next major release, with a six month notice period beforehand.' | json_escape)"
payload5=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content5_json}}}
EOF
)
run_case "5: prose without header tokens -> deny" 2 "$payload5"

# ---------------------------------------------------------------------------
# Case 6: deprecation-plan label immediately followed by heading (empty body) -> 2
content6_json="$(printf '# deprecation-plan\n## next-section\nSunset: 2027-01-01 Deprecation: 2026-01-01' | json_escape)"
payload6=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content6_json}}}
EOF
)
run_case "6: empty body after label -> deny" 2 "$payload6"

# ---------------------------------------------------------------------------
# Case 7: Edit whose old_string does NOT match on-disk content -> 2
cat > "$target3" <<'EOF'
# api-design

deprecation-plan: Sunset: 2027-01-01, Deprecation: 2026-01-01
EOF
old7_json="$(printf 'this string does not exist in the file' | json_escape)"
new7_json="$(printf 'replacement text' | json_escape)"
payload7=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old7_json},"new_string":${new7_json}}}
EOF
)
run_case "7: edit old_string mismatch -> deny" 2 "$payload7"

# ---------------------------------------------------------------------------
# Case 8: malformed non-JSON stdin -> 2
payload8='this is not json at all {{{'
run_case "8: malformed JSON -> deny" 2 "$payload8"

# ---------------------------------------------------------------------------
# Case 9: label + explicit "N/A — net new" -> 0
content9_json="$(printf 'deprecation-plan: N/A — net new' | json_escape)"
payload9=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content9_json}}}
EOF
)
run_case "9: N/A net new -> allow" 0 "$payload9"

echo
echo "Results: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
