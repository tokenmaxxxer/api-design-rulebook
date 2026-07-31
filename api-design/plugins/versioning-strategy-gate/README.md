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

## Independence

This gate is self-contained: it does not read, require, or interact with
any other api-design plugin, `directive.sh`, or `marketplace.json`. It
fails closed on any internal error, malformed payload, or undetermined
project root, and can be reasoned about and tested in complete isolation.
