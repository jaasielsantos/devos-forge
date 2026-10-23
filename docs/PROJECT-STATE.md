# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo pilot proven; Control Plane staging live; Gate 8 E2E active  
**Infrastructure:** Stages A-D complete  
**Migration:** Stage E proven through Forgejo-native branch; PR/Actions/review/merge proof remains intentionally paused until Control Plane production cutover  
**Control Plane:** Gates 0-7 complete; Gate 8 active in `devos-forge-control-plane` Issue #23  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`  
**Control Plane repository:** `devos-forge-control-plane`

## Current objective

Build and prove the **DevOS Forge MCP / ChatGPT Control Plane** so ChatGPT and DevOS can operate Forgejo directly without depending operationally on the GitHub connector.

Current bootstrap path:

```text
ChatGPT
  -> GitHub connector
  -> GitHub temporary primary
  -> Forgejo pull mirror
```

Target path:

```text
ChatGPT / DevOS / future clients
  -> MCP
  -> DevOS Forge Control Plane
       auth / policy / idempotency / ledger / evidence
  -> ForgeProvider
  -> ForgejoProvider
  -> Forgejo primary
  -> GitHub secondary / optional
```

Accepted endpoints:

```text
staging:    https://mcp-git-staging.criandofacil.com.br
production: https://mcp-git.criandofacil.com.br
reserved:   https://mcp.criandofacil.com.br
```

## Locked V1 Forgejo topology

```text
Internet
  -> Nginx :443 + TLS
  -> Forgejo 15.0.10 native binary + systemd
     127.0.0.1:3000
     -> PostgreSQL 16
     -> Forgejo Actions
        -> Forgejo Runner v13.1.0
        -> rootless Podman
```

Git-over-SSH uses OpenSSH port 22 with the dedicated `git` account.

## Infrastructure stages

```text
[x] Stage A  Forgejo + PostgreSQL
[x] Stage B  Nginx + DNS + TLS
[x] Stage C  Git SSH auth + clone/commit/push
[x] Stage D  Forgejo Runner + rootless Podman + Actions smoke
[~] Stage E  Forgejo-native branch proven; PR/Actions/review/merge intentionally paused
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

Stage E proof already recorded:

```text
forgejo_branch=eaddbb259fc710cafbecefa658912e8f9047752f
github_branch=ABSENT
FORGEJO_NATIVE_BRANCH=PASS
```

Remaining Stage E lifecycle proof resumes after the Control Plane production/cutover path is ready.

## Control Plane principles

- MCP is an adapter, not the domain layer;
- `ForgeProvider` is the portability boundary;
- semantic tools only;
- no raw Forgejo API passthrough;
- no unrestricted shell or SSH;
- risk classes are READ / WRITE / RELEASE / PRODUCTION / BREAK_GLASS;
- BREAK_GLASS is default-denied and not exposed through MCP V1;
- writes use explicit preconditions and optimistic concurrency;
- material operations use `operation_id`, durable PostgreSQL state and append-only evidence;
- staging and production keep separate service/state/credential boundaries;
- production should promote the same artifact proven in staging.

## Control Plane implementation map

```text
[x] Gate 0  architecture freeze
[x] Gate 1  bootstrap repository + mirror + self-hosted CI
[x] Gate 2  ForgeProvider contract
[x] Gate 3  ForgejoProvider read
[x] Gate 4  ForgejoProvider write
[x] Gate 5  Control Plane core: policy / idempotency / evidence
[x] Gate 6  MCP adapter
[x] Gate 7  staging deployment
[~] Gate 8  MCP -> Forgejo end-to-end proof
[ ] Gate 9  deployment control semantics
[ ] Gate 10 production Control Plane
[ ] Gate 11 Forgejo source-of-truth cutover / GitHub bootstrap retirement
```

Canonical implementation/evidence lives in `jaasielsantos/devos-forge-control-plane`.

## Gates 1-6 completion summary

```text
Gate 1: SELF_HOSTED_CI=PASS / CONTROL_PLANE_REPO_BOOTSTRAP=PASS
Gate 2: FORGE_PROVIDER_CONTRACT=PASS
Gate 3: FORGEJO_PROVIDER_READ=PASS
Gate 4: FORGEJO_PROVIDER_WRITE=PASS
Gate 5: POSTGRES_OPERATION_LEDGER=PASS / CONTROL_PLANE_CORE=PASS
Gate 6: MCP_ADAPTER=PASS
```

Gate 4 mutation proof used dedicated Forgejo scratch repositories only. Gate 5 durability used an isolated runner-owned PostgreSQL test cluster, not Forgejo's database. Gate 6 preserved capability-aware semantic tools, server-owned actor/risk semantics, default-denied BREAK_GLASS, and no generic escape hatch.

Canonical evidence:

```text
devos-forge-control-plane/docs/evidence/GATE-1-BOOTSTRAP.md
devos-forge-control-plane/docs/evidence/GATE-2-FORGE-PROVIDER.md
devos-forge-control-plane/docs/evidence/GATE-3-FORGEJO-READ.md
devos-forge-control-plane/docs/evidence/GATE-4-FORGEJO-WRITE.md
devos-forge-control-plane/docs/evidence/GATE-5-CONTROL-PLANE-CORE.md
devos-forge-control-plane/docs/evidence/GATE-6-MCP-ADAPTER.md
```

## Gate 7 — COMPLETE

Public staging is live at:

```text
https://mcp-git-staging.criandofacil.com.br
```

Runtime topology:

```text
Internet
  -> Nginx :443 / TLS
  -> 127.0.0.1:3187
  -> devos-cp-staging (non-root systemd service)
  -> devos_cp_staging PostgreSQL database
  -> staging-scoped Forgejo credential
