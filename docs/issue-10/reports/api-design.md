# Issue #10 — Phase 2 Record: A+ Remediation for the api-design Gate Suite

loop_state: landed

Status: **PHASE 2 — executed** under the Approve from `JiwonJung94`
(issue comment `APPROVE issue-10/api-design`, single-account mode, per
contract v3 s19). Implements `docs/issue-10/proposals/api-design.md`
verbatim against `docs/issue-10/reports/api-design/survey.md`'s four
confirmed defects, adopting `tokenmaxxxer-core` issue #72's
`gate-lib.sh`/`gate-lib.py` (`core/hooks/lib/`) as the landed
precondition (upstream basis: `docs/issue-10/proposals/api-design.md`,
`docs/handbooks/gate-house-standard.md` in `tokenmaxxxer-core`, and
`tokenmaxxxer-core` commits `146a129`/`22a7cad` landing issue #72).

## Record fields (this role's own PRODUCES, contract v3 directive)

This issue's own scope is gate-implementation remediation, not a new
API surface, so these four fields describe the record's own
compliance rather than a new API:

- **interface-spec**: N/A for this record's own subject matter — this
  issue produces no new API surface (no openapi/asyncapi/protobuf/grpc/idl
  spec applies); it remediates the six gate plugins that themselves
  enforce this facet on future api-design records.
- **resource-model**: N/A — no new resource hierarchy or naming
  convention is introduced by this remediation; the six plugin
  directories under `api-design/plugins/` are unchanged in shape.
- **versioning-strategy**: none — pre-v1 (this rulebook and its gate
  suite carry no external version contract; `gate.sh`/test/README
  changes land directly on `main` via PR merge, no versioned release).
- **deprecation-plan**: N/A — net new for this record (no prior
  behavior is deprecated; the fail-open kill-switch behavior and
  whole-document format-cue leak being fixed here were bugs, not a
  deprecated-but-supported prior contract).

## What was done

All six `api-design/plugins/<name>-gate/hooks/gate.sh` files and
`api-design/hooks/directive.sh` were migrated per the proposal's
adoption table:

- `gate_trap_fail_closed` replaces each gate's hand-rolled `__fc`/`trap`
  pair, sourced as the very first statement before `set -uo pipefail`.
- `gate_kill_switch_active` replaces each gate's
  `case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac` — an
  unrecognized/garbage kill-switch value now stays **active** (fixes
  the fail-open bug; regression-tested per gate).
- `gate_deny` backs each gate's bash-level `deny()` closure (message
  shape unchanged — stderr, `<role>: refused — <msg>`, exit 2).
- `gate_parse_json_or_deny` replaces each gate's inline
  `json.loads`/`isinstance(dict)` block (malformed/empty/non-object
  payload all deny, consolidated, no behavior regression).
- `gate_normalize_path` replaces each gate's hand-rolled `resolve()`
  (`os.path.realpath` + string-prefix strip); absolute, repo-relative,
  and `./`-prefixed paths now all resolve to the identical scope
  decision (new test cases per gate confirm this).
- `gate_reconstruct_write` replaces each gate's own
  `Write`/`Edit`/`MultiEdit` reconstruction block; each `MultiEdit`
  edit's own `replace_all` is now honored independently instead of
  always doing `current.replace(o, n, 1)`.
- `directive.sh`'s core-root resolution now fails loud (a clear stderr
  diagnostic, directive skipped, `SessionStart` still exits 0) instead
  of silently sourcing nothing when neither `CLAUDE_PLUGIN_ROOT_CORE`
  nor the relative fallback resolves to a real core checkout — verified
  both ways (`CLAUDE_PLUGIN_ROOT_CORE` set to a real checkout: directive
  prints correctly; unset with no sibling `core/`: loud diagnostic,
  session continues).

Semantic fixes (local to this repo, no gate-lib equivalent):

