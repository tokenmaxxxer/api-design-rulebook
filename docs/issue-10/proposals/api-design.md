# Issue #10 — Phase 1 Proposal: A+ Remediation for the api-design Gate Suite

Status: **PROPOSAL ONLY — phase 1.** No rulebook content, hook, test
file, or README under `api-design/plugins/**` or `tests/**` is changed
by this document. Execution (phase 2) requires an Approve from a login
in `docs/specs/approvers.md`, or (single-account mode) an issue comment
"APPROVE issue-10/api-design", per contract v3 s19. This document does
not itself constitute or contain that approval, and no implementation
work is performed as part of writing it.

Basis: `docs/issue-10/reports/api-design/survey.md` (current-state
defect confirmation against actual code, plus the corrected count of
six affected plugins, not five), the 2026-08-01 real-code audit that
graded this rulebook's gate implementation B+, and
`tokenmaxxxer-core`'s issue #72 "gate house standard"
(`core/hooks/lib/gate-lib.sh`, `core/hooks/lib/gate-lib.py`,
`docs/handbooks/gate-house-standard.md`), which landed as the
precondition this remediation must adopt by reference rather than
re-derive.

## Context

Issue #7 built this rulebook's six-plugin gate set
(`adr-section-gate`, `evidence-citation-gate`, `interface-spec-gate`,
`resource-model-gate`, `versioning-strategy-gate`,
`deprecation-plan-gate`), each independently enforcing one methodology
per issue #1's adopted proposal/deliverable norms. A 2026-08-01
real-code audit graded the merged implementation B+ and found four
defect classes, confirmed against the actual source in this proposal's
paired survey:

1. `interface-spec-gate`'s machine-readable-format-cue check searches
   the whole lower-cased document (`format_cue_re.search(low)`) before
   it ever windows to the label's own section, contradicting its own
   README's explicit locality promise.
2. `evidence-citation-gate`'s "named source" check is a closed,
   hardcoded `org_names` list tested by bare Python `in` substring
   containment — real vendor guidance (Stripe, AWS) that isn't on the
   list is rejected, while the four-letter substring `google` matches
   anywhere in a paragraph regardless of whether it appears as part of
   an actual citation.
3. `directive.sh`'s fallback path expression
   (`$(dirname "${BASH_SOURCE[0]}")/../../core`) assumes
   `tokenmaxxxer-core` is checked out as a sibling directory literally
   named `core`; in this environment's actual workspace layout
   (`/home/jwjung/.tokenmaxxxer/work/<repo>-issue-<n>-<role>/`), no
   such sibling exists, so the source fails and the role directive is
   silently not printed.
4. Zero tests exist anywhere under `tests/api-design/` that construct a
   `MultiEdit` tool-call payload; `replace_all` is never read by any
   gate's own reconstruction logic and no test could catch that either
   way; no test exercises a kill-switch garbage value or a
   relative/`./`-prefixed path variant.

Independently of issue #10's own text, `tokenmaxxxer-core` issue #72
landed a shared library (`gate-lib.sh` + `gate-lib.py`) plus a standard
six-case test harness and a static compliance detector, built
specifically because core's own gates had these same defect *shapes*
(fail-open kill switch, `replace_all` ignored) before that migration.
This proposal's remediation is designed to consume that library by
reference rather than hand-fix each defect locally a second time —
fixing this rulebook's four defects the same way core fixed its own
versions of defects 2 (semantic/allow-list shape is local to this
repo, not covered by gate-lib) and 3 (also local) is not optional
economy; defects 1... no — to be precise: gate-lib.sh/py directly
supplies the mechanism for defect 4 (kill-switch fail-open shape,
`replace_all`, JSON parsing, path normalization) and the plumbing
`interface-spec-gate`'s fix depends on (a real section-scoped scan
needs the same reconstructed-content and path-normalization primitives
gate-lib already provides); defects 2 and 3 have no core-provided
fix and are designed fresh below.

## Decision

**Adopt `gate-lib.sh`/`gate-lib.py` by reference in all six `gate.sh`
scripts and in `directive.sh`, replacing each script's hand-rolled
fail-closed trap, kill-switch case, path resolution, and
Edit/MultiEdit reconstruction with the corresponding `gate_*` call;
independently, redesign `interface-spec-gate`'s format-cue check to be
section-scoped and `evidence-citation-gate`'s source check to require
a structurally real citation phrase, not a bare word; independently,
fix `directive.sh`'s core-path resolution to use the same
`CLAUDE_PLUGIN_ROOT_CORE`-first pattern gate-lib's own usage comment
demonstrates, verified against a plugin-marketplace-install layout
rather than assumed; and add the mandatory six-case-plus test suite to
every one of the six existing `tests/api-design/*.sh` files.**

