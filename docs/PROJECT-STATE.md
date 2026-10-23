# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo pilot proven; production Control Plane live; Gate 11 active  
**Infrastructure:** Stages A-D complete  
**Migration:** Stage E branch proof complete; remaining PR/Actions/review/merge lifecycle resumes in Gate 11  
**Control Plane:** Gates 0-10 complete; Gate 11 active in `devos-forge-control-plane` Issue #32  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`  
**Control Plane repository:** `devos-forge-control-plane`

## Current objective

Complete the **Forgejo source-of-truth cutover** now that the DevOS Forge MCP / ChatGPT Control Plane is proven in production.

Current pre-cutover path:

```text
ChatGPT
  -> GitHub connector
  -> GitHub temporary writable bootstrap primary
  -> Forgejo pull mirror
```

Proven production path:

```text
ChatGPT / DevOS / future clients
  -> production MCP
  -> DevOS Forge Control Plane
       auth / policy / idempotency / ledger / evidence
  -> ForgeProvider
  -> ForgejoProvider
  -> Forgejo
```

Gate 11 target authority model:

```text
Forgejo = authoritative writable primary
production MCP / Control Plane = primary operational path
GitHub = explicit secondary role only (to be frozen during cutover)
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
[~] Stage E  Forgejo-native branch proven; PR/Actions/review/merge lifecycle remains
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

Existing Stage E proof:

```text
forgejo_branch=eaddbb259fc710cafbecefa658912e8f9047752f
github_branch=ABSENT
FORGEJO_NATIVE_BRANCH=PASS
```

The remaining Stage E lifecycle proof is now part of Gate 11 rather than blocked on Control Plane production.

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
- production promotes the exact artifact proven in staging;
- Gate 11 must not create dual-primary write authority.

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
[x] Gate 10 production Control Plane
[~] Gate 11 Forgejo source-of-truth cutover / GitHub bootstrap retirement
```

Canonical implementation/evidence lives in `jaasielsantos/devos-forge-control-plane`.

## Gates 1-9 summary

```text
Gate 1: SELF_HOSTED_CI=PASS / CONTROL_PLANE_REPO_BOOTSTRAP=PASS
Gate 2: FORGE_PROVIDER_CONTRACT=PASS
Gate 3: FORGEJO_PROVIDER_READ=PASS
Gate 4: FORGEJO_PROVIDER_WRITE=PASS
Gate 5: POSTGRES_OPERATION_LEDGER=PASS / CONTROL_PLANE_CORE=PASS
Gate 6: MCP_ADAPTER=PASS
Gate 7: STAGING_HOST_BOOTSTRAP=PASS / MCP_STAGING_DEPLOY=PASS
Gate 8: GATE_8_E2E=PASS
Gate 9: GATE_9_E2E=PASS / GATE_9=COMPLETE
```

