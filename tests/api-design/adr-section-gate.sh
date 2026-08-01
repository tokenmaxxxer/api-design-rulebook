#!/usr/bin/env bash
# Self-contained test for api-design/plugins/adr-section-gate/hooks/gate.sh.
# No bats dependency. Prints PASS/FAIL per case; exits 1 if any case failed.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GATE="$REPO_ROOT/api-design/plugins/adr-section-gate/hooks/gate.sh"

# shellcheck source=lib/core-fixture.sh
. "$REPO_ROOT/tests/api-design/lib/core-fixture.sh"

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

# --- Case 9: Edit with replace_all:true against old_string occurring twice,
# flips result from failing to passing (proves both occurrences replaced)
TWO_TBD='## Context

context text

## Decision

decision text

## Alternatives Considered

alternatives text

## Rationale

TBD

## Consequences

TBD
'
printf '%s' "$TWO_TBD" > "$REPO/docs/issue-9/proposals/api-design.md"
old_json="$(printf 'TBD' | json_escape)"
new_json="$(printf 'filled in with real content' | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Edit',
  'tool_input': {
    'file_path': 'docs/issue-9/proposals/api-design.md',
    'old_string': $old_json,
    'new_string': $new_json,
    'replace_all': True
  }
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case9.out" 2>"$TMPDIR_ROOT/case9.err"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case9: Edit replace_all:true, both TBDs replaced -> exit 0" "$ok"

# --- Case 10: MultiEdit, 2 edits applied in sequence, second only makes
# sense because first already ran -> exit 0
SEQ_BASE='## Context

context text

## Decision

decision text

## Alternatives Considered

alternatives text

## Rationale

STEP1_PLACEHOLDER

## Consequences

consequences text
'
printf '%s' "$SEQ_BASE" > "$REPO/docs/issue-9/proposals/api-design.md"
o1_json="$(printf 'STEP1_PLACEHOLDER' | json_escape)"
n1_json="$(printf 'STEP2_PLACEHOLDER' | json_escape)"
o2_json="$(printf 'STEP2_PLACEHOLDER' | json_escape)"
n2_json="$(printf 'final rationale text' | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'MultiEdit',
  'tool_input': {
    'file_path': 'docs/issue-9/proposals/api-design.md',
    'edits': [
      {'old_string': $o1_json, 'new_string': $n1_json},
      {'old_string': $o2_json, 'new_string': $n2_json}
    ]
  }
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case10.out" 2>"$TMPDIR_ROOT/case10.err"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case10: MultiEdit sequential edits (2nd depends on 1st) -> exit 0" "$ok"

# --- Case 11: MultiEdit, one edit replace_all:true against multiply-
# occurring string, another edit replace_all:false/absent against singly-
# occurring string, in same call -> both semantics honored -> exit 0
MIXED_BASE='## Context

context text

## Decision

decision text

## Alternatives Considered

alternatives text

## Rationale

TBD and TBD again

## Consequences

SINGLE_MARK
'
printf '%s' "$MIXED_BASE" > "$REPO/docs/issue-9/proposals/api-design.md"
o1_json="$(printf 'TBD' | json_escape)"
n1_json="$(printf 'done' | json_escape)"
o2_json="$(printf 'SINGLE_MARK' | json_escape)"
n2_json="$(printf 'final consequences text' | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'MultiEdit',
  'tool_input': {
    'file_path': 'docs/issue-9/proposals/api-design.md',
    'edits': [
      {'old_string': $o1_json, 'new_string': $n1_json, 'replace_all': True},
      {'old_string': $o2_json, 'new_string': $n2_json}
    ]
  }
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case11.out" 2>"$TMPDIR_ROOT/case11.err"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case11: MultiEdit mixed replace_all true/false in one call -> exit 0" "$ok"

# --- Case 12: Edit with replace_all absent/false against multiply-
# occurring old_string -> only first occurrence replaced (regression
# guard); resulting content still has an un-replaced TBD so the section
# stays empty-ish/failing -> exit 2
TWO_TBD_2='## Context

context text

## Decision

decision text

## Alternatives Considered

alternatives text

## Rationale

TBD

## Consequences

TBD
'
printf '%s' "$TWO_TBD_2" > "$REPO/docs/issue-9/proposals/api-design.md"
old_json="$(printf 'TBD' | json_escape)"
new_json="$(printf '' | json_escape)"
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
run_gate "$payload" >"$TMPDIR_ROOT/case12.out" 2>"$TMPDIR_ROOT/case12.err"
rc=$?
if [ "$rc" -eq 2 ] && grep -qi "rationale" "$TMPDIR_ROOT/case12.err" && ! grep -qi "consequences" "$TMPDIR_ROOT/case12.err"; then ok=1; else ok=0; fi
report "case12: Edit replace_all absent, only first occurrence replaced -> exit 2 (only rationale empty, consequences untouched)" "$ok"

# --- Case 13: malformed JSON, valid JSON but not an object at top level -> exit 2
printf '%s' "[1,2,3]" | CLAUDE_PROJECT_DIR="$REPO" bash "$GATE" >"$TMPDIR_ROOT/case13.out" 2>"$TMPDIR_ROOT/case13.err"
rc=$?
[ "$rc" -eq 2 ] && ok=1 || ok=0
report "case13: valid JSON, non-object top level ([1,2,3]) -> exit 2" "$ok"

