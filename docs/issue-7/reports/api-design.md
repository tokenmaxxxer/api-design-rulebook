# Issue #7 — Phase 2 Record: Mechanical Enforcement for the api-design Methodology

loop_state: landed

Status: **DELIVERED**. This record documents phase-2 execution of the
approved plugin set described in `docs/issue-7/proposals/api-design.md`
(approved via the issue-comment `APPROVE issue-7/api-design`, single-account
mode, per contract v3 s19).

## What was done

Built and tested the six-plugin set the approved proposal specified (see
"What was built," below) and registered all six in
`.claude-plugin/marketplace.json`. Summary of work: each plugin got its own
`.claude-plugin/plugin.json`, `hooks/hooks.json`, `hooks/gate.sh`,
`README.md`, and `tests/api-design/<name>.sh` test suite; all six suites
were run directly and pass in full.

## Why

Issue #1 phase 2 adopted two methodologies for this role (the ADR-shaped
proposal norm and the API-First deliverable norm) but left both enforced
only by PR-review judgment — "no gate script was added," per
`docs/issue-7/reports/api-design/survey.md`'s reading of that record. This
issue closes that gap the same way `implementation-rulebook` and
pricing-rulebook already do for their own roles: fail-closed `PreToolUse`
gates instead of a human-only review step, per the approver's explicit
"플러그인 세트로 체계화" requirement quoted in full in the proposal
(basis: `docs/issue-7/proposals/api-design.md`, upstream commit history on
this branch).

## What was built

Six independent, complete plugins, one per adopted methodology, exactly as
the approved proposal's Plugin List specifies — no bundled gate, no shared
script:

