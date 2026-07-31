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
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

This role no longer vendors its own copies of the record-fields gate,
trailer gate, handbook-trigger gate, or the warrant-hunter agent — core
canon now provides all four directly (core issues #63/#66): the three
role-agnostic `PreToolUse` gates are registered globally by core's own
`hooks.json`, and the warrant-hunt plugin (`warrant/`) runs unparameterized
per-repo. This role's decision-boundary and hand-off content lives only in
`directive.sh` now.

This is scaffolding, not a finished rulebook: fill in doctrine detail and
handoff enforcement before treating it as load-bearing.