# --- Case 14: malformed JSON, empty stdin -> exit 2
printf '' | CLAUDE_PROJECT_DIR="$REPO" bash "$GATE" >"$TMPDIR_ROOT/case14.out" 2>"$TMPDIR_ROOT/case14.err"
rc=$?
[ "$rc" -eq 2 ] && ok=1 || ok=0
report "case14: empty stdin -> exit 2" "$ok"

# --- Case 15: kill switch UNSET explicitly (no ADR_SECTION_GATE_OFF in env
# at all), content fails ADR-section check -> exit 2 (gate stays active)
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/proposals/api-design.md', 'content': '## Context\n\nonly context\n'}
}))
")
env -u ADR_SECTION_GATE_OFF bash -c "printf '%s' \"\$1\" | CLAUDE_PROJECT_DIR=\"\$2\" bash \"\$3\"" _ "$payload" "$REPO" "$GATE" >"$TMPDIR_ROOT/case15.out" 2>"$TMPDIR_ROOT/case15.err"
rc=$?
[ "$rc" -eq 2 ] && ok=1 || ok=0
report "case15: kill switch unset, failing content -> exit 2" "$ok"

# --- Case 16: kill switch set to garbage/unrecognized value, content fails
# check -> exit 2 (must stay active; regression test for fail-open bug)
printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$REPO" ADR_SECTION_GATE_OFF=banana bash "$GATE" >"$TMPDIR_ROOT/case16.out" 2>"$TMPDIR_ROOT/case16.err"
rc=$?
[ "$rc" -eq 2 ] && ok=1 || ok=0
report "case16: kill switch garbage value 'banana', failing content -> exit 2 (stays active)" "$ok"

# --- Case 17: same logical target expressed as repo-root-relative path
# (no $TMP/$REPO prefix), CLAUDE_PROJECT_DIR=$REPO set -> resolves
# identically to the existing absolute-path case (case 5's scenario, but
# path style varies)
content_json="$(printf '%s' "$MISSING_ALT" | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/proposals/api-design.md', 'content': $content_json}
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case17.out" 2>"$TMPDIR_ROOT/case17.err"
rc=$?
if [ "$rc" -eq 2 ] && grep -qi "alternatives" "$TMPDIR_ROOT/case17.err"; then ok=1; else ok=0; fi
report "case17: repo-root-relative path (no prefix) -> matches absolute-path scope decision" "$ok"

# --- Case 18: same logical target expressed with a leading "./" prefix ->
# resolves identically too
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': './docs/issue-9/proposals/api-design.md', 'content': $content_json}
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case18.out" 2>"$TMPDIR_ROOT/case18.err"
rc=$?
if [ "$rc" -eq 2 ] && grep -qi "alternatives" "$TMPDIR_ROOT/case18.err"; then ok=1; else ok=0; fi
report "case18: leading ./ prefix path -> matches absolute-path scope decision" "$ok"

# --- Case 19: MultiEdit, two edits each filling a DIFFERENT section's
# placeholder in the same call (not sequentially dependent on each other,
# unlike case 10/11) -> both sections end up non-empty -> exit 0
CROSS_SECTION_BASE='## Context

CONTEXT_PLACEHOLDER

## Decision

decision text

## Alternatives Considered

alternatives text

## Rationale

rationale text

## Consequences

CONSEQUENCES_PLACEHOLDER
'
printf '%s' "$CROSS_SECTION_BASE" > "$REPO/docs/issue-9/proposals/api-design.md"
o1_json="$(printf 'CONTEXT_PLACEHOLDER' | json_escape)"
n1_json="$(printf 'filled-in context text' | json_escape)"
o2_json="$(printf 'CONSEQUENCES_PLACEHOLDER' | json_escape)"
n2_json="$(printf 'filled-in consequences text' | json_escape)"
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'MultiEdit',
  'tool_input': {
    'file_path': 'docs/issue-9/proposals/api-design.md',
    'edits': [
      {'old_string': $o1_json, 'new_string': $n1_json},
      {'old_string': $o2_json, 'new_string': $n2_json}
    ]
  }
}))
")
run_gate "$payload" >"$TMPDIR_ROOT/case19.out" 2>"$TMPDIR_ROOT/case19.err"
rc=$?
[ "$rc" -eq 0 ] && ok=1 || ok=0
report "case19: MultiEdit, two edits filling two different sections in one call -> exit 0" "$ok"

# --- Case 20: CLAUDE_PLUGIN_ROOT_CORE points nowhere (missing-core,
# mirrors core#75's own missing-core test) -> the guarded gate-lib.sh
# source must deny, not silently allow -> exit 2
payload=$(python3 -c "
import json
print(json.dumps({
  'tool_name': 'Write',
  'tool_input': {'file_path': 'docs/issue-9/proposals/api-design.md', 'content': '## Context\n\nonly context\n'}
}))
")
printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$REPO" CLAUDE_PLUGIN_ROOT_CORE="$TMPDIR_ROOT/no-such-core" bash "$GATE" >"$TMPDIR_ROOT/case20.out" 2>"$TMPDIR_ROOT/case20.err"
rc=$?
[ "$rc" -eq 2 ] && ok=1 || ok=0
report "case20: missing-core (CLAUDE_PLUGIN_ROOT_CORE nowhere) -> deny, not silent-allow" "$ok"

echo ""
echo "Summary: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
