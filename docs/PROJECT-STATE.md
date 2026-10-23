# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo pilot proven; Control Plane staging live; Gate 10 active  
**Infrastructure:** Stages A-D complete  
**Migration:** Stage E proven through Forgejo-native branch; PR/Actions/review/merge proof remains intentionally paused until Control Plane production cutover  
**Control Plane:** Gates 0-9 complete; Gate 10 active in `devos-forge-control-plane` Issue #29  
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
- production must promote the exact artifact proven in staging.

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
[x] Gate 8  MCP -> Forgejo end-to-end proof
[x] Gate 9  deployment control semantics
[~] Gate 10 production Control Plane
[ ] Gate 11 Forgejo source-of-truth cutover / GitHub bootstrap retirement
```

Canonical implementation/evidence lives in `jaasielsantos/devos-forge-control-plane`.

## Gates 1-7 completion summary

```text
Gate 1: SELF_HOSTED_CI=PASS / CONTROL_PLANE_REPO_BOOTSTRAP=PASS
Gate 2: FORGE_PROVIDER_CONTRACT=PASS
Gate 3: FORGEJO_PROVIDER_READ=PASS
Gate 4: FORGEJO_PROVIDER_WRITE=PASS
Gate 5: POSTGRES_OPERATION_LEDGER=PASS / CONTROL_PLANE_CORE=PASS
Gate 6: MCP_ADAPTER=PASS
Gate 7: STAGING_HOST_BOOTSTRAP=PASS / MCP_STAGING_DEPLOY=PASS
```

Gate 4 mutation proof used dedicated Forgejo scratch targets only. Gate 5 durability used an isolated runner-owned PostgreSQL test cluster, not Forgejo's database. Gate 6 preserved capability-aware semantic tools, server-owned actor/risk semantics, default-denied BREAK_GLASS and no generic escape hatch. Gate 7 established the public staging endpoint with a non-root runtime and constrained root-owned deploy helper.

Canonical evidence through Gate 9:

```text
devos-forge-control-plane/docs/evidence/GATE-1-BOOTSTRAP.md
devos-forge-control-plane/docs/evidence/GATE-2-FORGE-PROVIDER.md
devos-forge-control-plane/docs/evidence/GATE-3-FORGEJO-READ.md
devos-forge-control-plane/docs/evidence/GATE-4-FORGEJO-WRITE.md
devos-forge-control-plane/docs/evidence/GATE-5-CONTROL-PLANE-CORE.md
devos-forge-control-plane/docs/evidence/GATE-6-MCP-ADAPTER.md
devos-forge-control-plane/docs/evidence/GATE-7-STAGING.md
devos-forge-control-plane/docs/evidence/GATE-8-MCP-FORGEJO-E2E.md
devos-forge-control-plane/docs/evidence/GATE-9-DEPLOYMENT-CONTROL.md
```

## Gate 8 — COMPLETE

Canonical tracking: `devos-forge-control-plane` Issue **#23**, closed completed.

Accepted release and E2E run:

```text
release_sha=c167a46518737165463655db82997ad52ddc569a
release_sha256=37d1400f039e202a5c52959731303a07cd4fffdfc0676274918aceaa99631820
workflow=gate8-control-plane-command
run=39978675219
job=120499913136
conclusion=success
```

Gate 8 proved the real public MCP -> Control Plane -> Forgejo path with bounded WRITE, idempotent replay, evidence and cleanup.

```text
GATE_8_E2E=PASS
GATE_8=COMPLETE
```

Detailed evidence: `devos-forge-control-plane/docs/evidence/GATE-8-MCP-FORGEJO-E2E.md`.

## Gate 9 — COMPLETE

Canonical tracking: `devos-forge-control-plane` Issue **#26**, closed completed.

Accepted implementation and release:

```text
implementation_pr=28
implementation_merge=ea7bf22900b1c12b5b13964d96ef19fb9a4b8380
release_sha=ea7bf22900b1c12b5b13964d96ef19fb9a4b8380
release_sha256=3f44573b695718d1574d067c869806b2568a7ce27012e2c24ab126955c4bc23b
unit_tests=63/63 PASS
```

Accepted public deployment-semantics proof:

```text
workflow=gate9-control-plane-command
run=39989576496
job=120537536119
target=gate9-smoke
artifact_digest=sha256:2deda67b9c59ae72c89cc830e5531614cd2f1d7776ab80bf642c8e17380c89a3
DEPLOYMENT_SEMANTICS_TYPED=PASS
BUILD_ONCE_ARTIFACT_IDENTITY=PASS
STAGING_DEPLOYMENT_OPERATION=PASS
DEPLOYMENT_IDEMPOTENCY=PASS
SAME_ARTIFACT_PROMOTION_MODEL=PASS
DEPLOYMENT_EVIDENCE_LINEAGE=PASS
production_mutation=DISABLED
GATE_9_E2E=PASS
GATE_9=COMPLETE
```

The staging actor now has `READ,WRITE,RELEASE` only. `PRODUCTION` and `BREAK_GLASS` remain ungranted. Promotion requires the exact source SHA + artifact digest already proven healthy in staging; a rebuild is a different artifact and is rejected.

Detailed evidence: `devos-forge-control-plane/docs/evidence/GATE-9-DEPLOYMENT-CONTROL.md`.

## Active Gate 10 — production MCP/control-plane deployment

Canonical tracking: `devos-forge-control-plane` Issue **#29**.

Objective:

```text
Gate 9 staging-proven artifact identity
  -> separate production service/state/credentials
  -> mcp-git.criandofacil.com.br TLS ingress
  -> explicit PRODUCTION actor/policy boundary
  -> promote exact staging artifact
  -> production health/readiness + append-only evidence
```

Required exit evidence:

```text
PRODUCTION_BOUNDARY_SEPARATE=PASS
PRODUCTION_TLS_HEALTH=PASS
PRODUCTION_ACTOR_POLICY=PASS
SAME_ARTIFACT_PROMOTED=PASS
PRODUCTION_DEPLOYMENT_OPERATION=PASS
PRODUCTION_EVIDENCE_LINEAGE=PASS
BREAK_GLASS=DENIED
GATE_10=COMPLETE
```

Gate 11 source-of-truth cutover remains deferred until production is proven.

## Security / credential lifecycle

- never commit runtime tokens, private keys or generated secrets;
- GitHub remains the temporary writable bootstrap primary until Gate 11;
- the private Forgejo pull-mirror credential remains repository-scoped while needed;
- `FORGEJO_READ_TOKEN` remains a bootstrap/integration read credential;
- the broad Gate 4 write credential is not a long-lived production credential;
- staging uses its own Forgejo credential stored only on the host;
- the staging MCP bearer credential is host-held and absent from Git/evidence;
- production credentials/services/state remain completely separate from staging;
- Forgejo Actions remain rootless-Podman/container-only; do not introduce generic host execution or expose the engine socket.

## Immediate next action

Implement Gate 10 production deployment from the proven Gate 9 model. Build/provision the separate production boundary first, then promote the exact staging-proven artifact without rebuilding it. `BREAK_GLASS` remains denied and Gate 11 remains paused until production is proven.
