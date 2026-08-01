# evidence-citation-gate

A `PreToolUse` gate (matching `Write|Edit|MultiEdit`) that enforces the
evidence-citation discipline established for the api-design rulebook by
issue #1.

## Methodology

Any paragraph in a phase-1 api-design proposal that asserts a "standard
practice", "common practice", "established practice", "is standard", or
"conventionally" conventionality claim must name a source in that same
paragraph. A source is either:

- an RFC number (e.g. `RFC 8594`), or
- a citation phrase: a citation-signal word (`per`, `sourced to`,
  `following`, `as documented by`, `as specified by`) immediately
  preceding a capitalized org token, optionally followed by a
  guideline-shaped noun (`guidelines`, `guidance`, `design review`,
  `design practice`, `design guide`, `API`, `RFC`, `spec`/`specification`).
  Examples: "per Stripe's API design review practice", "following AWS's
  API guidelines", "per Google AIP". This check is structural, not a
  closed enumerated list of organization names — it recognizes any
  capitalized org token that a citation-signal word points at, so
  vendors like Stripe or AWS are recognized on the same footing as
  Zalando or Google without needing to be added to a list. A bare
  mention of an org name with no citation-signal word immediately
  before it (e.g. "a search on Google" or "we also checked Google for
  prior art") does not count as a source.

If a paragraph makes a conventionality claim without naming any such
source in the same paragraph, the gate denies the write and names the
specific unsourced claim in its refusal message.

## Scope

The gate only evaluates writes targeting paths matching:

```
docs/issue-<n>/proposals/*api-design*.md
```

(regex: `^docs/issue-[0-9]+/proposals/.*api-design.*\.md$`, relative to
the detected project root). Writes outside this scope are allowed
unconditionally (exit 0) without inspecting their content.

## Fail-closed behavior

The gate fails closed (exit 2, deny) whenever it cannot make a
confident allow decision: missing `python3`, unparsable stdin payload,
no determinable project root, an on-disk file it cannot read, or an
`Edit`/`MultiEdit` whose `old_string` does not match the current
on-disk content (so the resulting text cannot be reconstructed). Only
a positive, fully-determined allow decision returns exit 0.

## Kill switch

Set `EVIDENCE_CITATION_GATE_OFF=1` (or any truthy-looking non-empty,
non-`0`/`false`/`no`/`off` value) in the environment to disable the
gate entirely. Unset or falsy values leave the gate active.

## Core adoption

This gate sources core's gate-house standard (issue #72) rather than
hand-rolling its own trap/kill-switch/parse/path/reconstruct machinery.
From `gate-lib.sh`: `gate_trap_fail_closed` installs the fail-closed
EXIT trap, and `gate_kill_switch_active` evaluates
`EVIDENCE_CITATION_GATE_OFF`. `deny()` is a thin wrapper around
`gate_deny`. From `gate-lib.py` (loaded via `importlib` inside the
embedded Python payload): `gate_parse_json_or_deny` parses the stdin
payload, `gate_normalize_path` resolves the target path against the
project root, and `gate_reconstruct_write` reconstructs the resulting
content for Write/Edit/MultiEdit. The methodology check itself —
citation-phrase matching — remains local to this plugin, by reference
only, never vendored.

## Independence

This plugin is self-contained. It does not read, import, or depend on
any other plugin under `api-design/plugins/`, on `marketplace.json`,
or on `directive.sh`. It determines its own scope, its own project
root, and its own pass/fail judgment using only the tool-call payload
it receives on stdin.
