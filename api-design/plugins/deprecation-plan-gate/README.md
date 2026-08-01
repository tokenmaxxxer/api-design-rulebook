# deprecation-plan-gate

A `PreToolUse` gate (`Write|Edit|MultiEdit`) that enforces the **deprecation-plan**
facet of the API-First deliverable norm on api-design phase-2 records.

## Methodology

The deprecation-plan facet is sourced to Zalando's `Deprecation` rule, built on
top of [RFC 8594 §3](https://www.rfc-editor.org/rfc/rfc8594#section-3) (the
`Sunset` HTTP response header field). A phase-2 api-design record must either:

- name the `deprecation-plan` label together with both literal HTTP header
  tokens `Sunset` and `Deprecation`, plus a concrete date (ISO `YYYY-MM-DD` or
  a recognizable month-day-year form), or
- state the explicit literal `N/A — net new` (common dash variants accepted)
  when the API is net new and has nothing to deprecate.

A prose description of an equivalent deprecation window that never names the
literal `Sunset` / `Deprecation` header tokens is **not** accepted — the gate
checks for the mechanical presence of the header names, not a paraphrase of
their intent.

## Scope

```
docs/issue-<n>/reports/api-design.md
```

Writes and edits outside this path are always allowed (exit 0) without
inspection.

## Kill switch

```
export DEPRECATION_PLAN_GATE_OFF=1
```

Any truthy value other than `""`, `0`, `false`, `no`, or `off` disables the
gate entirely for the current process.

## Core adoption

This gate sources its fail-closed trap, kill-switch check, deny helper,
JSON parsing, path normalization, and Write/Edit/MultiEdit reconstruction
from core issue #72's `gate-lib.sh` / `gate-lib.py`, by reference
(`CLAUDE_PLUGIN_ROOT_CORE`), rather than hand-rolling them locally:
`gate_trap_fail_closed`, `gate_kill_switch_active`, `gate_deny`,
`gate_parse_json_or_deny`, `gate_normalize_path`, and
`gate_reconstruct_write`. The METHODOLOGY CHECK below — the
deprecation-plan-specific Sunset/Deprecation/date/N/A logic — is not part
of core and stays local to this plugin.

## Independence

This plugin is independently complete: it does its own JSON payload parsing,
its own three-tier project-root detection, its own scope check, and its own
resulting-content reconstruction for `Write`/`Edit`/`MultiEdit`. It does not
depend on, share state with, or require coordination with any other
api-design plugin, and it fails closed (exit 2) on any internal error,
missing dependency (`python3`), or undeterminable resulting content.
