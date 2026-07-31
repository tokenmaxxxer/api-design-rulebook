# Issue #7 — Phase 1 Proposal: Mechanical Enforcement for the api-design Methodology

Status: **PROPOSAL ONLY — phase 1.** No rulebook content, hook, or
test file is changed by this document. Execution (phase 2) requires an
Approve from a login in `docs/specs/approvers.md`, or (single-account
mode) an issue comment "APPROVE issue-7/api-design", per contract v3
s19. This document does not itself constitute or contain that approval.
No executable script, plugin manifest, or test file is created as part
of this proposal — every plugin described below is a design, not an
implementation, per issue #7's explicit phase-1-only scope.

Basis: `docs/issue-7/reports/api-design/survey.md` (current-state gaps
— zero `PreToolUse` hooks exist for this role today);
`docs/issue-7/reports/api-design/scout-brief.md` (pricing-rulebook's
`methodology-gate.sh` as the locally available concrete pattern for a
rulebook-plugin methodology gate, `implementation-rulebook` not being
checked out in this workspace); and the approver's revision-request
comment on this branch's PR (#8), which superseded this document's
initial single-gate draft with an explicit requirement for a **plugin
set**, restated verbatim here so the requirement is traceable:

> FEEDBACK (승인자 전달): 이슈 #7의 '요구 정정' 코멘트 구조로 재작업 필요 —
> 단일 게이트/디렉티브 심화가 아니라 **플러그인 세트**: 방법론 1개 = 독립
> 플러그인 1개(freelunch 완성도, 룰북당 여러 개), 기획서·산출물 규범 각각을
> 플러그인 조합으로, proposal에 플러그인 목록(이름·담당 방법론·구성요소·조합
> 관계) 필수. 이 브랜치에 이어서 proposal을 개정하라.

This revision restructures the earlier single-`methodology-gate.sh`
draft into the required plugin set. Every technical fact the earlier
draft established (fail-closed design, path-regex scoping, three-tier
root detection, resulting-content reconstruction, all-missing-at-once
deny messages) is preserved — only the *unit of packaging* changes:
from one bundled gate covering two methodologies, to one independent,
complete plugin per methodology, composed together where a norm spans
more than one methodology.

## Context

Issue #1 adopted **two distinct methodologies** for this role, not one:

