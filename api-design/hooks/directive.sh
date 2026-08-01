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
_api_design_core_root="${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" 2>/dev/null && pwd -P)}"
if [ -z "$_api_design_core_root" ] || [ ! -f "$_api_design_core_root/hooks/lib/role-directive.sh" ]; then
  echo "api-design/directive: CLAUDE_PLUGIN_ROOT_CORE is not set and no core checkout was found at the relative fallback path; role directive skipped. Set CLAUDE_PLUGIN_ROOT_CORE to the tokenmaxxxer-core plugin root." >&2
  return 0 2>/dev/null || exit 0
fi
. "$_api_design_core_root/hooks/lib/role-directive.sh"
core_role_directive "YOU DECIDE: 서비스 경계의 인터페이스 형태" "USE_WHEN: 여러 소비자가 걸리는 API 표면을 설계/변경할 때" $'PRODUCES (required record fields, per issue #1\'s adopted deliverable norm — API-First / spec-as-artifact):\n1. interface-spec (machine-readable, OpenAPI-class or protocol equivalent — not prose-only)\n2. resource-model (resource hierarchy + naming convention applied)\n3. versioning-strategy (mechanism chosen, or "none — pre-v1", and why)\n4. deprecation-plan (notice window + migration path, or "N/A — net new" stated explicitly)\n\nPhase-1 proposals for this role additionally follow the ADR-shaped proposal\nnorm (context / decision / alternatives considered / rationale / consequences)\nper docs/issue-1/proposals/api-design.md — enforced by PR review at the\nApprove gate, not by this directive or a field-presence gate.\n\nWRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)' $'HAND-OFF: 컴포넌트 경계 자체가 바뀌면 → architecture; 스키마 신설/변경이면 → data-modeling\n\nBOUNDARY CASE: if the work in front of you drifts outside `decides` above,\nstop and hand off per the arrow — do not silently absorb another role\'s\nscope. Record the hand-off point in this role\'s record before opening the\nnext role\'s session.\n\n(phase-1 homes only pre-Approve; this record is phase-2 output.)'
