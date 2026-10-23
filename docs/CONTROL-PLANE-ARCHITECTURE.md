# DevOS Forge MCP / ChatGPT Control Plane — Architecture

## 1. Purpose

The DevOS Forge Control Plane is the agent-facing control surface for operating the DevOS Forge without depending operationally on the GitHub connector.

Its first concrete client is ChatGPT/OpenAI through MCP, but the architecture is intentionally client-agnostic.

The Control Plane must allow authorized clients to inspect and operate:

- repositories;
- files;
- branches;
- commits;
- issues;
- pull requests;
- Forgejo Actions;
- staging deployments;
- production promotions.

The Control Plane is not a replacement for Forgejo. Forgejo remains the forge substrate. The Control Plane adds a stable provider boundary, policy enforcement, audit/evidence, idempotency, deployment gates, and an MCP adapter.

## 2. Bootstrap transition

During bootstrap, GitHub is intentionally allowed to remain the temporary primary development surface because the existing ChatGPT GitHub connector provides reliable read/write access while the Forgejo-native Control Plane does not yet exist.

Transition model:

```text
Bootstrap

ChatGPT
   |
   v
GitHub connector
   |
   v
GitHub primary
   |
   v
Forgejo mirror
```

After the Control Plane is production-ready:

```text
Target

ChatGPT / DevOS / other clients
            |
            v
      MCP / Control API
            |
            v
     DevOS Forge Control Plane
            |
            v
        ForgeProvider
            |
            v
       Forgejo Provider
            |
            v
          Forgejo
            |
            +--> Git repositories
            +--> Issues / Pull Requests
            +--> Forgejo Actions
            +--> Staging / Production deploy flow

GitHub becomes mirror / optional secondary infrastructure.
```

The bootstrap use of GitHub is temporary and exists only to construct and validate the path that removes the operational dependency.

## 3. Public endpoints

Reserve `mcp.criandofacil.com.br` for a possible future CriandoFacil root MCP gateway.

The DevOS Forge Control Plane uses:

```text
Production: mcp-git.criandofacil.com.br
Staging:    mcp-git-staging.criandofacil.com.br
```

Both endpoints terminate TLS through the existing Nginx layer.

## 4. Logical architecture

```text
Human
  |
  v
ChatGPT / DevOS / OpenAI API / future clients
  |
  | MCP
  v
+------------------------------------------+
| MCP Adapter                              |
|                                          |
| - tool definitions                       |
| - request validation                     |
| - MCP transport                          |
+-------------------+----------------------+
                    |
                    v
+------------------------------------------+
| DevOS Forge Control Plane                |
|                                          |
| - authentication                         |
| - authorization / policy                 |
| - idempotency                            |
| - operation ledger                       |
| - audit / evidence                       |
| - capability discovery                   |
| - application services                   |
+-------------------+----------------------+
                    |
                    v
+------------------------------------------+
| ForgeProvider contract                   |
+-------------------+----------------------+
                    |
                    v
+------------------------------------------+
| ForgejoProvider                          |
|                                          |
| - Forgejo REST API                       |
| - Git/SSH primitives when appropriate    |
| - Actions API                            |
+-------------------+----------------------+
                    |
                    v
+------------------------------------------+
| Forgejo                                  |
| git.criandofacil.com.br                  |
+-------------------+----------------------+
                    |
          +---------+----------+
          |                    |
          v                    v
    repositories          Forgejo Actions
                               |
                               v
                         self-hosted runner
                               |
                     +---------+---------+
                     |                   |
                     v                   v
                  staging            production
```

## 5. Architectural boundaries

### 5.1 MCP is an adapter, not the domain

MCP exposes approved Control Plane capabilities. It must not contain Forgejo-specific business logic.

This ensures the same application layer can later be consumed by:

- DevOS CLI;
- an internal HTTP API;
- another model provider;
- automation jobs;
- a future CriandoFacil root MCP gateway.

### 5.2 ForgeProvider remains the central portability boundary

Application services depend on a small `ForgeProvider` contract.

Initial provider domains:

```text
ForgeProvider
|
+-- capabilities
+-- repositories
+-- files
+-- branches
+-- commits
+-- issues
+-- pullRequests
+-- workflows
+-- releases
+-- deployments
```

Forgejo-specific URLs, payloads, pagination, errors, and compatibility behavior stay inside `ForgejoProvider`.

### 5.3 No generic raw API escape hatch

The MCP V1 must not expose tools such as:

