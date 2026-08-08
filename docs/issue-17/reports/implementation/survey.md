# Survey: api-design.spec.json vs. this rulebook (issue #17)

## Spec read (on-the-record checkout, `roles/specs/api-design.spec.json`)

- `source_standard`: Spectral ruleset (OpenAPI linting) + OpenAPI schema conformance.
- `required_fields`: `endpoint_path` (string, required), `method` (enum
  GET/POST/PUT/PATCH/DELETE, required), `spectral_ruleset_id` (ref,
  required), `verdict` (enum pass/fail, required), `openapi_version`
  (string, optional).
- `reference_resolution`: `spectral_ruleset_id` must resolve to a real
  rule in the project's Spectral ruleset file — checked by
  `on-the-record/hooks/role-spec-reference-guard.sh` (not this repo).
- `recomputation`: `verdict` must be recomputed by re-running the ruleset,
  never a standalone asserted field — `checked_by: TBD`, explicitly
  flagged in the spec itself as an issue-521 out-of-scope follow-up.
- `write_scope`: `docs/issue-<n>/reports/api-design.md`.
- `loop_state`: progress `[linting, reviewing]`, terminal `[landed]`,
  refusal `[spec-undeclared]`, error `[ruleset-unreachable]`.
- `use_when`: an OpenAPI spec file changed on the branch AND no
  api-design record exists yet for that commit sha.

## Current rulebook state

- `README.md` / `api-design/hooks/directive.sh` `PRODUCES` list: 4 items —
  interface-spec, resource-model, versioning-strategy, deprecation-plan.
  No endpoint_path, method, spectral_ruleset_id, verdict, or
  openapi_version vocabulary anywhere (`grep -ri` across `docs/`,
  `README.md`, `api-design/` confirms zero hits for all five field
  names and for "spectral").
- Six vendored `PreToolUse` gates under `api-design/plugins/*/hooks/gate.sh`,
  one per PRODUCES facet, scoped to
  `docs/issue-<n>/reports/api-design.md`:
  - `interface-spec-gate`: requires the `interface-spec` label plus a
    machine-readable format cue (`openapi|asyncapi|protobuf|grpc|idl`)
    in the label's own section (Zalando guidelines 101-102). This is the
    only existing gate that already recognizes "openapi" as a token —
    natural anchor for `openapi_version`.
  - `resource-model-gate`: requires a resource hierarchy/naming
    statement. Natural anchor for `method` + `endpoint_path` (an HTTP
    method only means something paired with a path under a named
    resource).
  - `versioning-strategy-gate`, `deprecation-plan-gate`,
    `adr-section-gate`, `evidence-citation-gate`: unrelated to the five
    spec fields; no change needed.
  - All six gates: fail-closed, source `core/hooks/lib/gate-lib.sh` by
    reference, independent of each other, scope-anchored via a regex
    against `docs/issue-<n>/reports/api-design\.md`.
- No `docs/specs/record-fields-terminal-states.json` exists in this repo
  (checked: `find . -iname record-fields-terminal-states.json` → empty).
  Per core canon's contract-v3 directive text (visible in this session's
  SessionStart reminders), a repo may override a role's terminal-state
  vocabulary via that exact file; absent it, api-design's loop_state
  vocabulary is whatever core's generic default is — not spec-aligned.
- No reference to "Spectral" or ruleset-file conformance anywhere in the
  rulebook; `verdict` (pass/fail) as a recomputed, non-asserted field
  has no existing analog — the closest existing pattern (interface-spec
  gate) checks for a *label + cue*, not a *recomputed result*.
- `directive.sh`'s ADR-shaped-proposal note and `WRITE_SCOPE: []` line are
  unaffected by any of the five fields — no change needed there beyond
  the PRODUCES list.

## Gaps against the acceptance checks

1. Five field names must appear in `docs/` / `README.md` after phase 2 —
   currently zero do.
2. loop_state vocabulary must match the spec set exactly — currently no
   local override exists, so the repo has no matching (or exact) set at
   all.
3. `spectral_ruleset_id`'s reference-resolution and `verdict`'s
   recomputation are BOTH explicitly marked as enforced elsewhere (an
   external guard script and a TBD follow-up, respectively) in the spec
   itself — this rulebook's job is to adopt the vocabulary and the
   field-presence expectation, not to re-implement resolution or
   recomputation enforcement that the spec assigns to other systems.
4. `openapi_version` is optional in the spec — the existing
   `interface-spec-gate` already tolerates its absence structurally
   (it checks for the "openapi" token, not a version number), so no
   gate change is strictly required for that field, only doctrine text.
