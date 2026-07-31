# Issue #2 — Phase 2 Record (implementation)

loop_state: landed

## What was done

Executed the phase-1 proposal (`docs/issue-2/proposals/implementation.md`),
approved via issue comment `APPROVE issue-2/implementation` from
`JiwonJung94` (member).

1. Deleted `api-design/agents/warrant-hunter.md`. Core's actual warrant-hunt
   plugin (checked out at `<marketplace-root>/warrant/`, sibling to `core/`)
   is a standalone, unparameterized agent (proposal/write-set protocol,
   generic across all roles) — it takes no per-role decision-boundary/
   hand-off parameters, unlike this repo's old stance-rotation copy assumed.
   The two "role-unique" lines the proposal flagged (decision-boundary
   quote, hand-off line) were already present verbatim in `directive.sh`,
   so nothing was lost — no stub file was needed for this item.
2. Deleted `api-design/hooks/trailer-gate.sh`,
   `handbook-trigger-gate.sh`, and `record-fields-gate.sh`. Confirmed
   against core's actual `core/hooks/hooks.json`: core registers all three
   globally under its own `PreToolUse` (matcher `.*`), fired for every
   plugin install — this repo no longer needs its own copies or its own
   `hooks.json` entries for them.
3. Resolved the proposal's open 2a/2b question on `record-fields-gate.sh`:
   **2a**. Core's version (`core/hooks/record-fields-gate.sh`) is fully
   role-agnostic — it derives the role from `CLAUDE_ROLE`, the record path
   from `docs/issue-<n>/reports/<role>.md`, and checks generic contract §20
   fields (what-was-done/why/upstream-basis/loop_state/open-findings), not
   this role's old `REQUIRED_FIELDS = ["interface-spec", "lifecycle-plan"]`
   concept. There is no config surface for a role-specific required-fields
   list in core's version — that concept is superseded, not carried over.
4. Replaced `api-design/hooks/directive.sh` with a stub: sources
   `core/hooks/lib/role-directive.sh` and calls `core_role_directive` with
   this role's four values (YOU DECIDE / USE_WHEN+PRODUCES+WRITE_SCOPE /
   HAND-OFF+BOUNDARY CASE) inline as single-physical-line arguments (using
   `$'...'` ANSI-C quoting for embedded newlines), since core's
   `stub-check.sh` requires every non-blank line in the stub to be either
   the source line, a plain `VAR=value` assignment, or the one
   `core_role_directive` call line — a multi-line backslash-continued call
   fails that structural check.
5. `RECORD_FIELDS_TERMINAL_STATES`: left unset (core's gate defaults to
   `landed`). No `RECORD_FIELDS_TERMINAL_STATES` variance exists anywhere
   in this repo (grepped, none found) and this role has no documented
   multi-state lifecycle beyond `landed` — per the proposal's own
   fallback (item 4), documenting the omission here rather than inventing
   a value.
6. Updated `api-design/hooks/hooks.json` to keep only the `SessionStart` →
   `directive.sh` entry; dropped the `PreToolUse` block entirely (all three
   of its former entries pointed at now-deleted files).
7. Updated `README.md`'s Layout section to match.

## Why

Per issue #2: core canon now provides a single landed copy of the
warrant-hunt agent (core issue #63) and the three role-agnostic gates
(core issue #66), plus a shared `core_role_directive` boilerplate function.
Keeping per-role vendored copies is drift risk with no benefit once core
registers/provides the same behavior globally.

## Upstream basis

- Issue #2 (this repo), approved via issue comment `APPROVE
  issue-2/implementation`.
- `docs/issue-2/proposals/implementation.md` (phase-1 proposal), commit
  `c058a47`.
- Core canon, read directly from a local checkout at
  `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` (core issues #63, #66):
  `core/hooks/hooks.json`, `core/hooks/lib/role-directive.sh`,
  `core/hooks/record-fields-gate.sh`, `core/hooks/tests/stub-check.sh`,
  `warrant/agents/warrant-hunter.md`, `warrant/README.md`.

## stub-check.sh result

Ran core's actual `core/hooks/tests/stub-check.sh` against this repo's
`api-design/` tree:

```
$ bash <core-checkout>/core/hooks/tests/stub-check.sh api-design
stub-check: ok — no vendored 'trailer-gate.sh' under .../api-design
stub-check: ok — no vendored 'record-fields-gate.sh' under .../api-design
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under .../api-design
stub-check: ok — no vendored 'parse-check.sh' under .../api-design
stub-check: ok — .../api-design/hooks/directive.sh is a role-directive stub
```

Exit code 0 (all checks pass). Also verified separately: `bash -n
directive.sh` (syntax), `hooks.json` parses as valid JSON, and a live run
of `directive.sh` with `CLAUDE_ROLE=api-design` and
`CLAUDE_PLUGIN_ROOT_CORE` pointed at the core checkout produces the
expected directive text (YOU DECIDE/USE_WHEN/PRODUCES/WRITE_SCOPE/
HAND-OFF/BOUNDARY CASE/RECORD lines all present).

## Open findings

None. The proposal's one open question (warrant-hunter parameterization
mechanism) was resolved during this execution (see item 1 above) rather
than left open.