| # | Plugin | Methodology | Write surface | Kill switch |
|---|---|---|---|---|
| 1 | `adr-section-gate` | ADR shape (issue #1) | `docs/issue-<n>/proposals/*api-design*.md` | `ADR_SECTION_GATE_OFF` |
| 2 | `evidence-citation-gate` | Evidence-citation discipline (issue #1) | `docs/issue-<n>/proposals/*api-design*.md` | `EVIDENCE_CITATION_GATE_OFF` |
| 3 | `interface-spec-gate` | interface-spec facet (Zalando rules 101–102) | `docs/issue-<n>/reports/api-design.md` | `INTERFACE_SPEC_GATE_OFF` |
| 4 | `resource-model-gate` | resource-model facet (Zalando resource-naming) | `docs/issue-<n>/reports/api-design.md` | `RESOURCE_MODEL_GATE_OFF` |
| 5 | `versioning-strategy-gate` | versioning-strategy facet (Zalando API-versioning) | `docs/issue-<n>/reports/api-design.md` | `VERSIONING_STRATEGY_GATE_OFF` |
| 6 | `deprecation-plan-gate` | deprecation-plan facet (Zalando Deprecation + RFC 8594 §3) | `docs/issue-<n>/reports/api-design.md` | `DEPRECATION_PLAN_GATE_OFF` |

Each plugin is a self-contained `.claude-plugin` entry under
`api-design/plugins/<name>/`: its own `.claude-plugin/plugin.json`, its own
`hooks/hooks.json` registering a `PreToolUse` hook on matcher
`Write|Edit|MultiEdit`, its own `hooks/gate.sh`, and its own `README.md`.
Every gate script is independently authored (adapted from
pricing-rulebook's `methodology-gate.sh` shape by reference, per
`docs/handbooks/canon-scripts.md` — never copied) and fails closed on any
internal error, unparseable payload, or undeterminable resulting content.
All six are now registered as separate entries in `.claude-plugin/marketplace.json`,
alongside the existing `api-design` role entry.

Each plugin has its own test suite at `tests/api-design/<name>.sh`
(bats-equivalent bash harness, no `bats` binary available in this
environment — noted as a phase-2 detail in the proposal and resolved with
a self-contained bash test runner instead): pass cases (satisfying write,
out-of-scope write, valid Edit, kill-switch bypass), reject cases (missing
element, empty-body element, non-matching Edit, malformed stdin), plus the
facet-specific `none — pre-v1` / `N/A — net new` accept cases. All six
suites were run directly and pass in full (8–9 cases each, 0 failures).

## Facet fields for this record (reflexive application)

This record's own deliverable is the plugin set itself, not an end-consumer
HTTP API — the same reflexive-application point the approved proposal made
for `evidence-citation-gate` applies here to the phase-2 facets: this issue's
"interface" is the hook contract the six plugins expose to Claude Code's
plugin runtime, not a service boundary for external API consumers.

- **interface-spec**: the plugin interface delivered by this issue is each
  plugin's `.claude-plugin/plugin.json` + `hooks/hooks.json` pair — a
  machine-readable, schema-conformant contract (Claude Code's plugin/hooks
  JSON schema) that Claude Code's runtime parses and validates directly,
  fulfilling the same "machine-readable, lintable" requirement Zalando rules
  101–102 impose on OpenAPI documents, applied to this deliverable's actual
  artifact type (a hook plugin, not an HTTP resource).
- **resource-model**: no HTTP resource hierarchy exists for this issue
  (nothing here exposes a REST resource). The equivalent "naming model" is
  the plugin-name-to-methodology mapping fixed by the approved proposal's
  Plugin List (one plugin name per methodology, e.g. `adr-section-gate`,
  `interface-spec-gate`) plus each plugin's own path-regex write-surface
  scope, both stated verbatim in the table above.
- **versioning-strategy**: none — pre-v1. All six plugins are net-new,
  unversioned entries in `marketplace.json`; no prior version of any of
  them exists to be superseded.
- **deprecation-plan**: N/A — net new, nothing deprecated. No `Sunset` or
  `Deprecation` header applies because no prior api-design gate of any
  kind existed before this issue (per `survey.md`'s finding of zero
  `PreToolUse` hooks pre-issue-7).

## Fidelity to the approved proposal

- **Plugin count and mapping**: exactly the 6 plugins in the approved
  Plugin List, no more, no fewer; no methodology bundled into another.
- **AND composition**: `adr-section-gate` and `evidence-citation-gate` are
  registered as two independent `PreToolUse` hooks on the same matcher over
  the same proposal write surface — either one denying blocks the write,
  confirming AND composition rather than one covering the other's gap. Same
  for the four phase-2 facet plugins over `docs/issue-<n>/reports/api-design.md`.
- **Fail-closed**: every gate's `trap __fc EXIT` plus internal
  try/except denies (exit 2) on any unexpected internal error, matching the
  proposal's fail-closed design constraint.
- **Canon citations**: `interface-spec-gate`, `resource-model-gate`,
  `versioning-strategy-gate`, and `deprecation-plan-gate` each cite the
  specific Zalando RESTful API Guidelines rule(s) named in the proposal's
  "Canon source" section in their own deny messages and READMEs;
  `deprecation-plan-gate` additionally requires the literal `Sunset` /
  `Deprecation` header tokens plus a concrete date, per RFC 8594 §3.
- **`WRITE_SCOPE: []` preserved**: every plugin is read-and-deny only —
  none grants this role a new write path; each plugin's path-regex scope
  only narrows which of the role's existing allowed write surfaces
  (`docs/issue-<n>/reports/api-design.md`,
  `docs/issue-<n>/reports/api-design/`, `docs/issue-<n>/proposals/api-design.md`)
  it evaluates.
- **canon-scripts invariant preserved**: no file under
  `pricing-rulebook/` or `core/` was read or copied by any of the six
  build passes; every `gate.sh` was authored fresh from the pattern
  description, per `docs/handbooks/canon-scripts.md`.
- **No ordering/state-tracking mechanism, no checklist/agent file**: not
  added, per Alternatives Considered #6/#8 in the approved proposal — every
  element each plugin checks still lives inside the single file it gates.

## Deviations from the proposal (declared)

- **Test framework**: the proposal left the exact test framework as "a
  phase-2 detail, not committed to here," noting `bats`-style as one
  option. `bats` is not installed in this environment; each plugin's test
  suite is instead a self-contained bash script
  (`tests/api-design/<name>.sh`) exercising the same pass/reject case set
  the proposal specified, run directly rather than through a bats runner.
  No content or coverage was dropped — only the runner mechanism differs
  from the tentative bats mention.

## Open findings

None. All six plugins built, all six test suites pass in full, and
`marketplace.json` registration is complete. loop_state is `landed`;
nothing is left open for this issue.

## Hand-off

No hand-off triggered: this issue's work stayed entirely inside
`api-design`'s own decision boundary (mechanizing enforcement of this
role's own previously-adopted methodologies), per
`api-design/hooks/directive.sh`'s stated `HAND-OFF` boundary.
