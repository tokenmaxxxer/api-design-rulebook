# Issue #7 — Phase 1 Proposal: Mechanical Enforcement for the api-design Methodology

Status: **PROPOSAL ONLY — phase 1.** No rulebook content, hook, or
test file is changed by this document. Execution (phase 2) requires an
Approve from a login in `docs/specs/approvers.md`, or (single-account
mode) an issue comment "APPROVE issue-7/api-design", per contract v3
s19. This document does not itself constitute or contain that approval.
No executable script or test file is created as part of this proposal
— the gate, tests, and any checklist described below are designs, not
implementations, per issue #7's explicit phase-1-only scope.

Basis: `docs/issue-7/reports/api-design/survey.md` (current-state gaps
— zero `PreToolUse` hooks exist for this role today) and
`docs/issue-7/reports/api-design/scout-brief.md` (pricing-rulebook's
`methodology-gate.sh` as the locally available concrete pattern for a
rulebook-plugin methodology gate, `implementation-rulebook` not being
checked out in this workspace).

## Context

Issue #1 adopted a domain methodology for this role — an ADR-shaped
phase-1 proposal norm and an API-First/spec-as-artifact phase-2
deliverable norm with four named required record fields
(interface-spec, resource-model, versioning-strategy, deprecation-plan)
— but reflected it into the plugin only as a one-line `PRODUCES` string
inside `directive.sh`'s printed text, plus prose docs. Nothing checks
that a proposal or record actually contains what the norm requires;
enforcement today is entirely a human PR-review judgment call. Issue #7
asks this role to close that gap the way `pricing-rulebook` already
has: a `PreToolUse` gate script that mechanically validates the
required elements are present in the content being written, plus
concrete gate tests and (if warranted) a checklist for any repeated
procedure the methodology implies — while explicitly preserving this
role's `WRITE_SCOPE: []` report-only boundary, which the survey found
has itself never been mechanically enforced either.

## Decision

Adopt four coordinated deepenings, detailed below: (1) deepen the
directive text for both phases from a one-line summary into concrete
per-facet steps/criteria/prohibitions; (2) design (not implement) a
role-local `PreToolUse` gate, `api-design/hooks/methodology-gate.sh`,
following pricing-rulebook's pattern, that mechanically checks the four
PRODUCES fields on phase-2 record writes and the five ADR sections on
phase-1 proposal writes, scoped only to this role's two known write
surfaces; (3) design gate test cases under `tests/api-design/`; (4)
determine that no separate checklist/agent file is warranted, because
neither norm decomposes into a *repeated multi-step procedure* distinct
from the single gate check itself — reasoned below, not assumed.

### 1. Deepened directive text — phase 1 (proposal-time)

Per-facet steps, judgment criteria, and prohibitions for each of the
four PRODUCES facets, framed for what a *phase-1 proposal* must commit
to stating (not yet deliver) before Approve:

