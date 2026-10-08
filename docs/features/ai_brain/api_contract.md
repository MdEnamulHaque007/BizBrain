# AI Brain — API Contract (v1)

This document specifies the backend API contract for the AI Brain feature used by the BizBrain Flutter client. The backend implements AI inference, context building, knowledge retrieval, rule execution and approval workflows. The Flutter app is a consumer (UI + API client) and never holds secrets or performs LLM inference directly.

---

## 1. Overview

### Backend responsibilities
- Model gateway: Authenticate requests, route to a self-hosted LLM (or inference cluster), manage tokens/quota and bill per-tenant.
- Context building: Aggregate tenant-scoped business facts/time-series/connector payloads into an immutable BusinessContext used for inference and rules.
- Rule execution: Execute tenant business rules against a BusinessContext and produce RuleExecutionReport; forward actions to approval workflow when required.
- Knowledge retrieval: Serve vector/keyword search over organizational knowledge and return ranked KnowledgeChunk items.
- Approval & memory: Manage human-in-the-loop approval requests and persist feedback into long-term memory.
- Connectors: Run backend-only connectors to external systems (credentials in secret manager) and stream sync events.

### Flutter app responsibilities
- Authenticate users (Firebase Auth) and include an ID token on requests.
- Initiate requests (generate insights, start agents, request approvals, etc.) and render responses.
- Display approval UIs and allow users to approve/reject actions.
- Do not store model API keys or connector secrets.

### Authentication model
- Backend validates Firebase ID tokens for each request.
- Every request must include an organization context (header X-Organization-Id) and will be checked against the token's membership.

---

## 2. Base URL & Headers

- Production base URL: `https://api.bizbrain.app/v1/ai-brain`
- Staging base URL: `https://staging-api.bizbrain.app/v1/ai-brain`

Required headers for authorized endpoints:
- `Authorization: Bearer <firebase-id-token>`
- `X-Organization-Id: <org-id>`
- `Content-Type: application/json` (for JSON bodies)
- Optional: `Idempotency-Key: <uuid>` (see Idempotency section)

---

## 3. Endpoints

All POST endpoints expect JSON request bodies unless otherwise specified. All timestamps use ISO 8601 (UTC). IDs are UUID strings.

Note on status codes used across endpoints:
- 200 OK — successful GET or POST that returns a resource or success result
- 201 Created — a new resource was created
- 202 Accepted — request accepted for async processing
- 204 No Content — successful request with no body (e.g., DELETE)
- 400 Bad Request — validation error
- 401 Unauthorized — missing/invalid Firebase token
- 403 Forbidden — authenticated but insufficient permissions or org mismatch
- 404 Not Found — resource not found
- 409 Conflict — e.g., idempotency conflict
- 429 Too Many Requests — rate limit exceeded
- 500 Internal Server Error — transient server failure

Idempotency: POST requests that may be retried should accept `Idempotency-Key` header (UUID). When provided, server will return the same created resource/result for the same key.

Rate limits: default `X` requests/min per user and per organization; backend returns `429` with `Retry-After` header when exceeded. (Concrete numbers are configured per deployment.)

---

### A) Agent Orchestration

POST /agents/orchestrate
- Description: Start an agent plan (single agent or multi-agent orchestrated run). Can be sync or async depending on options.
- Method: POST
- Path: `/agents/orchestrate`
- Headers: Authorization, X-Organization-Id, Content-Type, Idempotency-Key (optional)

Request body schema:
```json
{
  "agentType": "ceo|finance|operations|sales|quality|hr",
  "input": "string (free form objective / prompt)",
  "context": { "contextId": "optional-context-id" },
  "options": {
    "async": true,
    "stream": false
  }
}
```
Example:
```json
{
  "agentType": "finance",
  "input": "Analyze last quarter cashflow and suggest 3 immediate cost reductions",
  "context": { "contextId": "ctx_123" },
  "options": { "async": true }
}
```

Success responses:
- 202 Accepted (async):
```json
{
  "executionId": "uuid",
  "status": "pending",
  "metadata": { "queuedAt": "2026-10-08T22:00:00Z" }
}
```
- 200 OK (sync completed):
```json
{
  "executionId": "uuid",
  "status": "completed",
  "result": {
    "summary": "...",
    "recommendations": ["..."],
    "requiresApproval": true
  },
  "metadata": { "modelId": "llm-13b", "durationMs": 1200 }
}
```

