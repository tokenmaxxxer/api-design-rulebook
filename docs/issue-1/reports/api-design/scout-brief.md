# Issue #1 — Scout Brief (Phase 1)

Mode: **parallel** (4 WebSearch angles in one batch). Stages used: 1
sweep + 1 judge point = saturated, no deepening round needed (see below).
Wall-clock: ~2 min.

## Angles run
1. Design-first RFC/design-review processes (Google, Stripe, Zalando, HashiCorp).
2. API deliverable required components (OpenAPI structure, resource model, versioning, deprecation).
3. ADR (Architecture Decision Record) format — for the *rationale* norm.
4. Cross-org REST style-guide convergence (Microsoft, Google AIP).

## Judge point — convergence found

All four angles converge on the same two-tier pattern, independent of
company:

- **Proposal-stage (phase 1 analog):** every serious org gates *design*
  before *build*. Google (AIP + independent reviewer review), Stripe
  (design docs circulated before implementation, stakeholders listed
  with sign-off checkboxes), Zalando ("API First" — spec before code,
  peer review), HashiCorp/generic RFC — all require a written proposal
  with: problem/background, proposed solution, alternatives considered,
  and impact/consequences, reviewed by someone other than the author
  before implementation starts.
- **Deliverable-stage (phase 2 analog):** converges on OpenAPI (or
  equivalent machine-readable IDL) as the interface spec artifact, plus
  three near-universal required components beyond the raw schema:
  resource/naming model (nouns not verbs, collection/item hierarchy),
  an explicit versioning strategy, and an explicit
  deprecation/migration policy with a stated notice window.

No angle surfaced disagreement on this shape — only on notice-window
length (3–24 months depending on org) and on versioning mechanism
(path vs. header vs. query param), which are deliverable-content
details, not structural norms.

Saturation: a second deepening round would only refine numeric details
(exact deprecation windows) that this proposal deliberately leaves as
role-config, not hard-coded methodology — so stopped after 1 judge
point per the budget's saturation rule.

## Must-bes (Kano) extracted

- Phase 1 proposal MUST have: problem/context, proposed decision,
  alternatives considered, rationale, consequences/impact — this is
  the ADR shape, converged on by Cognitect's ADR (context/decision/
  consequences), HashiCorp's RFC template, and Google/Stripe design-doc
  practice alike.
- Phase 2 deliverable MUST have: machine-readable interface spec
  (OpenAPI-class), explicit versioning strategy, explicit
  deprecation/migration plan — converged on by Google AIP, Zalando,
  Microsoft REST guidelines, and general API-design-best-practice
  literature.

## Performance axes (2-3 dimensions strong exemplars compete on)

1. **Spec machine-readability** — a spec a tool can lint/diff (OpenAPI)
   vs. prose-only description. All exemplars land on machine-readable.
2. **Review independence** — Google/Stripe/Zalando all route design
   docs through a reviewer distinct from the author before merge; this
   repo's contract v3 s19 Approve gate already satisfies this
   structurally (an approvers.md account distinct from author).
3. **Explicitness of the deprecation/migration contract** — weak specs
   leave this implicit; strong ones state a concrete window and
   migration path.

## Adopt / skip

- **Adopt:** ADR-shape for the phase-1 proposal (context → decision →
  alternatives/rationale → consequences); OpenAPI as the required
  phase-2 interface-spec format; explicit required components
  (resource model, versioning, deprecation/migration) as gated record
  fields.
- **Skip:** prescribing a specific versioning *mechanism* (path vs.
  header) or a specific deprecation *window length* as rulebook
  doctrine — these are legitimate per-API judgment calls the exemplars
  themselves disagree on numerically; the rulebook should require that
  a choice be stated and justified, not dictate which choice.

## Segment fit

This role is report-only (`WRITE_SCOPE: []` per current directive.sh) —
its phase-2 "deliverable" is a *specification document*, not running
code. This matches Zalando's "API First" model most directly (spec is
itself the artifact under review), more than Stripe's build-then-doc
practice.

## Gap line (current state vs. field must-bes)

Met: none of the converged must-bes are currently encoded anywhere in
this repo (see survey.md gaps 1–4) — `directive.sh`'s PRODUCES line
names two labels ("interface spec", "lifecycle/deprecation plan") but
binds no methodology, no required sub-components, and no gate to either.
Missing: ADR-shaped proposal norm (entirely absent), OpenAPI-class
machine-readable spec requirement (absent — currently just the word
"interface spec"), explicit resource-model/versioning/deprecation
sub-fields (absent — currently one merged free-text label), and any
gate enforcing either norm (absent — no record-fields-gate exists in
this repo).

## Sources
- https://google.aip.dev/1
- https://docs.cloud.google.com/apis/design
- https://chuniversiteit.nl/papers/api-governance-at-scale
- https://blog.postman.com/how-stripe-builds-apis/
- https://opensource.zalando.com/restful-api-guidelines/
- https://github.com/zalando/restful-api-guidelines/blob/main/chapters/design-principles.adoc
- https://www.hashicorp.com/en/how-hashicorp-works/articles/rfc-template
- https://adr.github.io/
- https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
- https://learn.microsoft.com/en-us/azure/well-architected/architect-role/architecture-decision-record
- https://spec.openapis.org/oas/v3.1.1.html
- https://learn.openapis.org/best-practices.html
- https://learn.microsoft.com/en-us/azure/architecture/best-practices/api-design
- https://www.speakeasy.com/api-design/versioning/
- https://www.gravitee.io/blog/api-versioning-best-practices