**interface-spec**
- Step: name the concrete artifact format the phase-2 record will
  produce (e.g. "OpenAPI 3.1 document", "protobuf/gRPC IDL", "AsyncAPI
  document for the event surface") — a facet cannot be left as "TBD" at
  proposal time even though the artifact itself doesn't exist yet.
- Judgment criterion: the named format must be machine-readable and
  lintable/diffable by tooling; a proposal that says "we'll write
  prose documentation of the endpoints" does not satisfy this facet
  regardless of how detailed the prose is.
- Prohibition: do not defer the format choice to phase 2 as an open
  question — the proposal's Decision section must commit to a format,
  because reviewers at the Approve gate need a concrete artifact shape
  to evaluate, not a placeholder.

**resource-model**
- Step: state the resource hierarchy and naming convention the
  decision will apply (nouns-not-verbs, collection/item structure, or
  an explicit named house style it follows) as part of the Decision
  section.
- Judgment criterion: "follows `<X>` convention" is acceptable only
  when `<X>` is a real, locatable house style (a doc, an existing API's
  pattern) — a bare "follows REST conventions" with no named referent
  does not satisfy this facet.
- Prohibition: do not leave resource naming to be decided ad hoc during
  phase-2 execution; a proposal whose Alternatives Considered section
  never touches resource shape at all has not actually proposed an
  interface shape, only a vague intent to build one.

**versioning-strategy**
- Step: state, in the Decision or Consequences section, which
  versioning mechanism this surface will use (path, header, query
  param, or "none — pre-v1") and why, referencing at least one
  alternative mechanism considered and rejected.
- Judgment criterion: "why" must name a consumer-facing consequence
  (e.g. cache-friendliness, client-library ergonomics) — not merely
  restate the mechanism's name as its own justification.
- Prohibition: never silently omit this facet on the theory that "it's
  obvious we won't version a pre-v1 API" — the proposal must say
  "none — pre-v1" explicitly rather than leave the topic untouched, per
  the existing PRODUCES text's own explicit-omission requirement.

**deprecation-plan**
- Step: state, in Consequences, either a concrete notice-window +
  migration-path commitment, or "N/A — net new, nothing deprecated"
  stated explicitly.
- Judgment criterion: a stated window must be a concrete duration (a
  number of days/weeks/months), not a vague "advance notice"; a stated
  migration path must name what consumers do (a replacement endpoint,
  a client-library major bump, a sunset header), not just "we'll
  communicate it."
- Prohibition: do not reuse a generic boilerplate deprecation sentence
  across proposals without adapting the window/path to the actual
  surface being proposed — a gate can check presence of the words, not
  whether the content is honest, so this prohibition is a human-review
  responsibility the gate cannot substitute for (see Alternatives
  Considered, below, on gate scope limits).

**Whole-document prohibition (phase 1):** a proposal must not omit any
of the five ADR sections (context, decision, alternatives considered,
rationale, consequences) inherited from issue #1's proposal norm — this
deepening does not replace that norm, it adds facet-level criteria
*within* the Decision/Consequences sections specifically for the four
PRODUCES facets.

### 2. Deepened directive text — phase 2 (record-time)

Per-facet steps, judgment criteria, and prohibitions for what the
*phase-2 record* must actually deliver, once Approved:

**interface-spec**
- Step: attach or embed the actual machine-readable document (or a
  path to it in-repo) matching the format committed to at phase 1 —
  not a restatement of the format name.
- Judgment criterion: the artifact must be syntactically valid in its
  claimed format (e.g. a document claiming to be OpenAPI 3.1 should
  parse as such) — the gate below checks *presence of the artifact
  reference and format label*, not deep schema validity, which is
  explicitly out of scope for a content-presence gate (see Alternatives
  Considered).
- Prohibition: do not deliver a spec in a different format than the
  one the Approved proposal committed to without a new phase-1 cycle;
  a format change is a methodology-relevant decision, not an
  implementation detail.

**resource-model**
- Step: state the final resource hierarchy actually implemented,
  including any deviations from the phase-1 Decision and why.
- Judgment criterion: deviations must be justified in the record itself
  (per this rulebook's existing evidence discipline), not silently
  introduced.
- Prohibition: do not leave this facet as a cross-reference back to the
  phase-1 proposal with no restatement — the record must be
  self-contained per contract v3's record-completeness expectation,
  even when the answer is unchanged from phase 1.

**versioning-strategy**
- Step: confirm the mechanism actually shipped matches (or explicitly
  updates) the phase-1 commitment.
- Judgment criterion: same test as phase 1 — a named mechanism plus a
  consumer-facing "why," restated for the as-built surface.
- Prohibition: do not state a versioning mechanism without it being
  visible/derivable from the interface-spec artifact itself (e.g. a
  path-based version segment claimed in prose but absent from the
  attached OpenAPI paths is a record defect the gate should catch as a
  cross-check where feasible, and human review must catch otherwise).

**deprecation-plan**
- Step: restate the concrete window and migration path (or confirm
  "N/A — net new"), and additionally confirm the migration path is
  reflected in the interface-spec artifact where applicable (e.g. a
  `Sunset` header or deprecated-flag in the schema).
- Judgment criterion: as phase 1, plus consistency with the attached
  spec artifact.
- Prohibition: do not deliver a record whose deprecation-plan
  contradicts what the attached spec artifact actually encodes.

**Whole-record prohibition (phase 2):** the record must not omit any of
the four PRODUCES fields as separate, labeled sections — a record that
buries "versioning: path-based" as an incidental clause inside prose
about something else does not satisfy this facet's presence
requirement, mechanically or otherwise.

## Alternatives considered

1. **No gate — keep enforcement entirely at PR review**, i.e. leave
   issue #1 phase 2's deferral in place indefinitely. Rejected: this is
   the status quo issue #7 was opened to move past, and pricing-rulebook
   already demonstrates a role-local gate is buildable without waiting
   on core to expose a generic mechanism (the exact blocker issue #1
   phase 2 cited).
2. **Wait for a core-provided generic required-fields gate** (as issue
   #1 phase 2 originally deferred to). Rejected for the same reason
   pricing-rulebook didn't wait: core issue #66's `record-fields-gate.sh`
   checks only generic contract §20 sections, not role-specific fields,
   and there is no indication a per-role config surface is imminent;
   pricing-rulebook's precedent shows a role-local script is the
   pattern this monorepo family has actually converged on for
   role-specific checks, not a hypothetical future core feature.
3. **A gate that deep-validates spec correctness** (e.g. actually
   parsing the attached OpenAPI document with a schema validator, not
   just checking a format label is present). Rejected for this
   proposal: it would require vendoring or invoking an OpenAPI-parsing
   dependency inside a Bash/Python `PreToolUse` hook, a materially
   larger and riskier surface than pricing-rulebook's own gate (which
   does pure text/keyword presence checks, not deep parsing of the
   pricing artifacts it gates). A field-presence gate mirroring
   pricing's granularity is the right scope for this iteration; deep
   spec linting is left as a possible future gate, not part of this
   proposal.
4. **A cross-file ordering/state-tracking mechanism** (e.g. a state
   file recording "survey done → scout done → proposal drafted" the
   way some maturation directives use). Rejected: per the scout-brief's
   analysis, this role's methodology — unlike, say, a multi-stage
   pipeline — has every required element for a given gated write living
   inside the *single file* being written (all five ADR sections in one
   proposal doc; all four PRODUCES fields in one record doc). There is
   no cross-file sequencing dependency for a role-local gate to
   enforce; the actual process ordering (survey → proposal → Approve →
   record) is already enforced by the PR/Approve mechanism contract v3
   s19 provides, and re-implementing that as file-based state inside
   this role's gate would duplicate, not add, enforcement.
5. **A checklist/agent file for a repeated procedure.** Considered and
   rejected as unnecessary for this iteration: neither the ADR-shape
   proposal norm nor the four-facet deliverable norm decomposes into a
   *multi-step operational procedure* a human or agent repeats across
   invocations distinct from "write the five sections" / "write the
   four fields" — which is exactly what the gate itself checks.
   Compare pricing-rulebook, whose six-element checklist (method,
   family, inputs, gate-check, labeled numbers, residual list) also has
   no separate checklist/agent file — the gate script *is* the
   checklist there too. If a future phase-2 execution surfaces a
   genuinely repeated multi-step judgment call (e.g. "how to choose
   between OpenAPI and AsyncAPI for a given surface" as a decision
   procedure, not just a presence check), that would warrant a
   checklist file at that time; nothing today calls for one.

## Rationale

- **Gate design mirrors pricing-rulebook, adapted, not copied.**
  Per `docs/handbooks/canon-scripts.md`'s canon-scripts norm (canon
  scripts are referenced, never copied) and the scout-brief's explicit
  finding that pricing-rulebook's script is a *pattern*, not a canon
  file to source: this proposal's gate is designed as an independent
  script that follows the same structural pattern (PreToolUse +
  Write|Edit|MultiEdit, fail-closed, path-regex scoping, resulting-content
  reconstruction, all-missing-at-once deny messages, three-tier root
  detection) adapted to api-design's own two write surfaces and its own
  nine required elements (five ADR sections + four PRODUCES fields,
  split by which surface is being written), not lifted verbatim.
- **No ordering/state file, because none is needed.** As argued in
  Alternatives Considered #4, this role's methodology has no genuine
  cross-file ordering dependency for a role-local gate to enforce;
  adding one would be gate surface without a defect it catches.
- **No checklist/agent file, because none is needed.** As argued in
  Alternatives Considered #5, the gate itself is the mechanized form of
  the only repeated procedure either norm implies.
- **Field-presence gate, not deep validation.** Matching
  pricing-rulebook's own scope (text/keyword presence, not deep parsing
  of the artifacts it gates) keeps the gate's blast radius and
  dependency footprint comparable to the one concrete exemplar
  available, rather than inventing a heavier mechanism this issue
  didn't ask for.

