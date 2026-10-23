# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo pilot proven; Control Plane staging live; Gate 9 active  
**Infrastructure:** Stages A-D complete  
**Migration:** Stage E proven through Forgejo-native branch; PR/Actions/review/merge proof remains intentionally paused until Control Plane production cutover  
**Control Plane:** Gates 0-8 complete; Gate 9 active in `devos-forge-control-plane` Issue #26  
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
[x] Gate 8  MCP -> Forgejo end-to-end proof
[~] Gate 9  deployment control semantics
[ ] Gate 10 production Control Plane
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

Canonical evidence through Gate 7:

```text
devos-forge-control-plane/docs/evidence/GATE-1-BOOTSTRAP.md
devos-forge-control-plane/docs/evidence/GATE-2-FORGE-PROVIDER.md
devos-forge-control-plane/docs/evidence/GATE-3-FORGEJO-READ.md
devos-forge-control-plane/docs/evidence/GATE-4-FORGEJO-WRITE.md
devos-forge-control-plane/docs/evidence/GATE-5-CONTROL-PLANE-CORE.md
devos-forge-control-plane/docs/evidence/GATE-6-MCP-ADAPTER.md
devos-forge-control-plane/docs/evidence/GATE-7-STAGING.md
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

Gate 8 proved the real path:

```text
ChatGPT / trusted command
  -> public staging MCP endpoint
  -> semantic MCP tools
  -> Control Plane policy / idempotency / evidence
  -> ForgejoProvider
  -> Forgejo pilot repository
```

Bounded mutation proof:

```text
target=jaasielsantos/devos-forge
observed_main_sha=34b872a85cf01cda5d8c59b019bf1756c097bde0
write_commit=a1b6feae28399a180877a125b3a6c9e0fcba4e53
cleanup=PASS
```

Exit evidence:

```text
GATE_8_COMMAND_SHA_PIN=PASS
MCP_PUBLIC_AUTHENTICATED_DISCOVERY=PASS
MCP_FORGEJO_READ_E2E=PASS
MCP_FORGEJO_WRITE_E2E=PASS
MCP_OPERATION_REPLAY=PASS
gate8_ledger_branch_create=PASS
gate8_ledger_file_write=PASS
gate8_ledger_branch_delete=PASS
MCP_EVIDENCE_LINEAGE=PASS
FORGEJO_DIRECT_CLEANUP=PASS
GATE_8_E2E=PASS
GATE_8=COMPLETE
```

The temporary Gate 8 branch was deleted through semantic MCP and independently verified absent in Forgejo. The same `file_write` operation was replayed with the same `operation_id` without a second provider mutation. No production mutation was introduced.

Closeout:

```text
implementation_pr_25=MERGED
closeout_pr_27=MERGED
control_plane_gate8_closeout_merge=1945cac0da2df29b50c8767a13a7c04feff4e60e
issue_23=CLOSED_COMPLETED
```

Detailed evidence: `devos-forge-control-plane/docs/evidence/GATE-8-MCP-FORGEJO-E2E.md`.

## Active Gate 9 — typed deployment control semantics

Canonical tracking: `devos-forge-control-plane` Issue **#26**.

Objective:

```text
proven public MCP path
  -> typed deployment operations
  -> immutable build-once artifact identity
  -> staging deployment semantics
  -> same-artifact promotion model
  -> idempotent ledger/evidence
```

Required exit evidence:

```text
DEPLOYMENT_SEMANTICS_TYPED=PASS
BUILD_ONCE_ARTIFACT_IDENTITY=PASS
STAGING_DEPLOYMENT_OPERATION=PASS
SAME_ARTIFACT_PROMOTION_MODEL=PASS
DEPLOYMENT_IDEMPOTENCY=PASS
DEPLOYMENT_EVIDENCE_LINEAGE=PASS
GATE_9=COMPLETE
```

Production mutation remains deferred to Gate 10.

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

Implement Gate 9 deployment-control semantics in the Control Plane, preserving build-once artifact identity, typed operations, exact preconditions, idempotency and evidence. No further manual VPS/Termux action is required for the completed Gate 8 proof.
