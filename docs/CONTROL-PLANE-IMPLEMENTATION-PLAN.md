# DevOS Forge Control Plane — Implementation Plan

## Goal

Move from the accepted Control Plane architecture to a production service that allows ChatGPT/OpenAI and DevOS clients to operate Forgejo directly, then remove GitHub from the normal operational path.

The implementation is gated. A later gate does not start until the previous gate has objective evidence.

## Gate 0 — Architecture freeze

### Deliverables

- accepted Control Plane architecture;
- accepted ADR;
- bootstrap source-of-truth strategy;
- public endpoint names;
- initial security boundaries;
- implementation gate plan.

### Exit evidence

```text
CONTROL_PLANE_ARCHITECTURE=ACCEPTED
```

## Gate 1 — Bootstrap repository

### Repository

```text
jaasielsantos/devos-forge-control-plane
```

### Temporary source-of-truth model

```text
GitHub primary
    -> Forgejo mirror
```

### Initial files

```text
00_PROMPT_ZERO.md
README.md
PROJECT-STATE.md
DECISIONS.md
package.json
tsconfig.json
src/
tests/
docs/
```

### Initial project invariants

- TypeScript strict mode;
- no committed secrets;
- dependency lockfile committed;
- formatter/linter/typecheck/test commands deterministic;
- production code separated from tests;
- no direct Forgejo calls outside `providers/forgejo`;
- no raw shell or raw Forgejo MCP tools.

### Exit evidence

```text
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
```

## Gate 2 — ForgeProvider contract

Implement the provider contract and stable internal types before implementing MCP tools.

### Initial provider areas

```text
capabilities
repositories
files
branches
commits
issues
pullRequests
workflows
releases
deployments
```

### Required provider properties

- normalized pagination;
- normalized errors;
- typed preconditions;
- deterministic conflict handling;
- capability model;
- no MCP-specific types.

### Tests

- contract type tests;
- provider error mapping tests;
- optimistic-concurrency tests;
- capability-unavailable tests.

### Exit evidence

```text
FORGE_PROVIDER_CONTRACT=PASS
```

## Gate 3 — ForgejoProvider read path

Implement authenticated Forgejo access for read-only operations first.

### Required operations

- server/version discovery;
- current identity / authentication verification;
- repository list/get;
- file read/tree;
- branch list;
- commit get/list/diff;
- issue list/get;
- PR list/get;
- workflow/run inspection where supported.

### Security

Use a staging-scoped Forgejo credential.

### Tests

- mocked unit tests;
- integration tests against a disposable Forgejo smoke repository;
- deterministic authentication and permission failures.

### Exit evidence

```text
FORGEJO_PROVIDER_READ=PASS
```

## Gate 4 — ForgejoProvider write path

Add writes in increasing risk order.

### Order

1. issue create/update/comment;
2. branch create;
3. file write / commit mutation;
4. PR create;
5. review;
6. merge with expected head SHA;
7. workflow dispatch.

### Mandatory protections

- operation ID;
- idempotency;
- expected SHA where applicable;
- repository allowlist;
- structured evidence;
- secret redaction.

### Exit evidence

```text
FORGEJO_PROVIDER_WRITE=PASS
```

## Gate 5 — Control Plane core

Implement the layers above the provider.

### Components

```text
application services
policy engine
operation ledger
idempotency service
audit/evidence service
credential boundary
capability service
```

### Initial policy classes

```text
READ
WRITE
RELEASE
PRODUCTION
BREAK_GLASS
```

`BREAK_GLASS` is deny-only in MCP V1.

### Persistence

Use PostgreSQL for durable operation/audit state if required by the final storage model.

### Exit evidence

```text
CONTROL_PLANE_CORE=PASS
```

## Gate 6 — MCP adapter

Only after provider + core are stable, expose the semantic MCP surface.

### Initial MCP tools

