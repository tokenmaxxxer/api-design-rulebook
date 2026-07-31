# Issue #2 — Phase 1 Proposal: Convert to Core-Canon References

Status: **PROPOSAL ONLY — phase 1.** No rulebook content is changed by
this document. Execution (phase 2) requires an Approve from a login in
`docs/specs/approvers.md`, or (single-account mode) an issue comment
"APPROVE issue-2/implementation", per contract v3 s19. This document does
not itself constitute or contain that approval.

Basis: `docs/issue-2/reports/implementation/survey.md` (current-state
findings) and `docs/issue-2/reports/implementation/scout-brief.md`
(pattern confirmation). Structured against the issue's 5 action items,
one section each.

## 1. Remove `agents/warrant-hunter.md` copy → reference core canon

**Remove:** the full mandate/stance-rotation/scope prose currently in
`api-design/agents/warrant-hunter.md` (lines 6–22) — this is the part the
file's own header admits is "adapted from implementation-rulebook's
agents/warrant-hunter.md," i.e. a copy of core's `warrant/` plugin
doctrine (core issue #63).

**Keep / preserve (role-unique):**
- The decision-boundary quote: `서비스 경계의 인터페이스 형태`
- The hand-off line: `컴포넌트 경계 자체가 바뀌면 → architecture; 스키마
  신설/변경이면 → data-modeling`

**Replace with:** a short reference stub, e.g.:

```markdown
# api-design warrant-hunter

This role uses core canon's warrant-hunt plugin (core `warrant/`, core
issue #63) directly — no local copy of the hunt mandate or stance
rotation is maintained here.

Role-specific parameters passed to the core plugin:
- Decision boundary: 서비스 경계의 인터페이스 형태
- Hand-off: 컴포넌트 경계 자체가 바뀌면 → architecture; 스키마 신설/변경이면
  → data-modeling
```

Open question for phase-2 execution (not resolved here, since core is not
checked out in this repo): confirm the exact mechanism core's `warrant/`
plugin uses to receive a role's decision-boundary/hand-off parameters
(config file vs. convention vs. no parameterization at all — in which
case this file may reduce to a one-line pointer with no parameter block).

## 2. Remove gate copies + their `hooks.json` registrations

**Remove entirely** (per the issue's explicit grouping of these three as
the "역할 무관 게이트 3종"):
- `api-design/hooks/trailer-gate.sh` — confirmed role-agnostic by its own
  header comment ("this file's logic is role-agnostic"). Safe to delete
  outright; no role-unique content found in survey.
- `api-design/hooks/handbook-trigger-gate.sh` — grouped as role-agnostic
  by the issue; currently a no-op placeholder in this repo regardless, so
  nothing load-bearing is lost.

**Remove the gate-registration entries** for these two from
`api-design/hooks/hooks.json`'s `PreToolUse` block (the `Bash` matcher
entries), since core issue #66 registers these on the core side via
injected `CLAUDE_ROLE`.

**Do not blanket-remove `record-fields-gate.sh`.** Per survey finding,
this file bundles role-agnostic gate mechanics (JSON payload parsing,
deny/exit-2 pattern, python3 dependency check) with role-specific
configuration (`REQUIRED_FIELDS = ["interface-spec", "lifecycle-plan"]`,
target path suffix `/reports/api-design.md`). Two sub-options, to be
decided during phase-2 execution once core's actual generic-gate
interface is known:

- **2a (preferred if core supports it):** if core's centralized gate
  registration (core issue #66) can accept role-supplied config (a
  required-fields list + record path pattern), remove this file entirely
  too and move `REQUIRED_FIELDS`/path into whatever config surface core
  defines (e.g. a `role-config.sh` or JSON file this repo owns).
- **2b (fallback):** if core only centralizes the 3 gates that are
  *fully* role-agnostic and record-fields-gate's role-specific values
  make it structurally different, keep a thin `record-fields-gate.sh`
  stub in this repo that sources shared mechanics from core (mirroring
  the directive.sh stub pattern in item 3) and supplies only
  `REQUIRED_FIELDS` and the record path as local config.

This ambiguity is flagged explicitly rather than guessed at, since
resolving it requires reading core's actual registration mechanism
(unavailable in this workspace — see survey.md's cross-repo-dependency
note).

**Update `hooks.json`** accordingly: drop the `trailer-gate.sh` and
`handbook-trigger-gate.sh` command entries from the `Bash` matcher; keep
(or replace with a stub reference) the `record-fields-gate.sh` entry
under `Write|Edit|MultiEdit|NotebookEdit` per whichever of 2a/2b is
chosen; keep the `SessionStart` → `directive.sh` entry (directive.sh
itself becomes a stub per item 3, but its registration in this repo's
`hooks.json` is unaffected unless core also centralizes SessionStart
invocation, which the issue does not claim).

## 3. Replace `directive.sh` with a stub sourcing `core_role_directive`

**Remove:** the boilerplate currently duplicated in
`api-design/hooks/directive.sh` — the `trap`/`set -uo pipefail`/kill-switch
`case`/`CLAUDE_ROLE` guard (lines 4–8), which the issue identifies as
now centralized in `core/hooks/lib/role-directive.sh`'s
`core_role_directive` function.

