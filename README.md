# api-design-rulebook

Rulebook for the `api-design` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion and
generated as skeleton scaffolding by issue-170.

- **decides**: 서비스 경계의 인터페이스 형태
- **use_when**: 여러 소비자가 걸리는 API 표면을 설계/변경할 때
- **produces**: interface spec (endpoints/schema/versioning), lifecycle/deprecation plan
- **write_scope**: []
- **hand-off**: 컴포넌트 경계 자체가 바뀌면 → architecture; 스키마 신설/변경이면 → data-modeling

## Install

```
claude plugin marketplace add tokenmaxxxer/api-design-rulebook
claude plugin install api-design
```

## Layout

- `api-design/.claude-plugin/plugin.json` — plugin manifest
- `api-design/hooks/hooks.json` — SessionStart wiring
- `api-design/hooks/directive.sh` — SessionStart role directive; a stub
  sourcing core canon's `core/hooks/lib/role-directive.sh`
  (`core_role_directive`) with this role's four unique values
- `api-design/plugins/<name>-gate/` — six `PreToolUse` (`Write|Edit|MultiEdit`)
  methodology gates this rulebook vendors itself, one per API-First
  deliverable facet (issue #7, remediated to A+ under issue #10):
  `adr-section-gate` (ADR-shaped phase-1 proposal, 5 required sections),
  `evidence-citation-gate` (every "standard/common/established practice"
  claim names a source), `interface-spec-gate` (machine-readable spec
  format cue near the label), `resource-model-gate` (resource
  hierarchy/naming statement), `versioning-strategy-gate` (named mechanism
  or "none — pre-v1"), `deprecation-plan-gate` (Sunset/Deprecation header
  tokens + date, or "N/A — net new"). Each sources core issue #72's
  `gate-lib.sh`/`gate-lib.py` by reference for its fail-closed trap,
  kill-switch, JSON parsing, path normalization, and Edit/MultiEdit/
  `replace_all` reconstruction — see each plugin's own README "Core
  adoption" section for the exact functions used.
- `tests/api-design/*.sh` — self-contained test suites for the six gates
  above, run via plain `bash tests/api-design/<name>.sh` (no bats
  dependency); `tests/api-design/lib/core-fixture.sh` resolves
  `CLAUDE_PLUGIN_ROOT_CORE` for the test run.
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

This role no longer vendors its own copies of the record-fields gate,
trailer gate, handbook-trigger gate, or the warrant-hunter agent — core
canon now provides all four directly (core issues #63/#66): the three
role-agnostic `PreToolUse` gates are registered globally by core's own
`hooks.json`, and the warrant-hunt plugin (`warrant/`) runs unparameterized
per-repo. This role's decision-boundary and hand-off content lives in
`directive.sh`; its own six methodology gates (API-First deliverable
facets, not role-agnostic) live under `api-design/plugins/`, listed above.

This is scaffolding, not a finished rulebook: fill in doctrine detail and
handoff enforcement before treating it as load-bearing.
