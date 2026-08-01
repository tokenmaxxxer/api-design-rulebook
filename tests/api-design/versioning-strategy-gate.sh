#!/usr/bin/env bash
# Self-contained test suite for versioning-strategy-gate's gate.sh.
# No bats. Builds a scratch git repo, invokes gate.sh with JSON payloads
# on stdin, and asserts exit codes. Prints PASS/FAIL per case.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
GATE="$REPO_ROOT/api-design/plugins/versioning-strategy-gate/hooks/gate.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/vsg-test.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

git -C "$WORK" init -q
git -C "$WORK" config user.email test@example.com
git -C "$WORK" config user.name test
mkdir -p "$WORK/docs/issue-9/reports"
mkdir -p "$WORK/docs/other"

pass_count=0
fail_count=0

run_case() {
  local name="$1" payload="$2" expected_rc="$3"
  local actual_rc
  local out_f="$WORK/.out.$$"
  local err_f="$WORK/.err.$$"
  set +e
  CLAUDE_PROJECT_DIR="$WORK" bash "$GATE" >"$out_f" 2>"$err_f" <<<"$payload"
  actual_rc=$?
  set -e
  if [ "$actual_rc" -eq "$expected_rc" ]; then
    echo "PASS: $name (rc=$actual_rc)"
    pass_count=$((pass_count+1))
  else
    echo "FAIL: $name (expected rc=$expected_rc, got rc=$actual_rc)"
    echo "  stderr: $(cat "$err_f")"
    fail_count=$((fail_count+1))
  fi
  rm -f "$out_f" "$err_f"
}

json_write() {
  local path="$1" content="$2"
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))
' "$path" "$content"
}