**Keep / preserve (role-unique):** the entire heredoc body (lines 10–30):
YOU DECIDE, USE_WHEN, PRODUCES, WRITE_SCOPE, HAND-OFF, BOUNDARY CASE text,
and the RECORD path/phase-gating note — this is api-design's own doctrine
and exists nowhere else.

**Proposed stub shape** (exact sourcing syntax to be confirmed against
core's real file in phase 2; this is illustrative):

```bash
#!/usr/bin/env bash
# SessionStart: api-design's role directive. Shared boilerplate lives in
# core/hooks/lib/role-directive.sh (core_role_directive). Kill switch:
# export API_DESIGN_CYCLE_OFF=1
source "${CLAUDE_PLUGIN_ROOT}/../../core/hooks/lib/role-directive.sh"

core_role_directive "api-design" "API_DESIGN_CYCLE_OFF" <<'DIRECTIVE'
[api-design] Role directive (on top of core's protocol):

YOU DECIDE: 서비스 경계의 인터페이스 형태
USE_WHEN: 여러 소비자가 걸리는 API 표면을 설계/변경할 때
PRODUCES (required record fields): interface spec (endpoints/schema/versioning), lifecycle/deprecation plan
WRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)
HAND-OFF: 컴포넌트 경계 자체가 바뀌면 → architecture; 스키마 신설/변경이면 → data-modeling

BOUNDARY CASE: if the work in front of you drifts outside `decides` above,
stop and hand off per the arrow — do not silently absorb another role's
scope. Record the hand-off point in this role's record before opening the
next role's session.

RECORD: docs/issue-<n>/reports/api-design.md, phase-gated per contract v3 s19
(phase-1 homes only pre-Approve; this record is phase-2 output).
DIRECTIVE
```

The exact function signature (positional args vs. env vars, how the
kill-switch variable name is passed) must be confirmed against core's
actual `role-directive.sh` in phase 2 — this repo cannot verify it now
(no core checkout present).

## 4. Preserve role-specific real differences explicitly via config

Per survey finding, this repo currently has **no**
`RECORD_FIELDS_TERMINAL_STATES` (or equivalent) setting and no documented
multi-state lifecycle/terminal-states concept at all — api-design is a
report-only role (`write_scope: []`) with a single record file, not a
role with distinct in-flight vs. terminal loop states.

**Proposal:** rather than inventing a terminal-states list with no basis,
phase-2 execution should:
- Confirm whether core's generic record-fields gate actually requires
  every role to define `RECORD_FIELDS_TERMINAL_STATES`, or whether it is
  optional/defaults sensibly for roles with no multi-state lifecycle.
- If required: set it to the minimal defensible value for this role,
  e.g. a single terminal state (`RECORD_FIELDS_TERMINAL_STATES=("handed-off")`
  or similar), explicitly derived from this role's `HAND-OFF` semantics
  (the record is "terminal" once a hand-off has been recorded), not
  copied from another role.
- If optional/not applicable: document explicitly in the phase-2 record
  that this role has no terminal-states variance beyond the default, so
  a future reader doesn't mistake the omission for an oversight.

The two settings this repo *does* already have and that must carry over
verbatim regardless of the 2a/2b choice in item 2:
- `REQUIRED_FIELDS = ["interface-spec", "lifecycle-plan"]`
- record path suffix `/reports/api-design.md`

## 5. Confirm `core/hooks/tests/stub-check.sh` passes; record it

This cannot be executed from this repo today (no `core/` tree is checked
out or linked here — see survey.md). Phase-2 execution must:
1. Obtain access to core canon (submodule, sibling checkout, or CI
   context that has both repos) sufficient to run
   `core/hooks/tests/stub-check.sh` against this repo's post-conversion
   `directive.sh` (and `record-fields-gate.sh` if item 2 keeps a stub).
2. Record the pass result (command run, output, date) in this role's
   phase-2 record file, `docs/issue-2/reports/implementation.md`
   (top-level, per contract v3 — not the `reports/implementation/`
   subdirectory used for phase-1 artifacts).
3. If stub-check fails, fix the stub shape before considering this
   action item done — do not report success without a passing run.

## Net file-level plan (summary)

| File | Action |
|---|---|
| `api-design/agents/warrant-hunter.md` | Replace body with reference stub; keep decision-boundary + hand-off lines |
| `api-design/hooks/trailer-gate.sh` | Delete |
| `api-design/hooks/handbook-trigger-gate.sh` | Delete |
| `api-design/hooks/record-fields-gate.sh` | Delete (2a) or thin to a stub sourcing shared mechanics + local `REQUIRED_FIELDS`/path/terminal-states config (2b) — decide in phase 2 against core's real interface |
| `api-design/hooks/directive.sh` | Replace boilerplate with `source .../role-directive.sh; core_role_directive ...`; keep full doctrine heredoc |
| `api-design/hooks/hooks.json` | Drop entries for deleted gates; keep/adjust remaining entries |
| `README.md` | Update "Layout" section to match post-conversion file list (phase 2) |
| `docs/issue-2/reports/implementation.md` | New in phase 2: record stub-check pass result and any 2a/2b decision made |

## Explicitly out of scope for this proposal

- No approvers.md changes (empty file remains empty; single-account-mode
  APPROVE remains the only currently-available approval path unless a
  human populates it separately).
- No actual edits to any file under `api-design/` or `README.md` — those
  are phase-2 execution, gated on Approve.
