---
name: security-review
description: Dedicated security review for risky changes. Invoke before merging or approving changes that touch auth, permissions, secrets, shell commands, file or network boundaries, MCP/hooks/agent config, payments, or PII. Also invoke when the user asks for a security audit, threat review, or OWASP-style review.
---

# Security Review

Normal code review is too broad for security-sensitive changes. This skill narrows the question to one thing: can an attacker turn this change into access, code execution, data exposure, or unsafe agent behavior?

If the diff touches a risky surface, run a dedicated security pass. Do not bury security under a generic "looks fine".

---

## When this review is mandatory

Run this skill when the change touches any of:

- authentication, sessions, tokens, password reset, OAuth, SSO
- authorization, roles, tenant boundaries, admin actions
- secrets, API keys, environment variables, signing keys
- user-controlled input reaching SQL, shell, file paths, HTML, templates, or URLs
- file upload/download, archive extraction, path handling
- outbound fetches, webhooks, SSRF-prone code, internal service calls
- payments, PII, logging, exports, audit trails
- dependency or security-config changes
- Claude hooks, MCP configs, agent/tool permissions, commands copied from external content

If you see one of these, security review is not optional.

---

## Step 1 - Define the asset, boundary, and attacker

Before reading line by line, answer:

1. What valuable thing is at risk?
2. Where is the trust boundary?
3. What input is attacker-controlled?
4. What capability would success give the attacker?

Examples:

- auth flow: account takeover
- role check: privilege escalation
- shell invocation: remote code execution
- exported logs: PII leak
- MCP / hook config: agent escapes intended permission boundaries

If you cannot name the boundary, you are not ready to review the diff.

---

## Step 2 - Walk the high-risk categories

Use the changed surface to pick categories. Do not mechanically run every category when half are irrelevant.

### Authentication and session handling

Check:

- credentials or tokens are validated at the real boundary
- password reset, email change, MFA, or token refresh cannot be replayed or guessed
- sessions expire, rotate, and do not survive privilege changes unexpectedly
- auth errors do not leak whether an account exists

### Authorization and access control

Check:

- authorization happens server-side, not just in UI
- object-level access is enforced for the specific resource, not just the route
- tenant/org/user scoping cannot be bypassed by changing IDs
- admin or internal paths are not reachable through alternate code paths

### Secrets and sensitive data

Check:

- no secrets in code, fixtures, logs, commits, screenshots, or error messages
- secrets stay in env or secret managers
- tokens are redacted in logs and telemetry
- PII is minimized, masked, or omitted where possible

### Injection and unsafe execution

Check:

- untrusted input does not reach SQL, shell, eval-like APIs, templates, or HTML unsafely
- command construction uses safe argument passing, not string concatenation
- path handling prevents traversal and archive-slip style writes
- fetch targets and webhook URLs cannot be abused for SSRF or internal access

### Files, network, and deserialization boundaries

Check:

- uploads validate type, size, and storage path
- downloads do not expose arbitrary files
- deserialization is constrained to trusted formats and known schemas
- internal network calls are allowlisted or otherwise bounded

### Agent and automation boundaries

For Claude / agent repos, also check:

- hooks do not execute tainted shell built from untrusted text
- MCP servers are scoped to the minimum required permissions
- rules or skills do not tell the agent to trust fetched content blindly
- copied commands from docs/issues/web pages are treated as untrusted until inspected

---

## Step 3 - Trace data flow, not just lines

For each risky input:

1. Where does it enter?
2. What validation or normalization happens?
3. What sink does it reach?
4. What authorization check stands in between?
5. What would the attacker gain if that check fails?

Typical dangerous sinks:

- database queries
- shell commands
- filesystem writes
- template rendering / browser output
- internal HTTP requests
- secrets or audit logs

Security bugs often hide in the gap between a trusted-looking caller and an unchecked sink.

---

## Step 4 - Look for evidence, not intent

Do not accept comments like "admin only", "internal use", "validated upstream", or "trusted source" without code that proves it.

Ask:

- where is the enforcement?
- what test proves the boundary?
- what prevents a caller from skipping the happy path?
- what happens on malformed, replayed, cross-tenant, or overlong input?

If the security property exists only in prose, treat it as missing.

---

## Step 5 - Report findings by exploitability

Use concrete findings with severity:

- `Critical` - likely account takeover, RCE, auth bypass, broad secret exposure
- `High` - privilege escalation, tenant escape, SSRF to internal services, unsafe hook/MCP execution
- `Medium` - missing hardening or partial exposure with mitigating conditions
- `Low` - defense-in-depth gaps, logging hygiene, missing tests for claimed controls

Each finding should include:

- location
- attacker-controlled input
- impacted asset or boundary
- exploit path
- fix direction

Good finding shape:

`High - app/api/admin.ts:42: Route checks that the user is authenticated but never verifies admin role, so any signed-in user can reach tenant-wide export. Add a server-side role check before the export path and a regression test for non-admin callers.`

---

## What this bundle is not

- Not a replacement for `code-review-gates` - that bundle is general review hygiene
- Not a replacement for `quality-gates` - passing tests do not prove security properties
- Not a full pentest - this is a focused secure-code and agent-config review pass

When in doubt, escalate to dedicated AppSec review rather than waving through a risky diff.