## Consequences

**Easier:** phase-1 proposals and phase-2 records for this role can no
longer silently omit any of the nine required elements (five ADR
sections, four PRODUCES fields) — a Write/Edit attempting to do so is
denied at tool-call time with a message naming exactly what's missing,
closing the gap issue #1 phase 2 explicitly left open ("enforcement...
stays a PR review responsibility").

**Harder:** authors of this role's proposals/records must satisfy the
gate's keyword/section-presence checks even when drafting incrementally
(e.g. via multiple small Edits) — per pricing-rulebook's own precedent,
an Edit/MultiEdit whose resulting content the gate cannot reconstruct
(non-matching `old_string`, etc.) is denied rather than silently passed,
which can be a minor friction cost during iterative drafting; this
mirrors a cost pricing-rulebook's authors already accept.

**Versioning/deprecation for this proposal's mechanism itself:** this
is a net-new gate — no prior api-design gate exists to deprecate or
migrate away from (per survey.md's finding of zero `PreToolUse` hooks
today). N/A — net new, nothing deprecated.

**Preserving `WRITE_SCOPE: []`:** this proposal does not add, widen, or
in any way redesign this role's write scope. The gate described below
is a *read-and-deny* mechanism only — it inspects tool-call payloads
and either allows (exit 0) or denies (exit 2) a write; it does not grant
this role permission to write anywhere it couldn't already attempt to
write. The gate's own path-regex scoping (limiting *which paths it even
evaluates*) is not a grant of write access to those paths — it is
strictly narrower than the role's existing permission surface, and
the role's actual write permissions (per whatever mechanism enforces
`WRITE_SCOPE` at a level above this gate — the survey found none exists
today, but this proposal does not claim to fill that separate gap)
remain exactly as they are: report-only, no code/doc write outside
`docs/issue-<n>/reports/api-design.md`,
`docs/issue-<n>/reports/api-design/`, and
`docs/issue-<n>/proposals/api-design.md`. Any future proposal to add a
*separate* `WRITE_SCOPE`-enforcing gate is out of scope for this
document and would need its own phase-1 cycle.