Errors: 400 / 401 / 403 / 429 / 500 with `ErrorResponse` (see Common Schemas).

Idempotency: supported. If provided and duplicate the server will return the original executionId and result.

SSE / streaming: use `/agents/orchestrate/stream` for real-time events (see Streaming Support section).

GET /agents/{executionId}
- Returns execution status/result.
- 200 OK:
```json
{
  "executionId": "uuid",
  "status": "pending|running|completed|failed",
  "result": null | { ... },
  "metadata": { ... }
}
```

---

### B) Insights Generation

POST /insights/generate
- Description: Generate insights from a BusinessContext using the model pipeline. Backend builds prompts and applies safety checks.
- Method: POST
- Path: `/insights/generate`
- Headers: Authorization, X-Organization-Id, Content-Type, Idempotency-Key (recommended)

Request body:
```json
{
  "dataSourceIds": ["sheet_1", "erp_foo"],
  "contextId": "ctx_123",      
  "prompt": "optional additional prompt or question",
  "options": { "includeNewsFeed": true, "maxInsights": 5 }
}
```

Success (201 Created or 200 OK):
```json
{
  "insightId": "uuid",
  "title": "Sales dip in region X",
  "content": "Longer summary text or markdown",
  "confidenceScore": 0.82,
  "sources": [ { "id": "doc_1", "title": "Q3 report" } ]
}
```

GET /insights
- Query params: `organizationId` (required), `limit`, `cursor`, `status` (pending|published|archived)
- Example: `/insights?organizationId=org_123&limit=20`

Response:
```json
{
  "items": [ { "insightId":"uuid", "title":"...", "severity":"info" } ],
  "nextCursor": "opaque-cursor",
  "total": 123
}
```

GET /insights/{id}
- Returns the full persisted insight object including metadata and confidence.
- 200 OK: full object
- 404 Not Found if no insight or not in org scope

DELETE /insights/{id}
- Deletes (or archives) an insight. Only admin/owner roles allowed.
- 204 No Content on success
- 403 if insufficient permissions

---

### C) Approval Workflow

POST /approvals
- Description: Create an approval request for an automated action suggested by agents or rules.
- Method: POST
- Path: `/approvals`
- Headers: Authorization, X-Organization-Id, Content-Type, Idempotency-Key

Request:
```json
{
  "requestType": "automation|publish_insight|execute_action",
  "requestData": { "action": "transfer_funds", "amount": 1000 },
  "title": "Transfer $1000 to vendor X",
  "description": "Automated payment proposed by finance agent",
  "approvers": ["userId1","userId2"]
}
```

Response (201):
```json
{
  "approvalId": "uuid",
  "status": "pending",
  "requiredApprovals": 2
}
```

GET /approvals?status=pending
- Lists pending approvals visible to the caller (scoped by org + role)

POST /approvals/{id}/approve
- Request: `{ "decision": "approve", "notes": "looks good" }`
- 200 OK on success
- Triggers webhook/notification to subscribers when the approval reaches final state

POST /approvals/{id}/reject
- Request: `{ "decision": "reject", "notes": "insufficient justification" }`
- 200 OK

Notes:
- Decisions are written server-side with the acting user's ID (from token) for auditability.
- Approval timeouts and escalation policies are configurable (see metadata).

---

### D) Business Context

POST /context/build
- Description: Instruct backend to build a BusinessContext for a time window and return `contextId`.
- Method: POST
- Path: `/context/build`
- Headers: Authorization, X-Organization-Id, Content-Type, Idempotency-Key

Request:
```json
{
  "dataSourceIds": ["erp_x","sheet_1"],
  "from": "2026-07-01T00:00:00Z",
  "to": "2026-09-30T23:59:59Z",
  "contextType": "summary|detailed"
}
```

Response (201 / 200):
```json
{
  "contextId": "ctx_123",
  "data": { "facts": { "revenue_q3": 12345 }, "knowledgeRefs": ["k_1","k_2"] },
  "version": "v1",
  "validUntil": "2026-10-08T23:59:59Z"
}
```

