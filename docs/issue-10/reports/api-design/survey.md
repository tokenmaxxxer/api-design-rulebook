# Issue #10 — Current-State Survey (Phase 1)

## Scope note

The task brief (and the issue's own paraphrase) refers to "5 gates."
The actual plugin count in this repo is **six**: `adr-section-gate`,
`evidence-citation-gate`, `interface-spec-gate`, `resource-model-gate`,
`versioning-strategy-gate`, `deprecation-plan-gate` (all six listed in
`.claude-plugin/marketplace.json` and present under
`api-design/plugins/`). `adr-section-gate` was omitted from the issue's
explicit read list but shares the exact same `gate.sh` skeleton
(fail-closed trap, kill-switch case, three-tier root detection,
`old_string`/`new_string` reconstruction) as the other five, so it
carries the same structural defects (#1's path-normalization approach,
#3's transitive dependency on `directive.sh`'s core-path, #4's missing
MultiEdit/replace_all coverage) even though it is not separately named
in the issue. This survey and the paired proposal treat all six
plugins plus `directive.sh` as in scope, not five.

## Defect 1 — locality bug: interface-spec-gate's format-cue check is document-wide, not scoped to the label

**Issue's paraphrase:** "interface-spec-gate's citation cue does a
document-wide grep instead of respecting README's 'local' promise."

**Confirmed, with a precise correction of *where* the bug is.** The
issue's wording ("citation cue") could be misread as pointing at
`evidence-citation-gate`; it is not — it is `interface-spec-gate`'s own
**format-cue** check (the `openapi`/`asyncapi`/`protobuf`/`grpc`/`idl`
token), not a citation/source check. The README makes an explicit
locality promise that the code does not keep:

`api-design/plugins/interface-spec-gate/README.md:20-23`:
> A record whose `interface-spec` label is immediately followed by
> another heading (i.e. left with an empty body and no format cue in
> that section) is treated as missing the facet, **even if a format cue
> happens to appear in some unrelated part of the document.**

The actual check, `api-design/plugins/interface-spec-gate/hooks/gate.sh:139-150`:
```python
low = new_text.lower()
missing = []
label_re = re.compile(r'interface-spec')
format_cue_re = re.compile(r'\b(openapi|asyncapi|protobuf|grpc|idl)\b')

if not label_re.search(low):
    missing.append("interface-spec (label absent)")
elif not format_cue_re.search(low):          # <-- searches the WHOLE document
    missing.append("interface-spec (missing machine-readable format cue: ...)")
else:
    # only reached if a cue exists *anywhere*; the window check below
    # can still find "present-but-empty" but can never re-trigger the
    # missing-cue case once format_cue_re.search(low) has already
    # matched globally
    ...
```
`format_cue_re.search(low)` is evaluated against `low`, the lower-cased
**entire** `new_text`, before any windowing is applied. The later
"present-but-empty" window logic (lines 161-167) only checks whether
the text between the label and the next heading is non-empty — it
never re-checks that the format cue specifically is inside that
window. Concretely: a record with `interface-spec: TBD` under its own
heading, and the word `grpc` appearing only in an unrelated
`## resource-model` section three headings later, passes this gate
today. That is the exact shape of bug the README's own prose disclaims
("even if a format cue happens to appear in some unrelated part of the
document") — the code was written to describe the fix but does not
implement it.

`versioning-strategy-gate`, `deprecation-plan-gate`, and
`resource-model-gate` do not have this exact bug — their mechanism/date
and hierarchy checks are already windowed correctly (they search
`window_low`/`window`, the slice between the label and the next
heading, not the whole document: see e.g.
`versioning-strategy-gate/hooks/gate.sh:146-156`,
`deprecation-plan-gate/hooks/gate.sh:150-164`). Only
`interface-spec-gate`'s format-cue branch has the document-wide leak,
because it short-circuits (`elif`) on a whole-document search before
reaching the window.

## Defect 2 — evidence-citation-gate's "source" check is bare substring matching, not real reference validation

**Issue's paraphrase:** "The citation gate rejects real vendor API
docs (Stripe/AWS etc.) while passing a bare substring match of the
word 'google' — i.e. semantic check is just substring matching, not
real reference validation."

**Confirmed**, and the mechanism is exactly substring matching, at
`api-design/plugins/evidence-citation-gate/hooks/gate.sh:141-152`:
```python
claim_re = re.compile(r'\b(standard practice|common practice|established practice|is standard|conventionally)\b', re.I)
source_re = re.compile(r'\bRFC\s*\d+\b', re.I)
org_names = ["zalando", "google aip", "google", "microsoft", "ietf", "w3c", "openapi initiative"]
paragraphs = re.split(r'\n\s*\n', new_text)
missing = []
for para in paragraphs:
    if claim_re.search(para):
        has_rfc = bool(source_re.search(para))
        has_org = any(name in para.lower() for name in org_names)   # <-- bare substring `in`
        if not (has_rfc or has_org):
            ...
```
Two independent problems compound into the symptom the issue names:

1. `has_org` is a literal Python `in` substring test against a
   **hardcoded, closed list** of six org tokens. `stripe` and `aws`
   (and `amazon`) are simply absent from `org_names` — so a paragraph
   that names Stripe's or AWS's real, citable API design guidance is
   denied not because the citation is invalid, but because the gate's
   allow-list was never extended to cover it. This is a coverage gap,
   not a semantic-validation gap: the gate has no way to recognize *any*
   named organization it wasn't hardcoded to know about, real or not.
2. Simultaneously, because the match is bare substring containment
   (`name in para.lower()`), any paragraph containing the four
   characters `g-o-o-g-l-e` anywhere — including inside an unrelated
   word, a URL, a person's name, or a sentence that only mentions
   "Google" in a throwaway aside unrelated to the standard-practice
   claim — satisfies `has_org` for `"google"`. There is no requirement
   that the token be part of an actual citation-shaped phrase (e.g. "per
   Google AIP", "Google's guideline states"); a bare substring hit is
   sufficient.

The issue's framing ("rejects Stripe/AWS... passes bare 'google'
substring") is an accurate description of the net effect, though the
root cause is two separable defects (closed allow-list + substring-only
matching) rather than one. The proposal below must fix both: replace
the closed enumeration with real reference-shaped recognition (RFC
numbers already work correctly via `source_re`; the org-name path needs
the analogous structural discipline) and require the org token to
appear as part of an actual citation phrase, not a bare word anywhere
in the paragraph.

## Defect 3 — directive.sh's core-path dependency does not resolve in this workspace

**Issue's paraphrase:** "directive.sh has a broken dependency on a
'core' path that doesn't resolve."

**Confirmed.** `api-design/hooks/directive.sh:6`:
```bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
```
The fallback (used whenever `CLAUDE_PLUGIN_ROOT_CORE` is unset) resolves
to `<repo-root>/../core` — i.e. it assumes the `tokenmaxxxer-core`
checkout sits as a directory literally named `core`, a sibling of this
repo's own root, in whatever directory this repo happens to be checked
out under. Verified against the actual workspace layout: this repo
lives at `/home/jwjung/.tokenmaxxxer/work/api-design-rulebook-issue-10-api-design`,
and its parent directory (`/home/jwjung/.tokenmaxxxer/work/`) contains
only other `<repo>-issue-<n>-<role>` checkouts (e.g.
`accessibility-rulebook-issue-10-accessibility`) — there is no `core`
directory anywhere in that listing. The `cd .../../core` inside the
`$(...)` command substitution fails (nonexistent directory), so
`pwd -P` fails, `CLAUDE_PLUGIN_ROOT_CORE` remains empty (bash's
`${var:-$(cmd)}` substitutes the command's stdout, which is empty on
failure, not an error), and the subsequent `source
"/hooks/lib/role-directive.sh"` (leading slash, since the empty
fallback plus the literal string produces a bogus absolute path) fails
with "No such file or directory." Because `directive.sh` has **no**
`gate_trap_fail_closed`-equivalent trap of its own (it is a
`SessionStart` hook, not a `PreToolUse` gate, and Claude Code does not
apply the same fail-closed exit-code remap to `SessionStart`), this
failure is silent from the gate-security standpoint — but it means the
role directive is not actually printed in this exact workspace layout,
which is the concrete, locally reproducible instance of "the dependency
doesn't resolve." The comment at `directive.sh:2-4` documents the
*intent* (source core canon's shared `role-directive.sh`) accurately;
the path expression implementing that intent is what's broken, and
specifically for the multi-repo, non-marketplace-install workspace
layout this environment actually uses.

This is a distinct problem from `directive.sh`'s *kill-switch* logic,
which lives inside `core_role_directive` itself
(`role-directive.sh:36`: `case "$off_val" in ""|0|false|no|off) ;; *)
return 0 ;; esac`) — that case statement has the same
fail-open-on-unrecognized-value shape gate-lib's handbook flags as a
core-repo-wide bug (see below), but it is a second, independent defect
from the path-resolution failure; both live in the same three lines of
`directive.sh` and its sourced file, so both need fixing together, but
they are not the same bug.

## Defect 4 — zero MultiEdit / replace_all test coverage

**Issue's paraphrase:** "Zero test coverage for MultiEdit tool-call
shape."

**Confirmed, and broader than stated.** `grep -c MultiEdit` across all
six test files under `tests/api-design/` returns `0` for every file:

```
tests/api-design/versioning-strategy-gate.sh:0
tests/api-design/resource-model-gate.sh:0
tests/api-design/deprecation-plan-gate.sh:0
tests/api-design/adr-section-gate.sh:0
tests/api-design/evidence-citation-gate.sh:0
tests/api-design/interface-spec-gate.sh:0
```

No test file constructs a `MultiEdit` tool-call payload at all, despite
every `gate.sh` having a `MultiEdit`-handling code path
(`tool == "MultiEdit"`, applying a list of edits in sequence). That
code path is therefore completely unexercised by the test suite.

Additionally, and not separately called out by the issue's paraphrase
but load-bearing for the same underlying gap:

- **`replace_all` is never read by any gate's own reconstruction
  logic.** Every gate's `Edit` and `MultiEdit` branches do
  `current.replace(o, n, 1)` unconditionally (see e.g.
  `interface-spec-gate/hooks/gate.sh:115,128`) — first occurrence only,
  regardless of whatever `tool_input.get("replace_all")` says. This
  exactly matches the bug `gate-lib.py`'s own docstring calls out as
  the "issue-72-confirmed bug" in core's *own* prior
  `record-fields-gate.sh` (`gate-lib.py:69-84`, `_apply_replace`
  docstring). No test in this repo could catch it even if it were
  fixed, because no test passes `replace_all: true` against a
  multiply-occurring `old_string`.
- **No malformed-JSON edge-case variety.** Each test file does have
  *one* malformed-JSON case (`grep` above shows all six files include
  one), but none test the JSON-valid-but-non-object case (e.g. a bare
  JSON array or string as the top-level payload) or the empty-payload
  case as textually distinct assertions — `gate-lib.py`'s
  `gate_parse_json_or_deny` explicitly treats "empty," "invalid JSON,"
  and "valid JSON but not an object" as three separate failure modes to
  cover.
- **No kill-switch garbage-value case.** Every test file that exercises
  the kill switch (`grep -n '_OFF=' tests/api-design/*.sh`) only ever
  sets it to the literal `1` (the one documented on-value) to assert
  "gate bypassed." None sets it to an unrecognized value (a typo like
  `"tru"` or `"2"`) to assert the gate **stays active** — which is
  exactly the fail-open risk gate-lib's handbook identifies as core's
  own historical bug class (see below): every one of this repo's six
  `gate.sh` scripts uses the *same* backwards case-statement shape
  (`case ... in ""|0|false|no|off) ;; *) exit 0 ;; esac` — see e.g.
  `interface-spec-gate/hooks/gate.sh:19-22`), so an unrecognized
  kill-switch value silently disables the gate today, and no test
  would catch a regression (or catch the bug itself) either way.
- **No absolute-vs-relative path-matching test variety.** Every test
  file's payloads already use an absolute `$TMP/...` path (because the
  test harness passes `CLAUDE_PROJECT_DIR="$TMP"` and constructs
  `file_path` as `"$target"`, itself absolute), so the *relative* and
  `./`-prefixed path forms `gate_normalize_path`'s docstring explicitly
  calls out as needing to normalize identically are never exercised.

## Every write-surface this phase-2 work will eventually touch

Gate scripts (fail-closed rework, path-matching fix, semantic-check
upgrade, Edit/MultiEdit/replace_all rework — all six, since all six
share the vulnerable skeleton):
- `api-design/plugins/adr-section-gate/hooks/gate.sh`
- `api-design/plugins/evidence-citation-gate/hooks/gate.sh`
- `api-design/plugins/interface-spec-gate/hooks/gate.sh`
- `api-design/plugins/resource-model-gate/hooks/gate.sh`
- `api-design/plugins/versioning-strategy-gate/hooks/gate.sh`
- `api-design/plugins/deprecation-plan-gate/hooks/gate.sh`

Role directive (core-path fix):
- `api-design/hooks/directive.sh`

Test suites (mandatory new cases: Edit, MultiEdit, replace_all,
malformed JSON, kill-switch unset/valid/garbage, absolute-vs-relative
path):
- `tests/api-design/adr-section-gate.sh`
- `tests/api-design/evidence-citation-gate.sh`
- `tests/api-design/interface-spec-gate.sh`
- `tests/api-design/resource-model-gate.sh`
- `tests/api-design/versioning-strategy-gate.sh`
- `tests/api-design/deprecation-plan-gate.sh`

READMEs (resync to remove ghost references, document real kill
switches/paths):
- `api-design/plugins/adr-section-gate/README.md`
- `api-design/plugins/evidence-citation-gate/README.md`
- `api-design/plugins/interface-spec-gate/README.md`
- `api-design/plugins/resource-model-gate/README.md`
- `api-design/plugins/versioning-strategy-gate/README.md`
- `api-design/plugins/deprecation-plan-gate/README.md`
- `README.md` (repo root — layout section)

None of the files above are modified by this phase-1 survey/proposal
pair; this is an enumeration for the phase-2 execution issue to consume.

## What gate-lib.sh / gate-lib.py / gate-house-standard.md actually provide

Fetched from `tokenmaxxxer-core` (main branch,
`core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
`docs/handbooks/gate-house-standard.md`), landed as core issue #72's
"gate house standard" — the precondition this issue's proposal is
required to build on rather than re-derive locally.

- **`gate_trap_fail_closed()`** (bash) — installs one canonical
  `trap ... EXIT` that remaps any non-{0,2} exit code to 2, matching
  (and intended to replace) the `__fc`/`trap __fc EXIT` boilerplate
  each of this repo's six `gate.sh` files currently hand-rolls
  identically at its own top (line 1-3 of every file here). Must be
  called as the *very first statement*, before `set -uo pipefail`.
- **`gate_kill_switch_active(value)`** (bash) — the corrected
  kill-switch convention: returns "stay active" (0/true) for
  empty/unset, a recognized off-spelling, **or any unrecognized
  value**; returns "disable" (1/false) only for a recognized
  on-spelling (`1`/`true`/`yes`/`on`, case-insensitive). This is the
  exact fix for the fail-open shape every one of this repo's six gates
  currently uses (`case ... in ""|0|false|no|off) ;; *) exit 0 ;;
  esac` — the *inverse* logic from what the handbook documents as
  core's own former bug, now fixed centrally).
- **`gate_deny(name, msg)` / `gate_allow()`** (bash) — the already-
  uniform stderr-deny (exit 2) / exit-0-allow protocol this repo's
  gates already follow by convention; centralizing it removes six
  copies of the same one-liner.
- **`gate_parse_json_or_deny(raw, deny)`** (Python, `gate-lib.py`) —
  malformed-JSON deny (parse failure, non-object top level, or empty
  payload all deny), loaded via `importlib.util.spec_from_file_location`
  against the `GATE_LIB_PY` env var `gate-lib.sh` exports when sourced.
- **`gate_normalize_path(root, path)`** (Python) — resolves an
  absolute, relative, or `./`-prefixed path against `root` to a
  root-relative forward-slash tail (or `None` if outside root), via
  pure `posixpath` string algebra (no `os.path.realpath`/symlink
  resolution — callers needing that should `realpath` their own `root`
  first). This directly replaces each gate's own hand-rolled `resolve()`
  closure (e.g. `interface-spec-gate/hooks/gate.sh:76-83`), which
  already does realpath-based resolution but does so independently,
  six times, with no shared normalization for the relative/`./`-prefixed
  cases this repo's tests never exercise.
- **`gate_reconstruct_write(tool, tool_input, current_content)`**
  (Python) — full `Write`/`Edit`/`MultiEdit`/`NotebookEdit`
  reconstruction, correctly honoring each edit's own `replace_all` flag
  independently (via an internal `_apply_replace` helper) — the direct
  fix for defect 4's `replace_all`-ignored bug found in every one of
  this repo's six gates today.
- **`gate_bash_write_targets(command)`** (bash) — token-scans a `Bash`
  tool-call's `command` string for path-shaped candidates, letting a
  gate that today only matches `Write|Edit|MultiEdit` also catch a
  `Bash`-issued file write (e.g. `echo ... > docs/issue-10/reports/api-design.md`)
  — a write surface none of this repo's six gates currently defends at
  all (their `hooks.json` matchers are all `Write|Edit|MultiEdit` only).
- **`core/hooks/tests/run-gate-lib-tests.sh`** and
  **`core/hooks/tests/compliance-check.sh`** — the standard six-case
  mandatory test harness (Edit+replace_all, MultiEdit mixed
  replace_all, malformed JSON, kill-switch garbage value, absolute +
  `./`-prefixed path, Bash-tool write) and a static detector that flags
  a gate reading a `*_OFF` var without calling `gate_kill_switch_active`
  or reconstructing content via its own `.replace()` instead of
  `gate_reconstruct_write`. Both are invoked by path against core's own
  install root, never vendored — `compliance-check.sh
  "$(dirname "$0")/.."` run against this repo's `api-design/` directory
  today would flag all six of this repo's `gate.sh` files on both
  counts (hand-rolled kill switch, hand-rolled `.replace(...,1)`).

The per-repo migration checklist in `gate-house-standard.md`
("Per-repo migration checklist," 5 steps: run `compliance-check.sh`,
migrate flagged gates, re-run gate tests, re-run `compliance-check.sh`
clean, file the remediation issue) is the exact procedure this issue's
phase-2 execution should follow, and the paired proposal document
adopts it as the sequencing for the "Adoption plan" section.