- **(a) an ADR-shaped proposal norm** for phase 1 (context / decision /
  alternatives considered / rationale / consequences), plus a
  free-standing **evidence-citation discipline** ("every claim of
  'this is standard practice' must name the source") stated inside
  that same document but analytically separable from the ADR shape
  itself — an ADR can have five well-formed sections that still assert
  unsourced "this is standard" claims, and an evidence check can be
  run independently of section-shape checking.
- **(b) an API-First / spec-as-artifact deliverable norm** for phase 2,
  itself a bundle of four independently statable facets
  (interface-spec, resource-model, versioning-strategy,
  deprecation-plan).

Both norms were reflected into the plugin only as a one-line
`PRODUCES` string inside `directive.sh`'s printed text, plus prose
docs. Nothing checks that a proposal or record actually contains what
either norm requires; enforcement today is entirely a human PR-review
judgment call.

This proposal's first draft closed that gap with a *single* role-local
`PreToolUse` gate script bundling every check for both methodologies
together, following pricing-rulebook's `methodology-gate.sh` shape.
The approver's feedback (quoted above) rejected that packaging: a
single bundled gate conflates methodologies that are logically
independent (an author could satisfy the ADR shape while never having
adopted evidence-citation discipline, or could satisfy interface-spec
while never having stated a deprecation-plan), makes each methodology
un-reusable by any other role or future rulebook that adopts only one
of them, and produces one large "freelunch"-style deny surface instead
of a set of small, independently versionable, independently
switchable-off plugins — the pattern this monorepo's plugin
marketplace (`.claude-plugin/marketplace.json`) is built around: each
entry is one complete, independently listed plugin, and a rulebook is
free to register several.

## Decision

**Adopt a plugin set of six independent, complete plugins — one per
methodology — composed into the two adopted norms, rather than one
bundled gate.** Each plugin below is a *complete* plugin in the sense
this repo's marketplace already requires of `api-design` itself: its
own `.claude-plugin/plugin.json`, its own `hooks/hooks.json`, its own
gate script under its own `hooks/` directory, and its own marketplace
entry — not a shared script with an internal if/else per methodology,
and not a partial stub that free-rides on another plugin's
registration. ("Freelunch completeness": a plugin that only half-works
without another plugin silently covering its gaps is not an
independent plugin; every plugin below must fail closed and produce a
correct, self-contained deny/allow decision using only its own scope,
even if every sibling plugin were absent.)

None of these six plugins is implemented, registered, or added to
`.claude-plugin/marketplace.json` by this document — phase 1 is design
only, per contract v3 s19.

### Methodology → plugin mapping (1 methodology = 1 plugin)

1. **`adr-section-gate`** — methodology: ADR shape (context / decision
   / alternatives considered / rationale / consequences). Gates phase-1
   proposal writes only.
2. **`evidence-citation-gate`** — methodology: evidence-citation
   discipline (every "this is standard practice" claim must name a
   source: an org guideline, an RFC number, a prior-art API). Gates
   phase-1 proposal writes only, independently of section-shape.
3. **`interface-spec-gate`** — methodology: machine-readable
   spec-as-artifact requirement (interface-spec facet of the API-First
   deliverable norm). Gates phase-2 record writes only.
4. **`resource-model-gate`** — methodology: resource/naming-model
   statement requirement (resource-model facet). Gates phase-2 record
   writes only.
5. **`versioning-strategy-gate`** — methodology: versioning-mechanism
   statement + justification requirement (versioning-strategy facet).
   Gates phase-2 record writes only.
6. **`deprecation-plan-gate`** — methodology: deprecation/migration
   statement requirement (deprecation-plan facet). Gates phase-2
   record writes only.

Each of the four phase-2 plugins (3–6) checks exactly one PRODUCES
facet and nothing else — deliberately, so that a future rulebook or
role which adopts, say, only a versioning-strategy discipline (without
committing to the full API-First bundle) can install
`versioning-strategy-gate` alone. Splitting the four-facet deliverable
norm at facet granularity, rather than packaging all four into one
"API-First plugin," is what makes "1 methodology = 1 independent
plugin" true at the level the approver's feedback specified rather
than at the coarser level of "1 *adopted norm* = 1 plugin" (which is
what the rejected first draft effectively did for phase 2, and what a
single `api-design-methodology-gate` would still do even split from
phase 1).

### Norm-to-plugin composition (기획서·산출물 규범 = 플러그인 조합)

Neither of issue #1's two adopted norms maps to a single plugin. Each
is a **composition**:

- **기획서 (planning-doc) norm = phase-1 ADR proposal norm** is the
  composition **`adr-section-gate` + `evidence-citation-gate`**. Both
  plugins gate the same write surface
  (`docs/issue-<n>/proposals/*api-design*.md`) independently; a
  proposal write must pass *both* plugins' `PreToolUse` checks (each
  registered separately in `hooks.json`, both firing on the same
  matcher) to be accepted. Composition semantics: **AND** — passing
  one does not exempt a write from the other, and either plugin may be
  disabled independently (its own kill-switch env var) without
  disabling the other, unlike a single bundled script where disabling
  the gate disables all checks at once.
- **산출물 (deliverable) norm = phase-2 API-First deliverable norm** is
  the composition **`interface-spec-gate` + `resource-model-gate` +
  `versioning-strategy-gate` + `deprecation-plan-gate`**. All four gate
  the same write surface (`docs/issue-<n>/reports/api-design.md`)
  independently; a record write must pass all four to be accepted.
  Composition semantics: **AND**, same reasoning as above — each facet
  plugin is independently switchable and independently reusable by any
  other role that adopts only a subset of the API-First bundle.

