#!/usr/bin/env bash
# SessionStart: api-design's role directive. Shared boilerplate (kill-switch
# case, CLAUDE_ROLE guard, EXIT trap) now lives in core canon's
# core/hooks/lib/role-directive.sh (core_role_directive, core issue #66).
# Kill switch: export API_DESIGN_CYCLE_OFF=1
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive "YOU DECIDE: 서비스 경계의 인터페이스 형태" "USE_WHEN: 여러 소비자가 걸리는 API 표면을 설계/변경할 때" $'PRODUCES (required record fields): interface spec (endpoints/schema/versioning), lifecycle/deprecation plan\n\nWRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)' $'HAND-OFF: 컴포넌트 경계 자체가 바뀌면 → architecture; 스키마 신설/변경이면 → data-modeling\n\nBOUNDARY CASE: if the work in front of you drifts outside `decides` above,\nstop and hand off per the arrow — do not silently absorb another role\'s\nscope. Record the hand-off point in this role\'s record before opening the\nnext role\'s session.\n\n(phase-1 homes only pre-Approve; this record is phase-2 output.)'
