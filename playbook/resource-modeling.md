---
axis: resource-modeling
rule_count_floor: 10
---

# Resource modeling

Research trail: practitioner layer from Google's AIP-121 (resource-oriented design) and AIP-156 (singleton resources), Microsoft/Azure REST API Guidelines, Zalando RESTful API Guidelines, and a Moesif nested-resources cookbook; named-standard layer from Roy Fielding's REST dissertation (Chapter 5) and the JSON:API v1.1 spec; the academic/HCI layer was thin for this axis beyond Fielding's own architectural-style analysis, which is treated here as the closest available theory source rather than a separate empirical literature.

## Rules

1. When an operation maps cleanly onto Get/List/Create/Update/Delete semantics, model it as a standard method on a noun resource rather than inventing a verb-named endpoint — resource-oriented design's core claim is that a small set of standard methods over many resources scales better for consumers than a large surface of bespoke RPC verbs. source: https://google.aip.dev/121

2. When an operation has no reasonable mapping to a standard CRUD method (e.g., a batch import, a transactional action, an analysis job), model it as a custom method with a verb in the URI rather than forcing it into a fake resource — AIP-121 explicitly reserves custom methods for exactly this case, since a small number of documented exceptions is safer than a proliferation of pseudo-resources built to dodge them. source: https://google.aip.dev/121

3. When a child object always exists exactly once per parent and never appears as zero, many, or independently (e.g., a per-user config object), model it as a singleton resource rather than a one-item collection — AIP-156 defines singletons precisely for this one-to-one-with-parent case and exempts them from supporting List, which a normal collection resource would need. source: https://google.aip.dev/156

4. When you're tempted to make an endpoint's request/response shape for a resource differ between its Get, List, and Create methods, unify the schema instead — AIP-121 requires that a resource's schema be the same across all methods that return or accept it, because divergent shapes force clients to special-case each verb. source: https://google.aip.dev/121

5. When designing a resource hierarchy, keep parent-child relationships acyclic (a strict tree/DAG, never a cycle) — AIP-121 mandates that resource relationships be representable as a directed acyclic graph, since cyclic references break simple hierarchical addressing and pagination assumptions. source: https://google.aip.dev/121

6. When a sub-resource relationship is many-to-many, changes frequently, or needs to be queried across multiple parents (e.g., "all reviews across all books" rather than "reviews of book X"), promote it to a top-level resource instead of nesting it under one parent — nesting hard-codes a single-parent path that breaks under cross-parent queries and N+1 lookups. source: https://www.moesif.com/blog/technical/api-design/REST-API-Design-Best-Practices-for-Sub-and-Nested-Resources/

7. When a sub-resource already has a globally unique identifier and can stand on its own outside the parent's context, expose it at the top level (e.g., `/sales-orders/{id}`) rather than only reachable through the parent path — Zalando's guidelines treat parent-dependent addressing as appropriate only when the child has no independent identity, and unique IDs are the signal that it does. source: https://github.com/zalando/restful-api-guidelines/blob/main/chapters/urls.adoc

8. When nesting is genuinely warranted (strict hierarchy, parent-dependent identity, low churn), cap nesting depth at roughly two to three path segments of resource/id pairs — both Microsoft's Azure guidelines (collection/item/collection maximum) and Zalando's guidelines (≤3 sub-resource levels) converge on a shallow ceiling because deeper paths increase URL length, complexity, and client fragility without added benefit. source: https://github.com/microsoft/api-guidelines/blob/master/Guidelines.md

9. When choosing resource identifiers and paths, model the API around domain/conceptual entities the consumer reasons about, not the underlying storage schema — Microsoft's guidance and Fielding's own definition of a resource as a stable conceptual mapping (not the current entity state) both argue that mirroring your database tables into the URL space couples clients to an implementation detail that will change independently of the concept. source: https://github.com/microsoft/api-guidelines/blob/master/Guidelines.md

10. When you need to represent a relationship between two already-independent resources (e.g., an article and its author) in a response body, use JSON:API-style relationship objects with resource identifier objects (type + id) rather than embedding full duplicate copies of the related resource inline — this keeps a single canonical representation per resource and lets compound documents (`included`) opt into full payloads only when needed. source: https://jsonapi.org/format/

11. **REMOVAL**: When a URL path exceeds roughly three nested resource/id segments (e.g., `/customers/123/orders/456/items/789/notes`), collapse the excess nesting into a flatter, independently addressable resource or a query-parameter-based relationship (e.g., `/notes?item=789`) — both the Microsoft and Zalando guidelines flag this as the point where nesting stops improving discoverability and starts causing fragile, hard-to-maintain client code. source: https://github.com/microsoft/api-guidelines/blob/master/Guidelines.md

12. **REMOVAL**: When an endpoint's shape is identical to an internal database table (same columns, same joins reflected as sub-resources), drop the one-to-one mirroring and consolidate or reshape it around the conceptual resource the consumer actually needs — AIP-121 calls API-equals-database-schema an anti-pattern because it tightly couples the public surface to internal storage, forcing a breaking API change every time the schema is refactored. source: https://google.aip.dev/121