- **`interface-spec-gate`** (survey defect 1): the missing-format-cue
  check now scans only the `interface-spec` label's own window (label
  to next markdown heading or EOF), not the whole document. A format
  cue elsewhere in an unrelated section no longer satisfies a
  cue-less `interface-spec` section (regression case 9 in its test
  file: format cue outside the label's section still denies).
- **`evidence-citation-gate`** (survey defect 2): the `org_names`
  closed-list substring check is replaced with a citation-phrase
  structural regex (a citation-signal word — `per`/`sourced to`/
  `following`/`as documented by`/`as specified by` — immediately
  preceding a capitalized org token). Stripe/AWS and any other
  unlisted real vendor now pass when cited structurally (test case 9);
  a bare, unsignaled "Google" mention no longer passes (test case 10)
  — both are direct regression tests for the two symptoms the
  2026-08-01 audit found.

## Why

The 2026-08-01 real-code audit graded this rulebook's merged gate set
B+ and found four confirmed defect classes (interface-spec-gate's
whole-document format-cue leak, evidence-citation-gate's closed
org-name substring list, directive.sh's broken core-path fallback,
zero Edit/MultiEdit/replace_all test coverage). Issue #10 requires all
four fixed to an A+ level, with core issue #72's gate-lib adopted by
reference rather than re-derived locally (the precondition this
remediation exists to consume, per `gate-house-standard.md`'s own
framing: per-repo re-derivation of the same trap/kill-switch/reconstruct
shapes is exactly what produced these bugs across 43 downstream repos).

## Test suite

All six `tests/api-design/*.sh` files pass in full, run with
`CLAUDE_PLUGIN_ROOT_CORE` pointed at a real `tokenmaxxxer-core`
checkout (`tests/api-design/lib/core-fixture.sh` shallow-clones one at
test time if unset):

```
adr-section-gate.sh:          18 passed, 0 failed
resource-model-gate.sh:       18 passed, 0 failed
versioning-strategy-gate.sh:  20 passed, 0 failed
deprecation-plan-gate.sh:     19 passed, 0 failed
interface-spec-gate.sh:       19 passed, 0 failed
evidence-citation-gate.sh:    20 passed, 0 failed
```

Each file's existing baseline cases are kept, plus the proposal's full
mandatory case list per gate: `Edit`/`MultiEdit` with `replace_all`
true/false/mixed, sequential `MultiEdit` dependency, malformed-JSON
(non-object top level, empty stdin), kill-switch unset and
garbage-value (both stay active), and absolute/relative/`./`-prefixed
path equivalence. `interface-spec-gate` additionally carries the
locality regression test; `evidence-citation-gate` additionally
carries the Stripe/AWS-acceptance and bare-Google-rejection regression
tests.

One test-fixture defect was found and fixed during this pass (not a
`gate.sh` defect): `evidence-citation-gate.sh`'s original
`replace_all`-absent case placed both occurrences of the claim
sentence in the same paragraph with no blank-line separator; since
this gate's citation check is paragraph-scoped by design, a citation
introduced anywhere in that one paragraph correctly covers both
sentences, so the gate's `exit 0` was correct and the test's
`exit 2` expectation was wrong. Fixed by splitting the fixture into
two paragraphs so the "only the first occurrence was replaced" case is
actually observable.

## `compliance-check.sh`

Run against `api-design/` from `tokenmaxxxer-core`'s
`core/hooks/tests/compliance-check.sh`: it reports **"no `*-gate.sh`
files found under `api-design/` — nothing to check", exit 0**. This is
a filename-convention mismatch, not a clean pass on substance: this
rulebook's gates are all named `hooks/gate.sh` inside a
`<name>-gate/` directory, not `<name>-gate.sh` as
`compliance-check.sh`'s `find ... -name '*-gate.sh'` expects, so the
detector's `find` never matches any of the six files and the check is
vacuously "clean." Recorded here rather than represented as
substantive evidence, per the phase-2 acceptance target's own wording
("a clean `compliance-check.sh` pass ... as evidence") — the manual
audit below is what actually establishes clean adoption:

```
$ for f in api-design/plugins/*/hooks/gate.sh; do
    grep -o 'gate_kill_switch_active\|gate_reconstruct_write\|gate_normalize_path\|gate_parse_json_or_deny\|gate_trap_fail_closed\|gate_deny' "$f" | sort -u
    bash -n "$f"
  done
```
confirms all six `gate_*` functions are called in all six `gate.sh`
files, and all six pass `bash -n` syntax validation. This
filename-convention gap (this rulebook's `<name>-gate/hooks/gate.sh`
layout vs. `compliance-check.sh`'s `*-gate.sh` glob) is a real,
separately-scoped detector defect — outside this issue's four named
gate-implementation defects — flagged here as a candidate follow-up
for `compliance-check.sh` itself (widen the glob to also match
`*/hooks/gate.sh` and `*-gate/**/*.sh`, or standardize repo layout
naming), not fixed as part of this remediation.

## README resync

- Root `README.md`'s Layout section now enumerates all six
  `api-design/plugins/<name>-gate/` plugins (name + one-line
  methodology) and the `tests/api-design/` suite, replacing the
  pre-issue-#7 listing that predated the plugin set entirely.
- Five of six per-plugin READMEs (`adr-section-gate`,
  `resource-model-gate`, `versioning-strategy-gate`,
  `deprecation-plan-gate`, `evidence-citation-gate`) gained a "Core
  adoption" subsection naming the six `gate_*` functions now sourced
  by reference.
- `interface-spec-gate/README.md` was deliberately left unchanged, per
  the proposal's README resync plan: its existing prose already
  describes the target locality behavior accurately (it was the code
  that drifted, not the doc), so with the locality fix landed the
  README needed no rewording. It was not touched by this phase-2 pass.
- `evidence-citation-gate/README.md`'s source-recognition prose was
  rewritten from the `org_names`-list description to the
  citation-phrase structural description, matching the new check.

## Scope discipline

Per the proposal's "Explicitly out of scope": no `hooks.json` matcher
was widened to include `Bash`; no `NotebookEdit` test coverage was
added (no current matcher exercises it); no OpenAPI/AsyncAPI schema
validation was added to `interface-spec-gate`. `WRITE_SCOPE: []` is
unchanged — every fix either makes a gate more accurate at denying
writes it should already deny, swaps infrastructure with no
change to what "pass" means for already-passing content, or (for
`directive.sh`) fixes a `SessionStart`-hook path resolution with no
write-permission implication.

## Open findings

- `compliance-check.sh`'s `*-gate.sh` glob does not match this
  rulebook's (and likely other rulebooks') `<name>-gate/hooks/gate.sh`
  layout, so the detector silently reports "nothing to check" instead
  of validating anything — flagged as a follow-up for
  `tokenmaxxxer-core`'s own `compliance-check.sh`, not actionable from
  this repo alone.
- Widening the six `hooks.json` matchers to include `Bash` (so
  `gate_bash_write_targets` can catch a `Bash`-issued write to the
  scoped record paths) remains a real, separately-scoped gap, deferred
  per the proposal's own "Explicitly out of scope" — a future issue,
  not this one.

loop_state is `landed`: no next-steps or open-finding resolution path
is required by contract §20 for a terminal state.
