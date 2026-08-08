---
code_under_review:
  - README.md
  - api-design/hooks/directive.sh
  - api-design/plugins/interface-spec-gate/hooks/gate.sh
  - api-design/plugins/resource-model-gate/hooks/gate.sh
  - tests/api-design/interface-spec-gate.sh
  - tests/api-design/resource-model-gate.sh
  - docs/specs/record-fields-terminal-states.json
loop_state: landed
---

# Issue #17 phase 2: apply approved api-design spec-alignment proposal

## What was done

Applied `docs/issue-17/proposals/api-design.md` (status: approved via issue
comment `APPROVE issue-17/implementation` from `JiwonJung94`, an
`docs/specs/approvers.md`-listed account) exactly as scoped:

1. `README.md` — documented `docs/specs/record-fields-terminal-states.json`
   in Layout, and added a "Realized-spec field alignment (issue #17)"
   section naming where each of the five spec fields
   (`endpoint_path`, `method`, `spectral_ruleset_id`, `verdict`,
   `openapi_version`) attaches.
2. `api-design/hooks/directive.sh` — extended the PRODUCES text: facet 1
   (interface-spec) now names `openapi_version` and `spectral_ruleset_id`;
   facet 2 (resource-model) now names `endpoint_path` and `method`; added
   a `verdict` line (recomputed, never asserted, enforcement deferred);
   added the `loop_state` vocabulary line.
3. `api-design/plugins/interface-spec-gate/hooks/gate.sh` — the
   `format_cue_re` now also accepts an adjacent `openapi_version:` or
   `spectral_ruleset_id:` field mention as satisfying the cue, additive to
   (never replacing) the existing openapi/asyncapi/protobuf/grpc/idl cue.
4. `api-design/plugins/resource-model-gate/hooks/gate.sh` — added a
   post-hierarchy-check requirement for an `endpoint_path: /...` value and
   a `method: GET|POST|PUT|PATCH|DELETE` token in the resource-model
   section, additive to (never replacing) the existing
   hierarchy/naming-statement check.
5. `tests/api-design/interface-spec-gate.sh` — added cases 22-24: the two
   new field-mention cues each independently satisfy the check (0), and
   confirmed no-cue-at-all is still denied (2, pre-existing behavior
   unchanged).
6. `tests/api-design/resource-model-gate.sh` — updated the pre-existing
   accept-fixtures (cases 1, 3, 9, 10, 11, 17, 18) to also carry
   `endpoint_path:`/`method:` so they still pass under the strengthened
   check, and added cases 20-22: missing `endpoint_path` denies, missing
   `method` denies, all three present allows.
7. `docs/specs/record-fields-terminal-states.json` — new file, pins this
   role's phase-2 record kind (`coding-record`)'s terminal `loop_state`
   set to `["landed"]`, matching the spec's terminal state.

No existing PRODUCES facet, gate, or test was deleted or replaced — every
change is additive, per the proposal's Constraints.

## Why

Per the proposal's Rationale (`docs/issue-17/proposals/api-design.md`):
`endpoint_path`/`method` describe a resource's addressing, so they attach
to resource-model, not interface-spec (which owns the spec document's
*format*, a different axis). `openapi_version` is a property of the spec
document, so it strengthens interface-spec's format cue. `spectral_ruleset_id`
attaches as doctrine to interface-spec, not a new resolver gate, because
the spec's own `reference_resolution.checked_by` already names
`on-the-record/hooks/role-spec-reference-guard.sh` as the enforcement
point — a second resolver here would duplicate that check with no shared
source of truth. `verdict` attaches to doctrine only, no gate, because the
spec's `recomputation.rule` requires re-running the ruleset (not asserting
a token) and its `checked_by` is the spec's own stated `TBD (follow-up)` —
a field-presence gate here would create false confidence. The
`loop_state` override file did not exist in this repo; leaving it to
core canon's generic default was rejected because the spec's terminal
state is role-specific vocabulary the generic default cannot know, and
the per-repo override mechanism exists precisely for this case.

## Upstream basis

Approved proposal: `docs/issue-17/proposals/api-design.md` (commit
`ecb77f0`). Approval: issue #17 comment `APPROVE issue-17/implementation`
by `JiwonJung94` (2026-08-08T20:44:13Z), single-account mode per contract
v3 s19 (PR #18's author and the approver are the same account).

## What did not work

- Wrote `docs/specs/record-fields-terminal-states.json` with the
  proposal's example literal, a per-kind object of category ->
  states-list (`{"api-design": {"progress": [...], "terminal": [...],
  "refusal": [...], "error": [...]}}`) — refused twice at write time by
  `record-fields-gate.sh`: first because `api-design` is not one of
  contract §2's canonical record kinds, then again (after correcting the
  key to `coding-record`) because the gate's actual schema is
  `{kind: [terminal states]}` — a flat list of terminal states only, not
  a categorized object. Corrected to `{"coding-record": ["landed"]}`; see
  Rationale for deviations below.
