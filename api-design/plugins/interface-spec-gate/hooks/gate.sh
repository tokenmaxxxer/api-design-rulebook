#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) for the interface-spec-gate plugin.
# Methodology: API-First deliverable norm, interface-spec facet — sourced to
# Zalando RESTful API Guidelines "Provide API Specification using OpenAPI"
# (rules 101-102). A phase-2 api-design record must name the "interface-spec"
# label plus a machine-readable-format cue (openapi/asyncapi/protobuf/grpc/
# idl); no N/A form is accepted for this facet. Independent of every sibling
# api-design plugin — fails closed and produces a correct allow/deny decision
# using only its own scope.
# Scope: docs/issue-<n>/reports/api-design.md
# Kill switch: export INTERFACE_SPEC_GATE_OFF=1
_gate_lib_core_root="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../core" 2>/dev/null && pwd -P)}"
if [ -z "$_gate_lib_core_root" ] || [ ! -f "$_gate_lib_core_root/hooks/lib/gate-lib.sh" ]; then
  echo "api-design/interface-spec-gate: refused — CLAUDE_PLUGIN_ROOT_CORE is not set and no core checkout was found at the relative fallback path; cannot load gate-lib.sh. Set CLAUDE_PLUGIN_ROOT_CORE to the tokenmaxxxer-core plugin root." >&2
  exit 2
fi
. "$_gate_lib_core_root/hooks/lib/gate-lib.sh" || { echo "api-design/interface-spec-gate: cannot source gate-lib.sh" >&2; exit 2; }
gate_trap_fail_closed
set -uo pipefail

role="api-design/interface-spec-gate"
deny() { gate_deny "$role" "$1"; }

gate_kill_switch_active "${INTERFACE_SPEC_GATE_OFF:-}" || { trap - EXIT; exit 0; }

command -v python3 >/dev/null 2>&1 || deny "gate.sh requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("file_path")
    if isinstance(v,str) and v: print(v)
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && [ -e "$1/.git" ]; }
root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed."

GATE_PAYLOAD="$payload" GATE_ROOT="$root" GATE_LIB_PY="$_gate_lib_core_root/hooks/lib/gate-lib.py" \
python3 <<'PY'
import sys as _fc_sys
try:
    import json, os, posixpath, re, sys

    import importlib.util
    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("api-design/interface-spec-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("GATE_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["GATE_ROOT"].replace("\\", "/"))
    SCOPE_RE = re.compile(r'^docs/issue-[0-9]+/reports/api-design\.md$')

    def resolve(p):
        rel = gate_lib.gate_normalize_path(root, p)
        return None if rel is None else posixpath.join(root, rel) if rel else root

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)
    if not SCOPE_RE.match(rel):
        sys.exit(0)
    abs_path = posixpath.join(root, rel)

    current = None
    if os.path.isfile(abs_path):
        try:
            with open(abs_path, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    new_text, _ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not _ok:
        new_text = None

    if new_text is None:
        deny(
            "this write targets %s but the resulting content cannot be determined "
            "from the tool input (tool=%r). Use Write for the full document, or an "
            "Edit/MultiEdit whose old_string matches on-disk content." % (rel, tool)
        )

    low = new_text.lower()
    # METHODOLOGY CHECK: "interface-spec" label present AND a
    # machine-readable-format cue present in the label's own section. No N/A
    # form accepted for this facet.
    missing = []
    label_re = re.compile(r'interface-spec')
    format_cue_re = re.compile(r'\b(openapi|asyncapi|protobuf|grpc|idl)\b')

    m = label_re.search(low)
    if not m:
        missing.append("interface-spec (label absent)")
    else:
        after = new_text[m.end():]
        next_heading = re.search(r'\n#{1,6}\s', after)
        if next_heading:
            window = after[:next_heading.start()]
        else:
            # No following heading (interface-spec is the file's last
            # section): bound the cue window to a fixed line-count cap
            # instead of "rest of document" (issue-13 locality fix) so
            # unrelated trailing content past the label's own section
            # can never be read as its cue window.
            window = "\n".join(after.split("\n")[:40])
        if not format_cue_re.search(window.lower()):
            missing.append("interface-spec (missing machine-readable format "
                            "cue near the label: openapi/asyncapi/protobuf/grpc/idl)")
        elif not window.strip():
            missing.append("interface-spec (label present, body empty)")

    if missing:
        deny(
            "API-First deliverable norm's interface-spec facet (Zalando RESTful API "
            "Guidelines rules 101-102, Provide API Specification using OpenAPI) "
            "requires the interface-spec label plus a machine-readable format cue "
            "(openapi/asyncapi/protobuf/grpc/idl); no N/A form accepted; missing: %s" % ", ".join(missing)
        )
    sys.exit(0)
except Exception as _fc_e:
    _fc_sys.stderr.write("gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "api-design/interface-spec-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
