# Issue #1 — Phase 2 Record (api-design)

loop_state: landed

## What was done

Executed the phase-1 proposal (`docs/issue-1/proposals/api-design.md`),
approved via issue comment `APPROVE issue-1/api-design` from `JiwonJung94`
(member, single-account mode).

1. **`directive.sh` PRODUCES line** — replaced the free-text `interface
   spec (endpoints/schema/versioning), lifecycle/deprecation plan` label
   with the proposal's four named required record fields:
   `interface-spec` (machine-readable, OpenAPI-class or protocol
   equivalent), `resource-model`, `versioning-strategy`,
   `deprecation-plan`. Added a note pointing phase-1 authors at the
   ADR-shaped proposal norm (context / decision / alternatives /
   rationale / consequences) from the same proposal document, stating
   explicitly that it is enforced by PR review at the Approve gate, not
   by this directive.
2. **Required-fields gate — resolved, not added.** The proposal left the
   gate's registration mechanism open pending core's actual interface
   (core wasn't checked out in the phase-1 workspace). Checked out at
   `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` for phase 2:
   `core/hooks/record-fields-gate.sh` is role-agnostic and checks only
   generic contract §20 sections (what-was-done / why / upstream-basis /
   loop_state / open-findings) against `docs/issue-<n>/reports/<role>.md`.
   It exposes no per-role `REQUIRED_FIELDS`-style config surface — same
   finding issue #2's phase-2 record made for the `implementation` role's
   gate. A role-specific field list (interface-spec/resource-model/
   versioning-strategy/deprecation-plan) therefore cannot be mechanically
   gated today; enforcement of *these four fields'* presence stays a PR
   review responsibility, same as the proposal norm's ADR sections. No
   gate script was added to this repo — adding one core doesn't support
   would be a vendored copy this rulebook's core-canon-reference
   conversion (issue #2/#4) already moved away from.
3. **Proposal-norm / deliverable-norm content** — no plugin change beyond
   (1); per the proposal's plan (d), the ADR proposal-norm constrains
   `docs/issue-<n>/proposals/api-design.md` content and is enforced by
   human PR review at the Approve gate, not by a directive-injected list.

## Why

Issue #1 asked phase 2 to reflect the approved norms into this
rulebook's plugin surface (directive / record fields / gates) while
keeping warrant-hunter as a core-canon reference (no copy) and preserving
the existing record-discipline strengthening — both honored: no new
vendored files were added, and the record fields got stricter (four named
fields instead of two prose labels), not looser.

## Upstream basis

- Issue #1 (this repo), approved via issue comment `APPROVE
  issue-1/api-design`.
- `docs/issue-1/proposals/api-design.md` (phase-1 proposal, commit
  c8109b0) and its basis documents
  `docs/issue-1/reports/api-design/{survey,scout-brief}.md`.
- Core canon, read directly from a local checkout at
  `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` (core issue #66):
  `core/hooks/record-fields-gate.sh`, `core/hooks/lib/role-directive.sh`,
  `core/hooks/tests/stub-check.sh`.

## Verification

- `bash -n api-design/hooks/directive.sh` — syntax OK.
- `bash <core-checkout>/core/hooks/tests/stub-check.sh api-design` — all
  checks pass, including "directive.sh is a role-directive stub".

## Open findings

None. The proposal's one open item (gate registration mechanism) was
resolved above (item 2) rather than left open: core provides no
role-specific required-fields config surface, so enforcement of the four
named fields stays a PR-review responsibility.
