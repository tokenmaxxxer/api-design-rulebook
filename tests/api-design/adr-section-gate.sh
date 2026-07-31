#!/usr/bin/env bash
# Self-contained test for api-design/plugins/adr-section-gate/hooks/gate.sh.
# No bats dependency. Prints PASS/FAIL per case; exits 1 if any case failed.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO_ROOT/api-design/plugins/adr-section-gate/hooks/gate.sh"

TMPDIR_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR_ROOT"; }
trap cleanup EXIT

REPO="$TMPDIR_ROOT/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"

pass_count=0
fail_count=0

report() {
  local name="$1" ok="$2"
  if [ "$ok" = "1" ]; then
    echo "PASS: $name"
    pass_count=$((pass_count+1))
  else
    echo "FAIL: $name"
    fail_count=$((fail_count+1))
  fi
}

run_gate() {
  # $1 = payload json, remaining env vars already exported by caller
  printf '%s' "$1" | CLAUDE_PROJECT_DIR="$REPO" bash "$GATE"
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

FULL_ADR_CONTENT='## Context

Some context text here.

## Decision

We decided to do X.

## Alternatives Considered

We considered Y and Z.

## Rationale

Because X is better.

## Consequences

This will require migration work.
'

# --- Case 1: Write to in-scope path, all 5 sections present -> exit 0
content_json="$(printf '%s' "$FULL_ADR_CONTENT" | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/proposals/api-design.md', 'content': $content_json}
}))
")
out="$(run_gate "$payload" 2>"$TMPDIR_ROOT/case1.err")"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case1: full ADR content -> exit 0" "$ok"

# --- Case 2: Write to unrelated path -> exit 0
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/reports/api-design.md', 'content': 'irrelevant content'}
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case2.out" 2>"$TMPDIR_ROOT/case2.err"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case2: unrelated path -> exit 0" "$ok"

# --- Case 3: Edit whose old_string matches on-disk content, result still has all 5 sections -> exit 0
mkdir -p "$REPO/docs/issue-9/proposals"
PLACEHOLDER_CONTENT='## Context

Some context text here.

## Decision

We decided to do X.

## Alternatives Considered

We considered Y and Z.

## Rationale

Because X is better.

## Consequences

TBD placeholder.
'
printf '%s' "$PLACEHOLDER_CONTENT" > "$REPO/docs/issue-9/proposals/api-design.md"

old_json="$(printf 'TBD placeholder.' | json_escape)"
new_json="$(printf 'This will require migration work and a rollout plan.' | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Edit',
  'tool_input': {
    'file_path': 'docs/issue-9/proposals/api-design.md',
    'old_string': $old_json,
    'new_string': $new_json
  }
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case3.out" 2>"$TMPDIR_ROOT/case3.err"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case3: Edit matching on-disk content, still complete -> exit 0" "$ok"

# --- Case 4: ADR_SECTION_GATE_OFF=1, content missing sections -> exit 0
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/proposals/api-design.md', 'content': '## Context\n\nonly context\n'}
}))
")
printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$REPO" ADR_SECTION_GATE_OFF=1 bash "$GATE" >"$TMPDIR_ROOT/case4.out" 2>"$TMPDIR_ROOT/case4.err"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case4: kill switch on, missing sections -> exit 0" "$ok"

# --- Case 5: Write missing "Alternatives Considered" entirely -> exit 2, stderr names it
MISSING_ALT='## Context

context text

## Decision

decision text

## Rationale

rationale text

## Consequences

consequences text
'
content_json="$(printf '%s' "$MISSING_ALT" | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/proposals/api-design.md', 'content': $content_json}
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case5.out" 2>"$TMPDIR_ROOT/case5.err"
rc=$?
if [ "$rc" -eq 2 ] && grep -qi "alternatives" "$TMPDIR_ROOT/case5.err"; then ok=1; else ok=0; fi
report "case5: missing Alternatives Considered -> exit 2, named in stderr" "$ok"

# --- Case 6: "## Rationale" immediately followed by "## Consequences" (empty body) -> exit 2
EMPTY_RATIONALE='## Context

context text

## Decision

decision text

## Alternatives Considered

alternatives text

## Rationale
## Consequences

consequences text
'
content_json="$(printf '%s' "$EMPTY_RATIONALE" | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/proposals/api-design.md', 'content': $content_json}
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case6.out" 2>"$TMPDIR_ROOT/case6.err"
rc=$?
if [ "$rc" -eq 2 ] && grep -qi "rationale" "$TMPDIR_ROOT/case6.err"; then ok=1; else ok=0; fi
report "case6: empty Rationale body -> exit 2" "$ok"

# --- Case 7: Edit whose old_string does NOT match on-disk content -> exit 2
old_json="$(printf 'this text does not exist on disk' | json_escape)"
new_json="$(printf 'replacement' | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Edit',
  'tool_input': {
    'file_path': 'docs/issue-9/proposals/api-design.md',
    'old_string': $old_json,
    'new_string': $new_json
  }
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case7.out" 2>"$TMPDIR_ROOT/case7.err"
rc=$?
[ "$rc" -eq 2 ] && ok=1 || ok=0
report "case7: Edit old_string not matching on-disk -> exit 2" "$ok"

# --- Case 8: Malformed non-JSON stdin for a matched path -> exit 2
# Since the shell layer's target-path extraction is best-effort, use a payload
# that fails JSON parsing entirely; the python judge should deny closed.
printf '%s' "not valid json {{{" | CLAUDE_PROJECT_DIR="$REPO" bash "$GATE" >"$TMPDIR_ROOT/case8.out" 2>"$TMPDIR_ROOT/case8.err"
rc=$?
[ "$rc" -eq 2 ] && ok=1 || ok=0
report "case8: malformed non-JSON stdin -> exit 2" "$ok"

echo ""
echo "Summary: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