This composition relationship (which plugins combine, over which write
surface, under what combining rule) is exactly the information the
approver's feedback required the required plugin list to carry; see
"Plugin List," below, which restates it in tabular form as the single
required-deliverable inventory.

## Plugin List (required deliverable of this proposal)

| # | Plugin name | Methodology it enforces | Components (what it checks) | Composed into (norm, combining rule, write surface) |
|---|---|---|---|---|
| 1 | `adr-section-gate` | ADR shape (issue #1 phase-1 proposal norm) | Presence + non-empty body of all 5 ADR headings: context, decision, alternatives considered, rationale, consequences | 기획서 norm — AND with #2 — `docs/issue-<n>/proposals/*api-design*.md` |
| 2 | `evidence-citation-gate` | Evidence-citation discipline (issue #1 phase-1 proposal norm) | Any sentence matching a "standard/common/established practice" claim pattern must be accompanied by a named source token (guideline name, RFC number, or named prior-art API) within the same paragraph | 기획서 norm — AND with #1 — `docs/issue-<n>/proposals/*api-design*.md` |
| 3 | `interface-spec-gate` | Spec-as-artifact / API-First, interface-spec facet (issue #1 phase-2 deliverable norm) | `interface-spec` label present + a machine-readable-format cue nearby (openapi, asyncapi, protobuf, grpc, idl); no N/A form accepted | 산출물 norm — AND with #4, #5, #6 — `docs/issue-<n>/reports/api-design.md` |
| 4 | `resource-model-gate` | Spec-as-artifact / API-First, resource-model facet | `resource-model` label present with non-empty stated hierarchy/naming convention | 산출물 norm — AND with #3, #5, #6 — `docs/issue-<n>/reports/api-design.md` |
| 5 | `versioning-strategy-gate` | Spec-as-artifact / API-First, versioning-strategy facet | `versioning-strategy` label present; accepts a named mechanism + justification, or the explicit value "none — pre-v1" | 산출물 norm — AND with #3, #4, #6 — `docs/issue-<n>/reports/api-design.md` |
| 6 | `deprecation-plan-gate` | Spec-as-artifact / API-First, deprecation-plan facet | `deprecation-plan` label present; accepts a concrete window + migration path, or the explicit value "N/A — net new, nothing deprecated" | 산출물 norm — AND with #3, #4, #5 — `docs/issue-<n>/reports/api-design.md` |

Every row is required; none of the six plugins is optional to the
proposal (though each is independently switchable at runtime via its
own kill switch, per plugin, once phase 2 implements it). This table
is the canonical plugin inventory for this rulebook going forward —
any future issue proposing a seventh api-design plugin must add a row
here (or its phase-2 successor document) rather than silently
expanding an existing plugin's scope, which is exactly the packaging
mistake ("bundle another methodology into an existing gate") this
revision was requested to undo.

## Deepened directive text — per facet (unchanged content, now attributed to owning plugin)

The facet-level steps/criteria/prohibitions below are unchanged from
this proposal's first draft; they are restated here attributed to the
plugin that now owns each check, so the directive-deepening work
already done is not lost in the restructuring — only its packaging
changes.

### Phase 1 (owned by `adr-section-gate` + `evidence-citation-gate`)

**Whole-document prohibition (`adr-section-gate`):** a proposal must
not omit any of the five ADR sections (context, decision, alternatives
considered, rationale, consequences) inherited from issue #1's proposal
norm, and none may be a bare heading with no non-empty body.

**Evidence discipline (`evidence-citation-gate`):** every claim that a
decision follows "standard," "common," or "established" practice must
name the source (an org's published guideline, an RFC number, a
prior-art API) in the same paragraph — a bare assertion of
conventionality is rejected regardless of which ADR section it appears
in. This is a plugin distinct from `adr-section-gate` precisely because
it is a content-quality check orthogonal to section presence: a
proposal can have all five sections present and non-empty and still
fail this check if any of those sections asserts unsourced
conventionality.

**interface-spec** (owned by `interface-spec-gate`, applies at phase-1
proposal-commitment time via the Decision section, enforced mechanically
at phase-2 record time)
- Step: name the concrete artifact format the phase-2 record will
  produce (e.g. "OpenAPI 3.1 document", "protobuf/gRPC IDL", "AsyncAPI
  document for the event surface") in the phase-1 Decision section —
  a facet cannot be left "TBD" at proposal time even though the
  artifact itself doesn't exist yet.
- Judgment criterion: the named format must be machine-readable and
  lintable/diffable by tooling; "we'll write prose documentation of the
  endpoints" does not satisfy this facet regardless of detail.
- Prohibition: do not defer the format choice to phase 2 as an open
  question.

**resource-model** (owned by `resource-model-gate`)
- Step: state the resource hierarchy and naming convention
  (nouns-not-verbs, collection/item structure, or a named house style)
  in the Decision section.
- Judgment criterion: "follows `<X>` convention" is acceptable only
  when `<X>` is a real, locatable house style.
- Prohibition: do not leave resource naming to phase-2 ad hoc decision.

**versioning-strategy** (owned by `versioning-strategy-gate`)
- Step: state, in Decision or Consequences, which versioning mechanism
  (path, header, query param, or "none — pre-v1") and why.
- Judgment criterion: "why" must name a consumer-facing consequence,
  not restate the mechanism's name.
- Prohibition: never silently omit — "none — pre-v1" must be stated
  explicitly, not left untouched.

**deprecation-plan** (owned by `deprecation-plan-gate`)
- Step: state, in Consequences, a concrete notice-window +
  migration-path commitment, or "N/A — net new, nothing deprecated".
- Judgment criterion: a stated window must be a concrete duration; a
  migration path must name what consumers do.
- Prohibition: do not reuse boilerplate deprecation prose unadapted to
  the actual surface (a gate can check presence, not honesty — a
  human-review responsibility the plugin cannot substitute for).

### Phase 2 (owned by the four facet plugins, each checking its own record-time delivery)

**interface-spec** (`interface-spec-gate`)
- Step: attach or embed the actual machine-readable document (or an
  in-repo path to it) matching the phase-1-committed format.
- Judgment criterion: the artifact must be syntactically valid in its
  claimed format; the gate checks *presence of the artifact reference
  and format label*, not deep schema validity (see Alternatives
  Considered on gate-scope limits).
- Prohibition: do not deliver a spec in a different format than the
  Approved proposal committed to without a new phase-1 cycle.

**resource-model** (`resource-model-gate`)
- Step: state the final resource hierarchy actually implemented,
  including deviations from phase 1 and why.
- Judgment criterion: deviations must be justified in the record
  itself, not silently introduced.
- Prohibition: do not leave this facet as a bare cross-reference to
  phase 1 with no restatement — the record must be self-contained.

**versioning-strategy** (`versioning-strategy-gate`)
- Step: confirm the mechanism actually shipped matches (or explicitly
  updates) the phase-1 commitment.
- Judgment criterion: same test as phase 1, restated for the as-built
  surface.
- Prohibition: do not state a mechanism not visible/derivable from the
  interface-spec artifact where feasible.

**deprecation-plan** (`deprecation-plan-gate`)
- Step: restate the concrete window and migration path (or confirm
  "N/A — net new"), and confirm the migration path is reflected in the
  interface-spec artifact where applicable.
- Judgment criterion: as phase 1, plus consistency with the attached
  spec artifact.
- Prohibition: do not deliver a record whose deprecation-plan
  contradicts what the attached spec artifact encodes.

## Alternatives considered

1. **No gate — keep enforcement entirely at PR review.** Rejected:
   status quo issue #7 was opened to move past; pricing-rulebook
   already demonstrates a role-local gate is buildable without core.
2. **Wait for a core-provided generic required-fields gate.** Rejected
   for the same reason pricing-rulebook didn't wait: core issue #66's
   `record-fields-gate.sh` checks only generic contract §20 sections,
   not role-specific fields.
3. **A single bundled gate script covering both methodologies**
   (this proposal's own first draft). Rejected per the approver's
   explicit feedback on this branch's PR: a single script conflates two
   logically independent methodologies (ADR shape and evidence
   discipline; and, within the deliverable norm, four independently
   statable facets), cannot be partially adopted by a future role or
   rulebook that wants only one of the checks, and does not produce
   the "plugin list" inventory the feedback required as a deliverable.
   Splitting at methodology (and, within the deliverable bundle, at
   facet) granularity is what "1 methodology = 1 independent plugin"
   requires; a single script split only "by phase" (one script, two
   `if` branches for phase 1 vs phase 2) would still fail this bar.
4. **One plugin per adopted norm (two plugins total: one for the ADR
   proposal norm, one for the API-First deliverable norm), rather than
   six.** Considered as a middle ground and rejected: it would still
   bundle the evidence-citation discipline inside the ADR-shape plugin
   (two methodologies, one plugin) and all four API-First facets
   inside one deliverable plugin (four methodologies, one plugin) —
   the same packaging mistake alternative #3 makes, only one level
   coarser. The plugin list in this document is written at the
   granularity where each row is a single, independently
   describable methodology; two rows would each still describe two-plus
   methodologies bundled together.
5. **A gate that deep-validates spec correctness** (e.g. actually
   parsing the attached OpenAPI document with a schema validator).
   Rejected for this proposal: would require vendoring/invoking an
   OpenAPI-parsing dependency inside a `PreToolUse` hook, a materially
   larger surface than pricing-rulebook's own text/keyword-presence
   gate. Left as a possible future `interface-spec-gate` enhancement
   (its own phase-1 cycle), not part of this proposal.
6. **A cross-file ordering/state-tracking mechanism** (survey done →
   scout done → proposal drafted). Rejected: per the scout-brief's
   analysis, every required element for a given gated write lives
   inside the single file being written (all ADR content in one
   proposal doc; all facet content in one record doc). The actual
   process ordering (survey → proposal → Approve → record) is already
   enforced by the PR/Approve mechanism, contract v3 s19; duplicating
   it as file-based state inside any of the six plugins would add
   surface, not enforcement.
7. **A checklist/agent file for a repeated procedure.** Considered and
   rejected as unnecessary for this iteration: none of the six
   methodologies decomposes into a *multi-step operational procedure* a
   human or agent repeats across invocations distinct from "state this
   one fact in this one section," which is exactly what each plugin's
   gate already checks. If a future phase-2 execution surfaces a
   genuinely repeated multi-step judgment call (e.g. "how to choose
   between OpenAPI and AsyncAPI for a given surface"), that would
   warrant a checklist file at that time; nothing today calls for one.

## Rationale

- **Six independent plugins, not one bundled gate, because the
  approver's feedback specified methodology-granularity packaging.**
  A single script with internal branching by phase or by facet is
  observationally different from six separately registered,
  separately switchable plugins only in packaging — but packaging is
  exactly what was flagged, because packaging determines reusability
  (can a future role adopt evidence-citation discipline without also
  adopting the ADR shape?), independent kill-switching (can one facet
  check be disabled during incident response without disabling all
  six?), and the presence of a genuine plugin-list deliverable (a table
  over one script's internal `if` branches is not the same artifact as
  a table over six actually-separate plugin manifests).
- **Facet-level splitting for the deliverable norm, not norm-level
  splitting.** The API-First deliverable norm bundles four
  independently statable facets (per issue #1's own text, which lists
  them as four separately numbered required components). Treating
  "API-First" as one methodology (and thus one plugin) would satisfy a
  coarse reading of "1 methodology = 1 plugin" while still bundling
  four checks a future role might want independently — see
  Alternatives Considered #4.
- **AND composition, not OR or priority-ordered composition, for both
  norms.** Both adopted norms require *all* their constituent facets to
  be present simultaneously (issue #1's text: "all four, per
  scout-brief's converged must-bes"; "must not omit any of the five ADR
  sections") — there is no norm-sanctioned case where satisfying a
  subset suffices, so AND is the composition rule the norms themselves
  dictate, not an arbitrary design choice.
- **Gate design mirrors pricing-rulebook, adapted, not copied,
  per plugin.** Per `docs/handbooks/canon-scripts.md`'s canon-scripts
  norm (canon scripts are referenced, never copied) and the
  scout-brief's finding that pricing-rulebook's script is a *pattern*,
  each of the six plugins' gate scripts, if implemented in phase 2,
  independently follows the same structural pattern (PreToolUse +
  Write|Edit|MultiEdit, fail-closed, path-regex scoping,
  resulting-content reconstruction, single-methodology deny messages)
  adapted to that plugin's own narrow check — none is a shared script
  invoked six times with different arguments, and none is a copy of
  pricing's file.
- **"Freelunch completeness" as a design constraint, not a metaphor.**
  Each of the six plugins must be independently complete (own
  `plugin.json`, own `hooks.json`, own gate script, own marketplace
  entry) so that any one of them functions correctly in isolation —
  no plugin in this set may rely on another plugin in the set being
  installed in order to fail closed correctly, matching how this
  repo's existing `api-design` plugin entry in `marketplace.json` is
  itself a complete, standalone entry rather than a fragment of a
  larger bundle.
- **No ordering/state file, no checklist/agent file, deep-validation
  deferred.** Same reasoning as the first draft's Alternatives
  Considered #4/#5 (renumbered #6/#7 above and #5 above); restructuring
  into six plugins does not change any of these three prior
  conclusions, since each plugin still checks content living entirely
  inside the single file it gates.

## Consequences

**Easier:** each of the six methodologies this rulebook has adopted
(ADR shape, evidence-citation discipline, and the four API-First
facets) is independently, mechanically enforced, and independently
reusable by any future role or rulebook that wants only a subset —
closing both issue #1 phase 2's original deferral ("enforcement...
stays a PR review responsibility") and the packaging gap the
approver's feedback identified in this proposal's first draft.

**Harder:** authors of this role's proposals/records must satisfy up
to six separate `PreToolUse` hooks (two on phase-1 proposal writes,
four on phase-2 record writes) instead of one, and maintaining the
rulebook now means maintaining six plugin manifests instead of one —
a real per-plugin maintenance cost accepted deliberately in exchange
for independent reusability and independent switchability, per the
approver's explicit request for this packaging.

**Versioning/deprecation for this proposal's mechanism itself:** all
six plugins are net-new — no prior api-design gate of any kind exists
to deprecate or migrate away from (per survey.md's finding of zero
`PreToolUse` hooks today). N/A — net new, nothing deprecated, for the
plugin set as a whole.

**Preserving `WRITE_SCOPE: []`:** none of the six plugins adds, widens,
or in any way redesigns this role's write scope. Every plugin's gate is
a *read-and-deny* mechanism only — it inspects tool-call payloads and
either allows (exit 0) or denies (exit 2) a write; none grants this
role permission to write anywhere it couldn't already attempt to
write. Each plugin's own path-regex scoping (limiting *which paths that
plugin even evaluates*) is not a grant of write access to those paths —
collectively the six plugins' scopes are still strictly narrower than
the role's existing permission surface, and the role's actual write
permissions (report-only, no code/doc write outside
`docs/issue-<n>/reports/api-design.md`,
`docs/issue-<n>/reports/api-design/`, and
`docs/issue-<n>/proposals/api-design.md`) remain exactly as they are.
Any future proposal to add a *separate* `WRITE_SCOPE`-enforcing plugin
is out of scope for this document and would need its own phase-1
cycle.

## Plugin designs (phase-2 execution only — not implemented in this proposal)

Each plugin below is designed to be a complete, independent
`.claude-plugin` entry: its own `plugin.json`, its own
`hooks/hooks.json` registering a `PreToolUse` hook on matcher
`Write|Edit|MultiEdit` pointed at its own gate script, plus (for the
two phase-1 plugins) contributing to the same `SessionStart` →
`directive.sh` deepening described above. None of these files, scripts,
or `marketplace.json` entries is created by this proposal.

Common shell-logic shape, shared by design-pattern (not by shared
script) across all six plugins, following pricing-rulebook's
`methodology-gate.sh` (read, not sourced or copied) per
`docs/handbooks/canon-scripts.md`'s canon-scripts norm:

```bash
#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — single-methodology,
# single-plugin. Pattern follows pricing-rulebook's own
# pricing/hooks/methodology-gate.sh (read, not sourced or copied).
#
# Kill switch (per plugin): export <PLUGIN>_GATE_OFF=1
set -uo pipefail
trap '__fc' EXIT
__fc(){ rc=$?; [ "$rc" != 0 ] && [ "$rc" != 2 ] && { echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; }; }
deny(){ echo "<plugin-name>: refused — $1" >&2; exit 2; }

# ... resolve project root via CLAUDE_PROJECT_DIR -> git rev-parse
#     --show-toplevel from target dir -> git rev-parse from cwd
#     (three-tier fallback, as pricing-rulebook's gate does).
# ... match tool_input.file_path against this plugin's own single
#     path-regex scope; exit 0 (not this plugin's business) on no match.
# ... reconstruct resulting content for Write/Edit/MultiEdit, denying
#     if it cannot be determined (non-matching old_string, etc).
# ... check this plugin's own single methodology's required element(s)
#     only; deny naming exactly what is missing if any; exit 0 otherwise.
```

Per-plugin specifics:

1. **`adr-section-gate`** — scope regex
   `^docs/issue-[0-9]+/proposals/.*api-design.*\.md$`. Checks: all five
   ADR headings present, each with non-empty body.
2. **`evidence-citation-gate`** — same scope regex as #1, registered
   independently. Checks: every paragraph matching a
   standard/common/established-practice claim pattern names a source
   token in the same paragraph.
3. **`interface-spec-gate`** — scope regex
   `^docs/issue-[0-9]+/reports/api-design\.md$`. Checks: `interface-spec`
   label present + machine-readable-format cue nearby (openapi,
   asyncapi, protobuf, grpc, idl); no N/A form accepted for this facet.
4. **`resource-model-gate`** — same scope regex as #3, registered
   independently. Checks: `resource-model` label present with
   non-empty hierarchy/naming statement.
5. **`versioning-strategy-gate`** — same scope regex as #3, registered
   independently. Checks: `versioning-strategy` label present; accepts
   a named mechanism + justification, or "none — pre-v1".
6. **`deprecation-plan-gate`** — same scope regex as #3, registered
   independently. Checks: `deprecation-plan` label present; accepts a
   concrete window + migration path, or "N/A — net new, nothing
   deprecated".

Design notes carried over from the scout-brief's must-bes, applying to
every one of the six plugins independently: fail-closed on any
parse/internal error; three-tier root detection; resulting-content
reconstruction for Edit/MultiEdit rather than checking only diff
fields; deny messages naming exactly the missing element(s) for that
plugin's own single methodology; path-regex scoping so each plugin
never fires on writes outside its own narrow surface.

## Gate test design (phase-2 execution only — no test files created by this proposal)

Intended location: `tests/api-design/<plugin-name>.bats` (bats-style,
matching the `.sh`/bats convention visible in core's own
`core/hooks/tests/stub-check.sh` naming; exact framework choice is a
phase-2 detail, not committed to here) — **one test file per plugin**,
matching the one-plugin-per-methodology packaging, rather than one
shared test file exercising all six.

Common pattern, instantiated per plugin with that plugin's own
required element(s) substituted in:

**Pass cases** (per plugin)
1. A `Write` to that plugin's write surface whose content contains
   that plugin's required element(s) with non-empty/satisfying values
   (including "none — pre-v1" / "N/A — net new" for the plugins that
   accept those forms) → gate exits 0.
2. A `Write` to an unrelated path → gate exits 0 without evaluating
   content (path-regex miss).
3. An `Edit` whose `old_string` matches on-disk content and whose
   reconstructed resulting text still satisfies the plugin's check →
   gate exits 0.
4. That plugin's own kill-switch env var set → gate exits 0 regardless
   of content.

**Reject cases** (per plugin)
5. A `Write` to that plugin's write surface missing its required
   element entirely → gate exits 2, deny message names that element.
6. (`adr-section-gate`, `interface-spec-gate` only, where a "heading
   present but empty" failure mode is meaningful) A `Write` where the
   required heading/label is present but immediately followed by
   another heading or EOF (empty body) → gate exits 2.
7. An `Edit` whose `old_string` does not match current on-disk content
   for a file matching that plugin's own regex → gate exits 2 with a
   "cannot determine resulting content" message.
8. A malformed/non-JSON stdin payload for a matched path → gate exits
   2 (fail-closed on unparseable payload).
9. A `Write` whose target path resolves outside the git-detected
   project root → gate must not evaluate it as if it were repo-relative;
   exits 0 only if genuinely outside root.

**Cross-plugin composition case** (one shared test, not per-plugin,
verifying the AND composition described under "Norm-to-plugin
composition"):
10. A `Write` to `docs/issue-<n>/proposals/*api-design*.md` that
    satisfies `adr-section-gate`'s check but fails
    `evidence-citation-gate`'s check (all five ADR headings present and
    non-empty, but a "this is standard practice" claim with no named
    source) → `adr-section-gate` exits 0 and `evidence-citation-gate`
    exits 2 independently; the overall write is denied because both
    hooks fire on the same matcher and either one denying blocks the
    tool call, confirming the two plugins genuinely combine by AND
    rather than one plugin's pass silently covering the other's gap.

Each reject case's assertion is: exit code 2, and stderr contains the
name of the specific missing/ambiguous element for that plugin's own
methodology — matching pricing-rulebook's practice of naming the
deficiency so an author can fix it without re-reading the whole norm
document.

## Checklist/agent file

None proposed, for any of the six plugins. Per Alternatives Considered
#7, none of the six methodologies decomposes into a repeated
multi-step operational procedure separate from what that plugin's own
gate already mechanizes. If phase-2 execution or later usage surfaces
a genuine repeated judgment procedure (e.g. choosing among
interface-spec formats for different surface types), a checklist can
be proposed at that time through its own phase-1 cycle; none is
warranted now for any plugin in this set.

## `WRITE_SCOPE: []` and canon-scripts invariants (explicit statement)

- This proposal does not modify, widen, or redesign this role's
  `WRITE_SCOPE: []`, for any of the six plugins individually or the set
  collectively. Each plugin's gate is scoped, by design, to only ever
  evaluate writes to paths already inside this role's existing allowed
  record/proposal homes (`docs/issue-<n>/reports/api-design.md`,
  `docs/issue-<n>/reports/api-design/`, and
  `docs/issue-<n>/proposals/api-design.md`); each exits 0 (no opinion)
  on anything else, which is a narrower, not broader, surface than
  today's status quo of no gate at all — and six narrowly-scoped
  plugins do not, in aggregate, cover any path outside that same set of
  surfaces.
- Per `docs/handbooks/canon-scripts.md`, this proposal references (by
  path, in survey.md/scout-brief.md/this document) `core/hooks/lib/
  role-directive.sh` and pricing-rulebook's `methodology-gate.sh` as
  design pattern sources, and copies neither into any of the six
  plugins under `api-design/`. Every gate script this proposal designs,
  if approved, will be an independently authored file specific to its
  own plugin, not a sourced or vendored copy of any other plugin's
  script, and not a single shared script invoked by six different
  plugin manifests.
- Marketplace registration (`.claude-plugin/marketplace.json`): if
  phase 2 implements this plugin set, each of the six plugins is
  intended to be registered as its own entry in `marketplace.json`
  (name, source path under `api-design/plugins/<plugin-name>/` or
  equivalent, one-line description naming the single methodology it
  enforces) — mirroring how the existing `api-design` entry is itself
  one complete, independently listed plugin. This document does not
  add any such entries; it records the intended registration shape so
  a phase-2 implementer does not need to re-derive it.