```

Gate 7 package and closeout:

```text
issue_17=CLOSED_COMPLETED
implementation_pr_21=MERGED
chatops_pr_22=MERGED
closeout_pr_24=MERGED
control_plane_gate7_closeout_merge=6d4eead87f157d06d42f7664445fa4c11f5e491e
```

Accepted staging release:

```text
staging_release_sha=cd462cb2bc1f275eee7d8d6fce3b8f6f061dc82e
staging_release_sha256=0e0a9cf461df212f1022522e79439db63e7f86e8cbcb516b9f45196b76a74a10
staging_deploy_run=39974466817
staging_deploy_job=120485353669
```

Host and deployment acceptance:

```text
STAGING_HOST_BOOTSTRAP=PASS
staging_dns=RESOLVES
staging_dns_ipv4=187.77.39.14
STAGING_COMMAND_SHA_PIN=PASS
STAGING_ARTIFACT_BUILD=PASS
staging_migration=PASS
staging_local_health=PASS
staging_local_readiness=PASS
staging_local_authenticated_mcp=PASS
staging_public_tls_health=PASS
MCP_STAGING_DEPLOY=PASS
GATE_7=COMPLETE
```

Public health returned:

```json
{"ok":true,"status":"alive"}
```

Normal staging deploy no longer requires an interactive root session. The self-hosted runner remains without generic sudo and crosses the privilege boundary only through the constrained root-owned helper:

```text
/usr/local/sbin/devos-cp-staging-deploy
```

A trusted ChatOps command slot on Control Plane Issue #17 now lets the approved GitHub integration trigger a SHA-pinned staging deployment without manual Actions clicks. The slot is neutral (`IDLE`) when not in use.

Detailed evidence: `devos-forge-control-plane/docs/evidence/GATE-7-STAGING.md`.

## Active Gate 8 — MCP -> Forgejo E2E

Canonical tracking: `devos-forge-control-plane` Issue **#23**.

Objective:

```text
ChatGPT / MCP client
  -> public staging MCP endpoint
  -> semantic MCP tool
  -> Control Plane policy / idempotency / evidence
  -> ForgejoProvider
  -> Forgejo
```

Gate 8 must prove, against an explicit non-production/reversible mutation target:

```text
MCP_PUBLIC_AUTHENTICATED_DISCOVERY=PASS
MCP_FORGEJO_READ_E2E=PASS
MCP_FORGEJO_WRITE_E2E=PASS
MCP_OPERATION_REPLAY=PASS
MCP_EVIDENCE_LINEAGE=PASS
GATE_8=COMPLETE
```

Production deployment semantics remain deferred to Gates 9-10.

## Security / credential lifecycle

- never commit runtime tokens, private keys or generated secrets;
- GitHub remains the temporary writable bootstrap primary until Gate 11;
- the private Forgejo pull-mirror credential remains repository-scoped while needed;
- `FORGEJO_READ_TOKEN` remains a bootstrap/integration read credential;
- the broad Gate 4 write credential is not a long-lived production credential;
- staging uses its own Forgejo credential stored only on the host;
- the staging MCP bearer credential is host-held and absent from Git/evidence;
- staging and production credentials/services/state stay separate;
- Forgejo Actions remain rootless-Podman/container-only; do not introduce generic host execution or expose the engine socket.

## Immediate next action

Execute Gate 8 through the real public staging MCP endpoint, proving authenticated discovery, semantic Forgejo read, one bounded reversible write, idempotent replay, and evidence lineage. No further manual VPS/Termux bootstrap action is required for normal staging operations.
