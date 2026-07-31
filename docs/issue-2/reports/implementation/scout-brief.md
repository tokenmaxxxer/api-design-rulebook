# Issue #2 — Scout Brief (Phase 1)

Bounded scout pass per the survey-first protocol (budget: ~5 stages /
~3 minutes). Kept minimal — reason below.

## Scope of this scout

The conversion this issue asks for (remove duplicated agent/gate copies,
replace with references to a canonical "core" source, stub out
role-specific config) is a standard **single-source-of-truth (DRY)**
refactor pattern, not a novel design problem. This repo's own file
headers already self-document the duplication (e.g. `trailer-gate.sh`:
"Adapted from implementation-rulebook's trailer-gate.sh, role name
substituted only"; `warrant-hunter.md`: "adapted from
implementation-rulebook's `agents/warrant-hunter.md`"). The authoritative
target state is specified precisely by the issue itself (core issue #63,
core issue #66, `core/hooks/lib/role-directive.sh`'s
`core_role_directive` function), which live in a sibling repo not checked
out here — the actual shared function signature and stub contract can
only be verified from that repo (or `core/hooks/tests/stub-check.sh`
directly), not from external web research.

**Decision: kept this scout minimal and did not run external web
searches.** External research on generic "DRY documentation" or
"single-source-of-truth for AI agent instruction sets" patterns would not
surface anything more specific than what's already implied by the
issue's own architecture (shared lib function + per-role stub +
role-specific config knobs), and would not reduce the actual uncertainty
in this task, which is entirely about matching this repo's stub shape to
core's actual `core_role_directive` interface — something only
observable by reading core's code or running core's own stub-check test.

## What generic pattern this maps to (from general software-engineering
knowledge, not fresh search)

This is the common **"thin adapter / shared-library extraction"** shape:
1. Identify byte-for-byte or near-identical logic duplicated across
   N call sites (here: N=1 known role repo, api-design, presumably
   alongside implementation-rulebook and others per the issue's own
   references).
2. Extract the invariant portion into a shared library (`core/hooks/lib/
   role-directive.sh`'s `core_role_directive`, and core's own
   `core/hooks/*-gate.sh` registrations for role-agnostic gates).
3. Leave a thin per-site stub that sources/calls the shared function and
   supplies only the variance (role directive text, required-fields list,
   terminal-states config).
4. Add/keep a conformance test (`core/hooks/tests/stub-check.sh`) that
   verifies every site's stub still satisfies the shared contract, so the
   thinning-out doesn't silently drop required behavior.

This maps directly onto the issue's 5 action items and requires no
additional external pattern research to execute — the proposal document
applies this shape mechanically to each of the 5 files/behaviors
inventoried in `survey.md`.

## Explicit gap / phase-2 dependency

This repo has no local `core/` checkout, so the actual current signature
of `core_role_directive` and the current pass/fail behavior of
`core/hooks/tests/stub-check.sh` were **not verified** in this phase-1
pass — only inferred from the issue text. Phase 2 execution must confirm
the real interface before writing the stub, and action item 5 (stub-check
passing) cannot be satisfied until then.
