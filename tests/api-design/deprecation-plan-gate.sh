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

# ---------------------------------------------------------------------------
# Case 10: Edit with replace_all:true against multiply-occurring old_string -> both replaced -> allow
cat > "$target3" <<'EOF'
# api-design

deprecation-plan: TBD TBD

other section
EOF
old10_json="$(printf 'TBD' | json_escape)"
new10_json="$(printf 'Sunset: 2027-04-01, Deprecation: 2026-10-01' | json_escape)"
payload10=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old10_json},"new_string":${new10_json},"replace_all":true}}
EOF
)
run_case "10: Edit replace_all:true replaces both occurrences -> allow" 0 "$payload10"

# ---------------------------------------------------------------------------
# Case 11: MultiEdit sequential edits, second depends on first having run -> allow
cat > "$target3" <<'EOF'
# api-design

deprecation-plan: STEP1

other section
EOF
old11a_json="$(printf 'STEP1' | json_escape)"
new11a_json="$(printf 'STEP2' | json_escape)"
old11b_json="$(printf 'STEP2' | json_escape)"
new11b_json="$(printf 'Sunset: 2027-05-01, Deprecation: 2026-11-01' | json_escape)"
payload11=$(cat <<EOF
{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","edits":[{"old_string":${old11a_json},"new_string":${new11a_json}},{"old_string":${old11b_json},"new_string":${new11b_json}}]}}
EOF
)
run_case "11: MultiEdit sequential dependent edits -> allow" 0 "$payload11"

# ---------------------------------------------------------------------------
# Case 12: MultiEdit mixed replace_all true/false in one call, both honored independently -> allow
cat > "$target3" <<'EOF'
# api-design

deprecation-plan: AAA AAA, BBB

other section
EOF
old12a_json="$(printf 'AAA' | json_escape)"
new12a_json="$(printf 'Sunset: 2027-06-01' | json_escape)"
old12b_json="$(printf 'BBB' | json_escape)"
new12b_json="$(printf 'Deprecation: 2026-12-01' | json_escape)"
payload12=$(cat <<EOF
{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","edits":[{"old_string":${old12a_json},"new_string":${new12a_json},"replace_all":true},{"old_string":${old12b_json},"new_string":${new12b_json},"replace_all":false}]}}
EOF
)
run_case "12: MultiEdit mixed replace_all honored independently -> allow" 0 "$payload12"

# ---------------------------------------------------------------------------
# Case 13: Edit with replace_all absent/false against multiply-occurring
# old_string -> only the FIRST occurrence is replaced (regression guard).
# The first "Sunset" occurrence is the real header token; a second, later
# "Sunset" is incidental prose. Replacing only the first turns the real
# token into "Twilight" while the incidental second "Sunset" is untouched
# and still (wrongly) satisfies \bsunset\b, so the gate allows -- if the
# implementation regressed to replace-ALL, that second "Sunset" would also
# be clobbered and the gate would (correctly, for a bug) deny instead.
cat > "$target3" <<'EOF'
# api-design

deprecation-plan: Sunset: 2027-07-01, Deprecation: 2026-01-01 example prose also mentions Sunset again for style

other section
EOF
old13_json="$(printf 'Sunset' | json_escape)"
new13_json="$(printf 'Twilight' | json_escape)"
payload13=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old13_json},"new_string":${new13_json}}}
EOF
)
run_case "13: Edit replace_all absent, only first occurrence replaced -> allow (regression guard)" 0 "$payload13"

# ---------------------------------------------------------------------------
# Case 14: Malformed JSON, valid JSON but not object at top level ([1,2,3]) -> 2
payload14='[1,2,3]'
run_case "14: JSON array (not object) at top level -> deny" 2 "$payload14"

# ---------------------------------------------------------------------------
# Case 15: Malformed JSON, empty stdin -> 2
payload15=''
run_case "15: empty stdin -> deny" 2 "$payload15"

# ---------------------------------------------------------------------------
# Case 16: kill switch unset explicitly, content fails check -> 2
content16_json="$(printf 'deprecation-plan: prose without header tokens' | json_escape)"
payload16=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content16_json}}}
EOF
)
actual_out="$(printf '%s' "$payload16" | CLAUDE_PROJECT_DIR="$REPO" DEPRECATION_PLAN_GATE_OFF= bash "$GATE" 2>&1)"
rc=$?
if [ "$rc" -eq 2 ]; then
  echo "PASS: 16: kill switch unset, failing content -> deny (exit 2)"
  pass=$((pass + 1))
else
  echo "FAIL: 16: kill switch unset, failing content -> deny (expected exit 2, got $rc)"
  echo "  output: $actual_out"
  fail=$((fail + 1))
fi

# ---------------------------------------------------------------------------
# Case 17: kill switch garbage value (banana), failing content -> stays active -> 2
content17_json="$(printf 'deprecation-plan: prose without header tokens' | json_escape)"
payload17=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content17_json}}}
EOF
)
actual_out="$(printf '%s' "$payload17" | CLAUDE_PROJECT_DIR="$REPO" DEPRECATION_PLAN_GATE_OFF=banana bash "$GATE" 2>&1)"
rc=$?
if [ "$rc" -eq 2 ]; then
  echo "PASS: 17: kill switch garbage value stays active -> deny (exit 2)"
  pass=$((pass + 1))
else
  echo "FAIL: 17: kill switch garbage value stays active -> deny (expected exit 2, got $rc)"
  echo "  output: $actual_out"
  fail=$((fail + 1))
fi

# ---------------------------------------------------------------------------
# Case 18: repo-root-relative path (no $TMP prefix) with CLAUDE_PROJECT_DIR=$TMP
# -> identical scope-match decision as absolute-path case (allow)
content18_json="$(printf 'deprecation-plan: N/A — net new' | json_escape)"
payload18=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content18_json}}}
EOF
)
run_case "18: repo-root-relative path -> allow (matches absolute-path case)" 0 "$payload18"

# ---------------------------------------------------------------------------
# Case 19: same target with leading "./" prefix -> identical result (allow)
content19_json="$(printf 'deprecation-plan: N/A — net new' | json_escape)"
payload19=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"./docs/issue-9/reports/api-design.md","content":${content19_json}}}
EOF
)
run_case "19: leading ./ prefix -> allow (matches absolute-path case)" 0 "$payload19"

echo
echo "Results: $pass passed, $fail failed"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
exit 0
