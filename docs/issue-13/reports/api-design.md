# Issue #13 — Phase 2 Record: Gate A+ Final Close-Out (Re-Audit Remediation)

loop_state: landed

Status: **PHASE 2 — executed** under the Approve from `jiwon.jung@thakicloud.co.kr`
(issue comment `APPROVE issue-13/api-design`, single-account mode, per
contract v3 s19). Implements `docs/issue-13/proposals/api-design.md`'s
"Decision" section (items 1-5) verbatim against
`docs/issue-13/reports/api-design/current-state.md`'s confirmed defect
list, consuming `tokenmaxxxer-core` issue #75 (`52bdc15`) as the landed
precondition for the `||`-guarded `gate-lib.sh` source line and
`compliance-check.sh`'s guard-detection rule.

## Record fields (this role's own PRODUCES, contract v3 directive)

Same framing as issue #10's phase-2 record: this issue's scope is gate-
implementation remediation, not a new API surface.

- **interface-spec**: N/A for this record's own subject matter — no new
  openapi/asyncapi/protobuf/grpc/idl spec applies; this remediation
  tightens the locality of the check the `interface-spec-gate` itself
  enforces on future records.
- **resource-model**: N/A — no new resource hierarchy or naming
  convention is introduced; the six plugin directories under
  `api-design/plugins/` are unchanged in shape.
- **versioning-strategy**: none — pre-v1 (unchanged from issue #10's
  record: this rulebook carries no external version contract).
- **deprecation-plan**: N/A — net new for this record (the fail-open
  source-guard gap and the interface-spec locality gap fixed here were
  bugs, not a deprecated-but-supported prior contract).

## What was done

1. **`||`-guarded `gate-lib.sh` source line, all six gates.** Each
   `api-design/plugins/<name>-gate/hooks/gate.sh` previously had an
   unguarded `. "$_gate_lib_core_root/hooks/lib/gate-lib.sh"` on its own
   line, reached only after an existing `[ ! -f ... ]` pre-check. That
   pre-check already caught the common "core root not found at all"
   case, but left a real fail-open gap: if `CLAUDE_PLUGIN_ROOT_CORE`
   resolves to a real path whose `gate-lib.sh` *exists* but fails to
   source for any other reason (permission error, syntax error, etc.),
   an unguarded `source` runs no code — including no `gate_*` function
   definitions — after which every `gate_kill_switch_active ... ||
   { exit 0; }` call site reads the resulting "command not found" (127)
   as the kill switch being off, silently allowing everything. Fixed by
   adding core#75's guard verbatim, using this repo's own existing
   `_gate_lib_core_root` variable name and each gate's own
   `api-design/<name>-gate` role-name prefix in the error message:
   ```
   . "$_gate_lib_core_root/hooks/lib/gate-lib.sh" || { echo "api-design/<name>-gate: cannot source gate-lib.sh" >&2; exit 2; }
   ```
   Verified with a fixture core whose `gate-lib.sh` exists but is
   syntactically invalid: all six gates now exit 2 (previously,
   pre-fix, would have hit the same problem the guard exists to close).