## Gate design (phase-2 execution only — not implemented in this proposal)

Intended file: `api-design/hooks/methodology-gate.sh`, registered in
`api-design/hooks/hooks.json` as a `PreToolUse` hook on matcher
`Write|Edit|MultiEdit`, alongside the existing `SessionStart` →
`directive.sh` registration:

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/directive.sh" } ] }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [ { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/methodology-gate.sh" } ]
      }
    ]
  }
}
```

Intended shell logic for `methodology-gate.sh` (design only — this
block is prose-adjacent pseudocode/shell for review, not a file to be
created by this proposal):

```bash
#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) — api-design-role-specific,
# on top of (never instead of) whatever generic core canon record
# checks apply. Pattern follows pricing-rulebook's own
# pricing/hooks/methodology-gate.sh (read, not sourced or copied) per
# docs/handbooks/canon-scripts.md's canon-scripts norm.
#
# Targets:
#   docs/issue-<n>/proposals/*api-design*.md   (phase-1 ADR proposal)
#   docs/issue-<n>/reports/api-design.md       (phase-2 PRODUCES record)
#
# Kill switch: export API_DESIGN_METHODOLOGY_GATE_OFF=1
set -uo pipefail
trap '__fc' EXIT
__fc(){ rc=$?; [ "$rc" != 0 ] && [ "$rc" != 2 ] && { echo "fail-closed: gate aborted (rc=$rc)" >&2; exit 2; }; }