- Wrote this record's `code_under_review:` frontmatter as a bare commit
  sha — refused by `record-fields-gate.sh`: per
  `docs/issue-100/decisions/2026-08-03-record-citation-format-and-kind-convention.md`
  this role's own record cites `code_under_review` as the reviewed file
  list, not a sha (the record's own commit sha does not exist yet when
  the file is written). Corrected to the file list matching the
  proposal's frozen write set.

## Rationale for deviations

Two corrections to the proposal's stated JSON literal for
`docs/specs/record-fields-terminal-states.json` (step 5 of "What will be
done"), both discovered only by attempting the write against the actual
gate:

1. Key name: the proposal's example used `"api-design"` as the top-level
   key. `record-fields-gate.sh` requires the key to be one of contract
   §2's canonical record kinds (`coding-record`, `feasibility-record`,
   `ops-record`, `product-record`, `qa-record`, `reflect-record`,
   `review-record`, `ux-design-record`, `verify-record`), not a role
   name. This role's phase-2 record kind is `coding-record` (the
   `implementation`/`coding` role, per this session's own naming-note
   directive), so the key was corrected.
2. Value shape: the proposal's example value was a categorized object
   (`progress`/`terminal`/`refusal`/`error` keys). The gate's actual
   schema (confirmed by reading `record-fields-gate.sh` after the second
   refusal) is `{kind: [terminal states]}` — a flat list naming only the
   TERMINAL states for that kind; it does not carry progress/refusal/
   error categories at all. The value was corrected to `["landed"]`.

Net effect: the file now mechanically pins only the terminal state
(`landed`) for `coding-record`, exactly what the gate can express. The
full five-state vocabulary this role uses (`landed`
terminal; `linting`/`reviewing` progress; `spec-undeclared` refusal;
`ruleset-unreachable` error) is still stated as doctrine in
`directive.sh` and `README.md`, per the proposal's intent — only the
mechanically-enforced subset shrank to match the gate's real schema.
`README.md`'s prose describing the override file was corrected to state
this accurately (terminal-only, not full-vocabulary enforcement). No
other deviation from the approved proposal occurred.

## Acceptance check verification (per issue #17's own Acceptance section)

- `grep -ri 'endpoint_path\|method\|spectral_ruleset_id\|verdict\|openapi_version' docs/ README.md`
  returns hits for every one of the five field names (checked manually
  post-edit).
- The rulebook's stated `loop_state` vocabulary (`directive.sh`,
  `README.md`) is exactly the spec's five states — `landed`, `linting`,
  `reviewing`, `ruleset-unreachable`, `spec-undeclared` — no stale or
  extra states; the mechanically-enforced terminal subset
  (`docs/specs/record-fields-terminal-states.json`) is the correct
  subset of that same set (`["landed"]`).
- Test suite: ran all six `tests/api-design/*.sh` suites directly
  (`bash tests/api-design/<name>.sh`); all six pass, including the two
  touched suites (`interface-spec-gate.sh`: 24/24,
  `resource-model-gate.sh`: 22/22) and the four untouched suites as a
  regression check (`adr-section-gate.sh` 20/20,
  `deprecation-plan-gate.sh` 20/20, `evidence-citation-gate.sh` 21/21,
  `versioning-strategy-gate.sh` 21/21).
- `spectral_ruleset_id` reference-resolution and `verdict` recomputation
  are each documented in this record's "Why" section and in the
  proposal's Rationale as deferred elsewhere, satisfying the acceptance
  criterion's "empty state" requirement (no field silently skipped).

## Open findings

None. Warrant-hunter dispatched at before-landing (stance 0: assume the
gate just touched is bypassable) per the standing warrant directive;
found and this session fixed one issue before landing: the new
`openapi_version:`/`spectral_ruleset_id:` additive cue in
`interface-spec-gate/hooks/gate.sh` accepted a placeholder value (e.g.
`openapi_version: not_specified`) as satisfying the cue, contradicting
the gate's own stated "no N/A form accepted" rule. Fixed by excluding a
placeholder-value set (`n/a`, `tbd`, `none`, `null`, `unspecified`,
`not_specified`, `unknown`) from the cue regex via a negative lookahead;
regression cases 25-26 added to
`tests/api-design/interface-spec-gate.sh` (26/26 pass after the fix). See
`docs/reports/2026-08-09-hunt-api-design-issue-17.md` for the hunter's
full finding.

## closed_checks

- check: interface-spec-gate.sh full suite (26 cases, incl. hunt-finding regression) — code_sha 7b25e9c9caaae47ecd79c359668e5a79e6492048
- check: resource-model-gate.sh full suite (22 cases) — code_sha 7b25e9c9caaae47ecd79c359668e5a79e6492048
- check: adr-section-gate.sh, deprecation-plan-gate.sh, evidence-citation-gate.sh, versioning-strategy-gate.sh regression run — code_sha 7b25e9c9caaae47ecd79c359668e5a79e6492048
- check: warrant-hunt before-landing, stance 0 — code_sha 7b25e9c9caaae47ecd79c359668e5a79e6492048
