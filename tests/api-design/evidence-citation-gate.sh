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

# ---- Case 9: Stripe/AWS acceptance regression (proves the citation-phrase fix) -> exit 0 ----
CASE9_FILE="$TMP/docs/issue-9/proposals/api-design-stripe.md"
CASE9_PAYLOAD=$(python3 - "$CASE9_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = ("It is standard practice per Stripe's API design review practice to version "
           "resources explicitly.\n\nIt is also common practice following AWS's API "
           "guidelines to use idempotency keys on write operations.")
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
run_gate "$CASE9_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 9: Stripe/AWS citation-phrase claims allowed"; else fail "case 9: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 10: bare "google" rejection regression (proves the fix) -> exit 2 ----
CASE10_FILE="$TMP/docs/issue-9/proposals/api-design-bare-google.md"
CASE10_PAYLOAD=$(python3 - "$CASE10_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = ("It is common practice to paginate collections using cursor tokens.\n\n"
           "We also checked Google for prior art before writing this section.")
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
run_gate "$CASE10_PAYLOAD"
if [ "$GATE_RC" -eq 2 ]; then pass "case 10: bare unsignaled 'Google' mention denied"; else fail "case 10: expected exit 2, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 11: Edit with replace_all:true against multiply-occurring old_string -> both replaced -> exit 0 ----
CASE11_FILE="$TMP/docs/issue-9/proposals/api-design-replaceall.md"
printf '%s' "TOKEN appears here. Some text. TOKEN appears again." > "$CASE11_FILE"
CASE11_PAYLOAD=$(python3 - "$CASE11_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
print(json.dumps({"tool_name": "Edit", "tool_input": {
    "file_path": path, "old_string": "TOKEN", "new_string": "REPLACED", "replace_all": True
}}))
PYEOF
)
run_gate "$CASE11_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 11: replace_all Edit both occurrences replaced, allowed"; else fail "case 11: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 12: MultiEdit with 2+ sequential edits, later edit depends on earlier -> exit 0 ----
CASE12_FILE="$TMP/docs/issue-9/proposals/api-design-multiedit-seq.md"
printf '%s' "Original text here." > "$CASE12_FILE"
CASE12_PAYLOAD=$(python3 - "$CASE12_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": path, "edits": [
    {"old_string": "Original text here.", "new_string": "Intermediate text here."},
    {"old_string": "Intermediate text here.", "new_string": "Final text here."}
]}}))
PYEOF
)
run_gate "$CASE12_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 12: sequential MultiEdit dependent edits allowed"; else fail "case 12: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 13: MultiEdit with mixed replace_all true/false in one call, both honored independently ----
CASE13_FILE="$TMP/docs/issue-9/proposals/api-design-multiedit-mixed.md"
printf '%s' "AAA one AAA two. BBB only once." > "$CASE13_FILE"
CASE13_PAYLOAD=$(python3 - "$CASE13_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
print(json.dumps({"tool_name": "MultiEdit", "tool_input": {"file_path": path, "edits": [
    {"old_string": "AAA", "new_string": "ZZZ", "replace_all": True},
    {"old_string": "BBB", "new_string": "YYY", "replace_all": False}
]}}))
PYEOF
)
run_gate "$CASE13_PAYLOAD"
if [ "$GATE_RC" -eq 0 ]; then pass "case 13: mixed replace_all MultiEdit honored independently"; else fail "case 13: expected exit 0, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 14: Edit with replace_all absent/false against multiply-occurring old_string -> only first replaced ----
# The citation check is paragraph-scoped by design (a citation anywhere in a
# paragraph covers every claim in that same paragraph), so the two occurrences
# must sit in DIFFERENT paragraphs for "only the first occurrence was replaced"
# to be observable as a still-denied second paragraph.
CASE14_FILE="$TMP/docs/issue-9/proposals/api-design-firstonly.md"
printf '%s' "$(printf 'It is common practice to do this.\n\nIt is common practice to do this.')" > "$CASE14_FILE"
CASE14_PAYLOAD=$(python3 - "$CASE14_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
old = "It is common practice to do this."
new = "It is common practice per RFC 9999 to do this."
print(json.dumps({"tool_name": "Edit", "tool_input": {"file_path": path, "old_string": old, "new_string": new}}))
PYEOF
)
run_gate "$CASE14_PAYLOAD"
# only the first paragraph's occurrence is replaced (sourced); the second
# paragraph remains unsourced -> should still be denied
if [ "$GATE_RC" -eq 2 ]; then pass "case 14: replace_all absent/false replaces only first occurrence"; else fail "case 14: expected exit 2 (unreplaced second occurrence still unsourced), got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 15: malformed JSON — valid JSON but not object at top level -> exit 2 ----
CASE15_STDERR="$(printf '[1,2,3]' | CLAUDE_PROJECT_DIR="$TMP" bash "$GATE" 2>&1 1>/dev/null)"
CASE15_RC=$?
if [ "$CASE15_RC" -eq 2 ]; then pass "case 15: non-object top-level JSON denied"; else fail "case 15: expected exit 2, got $CASE15_RC ($CASE15_STDERR)"; fi

