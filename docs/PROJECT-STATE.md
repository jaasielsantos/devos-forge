# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo pilot proven through native branch creation; Control Plane implementation active  
**Infrastructure:** Stages A-D complete  
**Migration:** Stage E proven through `FORGEJO_NATIVE_BRANCH=PASS`; Forgejo PR/Actions/review/merge proof intentionally paused until Control Plane production cutover  
**Control Plane:** Gates 0-4 complete; Gate 5 active  
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
[~] Gate 5  Control Plane core: policy / idempotency / evidence
[ ] Gate 6  MCP adapter
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

Canonical Control Plane evidence lives in:

```text
devos-forge-control-plane/docs/evidence/GATE-1-BOOTSTRAP.md
devos-forge-control-plane/docs/evidence/GATE-2-FORGE-PROVIDER.md
devos-forge-control-plane/docs/evidence/GATE-3-FORGEJO-READ.md
devos-forge-control-plane/docs/evidence/GATE-4-FORGEJO-WRITE.md
```

## Active Gate 5

Gate 5 builds the client-agnostic execution core above `ForgeProvider` and below MCP.

Required core semantics:

```text
policy engine
READ / WRITE / RELEASE / PRODUCTION / BREAK_GLASS
operation ledger keyed by operation_id
NEW / IN_PROGRESS / SUCCEEDED / FAILED_RETRYABLE / FAILED_FINAL
request fingerprinting
replay conflict detection
structured evidence
audit-safe metadata
capability + policy authorization
```

Replay rules:

- identical successful replay returns prior result/evidence without a second provider mutation;
- replay while IN_PROGRESS never starts a duplicate mutation;
- same `operation_id` with a materially different request fails deterministically;
- FAILED_RETRYABLE may be retried under explicit rules;
- FAILED_FINAL must not rerun implicitly;
- policy denial occurs before provider mutation;
- no evidence record may contain secrets.

Next exit evidence:

```text
CONTROL_PLANE_CORE=PASS
```

## Security / credential lifecycle

- never commit runtime tokens, private keys or generated secrets;
- `FORGEJO_READ_TOKEN` remains a bootstrap read credential only;
- the temporary broad `FORGEJO_WRITE_TOKEN` completed its Gate 4 proof and should be revoked/removed rather than retained long term;
- staging/production credentials will be environment-scoped and narrower where the Forgejo API permits;
- Forgejo Actions remain rootless-Podman/container-only; do not introduce a generic host runner label or expose the engine socket to jobs.

## Immediate next action

Implement Gate 5 in `jaasielsantos/devos-forge-control-plane` under Issue #12: policy engine, durable operation ledger, replay-safe idempotency, evidence model and tests before any MCP adapter work begins.