```text
forge_status
forge_capabilities
repo_list
repo_get
file_read
file_tree
branch_list
branch_create
commit_list
commit_get
commit_diff
issue_list
issue_get
issue_create
issue_update
issue_comment
pr_list
pr_get
pr_create
pr_review
pr_merge
workflow_list
workflow_dispatch
run_list
run_get
deploy_status
```

Deployment mutation tools may remain disabled until Gate 8.

### MCP requirements

- schema-validated inputs;
- bounded outputs;
- deterministic error envelope;
- no credentials in responses;
- request correlation / operation IDs;
- semantic tools only.

### Exit evidence

```text
MCP_ADAPTER=PASS
```

## Gate 7 — Staging deployment

### Endpoint

```text
mcp-git-staging.criandofacil.com.br
```

### Staging properties

- Nginx TLS endpoint;
- dedicated systemd service;
- dedicated environment configuration;
- staging-only Forgejo credentials;
- staging policy allowlist;
- health/readiness endpoints;
- logs through journald;
- restart/rollback procedure.

### Initial smoke target

Use a dedicated repository such as:

```text
control-plane-smoke
```

### Exit evidence

```text
MCP_STAGING_DEPLOY=PASS
```

## Gate 8 — MCP -> Forgejo end-to-end proof

The staging server must prove a real lifecycle from an MCP client.

### Required lifecycle

```text
connect
-> forge_status
-> repo_get
-> issue_create
-> branch_create
-> file mutation / commit
-> pr_create
-> workflow dispatch
-> CI pass
-> review
-> merge
```

### Negative tests

Also prove:

- repository outside allowlist is denied;
- stale expected SHA is rejected;
- duplicate operation ID does not duplicate mutation;
- unsupported capability returns deterministic error;
- token/secret values are not present in logs or evidence.

### Exit evidence

```text
MCP_FORGEJO_E2E=PASS
```

## Gate 9 — Deployment control

Implement staging and production deployment semantics.

### Target flow

```text
source commit
-> build once
-> immutable artifact + digest
-> staging deploy
-> staging E2E
-> production promotion of same artifact
-> production health verification
```

### Tools enabled after this gate

```text
deploy_staging
deploy_production
```

### Required production preconditions

- approved source ref;
- required CI success;
- staging success;
- same artifact digest;
- production repository/environment allowlist;
- auditable operation identity.

### Exit evidence

```text
CONTROL_PLANE_DEPLOYMENTS=PASS
```

## Gate 10 — Production Control Plane

### Endpoint

```text
mcp-git.criandofacil.com.br
```

### Production requirements

- dedicated systemd service;
- production policy;
- production credentials distinct from staging;
- durable operation ledger;
- backup of required Control Plane state;
- rollback procedure rehearsed;
- health monitoring;
- no dependency on staging runtime state.

### Exit evidence

```text
MCP_PRODUCTION=PASS
```

## Gate 11 — Source-of-truth cutover

After production Control Plane operations are stable:

```text
GitHub primary + Forgejo mirror
        ->
Forgejo primary + GitHub mirror
        ->
Forgejo primary + GitHub optional
```

### Required proof before cutover

- Control Plane can read/write the Forgejo Control Plane repository;
- branch/PR/CI/merge lifecycle works on Forgejo;
- deployment path works without GitHub;
- restore path exists for Control Plane state;
- ChatGPT/OpenAI can operate Forgejo through MCP without using the GitHub connector.

### Exit evidence

```text
GITHUB_OPERATIONAL_DEPENDENCY=REMOVED
```

## Implementation sequence summary

```text
[x] architecture decision
[ ] bootstrap repository
[ ] ForgeProvider
[ ] Forgejo read adapter
[ ] Forgejo write adapter
[ ] policy/idempotency/evidence core
[ ] MCP adapter
[ ] staging deploy
[ ] MCP -> Forgejo E2E
[ ] deployment semantics
[ ] production deploy
[ ] Forgejo source-of-truth cutover
```
