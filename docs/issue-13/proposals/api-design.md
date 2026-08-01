# Proposal — issue #13: 게이트 A+ 최종 마감 (재감사 잔여 결함 보수)

Subject: issue-13. Phase 1 (survey + proposal) only — no APPROVE requested,
no execution work in this PR. See
`docs/issue-13/reports/api-design/current-state.md` for the full survey and
re-verification of each defect claim, and
`docs/issue-13/reports/api-design/scout-brief.md` for the scout skip
record.

## Context

Issue #13 is a re-audit remediation (grade A-) against this repo's six
`api-design/plugins/*/hooks/gate.sh` methodology gates, listing four
required fixes plus a "공통 외" defect list. Two preconditions were
required to land first: core#75 (gate-lib source guard + compliance-check
rule + missing-core test + `gate_bash_write_targets` py parity) and
on-the-record#182 (`CLAUDE_PLUGIN_ROOT_CORE` injection in `spawn.py`).
Both are confirmed landed — core#75 as commit `52bdc15` in
`tokenmaxxxer-core`, on-the-record#182 as commit `e50fe08` on branch
`issue-182/implementation` (code-complete, not yet merged to main).

Direct re-verification against the current gate code (not the issue text
alone) found the "공통 외" list only partially reproducible:

- The citation-gate defect ("실선행 API(Stripe/AWS) 거부·'google' 부분문자열
  통과") and the interface-spec-gate "전역 grep" defect were both already
  fixed in commit `8b2eda1` (issue #10 phase 2). Running
  `tests/api-design/evidence-citation-gate.sh` confirms all 20 cases pass,
  including the Stripe/AWS-acceptance and bare-Google-rejection regression
  cases added in that commit.
- `interface-spec-gate` does have one narrower, real locality gap: its
  format-cue window falls back to "rest of document" when the
  `interface-spec` label has no following Markdown heading, instead of a
  bounded window.
- All six gates are missing core#75's `||` source guard on their
  `gate-lib.sh` sourcing line — this is the one defect class confirmed
  present across the whole plugin set, and it is the exact fail-open
  pattern (undefined `gate_kill_switch_active` on missing core silently
  reads as "kill switch off" at every `... || { exit 0; }` call site) that
  core#75 fixed at the core layer, per core's own gate-lib.sh usage-contract
  comment (`tokenmaxxxer-core` commit `52bdc15`).
- `hooks.json` matcher coverage (`Write|Edit|MultiEdit`) already matches
  each gate's code-level `tool in ("Write","Edit","MultiEdit")` handling in
  all six plugins — the requirement-2 gap is test coverage, not
  reachability: `adr-section-gate.sh` and `interface-spec-gate.sh` have
  zero MultiEdit-payload test cases while the other four have 1-2 each.
- README/manifest sweep (top-level + all six plugin READMEs +
  `.claude-plugin/plugin.json` manifests) found no stale 43-taxonomy role
  names and no references to files absent on disk.

## Decision

Fix, in phase 2, exactly the defects confirmed present by direct
re-verification — not the full issue-text list, since two of its four
"공통 외" claims no longer reproduce against current code:

1. Add core#75's `||`-guarded source line to all six
   `api-design/plugins/*/hooks/gate.sh`, verbatim per core's own
   usage-contract comment: `. "$_gate_lib_core_root/hooks/lib/gate-lib.sh"
   || { echo "<gate-name>: cannot source gate-lib.sh" >&2; exit 2; }`.
2. Bound `interface-spec-gate`'s fallback window to a fixed span (e.g. the
   label's own paragraph, or N lines) instead of "rest of document" when
   no following heading exists, so a label placed as the file's last
   section can't pull in unrelated trailing content as its own cue window.
3. Add one MultiEdit-payload regression test case each to
   `tests/api-design/adr-section-gate.sh` and
   `tests/api-design/interface-spec-gate.sh`, following the existing
   MultiEdit-case shape already used in the other four suites (sequential
   dependent edits + `replace_all` variants, per
   `docs/issue-10/reports/api-design/current-state.md`'s established
   pattern for this repo).
4. Add (or, if core's compliance-check.sh is the delivery vehicle,
   confirm coverage from) a repo-level check that the whole plugin set
   passes core#75's new `compliance-check.sh` `||`-guard detection rule,
   and a missing-core deny test case per gate mirroring core#75's own
   missing-core test — closing requirement 3 ("missing-core 케이스 포함 전
   스위트 배송 상태 green").
5. Leave requirement 4 (README/manifest stale-name/ghost-file sweep) as a
   re-check-only step in phase 2, since the phase-1 sweep found nothing to
   fix; re-run it after 1-4 land in case those edits introduce new drift.

`gate_bash_write_targets` is out of scope for this repo: no api-design
gate parses `Bash` tool_input, so there is no call site to port it to.

## Alternatives considered

- **Fix the full issue-text defect list as written, including the
  citation-gate and interface-spec "전역 grep" items.** Rejected: both
  reproduce as passing, not failing, against current code and current
  tests (20/20 in `evidence-citation-gate.sh`); "fixing" a passing
  regression test set with no failing case to drive the change would be
  fixing the wrong target and risks silently regressing the already-correct
  citation-phrase logic.
- **Defer the `||` source-guard fix to whenever core#75 lands on `main`
  and is pulled via a routine dependency bump, rather than proposing it
  now.** Rejected: core#75 is already landed in the core repo (commit
  `52bdc15`) and is the explicit precondition issue #13 names as
  "이미 랜딩됨" — the fix pattern is available to reference-apply today, and
  every api-design gate is currently fail-open on missing core, which is
  the exact defect class this issue exists to close.
- **Treat the interface-spec-gate "rest of document" fallback as
  low-priority given it only triggers when the label is the file's last
  section.** Rejected: leaving it unfixed while touching this exact file
  for the source-guard change means shipping a phase-2 diff that visibly
  brushes past a known, narrow locality gap in the same function.

## Rationale

Scoping phase 2 to what direct re-verification confirmed, rather than the
full issue-text list, follows this repo's own evidence-citation
discipline (issue #1): a defect claim gets acted on only when the claim
is checked against current code, not carried forward from the audit text
unverified. The `||` source-guard port is the highest-priority item
because it is a fail-open (silent-allow) defect, not a fail-closed
(over-strict) one — the two already-fixed citation/interface-spec items
were the opposite risk (false denies on legitimate content), which is
lower severity and, per re-verification, no longer present anyway. The
MultiEdit test-gap and compliance-check/missing-core work close out the
issue's explicit test-coverage and matcher-code-parity requirements with
the smallest diff that makes both true.

## Consequences

- All six gates fail closed (exit 2, not a silent allow) when
  `CLAUDE_PLUGIN_ROOT_CORE` is set but the resolved path's `gate-lib.sh`
  fails to source for any reason other than the already-guarded "no core
  root found" case — closing the fail-open gap core#75 fixed at the core
  layer.
- `interface-spec-gate`'s cue check becomes strictly local to the label's
  own section in every case, including the last-section case, matching
  its documented "국소성" intent.
- Test suites gain MultiEdit coverage in the two plugins currently at
  zero, bringing all six to parity.
- The re-audit's citation-gate and interface-spec "전역 grep" items close
  as "already fixed, re-verified" rather than "fixed again" — phase 2's
  record should state this explicitly so the re-audit trail is accurate
  rather than implying rework that didn't happen.
- Requirement 4 (README/manifest) closes as "swept, no defects found" in
  phase 1; phase 2 re-runs the sweep once after 1-4 land as a cheap
  regression check, not as new remediation work.
