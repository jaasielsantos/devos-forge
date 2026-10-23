# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo pilot proven through native branch creation; Control Plane implementation active  
**Infrastructure:** Stages A-D complete  
**Migration:** Stage E proven through `FORGEJO_NATIVE_BRANCH=PASS`; Forgejo PR/Actions/review/merge proof intentionally paused until Control Plane production cutover  
**Control Plane:** Gates 0-5 complete; Gate 6 active  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`  
**Control Plane repository:** `devos-forge-control-plane`

## Current objective

Build the **DevOS Forge MCP / ChatGPT Control Plane** so ChatGPT and DevOS can operate Forgejo directly without depending operationally on the GitHub connector.

Temporary bootstrap direction:

```text
ChatGPT
  -> GitHub connector
  -> GitHub temporary primary
  -> Forgejo pull mirror
```

Target direction after staging/E2E/production validation:

```text
ChatGPT / DevOS
  -> MCP / Control Plane
  -> ForgeProvider
  -> ForgejoProvider
  -> Forgejo primary
  -> GitHub mirror/secondary/optional
```

Accepted endpoints:

```text
Production: mcp-git.criandofacil.com.br
Staging:    mcp-git-staging.criandofacil.com.br
Reserved:   mcp.criandofacil.com.br
```

## Locked V1 Forgejo topology

```text
Internet
   |
   v
Nginx :443 + TLS
   |
   v
Forgejo 15.0.10
native binary + systemd
127.0.0.1:3000
   |
   +--> PostgreSQL 16
   |
   `--> Forgejo Actions
          |
          v
      Forgejo Runner v13.1.0
          |
          v
      rootless Podman
```

Git-over-SSH uses OpenSSH port 22 with the dedicated `git` account.

## Infrastructure stages

```text
[x] Stage A  Forgejo bootstrap + PostgreSQL
[x] Stage B  Nginx + DNS + TLS
[x] Stage C  Git SSH auth + clone/commit/push
[x] Stage D  Forgejo Runner + rootless Podman + Actions smoke
[~] Stage E  migration proven through Forgejo-native branch; PR/Actions/merge intentionally paused
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

Recorded Stage E evidence:

```text
forgejo_branch=eaddbb259fc710cafbecefa658912e8f9047752f
github_branch=ABSENT
FORGEJO_NATIVE_BRANCH=PASS
```

Remaining Stage E lifecycle proof:

- [ ] open Forgejo Pull Request on the pilot
- [ ] run Forgejo Actions on the pilot PR
- [ ] review and merge in Forgejo
- [ ] establish final source-of-truth direction after Control Plane production cutover
- [ ] document final migration/cutover procedure

## Control Plane architecture

```text
ChatGPT / DevOS / future clients
            |
            v
           MCP
            |
            v
DevOS Forge Control Plane
            |
            v
       ForgeProvider
            |
            v
     ForgejoProvider
            |
            v
         Forgejo
```

Locked principles:

- MCP is an adapter, not the domain layer;
- `ForgeProvider` is the portability boundary;
- no raw Forgejo API passthrough MCP tool;
- no unrestricted shell/SSH MCP tool;
- risk classes are READ / WRITE / RELEASE / PRODUCTION / BREAK_GLASS;
- BREAK_GLASS is not exposed through MCP V1;
- writes use optimistic concurrency and normalized errors;
- material operations use `operation_id` and structured evidence;
- staging and production use separate state/credentials;
- production should promote the same artifact validated in staging.

## Control Plane implementation gates

```text
[x] Gate 0  architecture freeze
[x] Gate 1  bootstrap repository + mirror + self-hosted CI
[x] Gate 2  ForgeProvider contract
[x] Gate 3  ForgejoProvider read path
[x] Gate 4  ForgejoProvider write path
[x] Gate 5  Control Plane core: policy / idempotency / evidence
[~] Gate 6  MCP adapter
[ ] Gate 7  staging deployment
[ ] Gate 8  MCP -> Forgejo end-to-end proof
[ ] Gate 9  deployment control semantics
[ ] Gate 10 production Control Plane
[ ] Gate 11 Forgejo source-of-truth cutover / GitHub dependency removal
```

## Gate 4 completion

Authenticated Forgejo mutation proof completed on dedicated scratch repositories only:

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

`workflow_dispatch` currently returns deterministic `NOT_FOUND` on the repository/instance Actions API surface and remains an unavailable optional capability rather than a generic write-path failure.

## Gate 5 completion

The client-agnostic execution core is implemented and proven with durable PostgreSQL replay semantics:

```text
implementation_pr=13
implementation_merge=e14c9e8089e553b3767d2df2d224f4fc433946b4
self_hosted_runner=devos-cp-vps-01
self_hosted_ci_run=39930231511
self_hosted_ci_job=120336474018
unit_tests=41/41 PASS
policy_default_deny=PASS
caller_risk_downgrade=DENIED
break_glass_default=DENIED
capability_pre_mutation_check=PASS
idempotent_success_replay=PASS
operation_id_conflict=PASS
retryable_reclaim=PASS
final_failure_no_reexecute=PASS
evidence_append_only=PASS
postgres_migration=PASS
postgres_first_execution=PASS
postgres_cluster_restart=PASS
postgres_restart_replay=PASS
postgres_operation_conflict=PASS
postgres_retry_history=PASS
postgres_concurrent_claim=PASS
postgres_null_result_replay=PASS
POSTGRES_OPERATION_LEDGER=PASS
CONTROL_PLANE_CORE=PASS
```

The PostgreSQL durability smoke uses an isolated PostgreSQL 16 cluster owned by the self-hosted runner on a high test port. It does not use or mutate the Forgejo PostgreSQL database on port 5432.

Canonical Control Plane evidence lives in:

```text
devos-forge-control-plane/docs/evidence/GATE-1-BOOTSTRAP.md
devos-forge-control-plane/docs/evidence/GATE-2-FORGE-PROVIDER.md
devos-forge-control-plane/docs/evidence/GATE-3-FORGEJO-READ.md
devos-forge-control-plane/docs/evidence/GATE-4-FORGEJO-WRITE.md
devos-forge-control-plane/docs/evidence/GATE-5-CONTROL-PLANE-CORE.md
```

## Active Gate 6

Gate 6 introduces the MCP adapter above the now-proven Control Plane core.

Required adapter semantics:

```text
MCP server transport
semantic MCP tool registry
schema validation at adapter boundary
authenticated actor/context mapping
Control Plane executor invocation
stable error/result mapping
capability-aware tool exposure
```

Boundaries remain locked:

- MCP stays an adapter and does not own policy/idempotency/evidence logic;
- no raw Forgejo API passthrough;
- no arbitrary shell/SSH tool;
- material writes must route through the Gate 5 executor and carry `operation_id`;
- unavailable capabilities remain deterministic and machine-readable;
- adapter validation happens locally before staging deployment.

Next exit evidence:

```text
MCP_ADAPTER=PASS
```

## Security / credential lifecycle

- never commit runtime tokens, private keys or generated secrets;
- `FORGEJO_READ_TOKEN` remains a bootstrap read credential only;
- the temporary broad `FORGEJO_WRITE_TOKEN` completed its Gate 4 proof and should be revoked/removed rather than retained long term;
- staging/production credentials will be environment-scoped and narrower where the Forgejo API permits;
- Forgejo Actions remain rootless-Podman/container-only; do not introduce a generic host runner label or expose the engine socket to jobs.

## Immediate next action

Implement Gate 6 in `jaasielsantos/devos-forge-control-plane`: semantic MCP tools and adapter transport over the proven Gate 5 execution core, before staging deployment work begins.
