# Issue #1 — Phase 1 Proposal: Proposal Norm + Deliverable Norm for api-design

Status: **PROPOSAL ONLY — phase 1.** No rulebook content is changed by
this document. Execution (phase 2) requires an Approve from a login in
`docs/specs/approvers.md`, or (single-account mode) an issue comment
"APPROVE issue-1/api-design", per contract v3 s19. This document does
not itself constitute or contain that approval.

Basis: `docs/issue-1/reports/api-design/survey.md` (current-state gaps)
and `docs/issue-1/reports/api-design/scout-brief.md` (field convergence
across Google AIP, Zalando RESTful API Guidelines, Microsoft REST API
Guidelines, Stripe's design-review practice, HashiCorp's RFC template,
and the ADR literature — see scout-brief's Sources list).

## (a) Proposal norm — phase 1 documents

**Methodology adopted: ADR shape** (context → decision → alternatives
considered → rationale → consequences), the structure independently
converged on by Cognitect's ADR format, HashiCorp's RFC template, and
Google/Stripe design-doc practice (scout-brief, Must-bes).

**Required sections for every api-design phase-1 proposal:**
1. **Context** — the problem/requirement driving the API surface change,
   stated in value-neutral language (who consumes it, what's forcing
   the change).
2. **Decision** — the proposed interface shape (resource model,
   endpoints, or equivalent), stated concretely enough to review.
3. **Alternatives considered** — at least one rejected shape, with why
   it was rejected. (Mirrors Stripe/Google design-doc practice of
   showing the option space, not just the winner.)
4. **Rationale** — why the decision serves consumers/the stated
   use_when better than the alternatives. Must cite external evidence
   (a named guideline, RFC, or precedent) wherever the decision follows
   an established convention, per this rulebook's existing evidence
   discipline — a bare assertion is not rationale.
5. **Consequences** — what becomes easier/harder for API consumers,
   including explicitly naming the versioning approach and the
   deprecation/migration impact of the change (even if "none" for a
   net-new API).

**Evidence format:** every claim of "this is standard practice" must
name the source (an org's published guideline, an RFC number, a
prior-art API) — same rule this repo's scout-directive already applies
to research; this proposal norm just extends it to ordinary decision
rationale, not only scouted claims.

## (b) Deliverable norm — phase 2 output

**Methodology adopted: API-First / spec-as-artifact** (Zalando's model:
the specification document *is* the reviewed artifact, matching this
role's `WRITE_SCOPE: []` report-only nature — there is no code to
build-then-document).

**Required components** (all four, per scout-brief's converged
must-bes; replaces the current single free-text `PRODUCES` label):
1. **Interface spec** — a machine-readable OpenAPI-class document (or,
   where the surface isn't HTTP/REST, the equivalent IDL for that
   protocol) — not prose-only description. Converged on by Google AIP,
   Zalando, Microsoft REST Guidelines (scout-brief, performance axis 1).
2. **Resource/naming model** — explicit statement of the resource
   hierarchy and naming convention applied (nouns-not-verbs,
   collection/item structure), even when this is just "follows
   `<X>` convention" pointing at an existing house style.
3. **Versioning strategy** — explicit statement of the mechanism
   chosen (path/header/query, or "none — pre-v1") and why. The
   rulebook does NOT prescribe which mechanism (scout-brief: exemplars
   disagree on this numerically) — it requires only that a choice be
   stated and justified per the proposal norm above.
4. **Deprecation/migration plan** — explicit notice window and
   migration path for anything the change deprecates, or "N/A — net
   new, nothing deprecated" stated explicitly rather than omitted.

## (c) Rationale for each adoption

- **ADR shape for proposals:** every scouted org's pre-implementation
  gate reduces to the same shape regardless of company culture (heavy
  process at Stripe, lightweight AIP at Google, guideline-driven at
  Zalando) — convergence across structurally different orgs is strong
  evidence this shape is intrinsic to the problem (reviewing a
  not-yet-built interface) rather than one company's house style. It
  also directly satisfies contract v3 s19's Approve gate: an approver
  distinct from the author needs "alternatives" and "consequences"
  sections to actually evaluate a decision, not just read a
  conclusion.
- **API-First / spec-as-artifact for deliverables:** this role is
  `WRITE_SCOPE: []` — report-only, no code. Stripe's "build then write
  20-page doc" model presumes an implementation exists to document;
  Zalando's model (spec precedes and gates implementation, spec itself
  is the reviewed unit) is the only one of the scouted exemplars that
  matches a role whose entire output is the specification. Adopting
  any other exemplar's deliverable model would require inventing a
  fictional "implementation" this role never produces.
- **Machine-readable spec requirement:** a prose-only "interface spec"
  (today's state) cannot be linted, diffed, or fed to consumer
  codegen — every scouted guideline treats this as the line between a
  real spec and a description of one. This is the highest-leverage
  single fix, since it's currently unenforced.
- **Not prescribing versioning mechanism/deprecation window:** scouted
  exemplars themselves disagree here (3–24 month windows, 3 different
  versioning mechanisms) — treating a majority mechanism as doctrine
  would optimize for one exemplar's context over this role's actual
  consumers. Requiring the *choice be stated and justified* (not which
  choice) keeps the norm generalizable while still closing the "silent
  omission" gap survey.md found.

## (d) Plugin reflection plan

**`directive.sh` (`PRODUCES` line):** replace the current single
free-text label with four named sub-fields, mirroring the deliverable
norm in (b):
```
PRODUCES (required record fields): interface-spec (machine-readable, OpenAPI-class or protocol equivalent), resource-model, versioning-strategy, deprecation-plan
```
The proposal-norm sections in (a) are **not** added to `PRODUCES` —
`PRODUCES` describes the phase-2 record; the proposal-norm instead
constrains what a conforming `docs/issue-<n>/proposals/api-design.md`
must contain, and is enforced by PR review against this document (the
Approve gate itself), not by a directive-injected required-fields list.

**Required-fields gate:** this repo currently has no
`record-fields-gate.sh` (survey.md gap 3) — issue #2's converted
`implementation` role's gate is the model to follow. Phase 2 execution
should add a role-config-driven gate (following whatever generic
mechanism core issue #66 exposes, same open cross-repo dependency
issue #2's proposal flagged) with:
```
REQUIRED_FIELDS = ["interface-spec", "resource-model", "versioning-strategy", "deprecation-plan"]
```
checked against `docs/issue-<n>/reports/api-design.md`, denying a
Write/Edit that omits any of the four headers. Exact registration
mechanism (core-centralized vs. local stub) is a phase-2 decision,
contingent on core's actual interface — not resolved here since core
is not checked out in this workspace (same limitation noted in
survey.md and issue #2's scout-brief).

**Proposal-norm gate:** no automated gate is proposed for the ADR
sections in (a) — unlike the phase-2 record, a phase-1 proposal's
adequacy (is the rationale actually sound, are alternatives real) is a
judgment call for the human Approve step, not a mechanically checkable
field-presence test. Section *presence* (all five headers exist) could
optionally reuse the same required-fields gate mechanism pointed at
`docs/issue-<n>/proposals/api-design.md` instead, if core's gate
mechanism is generic enough to target either path — left as a phase-2
implementation choice, not a phase-1 commitment, since it adds gate
surface for a check whose failure mode (empty section) is rare and low
severity next to record-field omission.
