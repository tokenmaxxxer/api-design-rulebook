#!/usr/bin/env bash
# Self-contained test suite for api-design/plugins/interface-spec-gate/hooks/gate.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
GATE="$REPO_ROOT/api-design/plugins/interface-spec-gate/hooks/gate.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/interface-spec-gate-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
git -C "$TMP" config user.email "test@example.com"
git -C "$TMP" config user.name "Test"

mkdir -p "$TMP/docs/issue-9/reports"
mkdir -p "$TMP/docs/other"

pass_count=0
fail_count=0

check() {
  local name="$1" expected_rc="$2" actual_rc="$3"
  if [ "$actual_rc" = "$expected_rc" ]; then
    echo "PASS: $name (rc=$actual_rc)"
    pass_count=$((pass_count+1))
  else
    echo "FAIL: $name (expected rc=$expected_rc, got rc=$actual_rc)"
    fail_count=$((fail_count+1))
  fi
}

run_gate() {
  local payload="$1"
  shift
  ( cd "$TMP" && CLAUDE_PROJECT_DIR="$TMP" "$@" bash "$GATE" <<<"$payload" ) >"$TMP/out.log" 2>"$TMP/err.log"
  echo $?
}

# Case 1: Write with label + cue -> exit 0
target="$TMP/docs/issue-9/reports/api-design.md"
content='# API Design\n\ninterface-spec: OpenAPI 3.1 document at specs/api.yaml\n'
payload=$(python3 -c "
import json
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$target','content':'$content'}}))
")
rc=$(run_gate "$payload")
check "1: Write with label+cue in scope" 0 "$rc"

# Case 2: Write to unrelated path -> exit 0
target2="$TMP/docs/other/notes.md"
payload=$(python3 -c "
import json
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$target2','content':'no relevant content here'}}))
")
rc=$(run_gate "$payload")
check "2: Write to unrelated path" 0 "$rc"

# Case 3: Edit whose old_string matches on-disk, resulting content still has label+cue -> exit 0
printf '%s\n' "# API Design" "" "interface-spec: OpenAPI 3.1 document at specs/api.yaml" "" "Other section" > "$target"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name':'Edit',
  'tool_input':{
    'file_path':'$target',
    'old_string':'Other section',
    'new_string':'Other section updated'
  }
}))
")
rc=$(run_gate "$payload")
check "3: Edit matching old_string, label+cue retained" 0 "$rc"

# Case 4: kill switch on, content missing cue -> exit 0
payload=$(python3 -c "
import json
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$target','content':'interface-spec: see design doc'}}))
")
rc=$(run_gate "$payload" env INTERFACE_SPEC_GATE_OFF=1)
check "4: kill switch bypasses missing cue" 0 "$rc"

# Case 5: label present, no format cue anywhere -> exit 2
payload=$(python3 -c "
import json
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$target','content':'interface-spec: described in prose only, no format named'}}))
")
rc=$(run_gate "$payload")
check "5: label with no format cue" 2 "$rc"

# Case 6: label immediately followed by heading (empty body), no cue elsewhere -> exit 2
content6="# Doc

## interface-spec
## Next Section

Some prose without any spec format mentioned."
payload=$(python3 -c "
import json, sys
content = '''$content6'''
print(json.dumps({'tool_name':'Write','tool_input':{'file_path':'$target','content':content}}))
")
rc=$(run_gate "$payload")
check "6: label followed immediately by heading, empty body" 2 "$rc"

# Case 7: Edit whose old_string does NOT match on-disk -> exit 2
printf '%s\n' "# API Design" "" "interface-spec: OpenAPI 3.1 document at specs/api.yaml" > "$target"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name':'Edit',
  'tool_input':{
    'file_path':'$target',
    'old_string':'This text does not exist in the file',
    'new_string':'replacement'
  }
}))
")
rc=$(run_gate "$payload")
check "7: Edit old_string mismatch" 2 "$rc"

# Case 8: malformed non-JSON stdin -> exit 2
rc=$(run_gate "this is not json at all {{{")
check "8: malformed JSON stdin" 2 "$rc"

echo ""
echo "Results: $pass_count passed, $fail_count failed"
if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
exit 0