```text
forgejo_request(method, path, body)
shell(command)
ssh_exec(command)
```

The model receives semantic capabilities, not unrestricted infrastructure primitives.

## 6. MCP semantic tool surface

Initial capability families:

### Read

```text
forge_status
forge_capabilities
repo_list
repo_get
file_read
file_tree
branch_list
commit_list
commit_get
commit_diff
issue_list
issue_get
pr_list
pr_get
workflow_list
run_list
run_get
deploy_status
```

### Write

```text
repo_create
file_write
file_delete
branch_create
branch_delete
issue_create
issue_update
issue_comment
pr_create
pr_review
pr_merge
workflow_dispatch
deploy_staging
deploy_production
```

### Composite operations

The Control Plane may provide higher-level operations where one human intention naturally spans multiple forge calls.

Example:

```text
change_submit
  -> validate base ref
  -> create branch
  -> apply file changes
  -> commit
  -> push
  -> open pull request
  -> return evidence bundle
```

Composite operations must remain deterministic and auditable.

## 7. Authorization model

Operations are classified by risk.

| Class | Examples | Default behavior |
| --- | --- | --- |
| READ | inspect repo, file, issue, PR, run | allowed according to repository policy |
| WRITE | branch, file, commit, issue, PR | allowed according to repository policy |
| RELEASE | merge, release, staging deploy | requires verified preconditions |
| PRODUCTION | production promotion | requires strong deployment gates |
| BREAK_GLASS | force push, repo deletion, auth bypass | not exposed through MCP V1 |

Authorization is intentionally layered:

```text
Control Plane policy
        +
Forgejo permissions
```

A successful operation must satisfy both.

## 8. Repository allowlists

Control Plane policy contains an explicit repository allowlist.

Example shape:

```yaml
repositories:
  jaasielsantos/devos-forge:
    read: true
    write: true
    merge: true
    deploy_staging: false
    deploy_production: false
```

Forgejo token permissions remain a second independent boundary.

## 9. Authentication and secrets

Clients authenticate to the Control Plane. The Control Plane authenticates independently to Forgejo.

Forgejo and deployment credentials must never be returned to the MCP client.

Secrets must not appear in:

- Git;
- MCP tool arguments unless the secret is the intended authentication material for that transport;
- operation logs;
- audit payloads;
- evidence payloads;
- error traces returned to clients.

Staging and production use distinct credentials and policy scopes.

## 10. Optimistic concurrency

Mutating operations that depend on an existing Git state use explicit preconditions.

Example:

```text
repository: jaasielsantos/project
branch: main
expected_sha: abc123
```

If `main` is no longer `abc123`, the mutation fails with a deterministic conflict rather than silently overwriting newer work.

Expected error family:

```text
REF_CONFLICT
RESOURCE_CONFLICT
PRECONDITION_FAILED
```

Force pushes are not part of the normal MCP surface.

## 11. Idempotency and operation ledger

Every mutation receives or generates an `operation_id`.

The Control Plane stores enough state to distinguish:

```text
NEW
IN_PROGRESS
SUCCEEDED
FAILED_RETRYABLE
FAILED_FINAL
```

A retried request with the same operation identity must not silently create duplicate branches, commits, PRs, workflow dispatches, or deployments.

## 12. Evidence model

Every material mutation returns structured evidence.

Example forge evidence:

```json
{
  "operation_id": "op_...",
  "repository": "jaasielsantos/devos-forge",
  "action": "pr_merge",
  "input_ref": "abc123",
  "result_ref": "def456",
  "pull_request": 14,
  "status": "succeeded"
}
```

Deployment evidence extends this with:

```text
source commit
artifact identifier
digest
workflow run
staging result
production result
health verification
rollback result when applicable
```

Evidence is designed to later connect naturally to DevOS PDS/PBI/PBP execution lineage.

## 13. Capability discovery

`ForgejoProvider` performs capability discovery against the running Forgejo instance and presents a stable internal capability model.

The application layer must prefer capability checks over assumptions based only on a hard-coded Forgejo version.

Example:

```text
ForgeCapabilities
|
+-- repositories.read
+-- repositories.write
+-- pullRequests.merge
+-- actions.dispatch
+-- actions.runs
+-- actions.logs
+-- releases.create
```

Unsupported capabilities produce deterministic `CAPABILITY_UNAVAILABLE` errors.

## 14. Deployment model

The MCP does not receive unrestricted SSH or root shell access to production.

