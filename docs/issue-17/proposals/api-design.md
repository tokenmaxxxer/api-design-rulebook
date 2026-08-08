---
status: proposed
files:
  - README.md
  - api-design/hooks/directive.sh
  - api-design/plugins/interface-spec-gate/hooks/gate.sh
  - api-design/plugins/resource-model-gate/hooks/gate.sh
  - tests/api-design/interface-spec-gate.sh
  - tests/api-design/resource-model-gate.sh
  - docs/specs/record-fields-terminal-states.json
---

## Request

Layer the realized marketplace `api-design.spec.json`'s five required
deliverable fields (`endpoint_path`, `method`, `spectral_ruleset_id`,
`verdict`, `openapi_version`) and its `loop_state` vocabulary (`landed`,
`linting`, `reviewing`, `ruleset-unreachable`, `spec-undeclared`) onto
this rulebook's methodology docs, hooks, and gates — strengthening the
existing PRODUCES facets and gates, never deleting or replacing them.

## Constraints

- Every one of the five field names must appear in `docs/` or
  `README.md` after phase 2 (acceptance check 1).
- The rulebook's loop_state vocabulary must match the spec set exactly —
  no stale or extra states (acceptance check 2).
- `spectral_ruleset_id`'s reference-resolution and `verdict`'s
  recomputation are both explicitly assigned elsewhere by the spec
  itself (`on-the-record/hooks/role-spec-reference-guard.sh`, and a
  stated `TBD` follow-up respectively) — this rulebook adopts the
  vocabulary and field-presence expectation only; it does not
  re-implement resolution or recomputation enforcement that belongs to
  another system.
- Existing gates are fail-closed, independent of each other, and scoped
  to `docs/issue-<n>/reports/api-design\.md`; any strengthening must
  preserve that shape (source `gate-lib.sh` by reference, same scope
  regex, same kill-switch pattern) per this repo's own conventions.
- No methodology content gets deleted — the four existing PRODUCES
  facets (interface-spec, resource-model, versioning-strategy,
  deprecation-plan) stay; the spec's fields attach to them, they don't
  replace them.

## Rationale

**Where each field attaches, and why not elsewhere:**