No `gate.sh`, `hooks.json`, `directive.sh`, README, or test file is
edited by this document; the sections below are the design each
phase-2 edit follows.

### Adoption plan — which gate-lib function replaces which local logic, in which file

| File | Local logic replaced | `gate-lib` call | Bash or Python, and why |
|---|---|---|---|
| All six `hooks/gate.sh` | `trap __fc EXIT` / `__fc()` (gate.sh:1-3 in every file) | `gate_trap_fail_closed` | Bash — must run as the outer script's very first statement, before `set -uo pipefail`; the outer shell wrapper (not the embedded Python heredoc) owns process exit codes, so this stays in bash. |
| All six `hooks/gate.sh` | `case "${<NAME>_GATE_OFF:-}" in ""\|0\|false\|no\|off) ;; *) exit 0 ;; esac` (e.g. `interface-spec-gate/hooks/gate.sh:19-22`) | `gate_kill_switch_active "${<NAME>_GATE_OFF:-}" \|\| { trap - EXIT; exit 0; }` | Bash — the kill switch is read before any Python is invoked (fast-path bypass), and the corrected on/off semantics are the fix for defect-class 4's garbage-value gap; must stay in the outer shell for the same reason as the trap. |
| All six `hooks/gate.sh` (Python heredoc) | `json.loads(raw)` + manual `isinstance(ev, dict)` checks (e.g. `interface-spec-gate/hooks/gate.sh:61-66`) | `gate_lib.gate_parse_json_or_deny(raw, deny)` | Python — the payload is already inside the embedded Python heredoc by this point (needed for `re`-based content checks downstream); loaded via the `importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])` pattern `gate-lib.sh`'s own header comment specifies, using the `GATE_LIB_PY` env var `gate-lib.sh` exports when sourced. |
| All six `hooks/gate.sh` (Python heredoc) | hand-rolled `resolve(p)` closure using `os.path.realpath` (e.g. `interface-spec-gate/hooks/gate.sh:76-83`) | `gate_lib.gate_normalize_path(root, path)` | Python — pure `posixpath` algebra, cheaper and centrally correct for the relative/`./`-prefixed cases this repo's own tests never exercised (survey defect 4); callers still `os.path.realpath(root)` once before calling, per `gate_normalize_path`'s own documented contract, so symlink-safety is preserved exactly as today. |
| All six `hooks/gate.sh` (Python heredoc) | `current.replace(o, n, 1)` for `Edit`, and the `for e in edits: ... text.replace(o, n, 1)` loop for `MultiEdit` (e.g. `interface-spec-gate/hooks/gate.sh:113-130`) | `gate_lib.gate_reconstruct_write(tool, ti, current)` | Python — this is the direct fix for the `replace_all`-ignored bug (survey defect 4); `gate_reconstruct_write` already honors each edit's own `replace_all` independently and returns `(new_text, ok)`, so each gate's own "deny if resulting content undeterminable" branch becomes `if not ok: deny(...)` instead of hand-checking `o in current`. |
| All six `hooks/gate.sh` deny call | `echo "...refused — %s" % m >&2; exit 2` inline in each `deny()` (e.g. `interface-spec-gate/hooks/gate.sh:57-58`) | `gate_lib.gate_deny(role, msg)` (bash side already matches; Python side gets an equivalent thin wrapper calling the same message shape) | Both — the bash-level `deny()` closure in the outer script already matches `gate_deny`'s exact stderr shape (`"<name>: refused — <msg>"`, exit 2); the Python-embedded `deny()` closure should be changed to call `sys.stderr.write` with the identical format string gate-lib.sh's `gate_deny` uses, for message-shape consistency across the bash/Python boundary — gate-lib.py does not itself expose a `gate_deny`, so this one function's Python side is a one-line adapter matching the bash convention rather than a new gate-lib import. |
| `hooks/directive.sh` | `. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd ".../../core" && pwd -P)}/hooks/lib/role-directive.sh"` (directive.sh:6) | Unchanged call target (`core_role_directive`), corrected path expression (see "Fail-closed rework" for the kill-switch half, and the dedicated subsection below for the path half) | Bash — `role-directive.sh` is already the correct core file to source; only the *path expression finding it* is broken, not the choice of file. |

`gate_bash_write_targets` (the `Bash`-tool token-scan helper) is
**not** adopted in this pass: none of this rulebook's six `hooks.json`
matchers include `Bash` today (`Write|Edit|MultiEdit` only, e.g.
`api-design/plugins/adr-section-gate/hooks/hooks.json`), so there is no
existing `Bash`-tool write path for it to backfill yet. Widening the
matcher to catch `Bash`-issued writes to
`docs/issue-<n>/reports/api-design.md` is a real, separately-scoped
gap (a `Bash` `echo ... > docs/issue-10/reports/api-design.md` bypasses
every one of these six gates today, matcher-wise), but changing six
`hooks.json` matchers is additional surface beyond the issue's named
four defects — flagged here as a candidate follow-up issue, out of
scope for this remediation (see "Explicitly out of scope").