Deployment control is expressed through approved deployment operations.

```text
deploy_production
        |
        v
policy + preconditions
        |
        +-- required CI passed
        +-- staging passed
        +-- commit matches approved source
        +-- artifact digest matches staged artifact
        |
        v
Forgejo Actions / controlled deployment path
        |
        v
production
```

The normal production path must not be an arbitrary shell execution facility.

## 15. Artifact promotion

Production promotes the exact artifact already validated in staging.

Target model:

```text
commit
  -> build once
  -> immutable artifact + digest
  -> staging deploy
  -> staging E2E
  -> promote same artifact
  -> production health check
```

Rebuilding between staging and production is not the target design.

## 16. Control Plane staging and production

Logical deployment:

```text
mcp-git-staging.criandofacil.com.br
        -> Nginx/TLS
        -> Control Plane staging service
        -> staging database / policy / credentials

mcp-git.criandofacil.com.br
        -> Nginx/TLS
        -> Control Plane production service
        -> production database / policy / credentials
```

The two environments must not share writable runtime state or Forgejo credentials.

## 17. Runtime baseline

Initial implementation baseline:

- TypeScript;
- current supported Node.js LTS/current project baseline;
- official MCP SDK;
- schema validation with a typed schema library;
- PostgreSQL for durable Control Plane state where persistence is required;
- systemd-managed service;
- Nginx/TLS through the existing host ingress;
- structured logs through journald;
- Forgejo Actions for CI/CD;
- self-hosted Forgejo Runner with rootless Podman for repository-defined jobs.

Exact dependency versions are implementation details and should be pinned during bootstrap after verification against current supported releases.

## 18. Control Plane repository

The Control Plane should live in its own repository:

```text
devos-forge-control-plane
```

Reason:

- independent release lifecycle;
- isolated deployment credentials;
- independent CI/CD;
- simpler rollback;
- clearer trust boundary;
- allows Forgejo itself to host and deploy the service that controls the forge.

During bootstrap this repository is created on GitHub first so ChatGPT can operate it through the existing connector. Forgejo mirrors it until the Control Plane is production-ready. The direction is then reversed so Forgejo becomes source of truth and GitHub becomes secondary or optional.

## 19. Proposed repository structure

```text
devos-forge-control-plane/
|
+-- src/
|   +-- mcp/
|   |   +-- server.ts
|   |   `-- tools/
|   +-- application/
|   +-- domain/
|   +-- policy/
|   +-- audit/
|   +-- evidence/
|   +-- persistence/
|   `-- providers/
|       +-- forge-provider.ts
|       `-- forgejo/
|
+-- tests/
|   +-- unit/
|   +-- integration/
|   `-- e2e/
|
+-- docs/
+-- scripts/
+-- .forgejo/workflows/
+-- package.json
+-- tsconfig.json
+-- README.md
+-- 00_PROMPT_ZERO.md
+-- PROJECT-STATE.md
`-- DECISIONS.md
```

## 20. End-to-end production gate

Before declaring the Control Plane production-ready, the staging environment must prove at least:

```text
MCP client connects
  -> forge_status
  -> repo_get
  -> issue_create
  -> branch_create
  -> file/commit mutation
  -> pr_create
  -> workflow_dispatch
  -> CI passes
  -> pr review / merge
  -> deployment to staging
  -> health passes
  -> production promotion on an approved smoke target
  -> production health passes
```

This proof should use a dedicated smoke repository and deployment target, not an active application as the first destructive test.

## 21. Break-glass boundary

The following are intentionally excluded from MCP V1:

- repository deletion;
- default-branch force push;
- arbitrary host shell;
- arbitrary SSH execution;
- disabling authentication;
- disabling backup or recovery protections;
- unrestricted credential access;
- raw Forgejo API passthrough.

If operational evidence later justifies a break-glass mechanism, it should be a separately authenticated administrative path with explicit audit and recovery requirements.

## 22. Bootstrap completion condition

The bootstrap phase ends when all of the following are true:

1. `devos-forge-control-plane` is implemented and tested;
2. staging MCP is reachable at `mcp-git-staging.criandofacil.com.br`;
3. end-to-end Forgejo operations pass through the Control Plane;
4. production MCP is reachable at `mcp-git.criandofacil.com.br`;
5. ChatGPT/OpenAI can operate Forgejo through the Control Plane;
6. Forgejo becomes the primary repository source for the Control Plane;
7. GitHub is demoted to mirror/secondary or removed from the critical path.