GET /context/{id}
- 200 OK returns full BusinessContext
- 404 if not found or out of scope

---

### E) Knowledge Retrieval

POST /knowledge/search
- Description: Query the organization's knowledge (vector + keyword search). Used by prompt RAG.
- Method: POST
- Path: `/knowledge/search`
- Headers: Authorization, X-Organization-Id, Content-Type

Request:
```json
{
  "query": "customer churn reasons",
  "filters": { "type": "report" },
  "limit": 8
}
```

Response:
```json
{
  "results": [ { "id":"k_1", "title":"Churn analysis Q2", "content":"...", "score":0.92 } ],
  "query": "customer churn reasons"
}
```

POST /knowledge/index
- Description: Index documents into vector store (backend-only). Accepts batch documents.
- Method: POST
- Path: `/knowledge/index`
- Headers: Authorization (service role token recommended), X-Organization-Id, Content-Type

Request:
```json
{
  "documents": [ { "id":"k_1", "title":"Q2 report", "content":"..." } ]
}
```

Response: 201 Created with indexed document ids and per-item status.

---

### F) Memory / Feedback

POST /memory/sessions
- Create / open a memory session.
- Method: POST
- Path: `/memory/sessions`

Request:
```json
{ "sessionId": "optional-uuid", "organizationId": "org_123" }
```

Response:
```json
{ "sessionId": "uuid", "createdAt": "2026-10-08T22:00:00Z" }
```

POST /memory/messages
- Append a message to a session (like chat history).
- Method: POST
- Path: `/memory/messages`

Request:
```json
{
  "sessionId": "uuid",
  "role": "user|assistant|system",
  "content": "text",
  "metadata": { "source": "ui" }
}
```

Response: 201 Created with message id and timestamp.

POST /memory/feedback
- Record feedback related to a message or insight.
- Method: POST
- Path: `/memory/feedback`

Request:
```json
{
  "messageId": "msg_uuid",
  "score": 0-1.0,
  "text": "Correction or comment",
  "authorId": "user_uuid"
}
```

Response: 201 Created

Also `GET /memory/sessions/{id}/messages` and `GET /memory/feedback?organizationId=...` can be implemented for consumption by the UI.

---

### G) Rule Execution

POST /rules/execute
- Description: Execute ruleset for an organization against fresh context.
- Method: POST
- Path: `/rules/execute`
- Headers: Authorization, X-Organization-Id, Content-Type, Idempotency-Key

Request:
```json
{ "ruleId": "optional-specific-rule-id", "inputData": { /* optional override context */ } }
```

Response (202 Accepted / 200):
```json
{ "executionId": "uuid", "status": "completed|pending", "output": { "results": [ { "ruleId":"r1","triggered":true } ] }, "executionTimeMs": 123 }
```

GET /rules/executions/{id}
- Returns the RuleExecutionReport

Notes:
- Rule execution is privileged. Only backend service roles should trigger some classes of rules — client requests are limited to safe read-only evaluations unless authorized.

---

## 4. Common Schemas

### Error response
All error responses follow:
```json
{
  "error": {
    "code": "AI_BRAIN_XXX",
    "message": "Human readable summary",
    "details": { /* optional structured details */ }
  }
}
```

### Pagination
Standard pagination response uses cursor-style paging:
```json
{
  "items": [ ... ],
  "nextCursor": "opaque-cursor",
  "total": 123
}
```

### IDs & timestamps
- IDs: UUID strings (v4 recommended) — e.g., `"3fa85f64-5717-4562-b3fc-2c963f66afa6"`
- Timestamps: ISO 8601 strings in UTC — e.g., `"2026-10-08T22:00:00Z"`

---

## 5. Streaming support

Long running operations may stream progress and partial results using Server-Sent Events (SSE).

Endpoint: POST `/agents/orchestrate/stream`
- The client POSTs the same request body as `/agents/orchestrate` and receives an SSE stream.
- SSE event types:
  - `started` — payload: `{ executionId, queuedAt }`
  - `progress` — payload: `{ executionId, phase, detail }`
  - `result` — payload: `{ executionId, result }` (final result)
  - `error` — payload: `{ executionId, error }`