role="${CLAUDE_ROLE:-api-design}"
deny(){ echo "${role}: refused — $1" >&2; exit 2; }

case "${API_DESIGN_METHODOLOGY_GATE_OFF:-}" in ""|0|false|no|off) ;; *) exit 0 ;; esac
command -v python3 >/dev/null 2>&1 || deny "requires python3, not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin."

# ... resolve project root via CLAUDE_PROJECT_DIR -> git rev-parse
#     --show-toplevel from target dir -> git rev-parse from cwd,
#     exactly as pricing-rulebook's gate does; fail closed if none found.

# Python body (embedded via heredoc, wrapped in try/except that fails
# closed on any internal error, mirroring pricing's outer __fc trap):
#   1. Parse payload -> tool_name, tool_input.
#   2. Resolve tool_input.file_path against root; if it does not match
#      either PROPOSAL_RE = ^docs/issue-[0-9]+/proposals/.*api-design.*\.md$
#      or RECORD_RE = ^docs/issue-[0-9]+/reports/api-design\.md$, exit 0
#      (not this gate's business).
#   3. Reconstruct resulting content for Write / Edit / MultiEdit,
#      denying if it cannot be determined (non-matching old_string, etc).
#   4. If RECORD_RE matched, require all four labeled PRODUCES fields
#      present as sections/labels in the resulting text:
#        "interface-spec" (or "interface spec"), and a nearby
#          machine-readable-format cue (openapi, asyncapi, protobuf,
#          grpc, idl) OR an explicit "N/A" style is rejected here since
#          interface-spec has no legitimate N/A case;
#        "resource-model" (or "resource model");
#        "versioning-strategy" (or "versioning strategy"), accepting
#          "none — pre-v1" as a satisfying value per the adopted norm;
#        "deprecation-plan" (or "deprecation plan" / "deprecation/
#          migration plan"), accepting "N/A — net new" as satisfying.
#   5. If PROPOSAL_RE matched, require all five ADR section headers
#      present (context, decision, alternatives considered, rationale,
#      consequences), case-insensitively, each with non-empty body text
#      following it (a bare heading with the next line being another
#      heading or EOF counts as missing, mirroring pricing's rule that
#      a gate should catch empty-content headings, not just absent
#      headings).
#   6. Collect all missing elements; if any, deny with a single message
#      listing every missing element and citing
#      docs/issue-1/proposals/api-design.md (deliverable norm) or
#      docs/issue-7/proposals/api-design.md (this deepening) as the
#      norm source, matching pricing's practice of naming the norm doc
#      in its deny message.
#   7. Exit 0 if nothing missing.
```

Design notes carried over from the scout-brief's must-bes: fail-closed
on any parse/internal error (not silent pass); three-tier root
detection; resulting-content reconstruction for Edit/MultiEdit rather
than checking only the diff fields; all-missing-at-once deny messages;
path-regex scoping so this gate never fires on writes outside its own
two surfaces (and therefore never expands `WRITE_SCOPE`, only narrows
what it inspects within the existing allowed surfaces).

## Gate test design (phase-2 execution only — no test files created by this proposal)

Intended location: `tests/api-design/methodology-gate.bats` (bats-style,
matching the `.sh`/bats convention visible in core's own
`core/hooks/tests/stub-check.sh` naming; exact framework choice is a
phase-2 detail contingent on what test runner this repo's CI already
uses, not committed to here). Intended cases:

**Pass cases**
1. A `Write` to `docs/issue-7/reports/api-design.md` whose content
   contains all four PRODUCES fields with non-empty values (including
   the "none — pre-v1" / "N/A — net new" satisfying forms) → gate exits
   0.
2. A `Write` to `docs/issue-7/proposals/api-design.md` whose content
   contains all five ADR section headers, each followed by non-empty
   body text → gate exits 0.
3. A `Write` to an unrelated path (e.g.
   `docs/issue-7/reports/architecture.md`) → gate exits 0 without
   evaluating any content (path-regex miss).
4. An `Edit` whose `old_string` matches current on-disk content and
   whose resulting reconstructed text still contains all required
   fields → gate exits 0.
5. `API_DESIGN_METHODOLOGY_GATE_OFF=1` set → gate exits 0 regardless of
   content (kill switch honored).

**Reject cases**
6. A `Write` to the phase-2 record path missing the `deprecation-plan`
   field entirely → gate exits 2, deny message names
   `deprecation-plan` specifically.
7. A `Write` to the phase-2 record path where `interface-spec` is
   present as a heading but with no machine-readable-format cue nearby
   → gate exits 2, deny message names `interface-spec`.
8. A `Write` to the phase-1 proposal path missing the "Alternatives
   Considered" section → gate exits 2, deny message names it.
9. A `Write` to the phase-1 proposal path where "Consequences" appears
   only as a heading immediately followed by another heading (empty
   body) → gate exits 2 (empty-section rule).
10. An `Edit` whose `old_string` does not match current on-disk content
    for a file matching one of the two regexes → gate exits 2 with a
    "cannot determine resulting content" message (mirrors pricing's own
    ambiguous-Edit deny case).
11. A malformed/non-JSON stdin payload for a matched path → gate exits
    2 (fail-closed on unparseable payload).
12. A `Write` whose target path resolves outside the git-detected
    project root entirely (e.g. via a crafted absolute path) →
    gate must not evaluate it as if it were a repo-relative path;
    exits 0 only if genuinely outside root, matching pricing's
    `root + "/"` prefix check.

Each reject case's assertion is: exit code 2, and stderr contains the
name of the specific missing/ambiguous element, not merely a generic
"denied" — matching pricing-rulebook's practice of naming the
deficiency so an author can fix it without re-reading the whole norm
document.

## Checklist/agent file

None proposed. Per Alternatives Considered #5, neither adopted norm
decomposes into a repeated multi-step procedure separate from what the
gate above already mechanizes. If phase-2 execution or later usage
surfaces a genuine repeated judgment procedure (e.g. choosing among
interface-spec formats for different surface types), a checklist can be
proposed at that time through its own phase-1 cycle; none is warranted
now.

## `WRITE_SCOPE: []` and canon-scripts invariants (explicit statement)

- This proposal does not modify, widen, or redesign this role's
  `WRITE_SCOPE: []`. The gate described is scoped, by design, to only
  ever evaluate writes to the two paths already inside this role's
  existing allowed record/proposal homes
  (`docs/issue-<n>/reports/api-design.md`,
  `docs/issue-<n>/reports/api-design/`, and
  `docs/issue-<n>/proposals/api-design.md`); it exits 0 (no opinion) on
  anything else, which is a narrower, not broader, surface than today's
  status quo of no gate at all.
- Per `docs/handbooks/canon-scripts.md`, this proposal references (by
  path, in survey.md/scout-brief.md/this document) `core/hooks/lib/
  role-directive.sh` and pricing-rulebook's `methodology-gate.sh` as
  design pattern sources, and copies neither into `api-design/`. The
  gate script this proposal designs, if approved, will be an
  independently authored file under `api-design/hooks/`, not a sourced
  or vendored copy of any other plugin's script.
