#!/usr/bin/env bash
# Self-contained test suite for the evidence-citation-gate plugin.
# No bats dependency: plain bash, temp git repo, plain assertions.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
GATE="$REPO_ROOT/api-design/plugins/evidence-citation-gate/hooks/gate.sh"

if [ ! -x "$GATE" ]; then
  echo "gate.sh not found or not executable at $GATE" >&2
  exit 1
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/ecg-test.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

git init -q "$TMP"
git -C "$TMP" config user.email test@example.com
git -C "$TMP" config user.name test

mkdir -p "$TMP/docs/issue-9/proposals"

overall_fail=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; overall_fail=1; }

run_gate() {
  # $1 = json payload, sets GATE_STDOUT/GATE_STDERR/GATE_RC globals
  local payload="$1"
  GATE_STDERR="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$TMP" EVIDENCE_CITATION_GATE_OFF="${EVIDENCE_CITATION_GATE_OFF:-}" bash "$GATE" 2>&1 1>/dev/null)"
  GATE_RC=$?
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# ---- Case 1: sourced "standard practice" claim -> exit 0 ----
CASE1_FILE="$TMP/docs/issue-9/proposals/api-design.md"
CASE1_CONTENT="It is standard practice per Zalando RESTful API Guidelines to use plural nouns for collection resources.

This paragraph has no claim at all."
CASE1_JSON=$(python3 -c '
import json
content = open("'"$CASE1_FILE"'.notused", "w") if False else None
' 2>/dev/null; true)
CASE1_PAYLOAD=$(python3 - "$CASE1_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = ("It is standard practice per Zalando RESTful API Guidelines to use plural "
           "nouns for collection resources.\n\nThis paragraph has no claim at all.")
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
run_gate "$CASE1_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 1: sourced standard-practice claim allowed"; else fail "case 1: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 2: unrelated path -> exit 0 ----
CASE2_FILE="$TMP/README.md"
CASE2_PAYLOAD=$(python3 - "$CASE2_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = "This is common practice with no source at all, nothing scoped here."
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
run_gate "$CASE2_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 2: unrelated path allowed"; else fail "case 2: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 3: Edit whose old_string matches on-disk content, adding sourced claim -> exit 0 ----
CASE3_FILE="$TMP/docs/issue-9/proposals/api-design-edit.md"
printf '%s' "## Background

Some neutral background text." > "$CASE3_FILE"
CASE3_PAYLOAD=$(python3 - "$CASE3_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
old = "Some neutral background text."
new = ("Some neutral background text.\n\nIt is common practice per RFC 8594 to signal "
       "deprecation via the Sunset header.")
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": path, "old_string": old, "new_string": new}}))
PYEOF
)
run_gate "$CASE3_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 3: matching Edit with sourced claim allowed"; else fail "case 3: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 4: kill switch on, unsourced claim -> exit 0 ----
CASE4_FILE="$TMP/docs/issue-9/proposals/api-design-off.md"
CASE4_PAYLOAD=$(python3 - "$CASE4_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = "This is common practice, trust me, no source given here at all."
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
EVIDENCE_CITATION_GATE_OFF=1 run_gate "$CASE4_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 4: kill switch bypasses gate"; else fail "case 4: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi
EVIDENCE_CITATION_GATE_OFF=""

# ---- Case 5: "common practice" claim with no source -> exit 2, names it ----
CASE5_FILE="$TMP/docs/issue-9/proposals/api-design-unsourced.md"
CASE5_PAYLOAD=$(python3 - "$CASE5_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = "It is common practice to version APIs via URL path segments, no citation needed."
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
run_gate "$CASE5_PAYLOAD"
if [ "$GATE_RC" -eq 2 ] && printf '%s' "$GATE_STDERR" | grep -qi "standard practice with no named source\|common practice\|no named source"; then
  pass "case 5: unsourced common-practice claim denied with naming"
else
  fail "case 5: expected exit 2 with named claim, got rc=$GATE_RC stderr=$GATE_STDERR"
fi

# ---- Case 6: N/A ----
echo "case 6: N/A for this plugin"

# ---- Case 7: Edit whose old_string does not match on-disk content -> exit 2 ----
CASE7_FILE="$TMP/docs/issue-9/proposals/api-design-nomatch.md"
printf '%s' "Actual on-disk content that will not match." > "$CASE7_FILE"
CASE7_PAYLOAD=$(python3 - "$CASE7_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
old = "This string does not exist in the file."
new = "It is standard practice per Zalando to do X."
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": path, "old_string": old, "new_string": new}}))
PYEOF
)
run_gate "$CASE7_PAYLOAD"
if [ "$GATE_RC" -eq 2 ]; then pass "case 7: non-matching old_string denied"; else fail "case 7: expected exit 2, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 8: malformed non-JSON stdin for a matched path -> exit 2 ----
CASE8_STDERR="$(printf 'not json at all {{{' | CLAUDE_PROJECT_DIR="$TMP" bash "$GATE" 2>&1 1>/dev/null)"
CASE8_RC=$?
if [ "$CASE8_RC" -eq 2 ]; then pass "case 8: malformed stdin denied"; else fail "case 8: expected exit 2, got $CASE8_RC ($CASE8_STDERR)"; fi

echo
if [ "$overall_fail" -ne 0 ]; then
  echo "OVERALL: FAIL"
  exit 1
else
  echo "OVERALL: PASS"
  exit 0
fi
