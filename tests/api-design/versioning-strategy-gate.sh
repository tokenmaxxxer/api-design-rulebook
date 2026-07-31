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
  local path="$1" old="$2" new="$3"
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3]}}))
' "$path" "$old" "$new"
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

echo ""
echo "Results: $pass_count passed, $fail_count failed"
if [ "$fail_count" -ne 0 ]; then
  exit 1
fi
exit 0
