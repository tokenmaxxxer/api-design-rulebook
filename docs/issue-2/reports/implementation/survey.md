# Issue #2 — Current-State Survey (Phase 1)

Role: `implementation` (working on behalf of the `api-design` rulebook repo).
Purpose: document what exists in this repo *before* any conversion work, as
input to the phase-1 proposal. This is a survey only — no files outside
`docs/issue-2/reports/implementation/` and `docs/issue-2/proposals/` were
modified to produce it.

## Repo layout observed

```
api-design-rulebook/
├── README.md
├── api-design/
│   ├── .claude-plugin/plugin.json
│   ├── agents/warrant-hunter.md
│   └── hooks/
│       ├── hooks.json
│       ├── directive.sh
│       ├── record-fields-gate.sh
│       ├── trailer-gate.sh
│       └── handbook-trigger-gate.sh
└── docs/specs/approvers.md
```

There is no `core/` directory or git submodule checked out in this repo
(`.gitmodules` present but not readable/populated in this workspace, and no
`core` path exists on disk). This survey therefore documents this repo's
side of the conversion only, based on the issue body's description of what
core now provides; it does not independently inspect core's landed
`warrant/` plugin, `core/hooks/`, or `core/hooks/lib/role-directive.sh`.

## Item-by-item findings, mapped to the issue's 5 action items

### 1. `agents/warrant-hunter.md` copy → core canon reference

- File: `api-design/agents/warrant-hunter.md` (23 lines).
- Content: a full, role-adapted copy of the hunt-agent doctrine (mandate,
  stance rotation, scope/out-of-scope). Line 3 explicitly says it is
  "adapted from implementation-rulebook's `agents/warrant-hunter.md`" —
  i.e. this is already a known-duplicated copy, not an original.
  - Role-unique content actually present: the decision-boundary quote
    (서비스 경계의 인터페이스 형태) and the hand-off line (컴포넌트 경계
    자체가 바뀌면 → architecture; 스키마 신설/변경이면 → data-modeling).
  - Explicitly marked as unfinished: "skeleton — enumerate this role's own
    stance set before shipping."
- Nothing in `hooks.json` currently registers this agent as a hook (it is
  referenced only as a `.md` agent definition file, presumably invoked by
  name/convention elsewhere e.g. plugin loading), so there is no hook
  wiring here to remove for this item — only the file content.

### 2. Gate copies (`trailer-gate.sh`, `record-fields-gate.sh`,
   `handbook-trigger-gate.sh`) + their `hooks.json` registration

- `api-design/hooks/hooks.json` registers, under `PreToolUse`:
  - `Write|Edit|MultiEdit|NotebookEdit` matcher → `record-fields-gate.sh`
  - `Bash` matcher → `handbook-trigger-gate.sh`, `trailer-gate.sh`
  - plus a `SessionStart` hook → `directive.sh` (see item 3).
