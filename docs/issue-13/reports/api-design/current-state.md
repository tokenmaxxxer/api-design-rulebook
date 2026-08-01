# Current-state survey — issue #13 (재감사 잔여 결함 보수)

Subject: issue-13. Scope: this repo's six `api-design/plugins/*/hooks/gate.sh`
gates, their `hooks.json` matchers, `tests/api-design/*.sh`, and
README/manifest text. Phase 1 only — no code changes made.

## Preconditions verified landed

- **core#75** (`tokenmaxxxer-core` commit `52bdc15`, PR #77): confirmed on
  disk. Adds (a) the mandatory `||`-guarded `gate-lib.sh` source line
  convention — `. ".../gate-lib.sh" || { echo "<gate>: cannot source
  gate-lib.sh" >&2; exit 2; }` — across `gate-lib.sh`'s own usage-contract
  comment and all 7 core gates; (b) a `compliance-check.sh` detection rule
  that fails any gate sourcing `gate-lib.sh"$` (source with no `||` guard
  on the same line) plus a missing-core deny test case for it; (c)
  `gate_bash_write_targets` ported to `gate-lib.py` (regex
  `[A-Za-z0-9_./~$-]+`), sh/py parity-tested.
- **on-the-record#182** (`e50fe08`, on branch `issue-182/implementation`,
  not yet merged to main but code-complete): `spawn_cmd()` now injects
  `CLAUDE_PLUGIN_ROOT_CORE` from the resolved core plugin-dir entry
  instead of falling through to an unresolvable relative path.

Both are usable as the "확정된 가드 형태" to reference-apply per the issue.

## Re-verification of the issue's specific defect claims

Ran `tests/api-design/evidence-citation-gate.sh` directly (all 20 cases
pass, including case 9 "Stripe/AWS citation-phrase claims allowed" and
case 10 "bare unsignaled 'Google' mention denied") and read
`evidence-citation-gate/hooks/gate.sh:114-133` and
`interface-spec-gate/hooks/gate.sh:115-134` directly:

- **"인용 게이트가 실선행 API(Stripe/AWS) 거부·'google' 부분문자열 통과"**:
  NOT reproducible in current code. The citation-phrase regex
  (`per|sourced to|following|as documented by|as specified by` + capitalized
  token) correctly accepts "per Stripe's API design review practice" /
  "following AWS's API guidelines" and correctly rejects a bare "checked
  Google for prior art" with no connector phrase. No substring/domain
  matching on "google" exists anywhere in this gate.
- **"interface-spec cue 문서 전역 grep (국소성 미이행)"**: the format-cue
  check in `interface-spec-gate/hooks/gate.sh:127-134` is windowed to the
  text between the `interface-spec` label match and the next Markdown
  heading (`next_heading = re.search(r'\n#{1,6}\s', after)`), not a
  whole-document grep. When the label is the last section in the file (no
  following heading), `window` falls through to the entire remainder —
  this is a genuine but narrow locality gap (falls back to "rest of
  document" only in the label-is-last-section case), not the blanket
  whole-doc grep the issue describes.

Both were fixed in `8b2eda1` (Issue #10 phase 2, core gate-lib adoption) —
this is the only commit that has touched either gate.sh since #7 phase 2.
The re-audit that produced issue #13 appears to predate or have missed
that landing for these two specific claims. Confirmed independently by a
second, isolated agent read of the same two files.

## Defects confirmed still present

1. **Missing `||` source guard (all 6 gates)** — `grep -n
   'gate-lib\.sh"$'` matches all six `api-design/plugins/*/hooks/gate.sh`
   sourcing lines; none carry the `|| { ...; exit 2; }` guard core#75
   added. Same fail-open-on-missing-core defect class core#75 fixed at
   the core layer: an unguarded failed `source` runs no code, so
   `gate_kill_switch_active` (etc.) is undefined afterward and every
   `... || { exit 0; }` call site reads that as "kill switch off,"
   silently allowing everything when `CLAUDE_PLUGIN_ROOT_CORE` is
   unreachable. This repo would also fail core's new
   `compliance-check.sh` rule as-is.
2. **`interface-spec-gate` window locality gap** — falls back to
   "rest of document" when the `interface-spec` label has no following
   Markdown heading (see above). Narrower than the issue's "전역 grep"
   description but a real locality defect worth closing while in the
   file.
3. **Zero MultiEdit test coverage in 2 of 6 plugins** — `grep -c
   '"MultiEdit"' tests/api-design/*.sh`: `adr-section-gate.sh` → 0,
   `interface-spec-gate.sh` → 0 (the other four have 1-2 MultiEdit
   cases). `hooks.json` in all six plugins advertises `matcher:
   "Write|Edit|MultiEdit"` and all six `gate.sh` handle `tool in
   ("Write","Edit","MultiEdit")` identically in code — so the matcher/code
   coverage itself is already consistent (issue requirement 2 is already
   met); the gap is test coverage, not reachability.
4. **README/manifest sweep** — grepped top-level `README.md`, all six
   plugin `README.md`s, and all `.claude-plugin/plugin.json` manifests for
   stale role names (other 43-taxonomy role names) and for filenames
   referenced but absent on disk (`api-design/hooks/hooks.json`,
   `api-design/hooks/directive.sh`, `tests/api-design/lib/core-fixture.sh`
   all exist as documented). Found no stale role names and no ghost-file
   references. Requirement 4 appears already satisfied; phase 2 will
   re-check after the other fixes land (new files/renames could introduce
   fresh drift) but no remediation is currently expected here.

## gate_bash_write_targets applicability

None of the six api-design gates parse `Bash` tool_input; all six gate on
`Write|Edit|MultiEdit` `file_path`/content reconstruction only. core#75's
`gate_bash_write_targets` (a Bash-command token scanner) has no call site
to port to in this repo — not applicable here.