- `endpoint_path` + `method` → attach to `resource-model-gate` /
  PRODUCES facet 2 (resource-model), not `interface-spec-gate`.
  Considered attaching both to `interface-spec-gate` instead (it already
  parses the record for a labeled section), but rejected: an HTTP method
  and path describe a *specific resource's addressing*, which is what
  the resource-model facet already claims ownership of ("resource
  hierarchy + naming convention applied"); interface-spec's facet is the
  *format* of the spec document (OpenAPI/AsyncAPI/etc.), a different
  axis. Keeping method+path on resource-model avoids two gates racing to
  parse the same tokens for different reasons.
- `openapi_version` → attaches to `interface-spec-gate` / PRODUCES
  facet 1 (interface-spec), as an optional strengthening of the existing
  format-cue check, since that gate already recognizes the literal
  token "openapi" as one of its accepted format cues. Considered adding
  it to resource-model-gate alongside endpoint_path/method, but rejected:
  a spec *version* string is a property of the spec document, not of a
  resource's naming — bundling it there would make resource-model-gate
  parse a fact irrelevant to resource modeling.
- `spectral_ruleset_id` → attaches to `interface-spec-gate` as a doctrine
  addition (the record must name which ruleset it was linted against),
  not as a new gate. Considered building a new
  `spectral-ruleset-reference-gate` that verifies the ID resolves to a
  real rule, but rejected: the spec's own
  `reference_resolution.checked_by` names
  `on-the-record/hooks/role-spec-reference-guard.sh` as the enforcement
  point — building a second, redundant resolver in this repo would
  duplicate that check with no shared source of truth, and the spec
  explicitly assigns it elsewhere.
- `verdict` → attaches to doctrine only (PRODUCES list text in
  `directive.sh` and `README.md`), no gate. Considered a
  `verdict-gate` requiring a pass/fail token near the label (mirroring
  how `interface-spec-gate` requires a format cue), but rejected: the
  spec's own `recomputation.rule` says verdict must be *recomputed by
  re-running the ruleset*, never asserted as a standalone field, and its
  `checked_by` is explicitly `TBD (follow-up)` — a field-presence gate
  here would enforce the wrong thing (that the word "pass" appears
  somewhere) while giving no signal about whether the ruleset was
  actually re-run. Doctrine states the requirement and defers the
  mechanism to the spec's own stated follow-up, rather than building a
  gate that would create false confidence.
- `loop_state` vocabulary → this repo currently has no
  `docs/specs/record-fields-terminal-states.json`, so api-design's
  loop_state vocabulary is unpinned rather than spec-aligned. Considered
  leaving it to core canon's generic default instead of adding a local
  override file, but rejected: the spec's five-state set
  (`landed`/`linting`/`reviewing`/`ruleset-unreachable`/`spec-undeclared`)
  is role-specific vocabulary core's generic default cannot know about,
  and the override mechanism (a per-repo JSON file, per this session's
  own SessionStart directive text) exists precisely for this case.

## What will be done

1. `README.md` and `api-design/hooks/directive.sh`: extend the PRODUCES
   list so facet 1 (interface-spec) names `openapi_version` and
   `spectral_ruleset_id` as record fields it expects, and facet 2
   (resource-model) names `endpoint_path` and `method` (enumerated
   GET/POST/PUT/PATCH/DELETE, per the spec's enum) as record fields it
   expects. Add a `verdict` line to the PRODUCES text noting it is
   recomputed (never asserted) and that recomputation enforcement is a
   stated upstream follow-up, not this rulebook's gate. Add the
   `loop_state` vocabulary (`landed` terminal; `linting`, `reviewing`
   progress; `spec-undeclared` refusal; `ruleset-unreachable` error) to
   the directive text so it is visible at SessionStart.
2. `api-design/plugins/interface-spec-gate/hooks/gate.sh`: strengthen the
   existing format-cue check's accepted-cue set to also recognize an
   adjacent `openapi_version:` or `spectral_ruleset_id:` field mention
   as satisfying (not replacing) the existing cue requirement — additive
   only, the current openapi/asyncapi/protobuf/grpc/idl cue check stays
   as-is and continues to pass on its own.
3. `api-design/plugins/resource-model-gate/hooks/gate.sh`: strengthen the
   existing resource-hierarchy check to also require an `endpoint_path`
   value and a `method` token from the spec's enum
   (GET/POST/PUT/PATCH/DELETE) somewhere in the resource-model section —
   additive to the existing hierarchy/naming check, not a replacement.
4. `tests/api-design/interface-spec-gate.sh` and
   `tests/api-design/resource-model-gate.sh`: add cases covering the new
   additive checks (accept with the new fields present, and confirm the
   pre-existing behavior — accept/deny on the old criteria alone — is
   unchanged).
5. `docs/specs/record-fields-terminal-states.json`: add (new file) the
   `api-design` kind's loop_state override, matching the spec's set
   exactly: `{"api-design": {"progress": ["linting", "reviewing"],
   "terminal": ["landed"], "refusal": ["spec-undeclared"], "error":
   ["ruleset-unreachable"]}}`.

## Out of scope

- Building a `spectral_ruleset_id` reference-resolution gate in this
  repo — the spec assigns that to `on-the-record`'s
  `role-spec-reference-guard.sh`.
- Building a `verdict` recomputation mechanism (actually invoking
  Spectral) — the spec marks this `TBD (follow-up)` itself.
- Any change to `versioning-strategy-gate`, `deprecation-plan-gate`,
  `adr-section-gate`, or `evidence-citation-gate` — none of the five
  spec fields maps onto those facets.
- Rewriting or deleting any existing PRODUCES facet, gate, or test —
  every change here is additive to what already exists.

## How you'll know it worked

- `grep -ri 'endpoint_path\|method\|spectral_ruleset_id\|verdict\|openapi_version' docs/ README.md`
  returns at least one hit per field name (acceptance check 1).
- The only loop_state vocabulary present in
  `docs/specs/record-fields-terminal-states.json` for the `api-design`
  kind is exactly `{landed, linting, reviewing, ruleset-unreachable,
  spec-undeclared}` — no stale or extra states (acceptance check 2).
- `bash tests/api-design/interface-spec-gate.sh` and
  `bash tests/api-design/resource-model-gate.sh` (and the other four
  untouched suites, as a regression check) all pass (acceptance check
  3 — this rulebook's test suite, `tests/api-design/*.sh`).
- Manual review confirms `spectral_ruleset_id` reference-resolution and
  `verdict` recomputation are each documented as deferred-elsewhere,
  with the reasoning stated in this proposal's Rationale section
  (acceptance check's "empty state" requirement).