### Fail-closed rework

- **Trap-at-top:** every `gate.sh`'s first statement becomes sourcing
  `gate-lib.sh` (resolved via the same
  `CLAUDE_PLUGIN_ROOT_CORE`-with-relative-fallback pattern
  `gate-lib.sh`'s own header comment shows: `. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh"`,
  adjusted for each plugin's own directory depth from `api-design/plugins/<name>/hooks/gate.sh`
  to wherever core is actually reachable — see the dedicated path
  subsection below, since this is the same class of path expression
  that broke `directive.sh`) immediately followed by
  `gate_trap_fail_closed`, both **before** `set -uo pipefail`, matching
  gate-lib.sh's own documented ordering requirement ("Call this as the
  very first statement in a gate script, before `set -uo pipefail`, so
  a syntax error or unset-variable abort on the next line is still
  caught"). This is a straight swap of six identical 3-line blocks for
  one sourced call each.
- **Malformed JSON -> deny:** replace each gate's inline
  `try: ev = json.loads(raw) ... except ValueError: deny(...)` with
  `ev = gate_lib.gate_parse_json_or_deny(raw, deny)`, which additionally
  covers the empty-payload case (already separately handled by each
  `gate.sh`'s outer bash `[ -n "$payload" ] || deny ...` today, so no
  behavior regresses) and the non-object-top-level case (already
  separately checked today via `isinstance(ev, dict)`, so this is a
  consolidation, not new behavior) uniformly across all six.
- **Kill-switch unrecognized value -> stays active:** replace each
  gate's own `case "${<NAME>_GATE_OFF:-}" in ""|0|false|no|off) ;; *)
  exit 0 ;; esac` (survey-confirmed fail-open-on-typo shape, identical
  to core's own former bug per `gate-house-standard.md`'s "two bugs
  this issue fixed") with `gate_kill_switch_active
  "${<NAME>_GATE_OFF:-}" || { trap - EXIT; exit 0; }`. The exact
  mechanism this fixes: `gate_kill_switch_active`'s case statement
  (`gate-lib.sh:64-67`) only returns 1 (disable) for a recognized
  on-spelling (`1|true|yes|on`, case-insensitive); every other value —
  empty, a recognized off-spelling, **or any unrecognized garbage** —
  returns 0 (stay active). This directly satisfies the issue's
  requirement that "an unrecognized/garbage kill-switch value must be
  treated as 'gate active' (never fail open)."
- **Deny reasons via stderr:** already true today in all six gates
  (`deny() { echo "${role}: refused — $1" >&2; exit 2; }`) and
  unchanged by this rework — `gate_deny`'s bash-side contract matches
  this exact shape, so adopting it is a rename, not a behavior change;
  called out explicitly here because it is one of the issue's
  requirements and this proposal confirms it is already satisfied
  structurally, not merely asserted.

### Path matching fix (interface-spec-gate's locality check)

Root cause (survey defect 1): `format_cue_re.search(low)` at
`interface-spec-gate/hooks/gate.sh:149` is evaluated against the whole
lower-cased document, short-circuiting the later window computation.
The fix is **not** a path-normalization change in the
`root`/`file_path` sense (that resolution — three-tier root detection,
`realpath`-then-strip-root — already works correctly and is what
"absolute-path normalization" below addresses for the *scope* check,
not this content-locality check); the two are easy to conflate because
both are called "path matching" in the issue text, so this proposal
treats them explicitly as two separate fixes:

1. **File-scope path matching** (which file is being written) already
   uses `os.path.realpath` + string-prefix stripping against `root`
   correctly today; this rework replaces that hand-rolled `resolve()`
   with `gate_lib.gate_normalize_path(root, path)` per the adoption
   table above, gaining the relative/`./`-prefixed normalization the
   survey found untested, with no behavior change for the
   already-working absolute case.
2. **In-document locality matching** (survey defect 1's actual bug):
   redesign the format-cue check to locate the `interface-spec` label
   first, compute the window from the label to the next markdown
   heading or EOF (the window computation already exists at
   `gate.sh:161-166` — it is simply not consulted for the missing-cue
   branch), and evaluate `format_cue_re.search(window)` — **not**
   `format_cue_re.search(low)` — as the sole test for "format cue
   present." Concretely, the `elif not format_cue_re.search(low):`
   branch is deleted; the label-found branch always proceeds to compute
   `window` first, then checks both non-emptiness and the format-cue
   pattern against that same `window` in one pass:
   ```python
   m = label_re.search(low)
   if not m:
       missing.append("interface-spec (label absent)")
   else:
       after = new_text[m.end():]
       next_heading = re.search(r'\n#{1,6}\s', after)
       window = after[:next_heading.start()] if next_heading else after
       if not format_cue_re.search(window.lower()):
           missing.append("interface-spec (missing machine-readable format "
                           "cue near the label: openapi/asyncapi/protobuf/grpc/idl)")
       elif not window.strip():
           missing.append("interface-spec (label present, body empty)")
   ```
   This is a genuine markdown-section-aware scan (label -> next heading
   boundary), matching the window-based approach
   `versioning-strategy-gate` and `deprecation-plan-gate` already use
   correctly for their own mechanism/date checks — bringing
   `interface-spec-gate` in line with its five siblings' existing
   (correct) pattern, not inventing a new one.

### Semantic upgrade design (evidence-citation-gate: substring -> structural citation check)

Root cause (survey defect 2): `has_org = any(name in para.lower() for
name in org_names)` is bare substring containment against a fixed
six-entry list that omits Stripe/AWS/Amazon, and admits "google" as a
bare four-letter match with no requirement that it appear as part of an
actual citation.

**Concrete mechanism:** replace the enumerated-org-name substring test
with a **citation-phrase pattern**: a source is recognized only when an
org-like token (capitalized word or short capitalized phrase,
1-4 tokens, e.g. "Stripe", "AWS", "Google AIP", "IETF") appears
**adjacent to a citation-signaling preposition/verb** — "per", "per
the", "sourced to", "following", "'s guideline(s)", "'s API", "'s
design [review/practice]", "as documented by", "'s RFC" — within the
same paragraph, and the citation phrase must be within a bounded token
distance (a small window, e.g. 8 words) of the conventionality claim
itself, not merely present anywhere in the paragraph. Concretely:

```python
CITATION_PHRASE_RE = re.compile(
    r'\b(?:per|sourced to|following|as documented by|as specified by)\s+'
    r'((?:[A-Z][A-Za-z0-9]*\s?){1,4}(?:\'s)?\b(?:guidelines?|guidance|'
    r'design (?:review|practice|guide)|api|rfc|spec(?:ification)?s?)?'
)
RFC_RE = re.compile(r'\bRFC\s*\d+\b', re.I)