2. **`interface-spec-gate` locality gap.** The format-cue window
   (`api-design/plugins/interface-spec-gate/hooks/gate.sh`) fell back to
   "rest of document" when the `interface-spec` label had no following
   Markdown heading (i.e., the label is the file's last section).
   Bounded that fallback to a fixed 40-line cap instead, matching the
   file's existing paragraph/section-scale windowing style used for the
   heading-present case:
   ```python
   if next_heading:
       window = after[:next_heading.start()]
   else:
       window = "\n".join(after.split("\n")[:40])
   ```
   A new MultiEdit-payload regression test (case 20 in
   `tests/api-design/interface-spec-gate.sh`) places a format cue past
   this cap when the label is the last section and confirms the gate
   now denies rather than incorrectly reading past the section.

3. **MultiEdit test coverage, `adr-section-gate` and
   `interface-spec-gate`.** Direct inspection of these two test files
   found they already contained MultiEdit-payload cases (sequential
   dependent edits + mixed-`replace_all` variants) landed in `8b2eda1`
   (issue #10 phase 2) — the phase-1 survey's `grep -c '"MultiEdit"'`
   check produced a false negative because these two files build their
   payloads via Python single-quoted string literals (`'MultiEdit'`)
   rather than the double-quoted JSON literal the grep pattern expected;
   the coverage was already present under a different quoting style. To
   still close the letter of the proposal's item 3 with a genuinely new
   case (not a duplicate of existing coverage), added:
   - `adr-section-gate.sh` case 19: a MultiEdit call with two edits that
     each fill a *different* ADR section's placeholder in the same call
     (not sequentially dependent, unlike the existing cases) — exit 0.
   - `interface-spec-gate.sh` case 20: the locality-fix regression test
     described in item 2 above, delivered as a MultiEdit payload.

4. **Missing-core deny test, all six gates.** Added one test case per
   `tests/api-design/*.sh` file mirroring core#75's own missing-core
   test pattern (`tokenmaxxxer-core`'s `run-gate-lib-tests.sh` group 7):
   `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path under the
   test's own scratch dir, asserting exit 2 (fail-closed) rather than a
   silent allow. All six new cases pass. Also ran core's
   `compliance-check.sh` (`tokenmaxxxer-core/core/hooks/tests/compliance-check.sh`,
   found at `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core` on this
   machine) against a scratch copy of the six gate files renamed to
   match its `*-gate.sh` glob (its `find -name '*-gate.sh'` does not
   match this repo's actual `<name>-gate/hooks/gate.sh` layout — the
   same filename-convention gap issue #10's phase-2 record already
   flagged as a `compliance-check.sh` follow-up, not fixed here since
   it's out of this repo's scope): all six report `compliance-check: ok`,
   confirming the `||`-guard detection rule (its issue-75-added check)
   now passes for all six gates. See "`compliance-check.sh`" section
   below for the exact commands run.

5. **README/manifest sweep.** Re-ran after 1-4 landed. No stale
   43-taxonomy role names and no ghost-file references found across the
   top-level `README.md`, all six plugin `README.md`s, and all six
   `.claude-plugin/plugin.json` manifests — confirmed by an independent
   read-only sweep. Nothing to fix; re-check only, per the proposal.

## Re-verified as already-fixed (not reworked)

Per the proposal's rationale, the issue text's citation-gate
("실선행 API(Stripe/AWS) 거부·'google' 부분문자열 통과") and interface-spec
"전역 grep" (whole-document grep) claims were **not** reworked in this
phase. Both were confirmed fixed already in `8b2eda1` (issue #10 phase
2), before issue #13 was filed:

- `evidence-citation-gate`'s citation-phrase structural regex (not a
  closed org-name substring list) correctly accepts "per Stripe's API
  design review practice" / "following AWS's API guidelines" and
  correctly rejects a bare unsignaled "Google" mention — verified by
  running `tests/api-design/evidence-citation-gate.sh` directly (all
  cases pass, including case 9's Stripe/AWS-acceptance and case 10's
  bare-Google-rejection regressions) and reading
  `evidence-citation-gate/hooks/gate.sh` directly: no substring/domain
  matching on "google" exists anywhere in this gate.
- `interface-spec-gate`'s format-cue check was already windowed to the
  label's own section (label to next Markdown heading), not a
  whole-document grep, before this phase-2 pass. The one *real* gap —
  the narrower "falls back to rest of document only when no following
  heading exists" case — is what item 2 above closes; the issue text's
  broader "전역 grep" description does not (and did not, as of `8b2eda1`)
  reproduce.

This phase-2 record states this explicitly, per the proposal's
Consequences section, so the re-audit trail reads as "already fixed,
re-verified" rather than implying rework that didn't happen.

## Test suite

All six `tests/api-design/*.sh` files pass in full, run with
`CLAUDE_PLUGIN_ROOT_CORE` pointed at a real `tokenmaxxxer-core` checkout:

```
adr-section-gate.sh:          20 passed, 0 failed
deprecation-plan-gate.sh:     20 passed, 0 failed
evidence-citation-gate.sh:    20 passed, 0 failed
interface-spec-gate.sh:       21 passed, 0 failed
resource-model-gate.sh:       19 passed, 0 failed
versioning-strategy-gate.sh:  21 passed, 0 failed
```

Total: 121 cases, 0 failures. Each file's full pre-existing baseline
(issue #7 phase 2 + issue #10 phase 2 coverage) is kept unchanged; this
phase adds one new MultiEdit case to `adr-section-gate.sh` and one new
MultiEdit locality-regression case to `interface-spec-gate.sh` (item 3
above), plus one missing-core deny case to every one of the six files
(item 4 above).

## `compliance-check.sh`

Run directly against `api-design/` (this repo's actual layout):

```
$ bash /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/compliance-check.sh api-design
compliance-check: no *-gate.sh files found under api-design — nothing to check
```

This reproduces the same filename-convention mismatch issue #10's
phase-2 record already documented: this rulebook's gates are all named
`hooks/gate.sh` inside a `<name>-gate/` directory (also past
`compliance-check.sh`'s `-maxdepth 3` from the `api-design/` root), not
`<name>-gate.sh` as its `find ... -name '*-gate.sh'` expects, so the
detector's `find` never matches any of the six files and the check is
vacuously "clean" — not evidence of a substantive pass.

To get substantive coverage of the actual detection rule issue #13
cares about (the `||`-guard check core#75 added), a scratch copy of the
six `gate.sh` files was renamed to match the glob and checked directly:

```
$ for d in api-design/plugins/*/; do
    name=$(basename "$d")
    cp "$d/hooks/gate.sh" "$SCRATCH/$name.sh"
  done
$ bash /home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/compliance-check.sh "$SCRATCH"
compliance-check: ok — .../adr-section-gate.sh
compliance-check: ok — .../resource-model-gate.sh
compliance-check: ok — .../evidence-citation-gate.sh
compliance-check: ok — .../versioning-strategy-gate.sh
compliance-check: ok — .../interface-spec-gate.sh
compliance-check: ok — .../deprecation-plan-gate.sh
rc=0
```

All six report `ok` (no `||`-guard-missing reason, no kill-switch or
`gate_reconstruct_write` reasons either) — this is the actual evidence
that the item-1 fix satisfies compliance-check's guard-detection rule.
The filename-convention gap itself is not fixed here (same as issue
#10's disposition): it's a `tokenmaxxxer-core` `compliance-check.sh`
follow-up, not actionable from this repo alone, and is not one of the
proposal's five decision items.

## README/manifest sweep result

Re-run after items 1-4 landed, per the proposal's item 5. No stale
43-taxonomy role names found (every role name mentioned across all
swept files is one of the six current api-design gates or the parent
`api-design` role itself); no references to files absent on disk found
(every `hooks/gate.sh`, `hooks/hooks.json`,
`tests/api-design/lib/core-fixture.sh`, and manifest-cited path was
confirmed present). Nothing required fixing.

## Scope discipline

Per the proposal: `gate_bash_write_targets` was not ported (no
api-design gate parses `Bash` tool_input, so there is no call site).
No `hooks.json` matcher was widened. No new methodology-check semantics
were added beyond the interface-spec-gate window bound in item 2. The
citation-gate and interface-spec "전역 grep" issue-text items were left
un-reworked, as documented above.

## Open findings

- `compliance-check.sh`'s `*-gate.sh` glob still does not match this
  rulebook's (and likely other rulebooks') `<name>-gate/hooks/gate.sh`
  layout, so the detector silently reports "nothing to check" instead
  of validating anything against the real repo layout — the same gap
  issue #10's phase-2 record flagged, still unfixed, and still a
  follow-up for `tokenmaxxxer-core`'s own `compliance-check.sh`, not
  actionable from this repo alone.
- No other open findings from this phase-2 pass: all five decision
  items landed, the full test suite is green, and the README/manifest
  re-sweep found nothing to fix.

loop_state is `landed`: no next-steps or open-finding resolution path
is required by contract §20 for a terminal state.