# ---- Case 16: malformed JSON — empty stdin -> exit 2 ----
CASE16_STDERR="$(printf '' | CLAUDE_PROJECT_DIR="$TMP" bash "$GATE" 2>&1 1>/dev/null)"
CASE16_RC=$?
if [ "$CASE16_RC" -eq 2 ]; then pass "case 16: empty stdin denied"; else fail "case 16: expected exit 2, got $CASE16_RC ($CASE16_STDERR)"; fi

# ---- Case 17: kill switch UNSET explicitly, failing content -> exit 2 ----
CASE17_FILE="$TMP/docs/issue-9/proposals/api-design-killunset.md"
CASE17_PAYLOAD=$(python3 - "$CASE17_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = "This is common practice with no source at all."
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
GATE_STDERR="$(printf '%s' "$CASE17_PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" env -u EVIDENCE_CITATION_GATE_OFF bash "$GATE" 2>&1 1>/dev/null)"
GATE_RC=$?
if [ "$GATE_RC" -eq 2 ]; then pass "case 17: kill switch unset stays active, denies"; else fail "case 17: expected exit 2, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 18: kill switch garbage value -> stays active -> exit 2 ----
CASE18_FILE="$TMP/docs/issue-9/proposals/api-design-killgarbage.md"
CASE18_PAYLOAD=$(python3 - "$CASE18_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = "This is common practice with no source at all."
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
GATE_STDERR="$(printf '%s' "$CASE18_PAYLOAD" | CLAUDE_PROJECT_DIR="$TMP" EVIDENCE_CITATION_GATE_OFF=banana bash "$GATE" 2>&1 1>/dev/null)"
GATE_RC=$?
if [ "$GATE_RC" -eq 2 ]; then pass "case 18: kill switch garbage value stays active, denies"; else fail "case 18: expected exit 2, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 19: repo-root-relative path (no $TMP prefix) with CLAUDE_PROJECT_DIR=$TMP -> same decision as absolute path ----
CASE19_REL="docs/issue-9/proposals/api-design-relpath.md"
CASE19_PAYLOAD=$(python3 - "$CASE19_REL" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = "This is common practice with no source at all."
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
run_gate "$CASE19_PAYLOAD"
if [ "$GATE_RC" -eq 2 ]; then pass "case 19: repo-root-relative path matches same scope decision as absolute"; else fail "case 19: expected exit 2, got $GATE_RC ($GATE_STDERR)"; fi

# ---- Case 20: same target with leading ./ prefix -> identical result ----
CASE20_REL="./docs/issue-9/proposals/api-design-relpath.md"
CASE20_PAYLOAD=$(python3 - "$CASE20_REL" <<'PYEOF'
import json, sys
path = sys.argv[1]
content = "This is common practice with no source at all."
print(json.dumps({"tool_name": "Write", "tool_input": {"file_path": path, "content": content}}))
PYEOF
)
run_gate "$CASE20_PAYLOAD"
if [ "$GATE_RC" -eq 2 ]; then pass "case 20: leading ./ prefix matches same scope decision"; else fail "case 20: expected exit 2, got $GATE_RC ($GATE_STDERR)"; fi

echo
if [ "$overall_fail" -ne 0 ]; then
  echo "OVERALL: FAIL"
  exit 1
else
  echo "OVERALL: PASS"
  exit 0
fi
