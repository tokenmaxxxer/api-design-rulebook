# adr-section-gate

A PreToolUse hook plugin for the api-design rulebook that enforces the
ADR-shaped proposal norm adopted in issue #1.

## Methodology

A phase-1 api-design proposal must be shaped like an Architecture Decision
Record: it must contain all five of the following sections, each present
as a markdown heading and each with non-empty (non-whitespace) body text
before the next heading or end of file:

1. Context
2. Decision
3. Alternatives Considered (also accepted as "Alternatives")
4. Rationale
5. Consequences

Section headings are matched case-insensitively regardless of heading
level (`#`–`######`). If any of the five is missing entirely, or is
present but has an empty body, the write is refused and the refusal
message names exactly which section(s) are missing or empty.

## Scope

The gate only inspects writes whose path (relative to the project root)
matches:

```
docs/issue-<n>/proposals/*api-design*.md
```

i.e. the regex `^docs/issue-[0-9]+/proposals/.*api-design.*\.md$`. Writes
outside this scope are allowed unconditionally (exit 0) without inspecting
content.

## Behavior

- Hooks into `PreToolUse` for `Write`, `Edit`, and `MultiEdit`.
- Reconstructs the resulting file content for the write being attempted
  (full content for `Write`; applies `old_string`/`new_string` against
  on-disk content for `Edit`/`MultiEdit`). If the resulting content cannot
  be determined (e.g. an `Edit`'s `old_string` does not match what is on
  disk), the write is denied rather than guessed at.
- Fails closed: any internal error, missing `python3`, malformed JSON
  payload, or inability to determine the project root causes the tool
  call to be denied (exit 2) rather than silently allowed.

## Kill switch

Set `ADR_SECTION_GATE_OFF=1` (or any truthy-looking non-empty/non-`0`/
non-`false`/non-`no`/non-`off` value) in the environment to bypass this
gate entirely.

## Independence

This plugin is self-contained. It does not read, invoke, or depend on any
sibling api-design plugin, and its methodology check (the 5-section ADR
shape) is evaluated entirely from its own scope logic and the tool-call
payload — no shared state or cross-plugin coordination is required for it
to produce a correct allow/deny decision.
