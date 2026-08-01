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

# ---------------------------------------------------------------------------
# Case 9: Edit with replace_all:true against old_string occurring twice ->
# both occurrences replaced, so the second (spurious) resource-model label
# is also rewritten and the remaining one still satisfies the check -> exit 0
# ---------------------------------------------------------------------------
target9="$WORKDIR/docs/issue-9/reports/api-design.md"
cat > "$target9" <<'EOF'
# API Design

resource-model: /widgets (plural noun collections), /widgets/{id} nested, consistent hierarchy

placeholder

## Other
placeholder
EOF
old9_json="$(printf 'placeholder' | json_escape)"
new9_json="$(printf 'X' | json_escape)"
payload9=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old9_json},"new_string":${new9_json},"replace_all":true}}
EOF
)
run_case "9 Edit replace_all:true replaces both occurrences" 0 "$payload9"

# ---------------------------------------------------------------------------
# Case 10: MultiEdit with 2 edits applied in sequence, second only succeeds
# because the first already ran -> exit 0
# ---------------------------------------------------------------------------
cat > "$target9" <<'EOF'
# API Design

resource-model: STEP1
EOF
e1old_json="$(printf 'STEP1' | json_escape)"
e1new_json="$(printf 'STEP2' | json_escape)"
e2old_json="$(printf 'resource-model: STEP2' | json_escape)"
e2new_json="$(printf 'resource-model: /orders (plural noun collections), /orders/{id} nested, consistent hierarchy' | json_escape)"
payload10=$(cat <<EOF
{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","edits":[{"old_string":${e1old_json},"new_string":${e1new_json}},{"old_string":${e2old_json},"new_string":${e2new_json}}]}}
EOF
)
run_case "10 MultiEdit sequential edits, later depends on earlier" 0 "$payload10"

# ---------------------------------------------------------------------------
# Case 11: MultiEdit, one edit replace_all:true on multiply-occurring string,
# another edit replace_all:false/absent on a singly-occurring string, in the
# same call -> both semantics honored independently -> exit 0
# ---------------------------------------------------------------------------
cat > "$target9" <<'EOF'
# API Design

resource-model: /items (plural noun collections), /items/{id} nested, consistent hierarchy

DUPTOKEN more text DUPTOKEN

SINGLETOKEN
EOF
e11a_old="$(printf 'DUPTOKEN' | json_escape)"
e11a_new="$(printf 'DUP' | json_escape)"
e11b_old="$(printf 'SINGLETOKEN' | json_escape)"
e11b_new="$(printf 'SINGLE' | json_escape)"
payload11=$(cat <<EOF
{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","edits":[{"old_string":${e11a_old},"new_string":${e11a_new},"replace_all":true},{"old_string":${e11b_old},"new_string":${e11b_new}}]}}
EOF
)
run_case "11 MultiEdit mixed replace_all semantics honored independently" 0 "$payload11"

# ---------------------------------------------------------------------------
# Case 12: Edit with replace_all absent against multiply-occurring old_string
# -> only first occurrence replaced (regression guard). The doc's
# resource-model statement itself contains the duplicated token as its only
# content, so replacing only the first occurrence leaves the label's body
# still non-empty (min length is trivially met either way); use a case where
# only-first-replaced leaves the label body too short while full-replace
# would not, to assert the semantics.
# ---------------------------------------------------------------------------
cat > "$target9" <<'EOF'
# API Design

resource-model: X X
EOF
old12_json="$(printf 'X' | json_escape)"
new12_json="$(printf '' | json_escape)"
payload12=$(cat <<EOF
{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","old_string":${old12_json},"new_string":${new12_json}}}
EOF
)
# after first-only replace: "resource-model:  X" (11 chars stripped body "X" after label+space) -> body len <=10? " X" stripped -> "X" len 1 <=10 -> deny (exit 2)
run_case "12 Edit replace_all absent replaces only first occurrence" 2 "$payload12"

# ---------------------------------------------------------------------------
# Case 13: Malformed JSON, valid JSON but not an object at top level -> exit 2
# ---------------------------------------------------------------------------
payload13='[1,2,3]'
run_case "13 valid JSON array (not object) at top level" 2 "$payload13"

# ---------------------------------------------------------------------------
# Case 14: Empty stdin -> exit 2
# ---------------------------------------------------------------------------
run_case "14 empty stdin" 2 ""

# ---------------------------------------------------------------------------
# Case 15: kill switch UNSET explicitly (no RESOURCE_MODEL_GATE_OFF in env)
# with content that fails the resource-model check -> exit 2
# ---------------------------------------------------------------------------
content15_json="$(printf 'no label here at all' | json_escape)"
payload15=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"docs/issue-9/reports/api-design.md","content":${content15_json}}}
EOF
)
run_case "15 kill switch unset stays active, failing content denied" 2 "$payload15"

# ---------------------------------------------------------------------------
# Case 16: kill switch set to garbage value e.g. banana, content fails check
# -> exit 2 (must stay active)
# ---------------------------------------------------------------------------
run_case "16 kill switch garbage value stays active" 2 "$payload15" "RESOURCE_MODEL_GATE_OFF=banana"

# ---------------------------------------------------------------------------
# Case 17: repo-root-relative path (no $TMP prefix) with
# CLAUDE_PROJECT_DIR=$WORKDIR -> identical scope-match decision as the
# absolute-path case (Case 1 uses a repo-relative path already; this case
# uses the absolute equivalent for comparison) -> exit 0
# ---------------------------------------------------------------------------
content17="# API Design

resource-model: /accounts (plural noun collections), /accounts/{id} nested, consistent hierarchy
"
content17_json="$(printf '%s' "$content17" | json_escape)"
payload17=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$WORKDIR/docs/issue-9/reports/api-design.md","content":${content17_json}}}
EOF
)
run_case "17 absolute path resolves to same scope decision as relative" 0 "$payload17"

# ---------------------------------------------------------------------------
# Case 18: same logical target with a leading ./ prefix -> identical result
# ---------------------------------------------------------------------------
payload18=$(cat <<EOF
{"tool_name":"Write","tool_input":{"file_path":"./docs/issue-9/reports/api-design.md","content":${content17_json}}}
EOF
)
run_case "18 leading ./ prefix resolves to same scope decision" 0 "$payload18"

# ---------------------------------------------------------------------------
# Case 19: CLAUDE_PLUGIN_ROOT_CORE points nowhere (missing-core, mirrors
# core#75's own missing-core test) -> the guarded gate-lib.sh source must
# deny, not silently allow -> exit 2
# ---------------------------------------------------------------------------
run_case "19 missing-core (CLAUDE_PLUGIN_ROOT_CORE nowhere) -> deny, not silent-allow" 2 "$payload15" "CLAUDE_PLUGIN_ROOT_CORE=$WORKDIR/no-such-core"

echo
if [ "$FAILED" -eq 0 ]; then
  echo "All cases passed."
  exit 0
else
  echo "Some cases FAILED."
  exit 1
fi
