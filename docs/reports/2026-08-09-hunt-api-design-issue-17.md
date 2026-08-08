---
proposal: docs/issue-17/proposals/api-design.md
---

# Hunt record — api-design-issue-17

## before-landing — stance 0: assume the gate just touched is bypassable — find the bypass

Verdict: FINDING — interface-spec-gate's new openapi_version:/spectral_ruleset_id: cue regex matches the bare field name plus colon with no value validation, so a placeholder like `openapi_version: not_specified` satisfies the "no N/A form accepted" machine-readable-format-cue requirement.
Kind: design-error
Seed: api-design/plugins/interface-spec-gate/hooks/gate.sh — format_cue_re additive alternative for openapi_version/spectral_ruleset_id
cap_seconds: 180
tier: size:>5-files
diff_stat_lines: ~150
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:15:00Z

### Reproduce
Payload (via stdin to the gate, CLAUDE_PROJECT_DIR/CLAUDE_PLUGIN_ROOT_CORE set to a valid core checkout), targeting the in-scope report path under the interface-spec label:

```json
{"tool_name":"Write","tool_input":{"file_path":"<in-scope api-design report path>","content":"# api-design\n\n## interface-spec\nopenapi_version: not_specified\n"}}
```

```
cat payload.json | bash api-design/plugins/interface-spec-gate/hooks/gate.sh
echo EXIT=$?
```

### Observed
`EXIT=0` — the write is allowed. The content contains no actual OpenAPI/AsyncAPI/protobuf/gRPC/IDL artifact reference and no real spec version identifier — just the literal field-name token `openapi_version:` followed by an explicit non-value placeholder (`not_specified`). The gate's own comment/deny message states "no N/A form accepted for this facet," but the additive cue regex only checks for the field-name-plus-colon token and never validates that a real value follows it, letting an N/A-equivalent placeholder through under a different spelling.

### Expected
A record whose interface-spec section contains only a field name with a non-substantive/placeholder value (`not_specified`, `N/A`, `TBD`, etc.) after `openapi_version:`/`spectral_ruleset_id:` should be denied, consistent with the pre-existing "no N/A form accepted" rule enforced for the openapi/asyncapi/protobuf/grpc/idl literal-word cue.
