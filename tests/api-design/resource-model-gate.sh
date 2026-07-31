#!/usr/bin/env bash
# Self-contained test suite for api-design/plugins/resource-model-gate/hooks/gate.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
GATE="$REPO_ROOT/api-design/plugins/resource-model-gate/hooks/gate.sh"

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

git init -q "$WORKDIR"
mkdir -p "$WORKDIR/docs/issue-9/reports"
mkdir -p "$WORKDIR/docs/other"

FAILED=0

run_case() {
  local name="$1" expected_rc="$2" payload="$3" extra_env="${4:-}"
  local actual_rc
  if [ -n "$extra_env" ]; then
    output="$(env $extra_env CLAUDE_PROJECT_DIR="$WORKDIR" bash "$GATE" <<<"$payload" 2>&1)"
  else
    output="$(CLAUDE_PROJECT_DIR="$WORKDIR" bash "$GATE" <<<"$payload" 2>&1)"
  fi
  actual_rc=$?
  if [ "$actual_rc" -eq "$expected_rc" ]; then
    echo "PASS: $name (rc=$actual_rc)"
  else
    echo "FAIL: $name (expected rc=$expected_rc, got rc=$actual_rc)"
    echo "  output: $output"
    FAILED=1
  fi
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

# ---------------------------------------------------------------------------
# Case 1: Write with a complete resource-model statement -> exit 0
# ---------------------------------------------------------------------------
content1='# API Design

resource-model: /users (plural noun collections), /users/{id} nested under user, consistent hierarchy
'
content1_json="$(printf '%s' "$content1" | json_escape)"
payload1=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content1_json}}}
EOF
)
run_case "1 Write with complete resource-model statement" 0 "$payload1"

# ---------------------------------------------------------------------------
# Case 2: Write to unrelated path -> exit 0
# ---------------------------------------------------------------------------
content2_json="$(printf 'just some notes' | json_escape)"
payload2=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/other/notes.md","content":${content2_json}}}
EOF
)
run_case "2 Write to unrelated path" 0 "$payload2"

# ---------------------------------------------------------------------------
# Case 3: Edit whose old_string matches, result still has label + content -> exit 0
# ---------------------------------------------------------------------------
target3="$WORKDIR/docs/issue-9/reports/api-design.md"
cat > "$target3" <<'EOF'
# API Design

resource-model: /orders (plural noun collections), /orders/{id} nested, consistent hierarchy

## Other Section
placeholder
EOF
old3="placeholder"
new3="placeholder updated with more detail"
old3_json="$(printf '%s' "$old3" | json_escape)"
new3_json="$(printf '%s' "$new3" | json_escape)"
payload3=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old3_json},"new_string":${new3_json}}}
EOF
)
run_case "3 Edit with matching old_string, label retained" 0 "$payload3"

# ---------------------------------------------------------------------------
# Case 4: kill switch on, content missing statement -> exit 0
# ---------------------------------------------------------------------------
content4_json="$(printf 'no label here at all' | json_escape)"
payload4=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content4_json}}}
EOF
)
run_case "4 kill switch bypasses gate" 0 "$payload4" "RESOURCE_MODEL_GATE_OFF=1"

# ---------------------------------------------------------------------------
# Case 5: Write with label absent entirely -> exit 2
# ---------------------------------------------------------------------------
content5_json="$(printf '# API Design\n\nSome unrelated content with no facet label.\n' | json_escape)"
payload5=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content5_json}}}
EOF
)
run_case "5 Write with label absent" 2 "$payload5"

# ---------------------------------------------------------------------------
# Case 6: label immediately followed by a heading (empty body) -> exit 2
# ---------------------------------------------------------------------------
content6="# API Design

resource-model
## Next Section
some other content
"
content6_json="$(printf '%s' "$content6" | json_escape)"
payload6=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content6_json}}}
EOF
)
run_case "6 label present with empty body" 2 "$payload6"

# ---------------------------------------------------------------------------
# Case 7: Edit whose old_string does NOT match on-disk content -> exit 2
# ---------------------------------------------------------------------------
old7_json="$(printf 'this string does not exist in the file' | json_escape)"
new7_json="$(printf 'replacement text' | json_escape)"
payload7=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old7_json},"new_string":${new7_json}}}
EOF
)
run_case "7 Edit with non-matching old_string" 2 "$payload7"

# ---------------------------------------------------------------------------
# Case 8: Malformed non-JSON stdin -> exit 2
# ---------------------------------------------------------------------------
payload8='{not valid json at all'
run_case "8 malformed non-JSON stdin" 2 "$payload8"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "All cases passed."
  exit 0
else
  echo "Some cases FAILED."
  exit 1
fi