Example curl consumer:
```bash
curl -N -H "Authorization: Bearer $TOKEN" -H "X-Organization-Id: org_123" \
  -H "Content-Type: application/json" \
  -X POST https://api.bizbrain.app/v1/ai-brain/agents/orchestrate/stream \
  --data '{"agentType":"finance","input":"..."}'
```

Note: SSE connection should be kept alive and reconnect on transient network failures. Server sets `retry:` field and may send `event: ping` heartbeats.

---

## 6. Webhooks (optional)

The backend supports outbound webhooks for integration points. Subscriptions are created per organization.

Example webhook events:
- `approval:decision` — fired when an approval request reaches a final state
- `insight:generated` — fired when a new insight is created

Subscription model:
- POST `/webhooks/subscribe` — `{ eventType, callbackUrl, secretRef }`
- Delivery uses `X-Signature` header HMAC using secret resolved from secret manager.
- Retries: exponential backoff; dead-lettering after N attempts.

---

## 7. Security Requirements

- Every request must include a valid Firebase ID token. Backend validates token and enforces org membership.
- Organization scoping: X-Organization-Id header required for all tenant-scoped endpoints and must match token claims.
- RBAC: roles (admin, owner, member, viewer). Certain endpoints (DELETE insight, /approvals decision writing, rules execution) require specific roles.
- Rate limiting per-organization and per-user. Return `429` with `Retry-After` header.
- Request signing / Idempotency: `Idempotency-Key` for potentially retried destructive requests.
- Secrets: model API keys, connector credentials and webhook signing secrets are stored in a secret manager; clients never receive these values.
- Audit logs: all actions that change state or trigger automation must be logged (who, when, payload summary, decision).

---

## 8. Error Codes (example enum)
Use globally-unique error codes in the `error.code` field:

- `AI_BRAIN_001` — Agent not found
- `AI_BRAIN_002` — Insufficient permissions
- `AI_BRAIN_003` — Model provider unavailable
- `AI_BRAIN_004` — Context build failed
- `AI_BRAIN_005` — Rate limit exceeded
- `AI_BRAIN_006` — Approval timeout
- `AI_BRAIN_007` — Connector unreachable
- `AI_BRAIN_008` — Knowledge index error
- `AI_BRAIN_009` — Invalid idempotency key
- `AI_BRAIN_010` — Invalid request schema

Include `details` in error responses for programmatic handling.

---

## 9. Versioning & Deprecation
- Current API base path: `/v1/ai-brain` (v1)
- When introducing breaking changes: increment major version (`/v2/ai-brain`) and provide a migration guide.
- Deprecation policy: announce deprecation of endpoints 90 days before disabling; include automated deprecation headers `X-Deprecation-Notice` and return a warning in responses for deprecated endpoints.

---

## 10. Implementation notes (for backend & Flutter teams)
- Backend should implement strict validation of `X-Organization-Id` against token claims.
- Use SSE for interactive orchestration where the client needs streaming progress.
- Expose light-weight health/metrics endpoints for model servers: `/health` and `/metrics` (Prometheus) and include modelId/latency in orchestration metadata.
- The Flutter app should implement retry/backoff for 429 responses; show friendly rate-limit messages.
- For integration tests: provide a test stub environment where the model provider returns canned responses and connectors return synthetic data.

---

## Appendix: Example full request/response
**Example: generate insight**

Request:
```http
POST /v1/ai-brain/insights/generate
Authorization: Bearer <token>
X-Organization-Id: org_123
Content-Type: application/json

{
  "dataSourceIds": ["erp_main"],
  "contextId": "ctx_2026_q3",
  "prompt": "Find revenue regressions and provide 3 suggested actions",
  "options": { "includeNewsFeed": true }
}
```

Response (201):
```json
{
  "insightId": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "title": "Revenue down in North region",
  "content": "Summary and actionable recommendations...",
  "confidenceScore": 0.87,
  "sources": [ { "id":"k_12", "title":"North region sales report" } ]
}
```

---

If anything needs to be changed (extra endpoints, different field names, or expanded schemas) tell me which edits to make and I will update this file. The backend team can implement directly from this contract and the Flutter team can map domain models to request/response DTOs.
