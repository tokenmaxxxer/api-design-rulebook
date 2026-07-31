# Issue #1 — Current-State Survey (Phase 1)

## What exists today in this repo

`api-design/` is a bare skeleton (seeded by c33ad8e, then converted to
core-canon references by issue #2/#4):

- `api-design/.claude-plugin/plugin.json` — role description only
  (decision boundary, use_when, hand-off), no methodology content.
- `api-design/hooks/directive.sh` — thin stub calling core canon's
  `core_role_directive` (core issue #66) with: decision boundary
  string, use_when string, a `PRODUCES` line listing required record
  fields as free text (`interface spec (endpoints/schema/versioning),
  lifecycle/deprecation plan`), an empty `WRITE_SCOPE` (report-only
  role), and the standard hand-off/boundary-case block.
- `api-design/hooks/hooks.json` — registers only the `SessionStart` →
  `directive.sh` hook. **No record-fields gate, no trailer gate, no
  warrant-hunter agent exist in this repo at all** — unlike the
  `implementation` role surveyed in issue #2, api-design never had
  role-specific copies of these to convert; it was seeded directly in
  post-core-canon-reference style.
- No `docs/issue-*/reports/api-design.md` record exists yet (phase 2 has
  never run for this role).

## Gaps this survey identifies (what scout should aim at)

1. **PRODUCES is prose, not a spec.** `interface spec
   (endpoints/schema/versioning), lifecycle/deprecation plan` names two
   required record fields by label only — no methodology is bound to
   either (e.g. is "interface spec" expected to be OpenAPI? a resource
   model? a plain endpoint table?). Nothing constrains *how* an
   api-design phase-2 deliverable must be produced or reviewed.
2. **No phase-1 proposal norm exists anywhere in this repo.** Contract
   v3 s19 mandates a two-phase PR (survey → proposal → Approve →
   record), but nothing in `api-design/` says what a *conforming*
   proposal document must contain structurally (required sections,
   what counts as adequate rationale/evidence) beyond the generic
   contract text injected by core's `core_role_directive`.
3. **No gate enforces either norm.** There is no
   `record-fields-gate.sh` analog checking that a phase-2 record
   actually contains the required components (e.g. a schema, a
   versioning statement, a deprecation plan) — today `REQUIRED_FIELDS`
   isn't even a structured list, just prose in the directive string.
4. **No plugin mechanism distinguishes proposal-quality gating from
   deliverable-quality gating** — issue #1 explicitly asks for both (a)
   and (b) as separate norms, but the current directive only speaks to
   the deliverable's PRODUCES line, with nothing for the proposal.

These four gaps are exactly what issue #1 asks phase 1 to close: pick a
methodology + required-component norm for (a) proposals and (b)
deliverables, justify the pick, and describe how each becomes enforced
in `directive.sh` (PRODUCES text), a new/adapted gate (required-fields
list + check), and the record path.

## Cross-repo dependency note

Like issue #2's survey found, `core_role_directive`'s actual accepted
parameters and core's centralized-gate mechanism (core issue #66) live
in the `core` canon repo, not checked out here. Any gate this proposal
recommends composes with whatever generic gate mechanics core exposes;
the exact registration surface is a phase-2 execution detail, flagged
here as an open dependency rather than guessed at.