for para in paragraphs:
    claim_matches = list(claim_re.finditer(para))
    if not claim_matches:
        continue
    has_rfc = bool(RFC_RE.search(para))
    has_citation_phrase = bool(CITATION_PHRASE_RE.search(para))
    if not (has_rfc or has_citation_phrase):
        missing.append(...)
```
This fixes the reported symptom directly:

- **Stripe/AWS accepted:** neither name needs to be enumerated in a
  closed list any more — "per Stripe's API design review practice" or
  "following AWS's API guidelines" matches
  `CITATION_PHRASE_RE` structurally (a citation-signal word adjacent to
  a capitalized org token plus a guideline-shaped noun), the same way
  "per Zalando's guidelines" would. The check becomes org-name-agnostic
  by construction instead of requiring every future vendor to be added
  to a hardcoded list — closing the coverage gap, not just adding two
  more strings to `org_names` (which would still be a closed
  enumeration vulnerable to the next unlisted vendor).
- **Bare "google" substring rejected:** the word "google" appearing
  without a citation-signal word immediately before it (e.g. "Google
  Docs," "a search on Google," or any other incidental mention) no
  longer satisfies `has_citation_phrase`, because the pattern requires
  the citation-signal prefix (`per`/`sourced to`/`following`/etc.)
  directly preceding the capitalized token. A real citation — "per
  Google AIP" or "following Google's API guidelines" — still matches,
  because that is the intended positive case; a bare mention does not,
  because it lacks the structural signal a real citation always
  carries.
- **Why this is section/adjacency-based, not another substring list:**
  the check no longer asks "does this string appear in the paragraph,"
  it asks "does this paragraph contain a citation-shaped phrase
  (signal-word + capitalized token + optional guideline-noun) in
  adjacency to each other." That is a structural (regex-adjacency)
  check over the paragraph's own local grammar, not a membership test
  against an enumerated vocabulary — the same category of fix as
  `interface-spec-gate`'s window-scoping above, applied to citation
  recognition instead of format-cue recognition. `RFC \d+` remains a
  second, independently sufficient path (unchanged, already correct
  today).

`adr-section-gate`'s own heading-based windowing (label -> next
heading) is the pattern this citation-phrase redesign generalizes from
whole-document substring matching to structural, section/adjacency-
aware matching — both fixes replace "is the token present somewhere"
with "is the token present in the right structural relationship to
what it's supposed to be evidencing."

### Edit/MultiEdit/replace_all handling redesign

All six gates currently reconstruct `Write`/`Edit`/`MultiEdit` inline,
duplicated six times, always ignoring `replace_all`
(`current.replace(o, n, 1)` unconditionally). The redesign is a
**straight replacement of each gate's own reconstruction block with a
single call**, normalizing all three tool-call shapes to the common
`(new_text, ok)` representation `gate_lib.gate_reconstruct_write`
already returns:

```python
new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
if not ok:
    deny(
        "this write targets %s but the resulting content cannot be "
        "determined from the tool input (tool=%r, replace_all=%r). Use "
        "Write for the full document, or an Edit/MultiEdit whose "
        "old_string matches on-disk content." % (rel, tool, ti.get("replace_all"))
    )
