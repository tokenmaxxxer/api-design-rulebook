# resource-model-gate

A PreToolUse hook plugin for the api-design rulebook.

## Methodology enforced

This gate enforces the **resource-model facet** of the API-First deliverable
norm on api-design phase-2 records. The facet requires that a phase-2 record
name the resource hierarchy and naming convention it commits to, sourced to
[Zalando's resource-naming rules](https://opensource.zalando.com/restful-api-guidelines/#resources):

- resources are named with **nouns, not verbs**;
- collection resources use **plural names**;
- the resource hierarchy is **consistent** (parent/child nesting reflects
  real ownership, not ad-hoc grouping).

Concretely, the gate requires a `resource-model` label to be present in the
record, followed by a non-empty statement (more than a token label with no
content) describing the hierarchy/naming decision before the next heading or
end of file.

## Scope

The gate only inspects writes whose resolved, repo-relative path matches:

```
docs/issue-<n>/reports/api-design.md
```

(regex: `^docs/issue-[0-9]+/reports/api-design\.md$`)

Any write outside this scope is allowed unconditionally (exit 0) without
inspecting content.

## Behavior

- Applies to `Write`, `Edit`, and `MultiEdit` tool calls (see
  `hooks/hooks.json`).
- Reconstructs the resulting file content for each tool type:
  - `Write`: uses `tool_input.content` directly.
  - `Edit`: applies `old_string` -> `new_string` against on-disk content;
    if `old_string` does not match, the write is **denied** rather than
    guessed at.
  - `MultiEdit`: applies each edit in sequence against on-disk content under
    the same match-or-deny rule.
- If the resulting content cannot be determined, the gate denies the write
  and explains why, rather than silently allowing an unverifiable change.
- If the resource-model label is missing, or present but with an empty/too
  short body, the gate denies and names exactly what is missing.
- On any internal error, missing `python3`, unparseable payload, or
  undeterminable project root, the gate fails closed (exit 2) rather than
  allowing the write through.

## Kill switch

Set `RESOURCE_MODEL_GATE_OFF=1` (or any truthy-looking non-empty/non-"0"/
non-"false"/non-"no"/non-"off" value) in the environment to bypass this gate
entirely (exit 0 immediately, before any content is inspected).

## Core adoption

This gate sources core's `gate-lib.sh` and `gate-lib.py` (core issue #72's
gate-house standard) by reference instead of hand-rolling its own
fail-closed trap, kill-switch parsing, JSON-parse-or-deny, path-normalize,
and Write/Edit/MultiEdit reconstruction logic. Functions used:
`gate_trap_fail_closed`, `gate_kill_switch_active`, `gate_deny`,
`gate_parse_json_or_deny`, `gate_normalize_path`, `gate_reconstruct_write`.
The resource-model methodology check itself is unchanged and remains
plugin-specific — gate-lib provides no equivalent for it.

## Independence

This plugin is independently complete: it does not read, import, or depend
on any other plugin in this repository (including sibling api-design
plugins or the pricing-rulebook's methodology-gate.sh). It determines its
own project root, its own scope, and its own pass/fail decision using only
the tool-call payload it receives on stdin.
