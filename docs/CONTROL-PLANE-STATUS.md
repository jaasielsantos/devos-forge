# DevOS Forge Control Plane — Status

## Current state

```text
CONTROL_PLANE_ARCHITECTURE=ACCEPTED
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
FORGE_PROVIDER_CONTRACT=PASS
FORGEJO_PROVIDER_READ=PASS
FORGEJO_PROVIDER_WRITE=PASS
BOOTSTRAP_PRIMARY=GITHUB
FORGEJO_ROLE=PULL_MIRROR_UNTIL_CUTOVER
SELF_HOSTED_CI=PASS
ACTIVE_GATE=5_CONTROL_PLANE_CORE
PRODUCTION_ENDPOINT=mcp-git.criandofacil.com.br
STAGING_ENDPOINT=mcp-git-staging.criandofacil.com.br
ROOT_MCP_ENDPOINT=mcp.criandofacil.com.br (reserved)
```

## Completed

- Control Plane architecture accepted;
- standalone `jaasielsantos/devos-forge-control-plane` repository bootstrapped;
- dedicated self-hosted runner `devos-cp-vps-01` qualified on `srv1805473`;
- private GitHub -> Forgejo pull mirror configured;
- ForgeProvider contract completed before Forgejo/MCP implementation;
- Forgejo read adapter completed and authenticated against the real Forgejo instance;
- Forgejo write adapter completed and authenticated against dedicated scratch repositories;
- optimistic branch/blob preconditions verified;
- repository/file/branch/issue/release/PR mutations proven end to end;
- repeated Gate 4 scratch validation is replay-safe;
- no MCP-specific types are present in the provider layer.

## Gate 1 evidence

```text
SELF_HOSTED_CI=PASS
CONTROL_PLANE_MIRROR=PASS
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
```

Canonical evidence: `devos-forge-control-plane/docs/evidence/GATE-1-BOOTSTRAP.md`.

## Gate 2 evidence

```text
implementation_pr=5
implementation_commit=0906a554f99d75be22886aa250d54f29c533582d
FORGE_PROVIDER_CONTRACT=PASS
```

Canonical evidence: `devos-forge-control-plane/docs/evidence/GATE-2-FORGE-PROVIDER.md`.

## Gate 3 evidence

```text
implementation_pr=8
implementation_merge=54d842245e87b436ce7a88f0a5213eed350def9b
self_hosted_ci_run=39912468413
self_hosted_ci_job=120278361017
unit_tests=14/14 PASS
FORGEJO_PROVIDER_READ_AUTHENTICATED_SMOKE=PASS
FORGEJO_PROVIDER_READ=PASS
```

Canonical evidence: `devos-forge-control-plane/docs/evidence/GATE-3-FORGEJO-READ.md`.

## Gate 4 evidence

```text
implementation_pr=10
implementation_merge=867df13fa27bfbc31f78a02fdafe8d9391787183
closeout_pr=11
closeout_merge=79259c86037535a8d18ba5e6a57eccaf99840953
self_hosted_ci_run=39913913446
self_hosted_ci_job=120306893061
replay_ci_run=39921763694
replay_ci_job=120308419920
unit_tests=23/23 PASS
repository_create=PASS
file_write_delete=PASS
branch_create_delete=PASS
issue_create_update_comment=PASS
release_create=PASS
pull_request_create_review_merge=PASS
FORGEJO_PROVIDER_WRITE_AUTHENTICATED_SMOKE=PASS
replay_safe_scratch=PASS
FORGEJO_PROVIDER_WRITE=PASS
```

`workflow_dispatch` is currently unavailable on the repository/instance Actions API surface and is normalized as an optional `NOT_FOUND` capability, not a write-path failure.

Canonical evidence: `devos-forge-control-plane/docs/evidence/GATE-4-FORGEJO-WRITE.md`.

## Current gate

**Gate 5 — Control Plane core: policy / idempotency / evidence**

Required components:

```text
policy engine
READ / WRITE / RELEASE / PRODUCTION / BREAK_GLASS classes
operation ledger keyed by operation_id
NEW / IN_PROGRESS / SUCCEEDED / FAILED_RETRYABLE / FAILED_FINAL
request fingerprint / replay conflict detection
structured mutation evidence
audit-safe metadata
capability + policy authorization boundary
```

Required behavior:

- policy denial before provider mutation;
- identical successful replay returns prior result without duplicate mutation;
- in-progress replay never starts a second mutation;
- same operation ID with a materially different request fails deterministically;
- retryable/final failure states remain explicit;
- BREAK_GLASS is modeled but not exposed through MCP V1;
- evidence never contains secret values.

## Next exit evidence

```text
CONTROL_PLANE_CORE=PASS
```