```
This one call replaces, per gate: the `if tool == "Write": ...`,
`elif tool == "Edit": ...`, and `elif tool == "MultiEdit": ...` blocks
(each ~10-20 lines, six times). Each edit's own `replace_all` is now
honored independently within a `MultiEdit`'s edit list (mixed
`true`/`false` per edit), matching the tool's documented real behavior
— `text.replace(old, new)` (every occurrence) when `replace_all` is
true, first-occurrence-only otherwise — which none of the six gates'
current `.replace(o, n, 1)` calls do regardless of what `replace_all`
says.

`NotebookEdit` is not currently matched by any of this rulebook's six
`hooks.json` (`Write|Edit|MultiEdit` only), so
`gate_reconstruct_write`'s `NotebookEdit` branch is adopted
transparently (available if a future matcher widening adds it) but not
exercised by this rulebook's current write surfaces — no test case for
it is required by this remediation (see "Explicitly out of scope").

### Mandatory test case list (phase-2 acceptance checklist)

Added to **each** of the six existing files under `tests/api-design/`
(`adr-section-gate.sh`, `evidence-citation-gate.sh`,
`interface-spec-gate.sh`, `resource-model-gate.sh`,
`versioning-strategy-gate.sh`, `deprecation-plan-gate.sh`), on top of
each file's existing passing cases (not replacing them):

1. **Edit — single-file positive:** an `Edit` whose `old_string`
   matches on-disk content and whose reconstructed result still
   satisfies that plugin's own check -> exit 0.
2. **Edit — single-file negative:** an `Edit` whose reconstructed
   result no longer satisfies the plugin's check (e.g. the edit removes
   the required label or cue) -> exit 2, naming the missing element.
3. **Edit with `replace_all: true` against a multiply-occurring
   `old_string`:** on-disk content containing the same `old_string`
   twice; `replace_all: true` -> assert **every** occurrence is
   replaced in the reconstructed text (distinguishing this from the
   current, buggy first-occurrence-only behavior) and the plugin's
   check runs against the fully-replaced text.
4. **MultiEdit — multi-edit, single file:** a `MultiEdit` with 2+ edits
   applied in sequence, at least one edit's replacement itself
   introducing the plugin's required element (i.e. the element is
   absent before the edits and present only after all edits apply in
   order) -> exit 0, proving edits are applied in sequence rather than
   independently against the original on-disk content.
5. **MultiEdit with mixed `replace_all` per edit:** one edit in the
   list with `replace_all: true` against a multiply-occurring string,
   another edit in the same call with `replace_all: false` (or absent)
   against a singly-occurring string -> assert both edits' semantics
   are honored independently within the one call.
6. **`replace_all` absent/false — default behavior unchanged:** an
   `Edit`/`MultiEdit` with no `replace_all` key against a
   multiply-occurring `old_string` -> only the first occurrence is
   replaced (regression guard for the default case, once the fix is in
   place).
7. **Malformed JSON — three distinct sub-cases**, each asserted
   separately: (a) truncated/non-JSON stdin (`"not valid json {{{"`,
   already covered today, kept); (b) syntactically valid JSON that is
   not an object at the top level (e.g. `"[1,2,3]"` or `"\"a string\""`);
   (c) empty stdin. All three -> exit 2.
8. **Kill-switch unset:** no `<NAME>_GATE_OFF` env var set, content
   that would otherwise fail the plugin's check -> exit 2 (gate stays
   active; regression guard distinguishing "unset" from "garbage" so a
   future change cannot conflate the two).
9. **Kill-switch valid on-value:** `<NAME>_GATE_OFF=1` (already covered
   today in each file, kept) -> exit 0 regardless of content.
10. **Kill-switch garbage/unrecognized value:** `<NAME>_GATE_OFF=banana`
    (or another unrecognized string, not `1`/`true`/`yes`/`on` and not
    `""`/`0`/`false`/`no`/`off`), content that would otherwise fail the
    plugin's check -> exit 2 (gate **stays active** — this is the
    direct regression test for the fail-open bug this remediation
    fixes; it must fail against the pre-fix code and pass after).
11. **Absolute path variant:** `file_path` given as an absolute path
    matching the plugin's scope regex under the detected root (already
    the implicit form every existing test uses) -> exit 0/2 per
    content, kept as the baseline.
12. **Relative path variant:** the same target expressed as a
    repo-root-relative path (e.g. `docs/issue-9/reports/api-design.md`
    with no leading `$TMP`) with `CLAUDE_PROJECT_DIR` set to `$TMP`
    -> must resolve to the identical scope-match/no-match decision as
    the absolute-path case for the same logical target.
13. **`./`-prefixed path variant:** the same target expressed with a
    leading `./` (e.g. `./docs/issue-9/reports/api-design.md`) -> must
    resolve identically to cases 11-12.

Cases 1-2 and 11 already exist in some form in each current test file
and are kept, not duplicated; cases 3, 5-10, 12-13 are the net-new
mandatory additions this remediation must land before phase-2 ships.
Full green run of all six updated test files, plus (per
gate-house-standard.md's migration checklist) a clean
`compliance-check.sh` pass against `api-design/`'s `hooks/` tree, is
the phase-2 acceptance target — not attempted or asserted by this
phase-1 document.

### README resync plan

Base: the actual file listing read for this survey/proposal pair (`git
ls-files`-equivalent walk of the repo), not assumption.

- **Root `README.md`** — the "Layout" section (lines 20-35) lists only
  `directive.sh`, `hooks.json`, and `docs/specs/approvers.md`,
  predating issue #7's six-plugin gate set entirely; it also states (in
  the prose above Layout) "This role no longer vendors its own copies
  of the record-fields gate, trailer gate, handbook-trigger gate, or
  the warrant-hunter agent" without ever mentioning that this repo *does*
  vendor six of its own methodology gates under `api-design/plugins/`.
  Resync: add a bullet enumerating `api-design/plugins/<name>/` for all
  six plugins (name, one-line methodology, write-surface), matching
  `.claude-plugin/marketplace.json`'s existing six entries (verified
  present, real, and consistent with what's on disk) so the root
  README stops under-describing what the repo actually ships.
- **No ghost files were found in the root README's plugin-adjacent
  prose** beyond the omission above — it does not name any specific
  nonexistent file path, only omits real ones. This is a completeness
  gap, not a stale-reference removal, and is noted as such rather than
  forcing a "removal" framing where none applies.
- **Per-plugin README ghost check** — each of the six plugins' own
  README.md was read in full for this proposal; none names a file that
  does not exist on disk (each accurately describes its own `gate.sh`,
  scope regex, and kill switch, all verified present and matching).
  The "ghost files" issue #10 flags are better understood as
  **behavior-vs-documentation drift**, not missing-file references, and
  the concrete instance found is `interface-spec-gate/README.md:20-23`
  (quoted in the survey) describing locality behavior the code does
  not yet implement — i.e. the README describes the *target* state
  accurately and the code is what needs to change to match it, the
  reverse of the usual "stale doc" direction. Once the "Path matching
  fix" section above lands, this README's existing text becomes
  accurate as written and needs no rewording — only the code changes.
  This is called out explicitly so phase-2 execution does not
  needlessly rewrite `interface-spec-gate/README.md`'s prose when the
  fix is purely on the `gate.sh` side.
- **Kill-switch/path documentation already accurate** in all six
  plugin READMEs (each correctly documents its own `<NAME>_GATE_OFF`
  var and scope regex as they exist in code today) — the resync's real
  work item, per the adoption plan above, is adding one short
  "Core adoption" subsection to each of the six plugin READMEs (and to
  the root README's Layout section) once phase 2 lands, stating that
  the gate now sources `gate-lib.sh`/`gate-lib.py` by reference (naming
  the exact functions called, per the adoption table) rather than
  re-describing kill-switch/path logic as if it were still local —
  this is new content to add, not a stale reference to delete, and is
  listed here so phase 2 does not skip it while focused on the four
  code-level defects.
- **`directive.sh`'s own comment** (`api-design/hooks/directive.sh:2-4`)
  already accurately states its intent ("Shared boilerplate ... now
  lives in core canon's `core/hooks/lib/role-directive.sh`") — no
  wording changes needed there once the path expression itself is
  fixed; the comment was never the ghost, the path expression was.

### Explicitly out of scope

- **No APPROVE** is given, requested to be inferred, or otherwise
  contained in this document. Nothing in this proposal, its paired
  survey, or any prior conversation authorizes phase-2 execution.
- **No implementation** — no `gate.sh`, `hooks.json`, `directive.sh`,
  README, or test file under `api-design/plugins/**` or `tests/**` is
  created, edited, or deleted by this phase-1 cycle.
- **Widening any `hooks.json` matcher to include `Bash`** (to adopt
  `gate_bash_write_targets`) is not part of this remediation — flagged
  above as a real, separately-scoped gap, deferred to its own future
  phase-1 cycle rather than bundled into this defect-fix pass.
- **`NotebookEdit` test coverage** is not required by this remediation,
  since no `hooks.json` in this rulebook currently matches that tool;
  `gate_reconstruct_write`'s `NotebookEdit` branch is adopted
  transparently (no local reimplementation needed later if the matcher
  is ever widened) but not tested here.
- **Deep OpenAPI/AsyncAPI schema validation** for `interface-spec-gate`
  (actually parsing the attached spec document) remains out of scope,
  unchanged from issue #7's own Alternatives Considered #5 — this
  remediation fixes the *locality* of the existing keyword-presence
  check, not its depth.
- **Rewriting `interface-spec-gate/README.md`'s prose** is not required
  (see README resync plan above) — its existing description of the
  target locality behavior is accurate; only the code needs to change
  to match it.

## Alternatives considered

1. **Hand-fix each of the four defects locally in this repo, without
   adopting `gate-lib.sh`/`gate-lib.py`.** Rejected: `gate-house-
   standard.md` explicitly frames itself as "the canon fix every
   rulebook gate should source instead of re-deriving its own version
   of each shape," landed specifically because per-repo re-derivation
   of the same trap/kill-switch/reconstruct machinery is what produced
   "same shapes, 2-3 different idioms each, one confirmed live bug"
   across 43 repos (issue #72's own survey, per the handbook). Hand-
   fixing locally would repeat exactly that mistake a second time in
   this repo alone, and would leave this repo's own
   `compliance-check.sh` run non-clean even after a correct-behaving
   local fix, since the detector flags hand-rolled kill-switch/replace
   patterns regardless of whether they happen to be currently correct.
2. **Fix only the four literally-named defects (skip `adr-section-gate`
   since it wasn't in the issue's explicit read list).** Rejected: the
   survey found `adr-section-gate` shares the identical vulnerable
   skeleton (fail-closed trap, kill-switch case, three-tier root
   detection, `old_string`/`new_string` reconstruction ignoring
   `replace_all`) as the other five, and is listed in
   `marketplace.json` as a real, shipped plugin. Silently leaving it
   unfixed would mean `compliance-check.sh` still flags one of six
   gates after remediation, and a future MultiEdit/replace_all write
   to a phase-1 proposal document would remain exploitable through the
   one gate this narrower reading would skip.
3. **Fix evidence-citation-gate's Stripe/AWS gap by simply adding
   `"stripe"`, `"aws"`, `"amazon"` to the existing `org_names` list.**
   Rejected: this closes today's two specific examples but leaves the
   check a closed enumeration — the next unlisted real vendor
   (Twilio, GitHub, Shopify, etc.) reproduces the identical bug
   immediately. The proposal's citation-phrase redesign is
   org-name-agnostic by construction, closing the entire defect class
   rather than two named instances of it.
4. **Fix `interface-spec-gate`'s locality bug by shrinking the
   scope-wide `SCOPE_RE` file-matching regex instead of touching the
   in-document window logic.** Rejected as a category error: the
   file-scope regex (which *file* this gate evaluates) and the
   in-document format-cue window (where, *within* that file, the cue
   must appear) are unrelated matching layers; the survey confirms the
   bug is entirely in the second layer (`format_cue_re.search(low)`
   evaluated against the whole document instead of the label's own
   window), and the first layer already works correctly today.
5. **Fix `directive.sh`'s path bug by hardcoding an absolute path to
   this specific environment's core checkout location.** Rejected:
   would fix this one workspace layout while remaining broken for a
   real marketplace-install layout (or any other developer's checkout
   path) — `role-gates-tests.md`'s own caveat about the
   `stub-check.sh` invocation ("this repo's own test run happens from
   a single checkout ... which may not match the external 43-repo
   marketplace-install layout") applies identically here; the fix must
   be verified against how a real marketplace install resolves a
   sibling plugin root (mirroring `CLAUDE_PLUGIN_ROOT` for the api-design
   plugin itself), not hardcoded to one workspace's directory layout.
6. **Defer this whole remediation until core's `compliance-check.sh` is
   run against this repo as a formal precondition, rather than proposing
   the fix now based on manual code reading.** Rejected: `gate-house-
   standard.md`'s migration checklist step 1 ("Run `compliance-check.sh`
   against the rulebook's current gates and record the violation list")
   is explicitly a phase-2 execution step, not a phase-1 gating
   precondition — the checklist assumes the rulebook's own remediation
   issue already exists and is proposing the fix, then runs the
   detector to confirm before/after. Manual code reading (this survey)
   is sufficient for a phase-1 design; running the actual detector
   script is properly phase-2 verification work.

## Rationale

- **Core adoption by reference, not reimplementation, because the
  precondition explicitly exists to prevent per-repo re-derivation.**
  Every one of this rulebook's six gates independently re-derived the
  same trap/kill-switch/JSON-parse/path-resolve/reconstruct shapes —
  exactly the pattern `gate-house-standard.md` names as the root cause
  of "2-3 different idioms each, one confirmed live bug" across the 43
  downstream repos it surveyed. Citing `gate-lib.sh`/`gate-lib.py`'s
  exact function names (per the adoption table) rather than describing
  equivalent logic in prose is what makes this proposal auditable
  against `compliance-check.sh`'s actual detector rules, not just
  plausible-sounding.
- **Locality and semantic-upgrade fixes are local-only because
  gate-lib provides no equivalent.** `gate-lib.sh`/`gate-lib.py`
  supply infrastructure (trap, kill switch, JSON parse, path
  normalize, write reconstruct) that is genuinely shared across any
  rulebook's gates; `interface-spec-gate`'s label-to-heading windowing
  and `evidence-citation-gate`'s citation-phrase recognition are this
  rulebook's own methodology-specific content checks, with no
  equivalent in core's library and no reason to expect one — core's
  precondition is infrastructure, not per-methodology semantics, and
  this proposal does not misattribute the semantic fixes to core.
- **Structural (section/adjacency) checks generalize the same fix
  shape already correct in three of the six gates.**
  `versioning-strategy-gate` and `deprecation-plan-gate` already window
  their mechanism/date and header/date checks to the label's own
  section; `adr-section-gate` already scopes each ADR section's
  non-empty-body check between consecutive headings. `interface-
  spec-gate`'s fix and `evidence-citation-gate`'s fix both bring a
  gate that had drifted from this already-established, already-correct
  in-repo pattern back in line with it, rather than inventing a novel
  mechanism specific to just these two gates.
- **The mandatory test list is scoped to what the issue and the
  gate-house standard both independently require, not padded.** Cases
  3, 5, and 10 map directly to gate-house-standard.md's own six
  mandatory harness cases (Edit+replace_all, MultiEdit mixed
  replace_all, kill-switch garbage); cases 7, 12-13 map to the
  malformed-JSON and absolute/relative-path requirements this issue's
  own text names explicitly; cases 1-2, 4, 6, 8-9, 11 are the
  necessary complements (positive/negative baselines, default-behavior
  regression guards) without which the new mandatory cases would be
  untestable in isolation.

## Consequences

**Easier:** all six gates gain a uniform, centrally-fixed fail-closed
posture (trap, kill switch, JSON parse, path normalize, write
reconstruct) traceable to one upstream library instead of six
independently-drifting copies; `interface-spec-gate` and
`evidence-citation-gate`'s methodology checks become resistant to the
two concrete bypasses (locality leak, closed-list/bare-substring
citation) the 2026-08-01 audit found; `directive.sh` prints correctly
in this and other real workspace layouts instead of silently failing
in some of them; the six test suites gain the mandatory coverage
needed to catch a `replace_all` or kill-switch regression before it
ships, closing the exact gap that let three of these four defects go
undetected until a manual audit found them.

**Harder:** all six `gate.sh` files and `directive.sh` now carry a
runtime dependency on `tokenmaxxxer-core`'s `gate-lib.sh`/`gate-lib.py`
being resolvable at the path each script's own
`CLAUDE_PLUGIN_ROOT_CORE`-with-fallback expression computes — the same
class of dependency that caused defect 3 in `directive.sh`, now
extended (correctly, this time, per the path-matching fix's own
verification requirement) to six more files; each of those six files'
own fallback-path expression must be independently verified against a
real marketplace-install layout before phase-2 ships, not merely
assumed to work because `directive.sh`'s analogous expression was
fixed. Test-suite size roughly doubles across all six files (13
mandatory case categories added per file, on top of the 6-9 cases each
already has), a maintenance cost accepted deliberately for the
regression protection it buys.

**Versioning/deprecation for this remediation itself:** all four fixes
(locality, semantic-upgrade, path, tests) are corrections to already-
shipped issue #7 plugins, not a new methodology — nothing is deprecated
or removed from this role's `PRODUCES`/`WRITE_SCOPE` surface; `N/A —
not a versioning-strategy or deprecation-plan facet change, a gate-
implementation-correctness fix` for this proposal's own scope.

**Preserving `WRITE_SCOPE: []`:** none of the fixes above adds, widens,
or redesigns this role's write scope. Every fix is either (a) a gate
becoming *more* accurate at denying writes it should already have
denied (interface-spec locality, evidence-citation semantics), (b) an
infrastructure swap with no change to which paths are evaluated or
what "pass" means for already-passing content (fail-closed rework), or
(c) a `SessionStart`-hook path-resolution fix with no write-permission
implication at all (`directive.sh`). The one item flagged as tempting
scope creep — widening `hooks.json` matchers to include `Bash` — is
explicitly deferred (see "Explicitly out of scope"), precisely because
it would be a genuine write-surface change requiring its own phase-1
cycle, unlike every fix actually proposed here.
