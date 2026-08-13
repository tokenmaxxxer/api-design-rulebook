---
axis: versioning-evolution
rule_count_floor: 10
---

# Versioning & evolution

Research trail: Stripe's date-based versioning docs, GitHub REST API versioning/deprecation docs, Microsoft Graph and Azure versioning policies, Google AIP-180/181, Zalando's RESTful API guidelines, RFC 8594 (Sunset header), the OpenAPI `deprecated` convention, and the Adams/Converse/Hales/Klotz (Nature 2021) subtraction-neglect finding, all fetched or read via search this session.

## Rules

1. When deciding how to expose API versions at all, prefer a versioning scheme that lets you ship additive changes continuously without forcing a version bump, and reserve an explicit version identifier only for backward-incompatible releases — Stripe issues monthly releases containing only backward-compatible changes under the same version name, and only bumps the named version (e.g., "Basil") for breaking changes. source: https://docs.stripe.com/upgrades.md

2. When a URL-based version prefix (e.g., `/v1/customers`) is being proposed, avoid it in favor of a header- or media-type-based version signal, because URL versioning creates tight coupling and complicates hyperlinked/HATEOAS-style service dependencies — Zalando's guidelines explicitly prohibit URL versioning for this reason and reserve custom media types for endpoint versioning tied to incompatible changes. source: https://github.com/zalando/restful-api-guidelines/blob/main/chapters/deprecation.adoc

3. When classifying whether a proposed change is breaking, treat adding new optional request parameters, adding new response properties, reordering response properties, adding new resources, and adding new webhook/event types as non-breaking — but treat adding a required parameter, changing a type, or renaming/removing a property or method as breaking. source: https://docs.stripe.com/upgrades.md

4. When classifying a schema/message-level change against Google's API design guidance, treat removal of any existing component (interface, method, message, field, enum, or enum value) as backward-incompatible within the same major version, and likewise treat moving a field into/out of a `oneof` or changing a field's type (even if wire-compatible) as breaking, since both alter generated client code. source: https://google.aip.dev/180

5. When your API returns opaque strings such as IDs or error messages, do not treat a client's assumption about their exact length or format as part of the contract — Stripe classifies changing the length/format of opaque strings (including added/removed ID prefixes) as backward-compatible, so consumers must be built to tolerate this rather than hardcode format. source: https://docs.stripe.com/upgrades.md

6. When choosing between adding a new field/parameter and cutting a new API version, default to the additive field so long as the change is optional-in/optional-out and doesn't alter existing behavior — Microsoft Graph's breaking-change definition (removing/renaming endpoints, removing required fields, changing response structures) implies additive, optional fields are the standard non-version-bumping evolution path. source: https://learn.microsoft.com/en-us/graph/versioning-and-support

7. When your organization needs a formal gate before merging any interface change, route the change through a dedicated review process comparing it against a written breaking-change policy rather than relying on author judgment — Azure requires PRs touching `azure-rest-api-specs` to pass its Breaking Change Review Board before merge. source: https://devblogs.microsoft.com/azure-sdk/azure-approach-to-versioning-and-avoiding-breaking-changes/

8. When you deprecate a field, endpoint, or parameter in an OpenAPI-described API, mark it with `deprecated: true` in the schema/parameter object (not just prose in a changelog), so tooling and generated clients can surface the deprecation programmatically; keep the deprecated element usable until formal removal. source: https://spec.openapis.org/oas/v3.2.0.html

9. **REMOVAL**: When retiring an API version or feature, do not remove it unilaterally on your own timeline — first confirm all known consumers have consented to a sunset date, publish a migration guide, and only then proceed to shutdown; during the interim, send `Deprecation` and (when a firm date is set) `Sunset` response headers so automated clients can detect the coming removal. source: https://github.com/zalando/restful-api-guidelines/blob/main/chapters/deprecation.adoc

10. **REMOVAL**: When you have committed to a concrete removal date for a resource, communicate it via the standard `Sunset` HTTP response header (an HTTP-date value) rather than only in docs or email, and optionally pair it with a `sunset` link relation pointing to a migration/deprecation policy page, since RFC 8594 defines exactly this machine-readable mechanism for signaling upcoming unresponsiveness. source: https://www.rfc-editor.org/rfc/rfc8594.html

11. When setting a deprecation-to-removal timeline for a GA (generally available) API version, hold a minimum 24-month notice window before retiring it — both GitHub (API versions supported 24 months after a newer version ships) and Microsoft (APIs/versions deprecated at least 24 months before removal from GA) converge independently on this floor, making it a reasonable default absent a stronger reason to move faster or slower. source: https://docs.github.com/en/rest/about-the-rest-api/api-versions

12. **REMOVAL**: When planning a deprecation/removal effort, budget extra review and communication effort specifically for the subtractive step (not just the additive rollout), because people systematically default to generating and noticing additive changes and overlook subtractive ones even when removal is the objectively correct move — expect deprecated-field removal to get silently skipped or under-scoped in planning unless explicitly called out as its own tracked task. source: https://www.nature.com/articles/s41586-021-03380-y

13. When an emergency (critical security vulnerability, data exposure, severe reliability issue) makes a breaking change necessary before your normal deprecation timeline completes, treat the standard notice-and-sunset process as overridable — GitHub explicitly reserves the right to ship an unscheduled version, backport fixes, or in rare cases break an existing supported version to protect users, rather than being bound by the routine schedule. source: https://docs.github.com/en/rest/about-the-rest-api/breaking-changes

14. When a breaking-change policy (rule 3-4 above) exists but its enforcement depends on a human re-reading the whole spec diff at review time, replace that with an automated compatibility check that runs on every proposed spec change and fails the build on a disallowed diff class — CI-run compatibility checkers for both schema-first (OpenAPI) and IDL-first (protobuf/gRPC) APIs converge on comparing the previous published spec against the proposed one file-by-file rather than trusting reviewer memory, and independent breaking-change detectors report finding violations human review missed. source: https://buf.build/docs/breaking/overview/

15. When defining what counts as a breaking change for machine-checkable enforcement, do not collapse the category to one bit (breaking/non-breaking) — separate it into at least: source-level compatibility (does generated client/server code still compile against the new spec), wire-level compatibility (do bytes/JSON produced by an old client or server still parse correctly under the new spec), and semantic compatibility (does the same request now produce different externally-visible behavior) — a change can hold one axis and violate another (e.g., widening an int32 to int64 stays wire-compatible in protobuf but is source-breaking in strongly-typed clients), so a rule 3/4-style breaking/non-breaking table needs a compatibility-axis tag, not just a verdict. source: https://buf.build/docs/breaking/rules/
