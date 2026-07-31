#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) for the deprecation-plan-gate
# plugin. Methodology: API-First deliverable norm, deprecation-plan facet —
# sourced to Zalando's Deprecation rule, built on RFC 8594 (Sunset HTTP
# header field, RFC 8594 §3) plus Zalando's companion Deprecation response
# header. A phase-2 api-design record must name the "deprecation-plan"
# label with both literal header tokens "Sunset" and "Deprecation" plus a
# concrete date, or the explicit literal "N/A — net new" (dash variants
# accepted). A prose description of an equivalent window that never names
# the literal header tokens is NOT accepted. Independent of every sibling
# api-design plugin — fails closed and produces a correct allow/deny
# decision using only its own scope.
# Scope: docs/issue-<n>/reports/api-design.md
# Kill switch: export DEPRECATION_PLAN_GATE_OFF=1
set -uo pipefail

role="api-design/deprecation-plan-gate"
deny() { echo "${role}: refused — $1" >&2; exit 2; }

case "${DEPRECATION_PLAN_GATE_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

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

GATE_PAYLOAD="$payload" GATE_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("api-design/deprecation-plan-gate: refused — %s\n" % m); sys.exit(2)

    raw = os.environ.get("GATE_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; failing closed.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["GATE_ROOT"].replace("\\", "/"))
    SCOPE_RE = re.compile(r'^docs/issue-[0-9]+/reports/api-design\.md$')

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    if not SCOPE_RE.match(rel):
        sys.exit(0)

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text

    if new_text is None:
        deny(
            "this write targets %s but the resulting content cannot be determined "
            "from the tool input (tool=%r). Use Write for the full document, or an "
            "Edit/MultiEdit whose old_string matches on-disk content." % (rel, tool)
        )

    low = new_text.lower()
    # METHODOLOGY CHECK: "deprecation-plan" label present, plus either both
    # literal "sunset"/"deprecation" header tokens with a date nearby, or
    # the explicit "N/A - net new" literal.
    missing = []
    m = re.search(r'deprecation-plan', low)
    if not m:
        missing.append("deprecation-plan (label absent)")
    else:
        after = new_text[m.end():]
        next_heading = re.search(r'\n#{1,6}\s', after)
        window = after[:next_heading.start()] if next_heading else after
        window_low = window.lower()

        na_re = re.compile(r'n/a\s*[-–—,]\s*net new')
        has_sunset = bool(re.search(r'\bsunset\b', window_low))
        has_deprecation_header = bool(re.search(r'\bdeprecation\b', window_low))
        date_re = re.compile(
            r'\b\d{4}-\d{2}-\d{2}\b|'
            r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+\d{1,2},?\s*\d{4}\b',
            re.I
        )
        has_date = bool(date_re.search(window))

        if na_re.search(window_low):
            pass  # accepted
        elif has_sunset and has_deprecation_header and has_date:
            pass  # accepted
        else:
            missing.append(
                "deprecation-plan (headers not named: requires literal Sunset + "
                "Deprecation header tokens with a concrete date, or 'N/A — net new')"
            )

    if missing:
        deny(
            "API-First deliverable norm's deprecation-plan facet (Zalando's "
            "Deprecation rule, built on RFC 8594 §3 Sunset header) requires the "
            "deprecation-plan label with both the Sunset and Deprecation header "
            "tokens plus a concrete date, or the explicit 'N/A — net new'; "
            "missing: %s" % ", ".join(missing)
        )
    sys.exit(0)
except Exception as _fc_e:
    _fc_sys.stderr.write("gate.sh: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "api-design/deprecation-plan-gate: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
