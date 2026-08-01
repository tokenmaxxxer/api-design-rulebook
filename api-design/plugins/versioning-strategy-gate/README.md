# versioning-strategy-gate

A `PreToolUse` gate (matches `Write|Edit|MultiEdit`) that enforces the
**versioning-strategy facet** of the API-First deliverable norm on
api-design phase-2 records.

## Methodology

The API-First deliverable norm requires that a phase-2 api-design record
name its versioning approach. This facet is sourced to **Zalando's
API-versioning rule**: APIs should use a deliberate versioning mechanism
— URI-path versioning, media-type versioning, or another named scheme —
with semantic-versioning discipline for breaking vs. non-breaking
changes. Pre-v1 APIs may instead declare, explicitly, that no versioning
strategy is in force yet.

Concretely, the gate requires the record to contain a
`versioning-strategy` label, and — in the text following that label, up
to the next markdown heading — either:

- a recognizable mechanism cue (e.g. "URI-path", "media-type", "header
  versioning", "query param", "semantic version"/"semver"), or
- the explicit literal `none — pre-v1` (dash variants `-`, `–`, `—`, or
  `,` between "none" and "pre-v1" are all accepted).

If neither is found, the gate denies the write and names exactly what is
missing.

## Scope

Only tool calls whose `file_path` resolves (relative to the detected
project root) to a path matching:

```
docs/issue-<n>/reports/api-design.md
```

are evaluated. Every other path is allowed through unconditionally
(`exit 0`).

## Resulting-content reconstruction

For `Write`, the gate reads `tool_input.content` directly. For `Edit` and
`MultiEdit`, it reconstructs the resulting file content by applying the
requested string replacement(s) against the current on-disk content. If
the `old_string` doesn't match the on-disk content (so the true resulting
content can't be determined), the gate denies — it never guesses.

## Kill switch

Set `VERSIONING_STRATEGY_GATE_OFF=1` (or any other truthy value) in the
environment to bypass the gate entirely.

## Core adoption

`gate.sh` sources core's gate-house standard library (issue #72:
`gate-lib.sh`/`gate-lib.py`) by path reference rather than hand-rolling
the same machinery. It uses `gate_trap_fail_closed` for the fail-closed
EXIT trap, `gate_kill_switch_active` for the kill-switch check,
`gate_deny` for the stderr-refuse-and-exit-2 protocol, and, in the
embedded Python judge, `gate_parse_json_or_deny` for malformed-payload
handling, `gate_normalize_path` for root-relative path resolution, and
`gate_reconstruct_write` for Write/Edit/MultiEdit content
reconstruction. The library is referenced via `CLAUDE_PLUGIN_ROOT_CORE`
(with a relative-path fallback) and is never vendored into this repo.

## Independence

This gate is self-contained: it does not read, require, or interact with
any other api-design plugin, `directive.sh`, or `marketplace.json`. It
fails closed on any internal error, malformed payload, or undetermined
project root, and can be reasoned about and tested in complete isolation.
