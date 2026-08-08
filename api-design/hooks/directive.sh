#!/usr/bin/env bash
# SessionStart: api-design's role directive. Shared boilerplate (kill-switch
# case, CLAUDE_ROLE guard, EXIT trap) now lives in core canon's
# core/hooks/lib/role-directive.sh (core_role_directive, core issue #66).
# Kill switch: export API_DESIGN_CYCLE_OFF=1
#
# Core-root resolution (issue #10 fix): CLAUDE_PLUGIN_ROOT_CORE is the
# authoritative source (set by the plugin marketplace runtime); the
# relative fallback below is a local-dev convenience only, not a layout
# guarantee (survey defect 3: a hardcoded sibling-checkout assumption
# fails silently in this workspace's actual layout). If neither resolves
# to a real core checkout, this prints a loud diagnostic and skips the
# directive instead of failing silently.
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive "YOU DECIDE: 서비스 경계의 인터페이스 형태" "USE_WHEN: 여러 소비자가 걸리는 API 표면을 설계/변경할 때" $'PRODUCES (required record fields, per issue #1\'s adopted deliverable norm — API-First / spec-as-artifact; issue #17 layers the realized marketplace api-design.spec.json\'s required fields onto these same facets, additive only):\n1. interface-spec (machine-readable, OpenAPI-class or protocol equivalent — not prose-only); also names openapi_version and spectral_ruleset_id (which ruleset it was linted against — reference-resolution enforced elsewhere, by on-the-record/hooks/role-spec-reference-guard.sh)\n2. resource-model (resource hierarchy + naming convention applied); also names endpoint_path and method (one of GET/POST/PUT/PATCH/DELETE)\n3. versioning-strategy (mechanism chosen, or "none — pre-v1", and why)\n4. deprecation-plan (notice window + migration path, or "N/A — net new" stated explicitly)\n5. verdict — recomputed by re-running the ruleset, never asserted as a standalone pass/fail token; recomputation enforcement is the spec\'s own stated TBD (follow-up), not a gate in this rulebook\n\nloop_state vocabulary (docs/specs/record-fields-terminal-states.json, coding-record kind): landed (terminal); linting, reviewing (progress); spec-undeclared (refusal); ruleset-unreachable (error).\n\nPhase-1 proposals for this role additionally follow the ADR-shaped proposal\nnorm (context / decision / alternatives considered / rationale / consequences)\nper docs/issue-1/proposals/api-design.md — enforced by PR review at the\nApprove gate, not by this directive or a field-presence gate.\n\nWRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)' $'HAND-OFF: 컴포넌트 경계 자체가 바뀌면 → architecture; 스키마 신설/변경이면 → data-modeling\n\nBOUNDARY CASE: if the work in front of you drifts outside `decides` above,\nstop and hand off per the arrow — do not silently absorb another role\'s\nscope. Record the hand-off point in this role\'s record before opening the\nnext role\'s session.\n\n(phase-1 homes only pre-Approve; this record is phase-2 output.)'
