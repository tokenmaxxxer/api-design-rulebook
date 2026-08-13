---
axis: http-semantics
rule_count_floor: 10
---

# HTTP method & status code semantics

This playbook synthesizes RFC 9110 (HTTP Semantics) and the IANA HTTP status code registry as primary standards, cross-checked against practitioner guidance from Stripe's idempotency docs, Google AIP-131, Microsoft/Azure REST API Guidelines, and the Zalando RESTful API Guidelines, all fetched this session. Rules are ordered decision-first: condition, imperative choice, and the source reasoning.

## Rules

1. When a request only retrieves data and causes no server-side state change, use GET (or HEAD/OPTIONS), never POST — RFC 9110 defines "safe" methods as those whose semantics are read-only, so clients and intermediaries (caches, crawlers, proxies) can invoke them without user warning; violating this breaks caching and prefetching assumptions. source: https://www.rfc-editor.org/rfc/rfc9110.html

2. When a client needs to safely retry a request after a timeout or dropped connection, only rely on automatic retry-without-side-effects for GET, HEAD, PUT, DELETE, OPTIONS, and TRACE — RFC 9110 defines these as idempotent (repeated identical requests yield the same server state as one request); POST and arbitrary PATCH are excluded because repetition is not guaranteed side-effect-free. source: https://www.rfc-editor.org/rfc/rfc9110.html

3. When a client must create or mutate a resource via POST but the network is unreliable, require an `Idempotency-Key` header, generated client-side as a high-entropy value (Stripe recommends a v4 UUID) and cache the first response (status + body) keyed to it for a bounded window (Stripe uses ~24 hours) so retries return the original result instead of executing twice — mismatched parameters on key reuse should error rather than silently proceeding. source: https://docs.stripe.com/idempotency

4. When designing idempotency-key behavior, do not send an idempotency key on GET or DELETE requests — Stripe's docs state these are idempotent by definition and the key has no effect, so adding one just adds client-side complexity with zero benefit. source: https://docs.stripe.com/idempotency

5. When a client wants to fully replace a resource's representation at a known identifier (including client-assigned IDs), use PUT rather than POST — Azure/Microsoft guidelines note PUT (like PATCH) is preferred for resource creation when idempotency and client-chosen naming matter, since PUT's semantics guarantee repeated identical requests converge to the same state. source: https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md

6. When a client needs to apply a partial, incremental modification to a resource, use PATCH rather than PUT — Microsoft's guidelines flag PUT as dangerous for partial updates because a client resending a stale full-replacement payload can silently clobber fields it didn't intend to touch; PATCH (RFC 5789) is the IETF-standardized method for incremental updates. source: https://github.com/microsoft/api-guidelines/blob/master/Guidelines.md

7. When a server team wants POST-based resource creation to be safely retryable (e.g., "create order" triggered twice by a flaky client), design idempotency via a client-supplied secondary key or an `Idempotency-Key`/`Repeatability-Request-ID` header rather than assuming POST is naturally safe to repeat — both Zalando ("SHOULD use secondary key for idempotent POST design") and Azure guidelines (Repeatability-Request-ID + Repeatability-First-Sent headers) converge on this pattern because RFC 9110 explicitly leaves POST idempotency unguaranteed by default. source: https://opensource.zalando.com/restful-api-guidelines/

8. When a resource is successfully created via POST or PUT, return 201 Created with a `Location` header pointing to the new resource, not a bare 200 OK — this is the status IANA/RFC 9110 §15.3.2 designates specifically for creation, and omitting it forces clients to guess success semantics from body inspection alone. source: https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

9. When an operation succeeds but there is no representation to return (e.g., a successful DELETE or a PUT that intentionally returns nothing), return 204 No Content rather than 200 OK with an empty or placeholder body — this matches the IANA registry's definition of 204 as "successful action with no content to return" and avoids clients having to special-case empty 200 bodies. source: https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

10. When a create/update/delete operation is processed asynchronously (queued, not completed by response time), return 202 Accepted instead of 200/201 — Zalando's guidelines list 202 explicitly for "asynchronous processing," signaling to clients that they must poll or subscribe for the eventual result rather than treating the resource as already in its final state. source: https://opensource.zalando.com/restful-api-guidelines/

11. **REMOVAL**: When choosing a redirect status for cross-origin or proxy-mediated indirection, drop 305 Use Proxy from the design vocabulary entirely — the IANA HTTP status code registry marks it as deprecated/problematic in modern implementations (major browsers never implemented it safely), so use 307/308 (method-preserving) or 301/302/303 as appropriate instead. source: https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml

12. **REMOVAL**: When a numbered API operation like AIP-131's standard `Get` is being designed, collapse ad hoc verbs like "Fetch" or "Retrieve" as separate custom methods and standardize solely on GET with the resource name in the path — Google's AIP-131 mandates "the HTTP verb must be GET" for standard Get methods, removing the temptation to invent synonymous custom RPC-style endpoints for simple reads. source: https://google.aip.dev/131