- `trailer-gate.sh`: header comment says "Adapted from
  implementation-rulebook's trailer-gate.sh, role name substituted only
  (this file's logic is role-agnostic)." Confirms this is a role-agnostic,
  duplicated gate — a strong candidate for removal in favor of core's
  registration (core issue #66 puts the 3 role-agnostic gates in
  `core/hooks/`).
- `handbook-trigger-gate.sh`: currently a **placeholder** — `exit 0` no-op
  with a `# TODO before this repo is treated as load-bearing` comment, and
  an explicit note questioning whether a report-only role with empty
  `write_scope` even needs this gate. Role-agnostic per the issue (item 2
  groups it with the other two "역할 무관" gates), but this file's content
  is not yet meaningfully implemented here, so there's nothing role-unique
  lost by removing it.
- `record-fields-gate.sh`: this one is **not** role-agnostic — it hardcodes
  `REQUIRED_FIELDS = ["interface-spec", "lifecycle-plan"]` and the target
  path suffix `/reports/api-design.md`, both derived from api-design's own
  `produces` field (per its own header comment: "adapted per issue-170
  from roles/api-design.json's `produces`, NOT copied from another role's
  field set"). The issue's action item 2 only lists
  trailer-gate/record-fields-gate/handbook-trigger-gate as a group to
  remove, but item 3/4 imply record-fields-gate's role-specific values
  (REQUIRED_FIELDS, terminal states) need to survive the conversion —
  see below. This needs care: the *gate script itself* may still be
  role-agnostic machinery that core could run generically, with only the
  *field list/terminal-states* being role config — but this repo's file
  currently bundles logic + role config in one script.

### 3. `directive.sh` → stub form

- Current `api-design/hooks/directive.sh` is a self-contained script (31
  lines): boilerplate (kill-switch check, `CLAUDE_ROLE` guard, EXIT trap)
  + a heredoc printing the full role directive text.
- Boilerplate parts (trap/`case`/`CLAUDE_ROLE` guard) look like exactly
  what the issue says core now centralizes as `core_role_directive` in
  `core/hooks/lib/role-directive.sh`.
- Role-unique parts that must be preserved: the heredoc body — YOU DECIDE,
  USE_WHEN, PRODUCES, WRITE_SCOPE, HAND-OFF, BOUNDARY CASE text, and the
  RECORD path/phase-gating note. These are api-design's own doctrine and
  are not present anywhere else in this repo.

### 4. Role-specific terminal-state / required-field preservation

- No `RECORD_FIELDS_TERMINAL_STATES` (or equivalent) setting currently
  exists anywhere in this repo — grepped, not found.
- The closest existing role-specific data is:
  - `record-fields-gate.sh`'s `REQUIRED_FIELDS = ["interface-spec",
    "lifecycle-plan"]` and its target-path suffix
    `/reports/api-design.md`.
  - `directive.sh`'s `PRODUCES` line (same two fields, prose form) and
    `WRITE_SCOPE: []`.
- No loop/terminal-state concept (e.g. "closed", "handed-off") appears
  anywhere in this repo's hooks or docs today. If core's generic gate
  needs a `RECORD_FIELDS_TERMINAL_STATES` config to know when the
  required-fields check applies, this repo has no existing value for it
  — the proposal will need to define one from scratch (see proposal
  document), since api-design is a report-only role with `write_scope: []`
  and no multi-state lifecycle documented yet.

### 5. `core/hooks/tests/stub-check.sh` pass confirmation

- No `core/` tree exists in this workspace, so `core/hooks/tests/stub-check.sh`
  cannot be located or run from here. This action item is inherently
  cross-repo (core canon must be present/linked) and cannot be executed
  as part of this repo's phase-1 survey. Flagged as a phase-2 dependency:
  phase 2 execution will need either a core checkout/submodule reachable
  from this repo, or CI wiring that runs core's stub-check against this
  repo's stubs.

## Other relevant existing infrastructure

- `docs/specs/approvers.md`: currently empty (comment-only placeholder).
  Per contract v3 s19, phase 2 for this issue requires either a GitHub PR
  Approve from a login listed here, or (single-account mode) an issue
  comment "APPROVE issue-2/implementation". Since this file is unpopulated,
  single-account-mode APPROVE is the only currently-available path unless
  someone populates `approvers.md` first.
- `README.md`'s "Layout" section documents the current (pre-conversion)
  file list and will need updating in phase 2 once files are
  removed/stubbed.
- `api-design/.claude-plugin/plugin.json` — plugin manifest, unaffected by
  this conversion (no core-canon duplication in it).

## Summary of duplication vs. role-unique content

| File | Role-agnostic (duplicated, remove) | Role-unique (preserve) |
|---|---|---|
| `agents/warrant-hunter.md` | mandate template, stance-rotation framing, report-only-scope boilerplate | decision-boundary quote, hand-off line |
| `hooks/trailer-gate.sh` | entire file (confirmed role-agnostic by its own header) | none |
| `hooks/handbook-trigger-gate.sh` | entire file (role-agnostic per issue grouping; currently a stub anyway) | none |
| `hooks/record-fields-gate.sh` | gate mechanics (payload parsing, deny/exit pattern) | `REQUIRED_FIELDS`, target record path, (future) `RECORD_FIELDS_TERMINAL_STATES` |
| `hooks/directive.sh` | kill-switch trap, `CLAUDE_ROLE` guard boilerplate | full heredoc doctrine body (YOU DECIDE/USE_WHEN/PRODUCES/WRITE_SCOPE/HAND-OFF/BOUNDARY CASE/RECORD) |
| `hooks/hooks.json` | gate hook registrations for the 3 role-agnostic gates (superseded by core registration) | `SessionStart` → `directive.sh` registration stays (directive itself becomes a stub, but is still role-owned and still needs registering here unless core also centralizes invocation) |
