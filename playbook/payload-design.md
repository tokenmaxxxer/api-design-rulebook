---
axis: payload-design
rule_count_floor: 10
---

# Payload design (pagination, filtering, field selection)

Research trail: fetched/read Stripe's pagination docs, GitHub REST API pagination docs, Slack's cursor pagination docs, Microsoft REST API Guidelines, Google AIP-158 (pagination) and AIP-160 (filtering), the JSON:API v1.1 spec, and independent engineering write-ups on offset vs. keyset performance (GitLab, Sequin, design gurus). Rules below are decision-grade: each names a trigger condition and the choice it forces, not a taxonomy of pagination styles.

## Rules

1. When a collection can grow past a few thousand rows and clients mostly page forward sequentially (activity feeds, list-all sync jobs), use cursor/keyset pagination keyed on an opaque or ID-based cursor rather than numeric offsets — offset queries degrade to O(n) per page because the database must still traverse and discard all preceding rows, while keyset lookups stay near O(1) regardless of depth. source: https://blog.sequinstream.com/keyset-cursors-not-offsets-for-postgres-pagination/

2. When users need to jump to an arbitrary page number or see total result counts (admin dashboards, reporting UIs), keep offset-style pagination available even if cursor pagination is the default for the same resource — cursors cannot support random-access jumps or cheap total counts, and offset pagination remains adequate for shallow, human-browsed pages. source: https://blog.paulserban.eu/post/pagination-patterns-explained-offset-vs-cursor-vs-keyset-with-real-world-tradeoffs/

3. When designing a list endpoint's pagination response, return a boolean continuation flag (e.g. `has_more`) alongside the page's `data` array instead of requiring clients to infer completion from an empty page or a returned-count-less-than-limit check — Stripe's list endpoints return `has_more` explicitly so callers loop correctly and don't silently drop trailing objects. source: https://docs.stripe.com/pagination

4. When a list endpoint could return enough rows to matter for cost or latency, always implement server-driven paging with a `limit`/page-size parameter capped at a max, even for resources that are small today — Microsoft's guidelines require supporting server-side paging up front because adding it later to an existing method is a breaking change for AIP-based collections and a compatibility hazard generally. source: https://google.aip.dev/158

5. When exposing a paginated collection over HTTP, prefer opaque, server-issued page tokens (a cursor string) over exposing raw internal keys or offsets in the parameter — GitHub's pagination model surfaces `next`/`prev`/`first`/`last` links in a `Link` response header rather than making clients construct query strings by hand, decoupling the pagination mechanism from client logic. source: https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api

6. When an endpoint supports both a full list and a targeted lookup (e.g. Stripe's `/customers` list vs. `/customers/search`), give search/query endpoints their own distinct cursor parameter (`page`/`next_page`) rather than reusing the list endpoint's `starting_after`/`ending_before` object-ID cursors — the underlying indexing differs (search results aren't strictly ID-ordered), so conflating the two cursor semantics produces incorrect pagination. source: https://docs.stripe.com/api/pagination/search

7. When clients need to fetch resources with different sets of relationships or nested detail, expose an explicit `fields[type]=a,b,c` sparse-fieldset query parameter rather than a fixed-shape response, letting clients opt into exactly the attributes they need per resource type. source: https://jsonapi.org/format/

8. **REMOVAL**: When a resource's default list/get response includes rarely-used relationship or attribute data, stop returning it by default and require clients to request it explicitly via sparse fieldsets or an `include`-style parameter — JSON:API's model treats full inclusion as opt-in specifically to keep default payloads small and avoid over-fetching. source: https://jsonapi.org/format/

9. When designing filter query parameters for a list/search method, use a single structured filter-expression string parameter (e.g. `filter=state=ACTIVE AND createTime>...`) with a documented grammar rather than one ad hoc query parameter per filterable field — AIP-160 standardizes this so filter capability can grow without breaking the parameter surface and stays legible to non-technical callers. source: https://google.aip.dev/160

10. **REMOVAL**: When a list endpoint currently returns a top-level `total_count`/`total_size` field computed via a full `COUNT(*)`, drop it from the default response (or make it opt-in via a separate parameter) once the table is large enough that offset-depth queries already show the O(n) scan problem — computing an exact total forces the same expensive full-scan cost pagination is trying to avoid, and cursor-based collections generally cannot supply an exact count cheaply. source: https://google.aip.dev/158

11. When a list endpoint's result set can be large enough to strain client memory or a single response payload, provide a client-side auto-pagination helper in official SDKs (looping on the continuation flag/cursor until exhausted) instead of expecting every caller to hand-roll pagination loops — Stripe ships this as a standard SDK feature to reduce the chance of naive integrations dropping objects or looping incorrectly. source: https://docs.stripe.com/pagination

12. When a collection is accessed by many concurrent, high-volume API clients (e.g. Slack's channel/user lists), use cursor pagination with a `limit` and `cursor` parameter pair and return the next cursor in a dedicated `response_metadata.next_cursor` field rather than embedding it in `data`, so the continuation token is unambiguous and stable even as the underlying set mutates between calls. source: https://docs.slack.dev/apis/web-api/pagination/