Canonical evidence through Gate 10:

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
devos-forge-control-plane/docs/evidence/GATE-10-PRODUCTION.md
```

## Gate 8 — COMPLETE

```text
release_sha=c167a46518737165463655db82997ad52ddc569a
run=39978675219
job=120499913136
GATE_8_E2E=PASS
GATE_8=COMPLETE
```

## Gate 9 — COMPLETE

```text
implementation_merge=ea7bf22900b1c12b5b13964d96ef19fb9a4b8380
artifact_digest=sha256:2deda67b9c59ae72c89cc830e5531614cd2f1d7776ab80bf642c8e17380c89a3
DEPLOYMENT_SEMANTICS_TYPED=PASS
BUILD_ONCE_ARTIFACT_IDENTITY=PASS
STAGING_DEPLOYMENT_OPERATION=PASS
DEPLOYMENT_IDEMPOTENCY=PASS
SAME_ARTIFACT_PROMOTION_MODEL=PASS
DEPLOYMENT_EVIDENCE_LINEAGE=PASS
GATE_9=COMPLETE
```

## Gate 10 — COMPLETE

Canonical tracking: `devos-forge-control-plane` Issue **#29**, closed completed. Implementation PR **#31**; closeout PR **#33**.

Production release:

```text
release_sha=d091daff4047194a52e62561ede3d0e2b153ebb7
staging_release_tar_sha256=8971b5410d1a2066e29e5668f56eb0f2ac9b502b83912b19f36d2880da953de6
staged_semantic_artifact_digest=sha256:e947d425c4bba93e203280ab6703b01a3b92f02701507690e636c35034ae61ab
release_tree_sha256=290b5a4c62da8493cbe5843218f89df1a232767d6faa8fa060b7960b26360853
```

The exact implementation release was first refreshed and re-proven in staging:

```text
staging_run=40025339905
staging_job=120660007003
MCP_STAGING_DEPLOY=PASS
STAGING_CANDIDATE_REPROVED=PASS
```

Then that same release tree was promoted to the isolated production boundary:

```text
production_run=40025552767
production_job=120660713791
staging_release_content_sha256=290b5a4c62da8493cbe5843218f89df1a232767d6faa8fa060b7960b26360853
production_release_content_sha256=290b5a4c62da8493cbe5843218f89df1a232767d6faa8fa060b7960b26360853
PRODUCTION_BOUNDARY_SEPARATE=PASS
PRODUCTION_TLS_HEALTH=PASS
PRODUCTION_ACTOR_POLICY=PASS
SAME_ARTIFACT_PROMOTED=PASS
PRODUCTION_DEPLOYMENT_OPERATION=PASS
PRODUCTION_EVIDENCE_LINEAGE=PASS
BREAK_GLASS=DENIED
PRODUCTION_PUBLIC_HEALTH=PASS
GATE_10=COMPLETE
```

Production is isolated from staging by service identity, PostgreSQL state, bearer credential and Forgejo credential. The production app binds to loopback port 3188 behind TLS at `mcp-git.criandofacil.com.br`.

Detailed evidence: `devos-forge-control-plane/docs/evidence/GATE-10-PRODUCTION.md`.

## Active Gate 11 — Forgejo source-of-truth cutover

Canonical tracking: `devos-forge-control-plane` Issue **#32**.

Objective:

```text
final GitHub -> Forgejo parity
  -> explicit write-authority cutover
  -> Forgejo authoritative primary
  -> production MCP primary operational path
  -> Forgejo-native branch/PR/review/Actions/merge proof
  -> GitHub bootstrap-primary authority retired
```

Required exit evidence:

```text
FORGEJO_SOURCE_OF_TRUTH=PASS
GITHUB_BOOTSTRAP_PRIMARY=RETIRED
FORGEJO_NATIVE_LIFECYCLE=PASS
PRODUCTION_MCP_PRIMARY_PATH=PASS
CREDENTIAL_CUTOVER=PASS
ROLLBACK_CUTBACK_PROVEN=PASS
STAGE_E=COMPLETE
STAGE_G=COMPLETE
GATE_11=COMPLETE
```

Gate 11 must define GitHub's post-cutover secondary role and sync direction explicitly. No dual-primary interval is acceptable.

## Security / credential lifecycle

- never commit runtime tokens, private keys or generated secrets;
- GitHub remains the temporary writable bootstrap primary only until Gate 11 cutover;
- staging and production use separate host-held Forgejo and MCP bearer credentials;
- production state is in the separate `devos_cp_production` PostgreSQL database;
- `BREAK_GLASS` remains default-denied;
- Forgejo Actions remain rootless-Podman/container-only;
- bootstrap credentials are retired/rotated only after cutback is proven.

## Immediate next action

Execute Gate 11 as a controlled authority migration: freeze final parity, prove cutback, transfer write authority to Forgejo, prove the full Forgejo-native lifecycle through production MCP, then retire GitHub's bootstrap-primary role.
