# Issue #7 — Current-State Survey (Phase 1)

## What exists today in this repo

- `api-design/hooks/directive.sh` — a thin stub sourcing core canon's
  `core_role_directive` (core issue #66) and passing it four strings:
  decision boundary, use_when, a `PRODUCES` block, and a hand-off block.
  The `PRODUCES` block (added by issue #1 phase 2) already names four
  required record fields — `interface-spec`, `resource-model`,
  `versioning-strategy`, `deprecation-plan` — plus one line of prose
  pointing phase-1 authors at the ADR-shaped proposal norm in
  `docs/issue-1/proposals/api-design.md`, explicitly stating that norm
  "is enforced by PR review at the Approve gate, not by this directive
  or a field-presence gate." That sentence is this issue's target: the
  norm exists in prose only, nothing mechanical checks it.
- `api-design/hooks/hooks.json` — registers exactly one hook:
  `SessionStart` → `directive.sh`. **No `PreToolUse` hook is
  registered at all.** There is no gate of any kind on this role's
  writes — a Write/Edit to `docs/issue-<n>/reports/api-design.md` or
  `docs/issue-<n>/proposals/api-design.md` today passes through
  unchecked by anything specific to api-design (only whatever generic
  core-level gates apply to every role, per issue #1 phase 2's finding
  that core's `record-fields-gate.sh` checks only generic contract
  §20 sections, not role-specific fields).
- `docs/issue-1/proposals/api-design.md` and
  `docs/issue-1/reports/api-design.md` — the adopted methodology
  itself (not re-litigated here): ADR-shaped proposal norm for phase 1
  (context / decision / alternatives considered / rationale /
  consequences), API-First / spec-as-artifact deliverable norm for
  phase 2 (interface-spec, resource-model, versioning-strategy,
  deprecation-plan). Issue #1 phase 2's record explicitly closed with
  "no gate script was added to this repo" and left enforcement of the
  four named fields as "a PR review responsibility" — a deliberate,
  reasoned deferral at the time (core exposed no per-role
  `REQUIRED_FIELDS` config surface), not an oversight. Issue #7 revisits
  that deferral now that a concrete non-core pattern (pricing-rulebook's
  own local `methodology-gate.sh`) exists to follow instead of waiting
  on core.
- `WRITE_SCOPE: []` on this role (report-only — no code/doc write
  outside its own record) is stated in the directive string but,
  like the PRODUCES fields, is not mechanically enforced by any hook
  today. Nothing currently stops this role's session from writing
  outside `docs/issue-<n>/reports/api-design.md`,
  `docs/issue-<n>/reports/api-design/`, or
  `docs/issue-<n>/proposals/api-design.md`.

## What a comparable "hook machine" looks like (structural reference)

`implementation-rulebook` (the sibling plugin issue #7 cites as the bar
to reach) is not checked out in this workspace, so this survey relies on
the one concrete, locally readable exemplar available: the
`pricing-rulebook` plugin at
`/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook`. Its
`pricing/hooks/` directory contains, alongside `directive.sh`:

- `hooks.json` registering a `PreToolUse` hook on matcher
  `Write|Edit|MultiEdit` pointed at `methodology-gate.sh`, in addition
  to the `SessionStart` → `directive.sh` hook.
- `methodology-gate.sh` — a bash script that: (1) fails closed on any
  internal error (`trap __fc EXIT` plus a wrapping `try/except` around
  its Python payload-parsing body, per its own header comment "fails
  closed when a required element is absent, mirroring
  record-fields-gate.sh's fail-closed pattern"); (2) reads the
  `PreToolUse` JSON payload from stdin and extracts `tool_name` /
  `tool_input`; (3) resolves the target `file_path` against the
  project root (found via `CLAUDE_PROJECT_DIR` or `git rev-parse
  --show-toplevel`, in that order) and matches it against two regexes
  scoped to this role's own write surfaces —
  `docs/issue-[0-9]+/proposals/.*pricing.*\.md` and
  `docs/issue-[0-9]+/reports/pricing\.md`; anything outside those two
  patterns exits 0 immediately (not this gate's business); (4)
  reconstructs the *resulting* file content for `Write`, `Edit`, and
  `MultiEdit` tool calls (applying `old_string`/`new_string` against
  the current on-disk content when the tool is `Edit`/`MultiEdit`), and
  denies (exit 2) if it cannot determine the resulting content from the
  given tool input; (5) runs a checklist of required-element checks
  against the lower-cased resulting text (method named, family named
  under certain conditions, inputs-needed stated, a gate-check result
  present, numbers carrying a label, a residual list) and denies with a
  message naming every missing element if any check fails.
- No `PreToolUse` state-tracking/ordering file was found under
  pricing-rulebook (its methodology has no cross-file ordering
  constraint to enforce — every element it checks lives inside the one
  file being written). No `tests/` directory under pricing-rulebook was
  found either at the time of this survey — gate test cases there, if
  any exist, were not locally discoverable; the scout-brief for this
  issue treats pricing-rulebook's shell logic as the pattern reference
  and treats its *test-case design*, not literal test files, as what
  this proposal must supply.

## Gaps this survey identifies (what the phase-1 proposal must close)

1. **No `PreToolUse` gate exists for api-design at all** — the field
   list issue #1 defined (interface-spec / resource-model /
   versioning-strategy / deprecation-plan) and the ADR-shaped proposal
   sections (context / decision / alternatives / rationale /
   consequences) are both currently unchecked by any hook, unlike
   pricing-rulebook's role which gates its own six required elements on
   every `Write|Edit|MultiEdit` to its own write surfaces.
2. **No ordering/state-tracking mechanism has been designed.** Issue
   #1's methodology has an implicit ordering constraint at the
   repo-process level (contract v3 s19's survey → proposal → Approve →
   record sequence) but no api-design-specific mechanism tracks or
   enforces it today; whether the phase-1 → phase-2 progression needs
   its own state file (beyond the generic role-handoff contract state)
   is an open design question this issue's proposal must resolve.
3. **No gate test cases exist** — pricing-rulebook's own `tests/`
   coverage (if any) is not present in this repo, and api-design has
   nothing analogous under repo-root `tests/`.
4. **No checklist/agent file exists for a repeated procedure.** Whether
   the ADR-shape or the four-field deliverable norm involves a
   repeated multi-step procedure worth encoding as a checklist (as
   opposed to a single gate check) has not yet been assessed.
5. **The `WRITE_SCOPE: []` invariant has no enforcement surface.**
   Today it is prose-only inside the directive string; any gate design
   proposed here must state explicitly that it does not attempt to
   loosen or redesign this boundary — a gate here can *validate content
   within* the two known write surfaces but must never be read as
   licensing writes elsewhere.

## Cross-repo dependency note

Like issue #1's survey and issue #2's survey both found, `core`'s
generic gate mechanics (`core/hooks/record-fields-gate.sh`, and any
per-role config surface it may or may not expose) live in a separate
canon repo. This survey does not re-check that repo; the proposal
that follows designs a *role-local* gate (following pricing-rulebook's
precedent of a locally-owned `methodology-gate.sh`, not a core-provided
generic mechanism) precisely because issue #1 phase 2 already found
core exposes no per-role required-fields config surface — the same gap
pricing-rulebook's own plugin closed by writing its own local script
rather than waiting on core.