json_edit() {
  local path="$1" old="$2" new="$3" replace_all="${4:-}"
  python3 -c '
import json,sys
ti = {"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3]}
if len(sys.argv) > 4 and sys.argv[4]:
    ti["replace_all"] = sys.argv[4] == "true"
print(json.dumps({"tool_name":"Edit","tool_input":ti}))
' "$path" "$old" "$new" "$replace_all"
}

json_multiedit() {
  # $1 = path, then repeated triples: old new replace_all("true"/"false"/"")
  local path="$1"; shift
  python3 -c '
import json,sys
path = sys.argv[1]
rest = sys.argv[2:]
edits = []
for i in range(0, len(rest), 3):
    o, n, ra = rest[i], rest[i+1], rest[i+2]
    e = {"old_string": o, "new_string": n}
    if ra:
        e["replace_all"] = ra == "true"
    edits.append(e)
print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":path,"edits":edits}}))
' "$path" "$@"
}

TARGET="$WORK/docs/issue-9/reports/api-design.md"
OTHER="$WORK/docs/other/notes.md"

# Case 1: Write with label + mechanism -> allow
c1_content="# API Design

versioning-strategy: URI-path versioning (/v1/...), because clients need explicit major-version pinning
"
run_case "1 write-with-mechanism-allow" "$(json_write "$TARGET" "$c1_content")" 0

# Case 2: Write to unrelated path -> allow
run_case "2 unrelated-path-allow" "$(json_write "$OTHER" "no versioning-strategy content here at all")" 0

# Case 3: Edit whose old_string matches, result still has label + mechanism -> allow
printf '%s' "$c1_content" > "$TARGET"
c3_old="URI-path versioning (/v1/...)"
c3_new="URI-path versioning (/v2/...)"
run_case "3 edit-matches-allow" "$(json_edit "$TARGET" "$c3_old" "$c3_new")" 0

# Case 4: kill switch on, content missing mechanism -> allow
c4_content="versioning-strategy: TBD"
actual_rc=""
out_f4="$WORK/.out4.$$"
err_f4="$WORK/.err4.$$"
set +e
CLAUDE_PROJECT_DIR="$WORK" VERSIONING_STRATEGY_GATE_OFF=1 bash "$GATE" >"$out_f4" 2>"$err_f4" <<<"$(json_write "$TARGET" "$c4_content")"
actual_rc=$?
set -e
if [ "$actual_rc" -eq 0 ]; then
  echo "PASS: 4 kill-switch-allow (rc=0)"
  pass_count=$((pass_count+1))
else
  echo "FAIL: 4 kill-switch-allow (expected rc=0, got rc=$actual_rc)"
  fail_count=$((fail_count+1))
fi
rm -f "$out_f4" "$err_f4"

# Case 5: label present, no mechanism, no none-pre-v1 -> deny
c5_content="versioning-strategy: we will figure this out later"
run_case "5 label-no-mechanism-deny" "$(json_write "$TARGET" "$c5_content")" 2

# Case 6: label immediately followed by heading (empty body) -> deny
c6_content="versioning-strategy
## Next Section
some other content
"
run_case "6 label-then-heading-deny" "$(json_write "$TARGET" "$c6_content")" 2

# Case 7: Edit whose old_string does NOT match on-disk content -> deny
printf '%s' "$c1_content" > "$TARGET"
run_case "7 edit-no-match-deny" "$(json_edit "$TARGET" "THIS STRING DOES NOT EXIST IN FILE" "replacement")" 2

# Case 8: malformed non-JSON stdin -> deny
run_case "8 malformed-json-deny" "not valid json {{{" 2

# Bonus case: label + explicit "none — pre-v1" -> allow
c9_content="versioning-strategy: none — pre-v1, no public consumers yet"
run_case "9 none-pre-v1-allow" "$(json_write "$TARGET" "$c9_content")" 0

# Case 10: Edit with replace_all:true against a multiply-occurring old_string
# -> assert BOTH occurrences replaced. old_string "TBD" occurs once BEFORE
# the label (outside the label's check window) and once inside the
# window (right after the label). A first-occurrence-only replace hits the
# pre-label "TBD" and leaves the window's "TBD" untouched (deny); only
# replace_all:true reaches the in-window occurrence too (allow). This
# content flips pass/fail depending on whether both occurrences replace.
c10_content="Prior note: schedule TBD.

versioning-strategy: TBD"
printf '%s' "$c10_content" > "$TARGET"
run_case "10 edit-replace-all-both-occurrences" "$(json_edit "$TARGET" "TBD" "URI-path versioning" "true")" 0

# Case 11: MultiEdit with 2+ sequential edits where a later edit only
# succeeds because an earlier one already ran -> exit 0.
c11_content="versioning-strategy: PLACEHOLDER"
printf '%s' "$c11_content" > "$TARGET"
run_case "11 multiedit-sequential-dependency" "$(json_multiedit "$TARGET" \
  "PLACEHOLDER" "URI-path" "" \
  "URI-path" "URI-path versioning (/v1/...)" "")" 0

# Case 12: MultiEdit with mixed replace_all:true/false edits in one call ->
# both honored independently. Edit 1 (replace_all:true) must replace BOTH
# "XX" occurrences flanking the label to satisfy the window (the first "XX"
# sits before the label, outside the window; the second sits inside it) —
# if replace_all were ignored for edit 1, the in-window "XX" would remain
# and the check would fail. Edit 2 (replace_all:false/absent) only needs
# its single "YY" occurrence (inside the window) replaced with a second
# unrelated mechanism-adjacent token to prove it still ran; a real
# multi-occurrence "YY" case only-first-replaced would deny if the first
# instance is outside the window.
c12_content="Prior XX note.

versioning-strategy: XX and YY here"
printf '%s' "$c12_content" > "$TARGET"
run_case "12 multiedit-mixed-replace-all" "$(json_multiedit "$TARGET" \
  "XX" "URI-path versioning" "true" \
  "YY" "reference" "false")" 0

# Case 13: Edit with replace_all absent against multiply-occurring old_string
# -> only first occurrence replaced (regression guard). "TBD" occurs twice;
# replacing only the first leaves the second "TBD" but the label's own
# window (right after "versioning-strategy:") gets the mechanism, so this
# should still allow (mirrors real gate behavior: only nearby text matters).
c13_content="versioning-strategy: TBD

Notes: rollout plan TBD"
printf '%s' "$c13_content" > "$TARGET"
run_case "13 edit-replace-all-absent-first-occurrence-only" "$(json_edit "$TARGET" "TBD" "URI-path versioning")" 0

# Case 13b: MultiEdit with replace_all:false explicit against multiply-occurring
# old_string where only replacing the first occurrence fails the check ->
# regression guard the other direction (label's own window untouched, mechanism
# added far away doesn't count) -> deny.
c13b_content="Notes: rollout plan TBD

versioning-strategy: TBD"
printf '%s' "$c13b_content" > "$TARGET"
run_case "13b edit-first-occurrence-only-misses-label-window-deny" "$(json_edit "$TARGET" "TBD" "URI-path versioning" "false")" 2

# Case 14: Malformed JSON, valid JSON but not object at top level -> exit 2
run_case "14 json-array-not-object-deny" "[1,2,3]" 2

# Case 15: Malformed JSON, empty stdin -> exit 2
run_case "15 empty-stdin-deny" "" 2

# Case 16: Kill switch UNSET explicitly with content that fails the check -> exit 2
c16_content="versioning-strategy: we will figure this out later"
actual_rc16=""
out_f16="$WORK/.out16.$$"
err_f16="$WORK/.err16.$$"
set +e
CLAUDE_PROJECT_DIR="$WORK" env -u VERSIONING_STRATEGY_GATE_OFF bash "$GATE" >"$out_f16" 2>"$err_f16" <<<"$(json_write "$TARGET" "$c16_content")"
actual_rc16=$?
set -e
if [ "$actual_rc16" -eq 2 ]; then
  echo "PASS: 16 kill-switch-unset-still-active (rc=2)"
  pass_count=$((pass_count+1))
else
  echo "FAIL: 16 kill-switch-unset-still-active (expected rc=2, got rc=$actual_rc16)"
  fail_count=$((fail_count+1))
fi
rm -f "$out_f16" "$err_f16"

# Case 17: Kill switch garbage value e.g. VERSIONING_STRATEGY_GATE_OFF=banana
# with failing content -> exit 2 (must stay active).
actual_rc17=""
out_f17="$WORK/.out17.$$"
err_f17="$WORK/.err17.$$"
set +e
CLAUDE_PROJECT_DIR="$WORK" VERSIONING_STRATEGY_GATE_OFF=banana bash "$GATE" >"$out_f17" 2>"$err_f17" <<<"$(json_write "$TARGET" "$c16_content")"
actual_rc17=$?
set -e
if [ "$actual_rc17" -eq 2 ]; then
  echo "PASS: 17 kill-switch-garbage-value-stays-active (rc=2)"
  pass_count=$((pass_count+1))
else
  echo "FAIL: 17 kill-switch-garbage-value-stays-active (expected rc=2, got rc=$actual_rc17)"
  fail_count=$((fail_count+1))
fi
rm -f "$out_f17" "$err_f17"

# Case 18: Same logical target as repo-root-relative path (no $WORK prefix)
# with CLAUDE_PROJECT_DIR=$WORK -> identical scope-match decision as
# absolute-path case (deny, since content lacks mechanism).
rel_target="docs/issue-9/reports/api-design.md"
printf '%s' "$c16_content" > "$WORK/$rel_target"
run_case "18 relative-path-same-decision-as-absolute" "$(json_write "$rel_target" "$c16_content")" 2

# Case 19: Same target with leading "./" prefix -> identical result.
dotslash_target="./docs/issue-9/reports/api-design.md"
run_case "19 dotslash-prefix-same-decision" "$(json_write "$dotslash_target" "$c16_content")" 2

# Case 20: CLAUDE_PLUGIN_ROOT_CORE points nowhere (missing-core, mirrors
# core#75's own missing-core test) -> the guarded gate-lib.sh source must
# deny, not silently allow -> exit 2.
actual_rc20=""
out_f20="$WORK/.out20.$$"
err_f20="$WORK/.err20.$$"
set +e
CLAUDE_PROJECT_DIR="$WORK" CLAUDE_PLUGIN_ROOT_CORE="$WORK/no-such-core" bash "$GATE" >"$out_f20" 2>"$err_f20" <<<"$(json_write "$rel_target" "$c16_content")"
actual_rc20=$?
set -e
if [ "$actual_rc20" -eq 2 ]; then
  echo "PASS: 20 missing-core-CLAUDE_PLUGIN_ROOT_CORE-nowhere-denies (rc=2)"
  pass_count=$((pass_count+1))
else
  echo "FAIL: 20 missing-core-CLAUDE_PLUGIN_ROOT_CORE-nowhere-denies (expected rc=2, got rc=$actual_rc20)"
  fail_count=$((fail_count+1))
fi
rm -f "$out_f20" "$err_f20"

echo ""
echo "Results: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
