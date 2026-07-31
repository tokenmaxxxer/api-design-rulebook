# interface-spec-gate

A `PreToolUse` gate (`Write|Edit|MultiEdit`) for the api-design rulebook.

## Methodology

Enforces the **interface-spec facet** of the API-First deliverable norm on
api-design phase-2 records. The facet is sourced to the Zalando RESTful API
Guidelines, rules 101-102 ("Provide API Specification using OpenAPI"): an
API-First deliverable must name a machine-readable spec format for the
interface, not just describe it in prose.

A conforming record must contain:

- the `interface-spec` label, **and**
- at least one machine-readable-format cue near that label: `openapi`,
  `asyncapi`, `protobuf`, `grpc`, or `idl` (case-insensitive).

No N/A form is accepted for this facet — every phase-2 api-design record
must name a concrete spec format. A record whose `interface-spec` label is
immediately followed by another heading (i.e. left with an empty body and no
format cue in that section) is treated as missing the facet, even if a
format cue happens to appear in some unrelated part of the document.

## Scope

Only file writes/edits resolving (after realpath) to a path matching:

```
docs/issue-<n>/reports/api-design.md
```

relative to the detected project root are evaluated. Everything else is
allowed through unconditionally (exit 0).

## Root detection

Three-tier: `CLAUDE_PROJECT_DIR` (if it plausibly looks like a git repo),
then `git rev-parse --show-toplevel` from the target file's directory, then
`git rev-parse --show-toplevel` from the current working directory. If none
resolve, the gate fails closed (exit 2).

## Resulting-content reconstruction

For `Write`, the new content is `tool_input.content` directly. For `Edit`,
the gate reconstructs the resulting file by applying `old_string` ->
`new_string` to the on-disk content, and denies if `old_string` does not
match. For `MultiEdit`, all edits are applied in sequence with the same
matching requirement. If the resulting content cannot be determined, the
gate denies rather than guessing.

## Kill switch

```
export INTERFACE_SPEC_GATE_OFF=1
```

Any value other than the empty string, `0`, `false`, `no`, or `off`
disables the gate entirely (exit 0 without evaluation).

## Independence

This plugin is independently complete: it does not read, invoke, or depend
on any other api-design plugin's files or state. It fails closed on any
unexpected condition (malformed payload, unreadable file, undeterminable
resulting content, missing python3, undeterminable project root) and only
denies naming exactly what is missing.
