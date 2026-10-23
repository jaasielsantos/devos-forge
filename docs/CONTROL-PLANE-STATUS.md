# DevOS Forge Control Plane — Status

## Current state

```text
CONTROL_PLANE_ARCHITECTURE=ACCEPTED
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
FORGE_PROVIDER_CONTRACT=PASS
FORGEJO_PROVIDER_READ=PASS
FORGEJO_PROVIDER_WRITE=PASS
CONTROL_PLANE_CORE=PASS
MCP_ADAPTER=PASS
MCP_STAGING_DEPLOY=PASS
GATE_8_E2E=PASS
GATE_9_E2E=PASS
GATE_10_E2E=PASS
GATE_10=COMPLETE
BOOTSTRAP_PRIMARY=GITHUB_UNTIL_GATE_11_CUTOVER
FORGEJO_ROLE=PULL_MIRROR_UNTIL_CUTOVER
SELF_HOSTED_CI=PASS
ACTIVE_GATE=11_FORGEJO_SOURCE_OF_TRUTH
ACTIVE_ISSUE=devos-forge-control-plane#32
PRODUCTION_ENDPOINT=mcp-git.criandofacil.com.br
PRODUCTION_ENDPOINT_STATE=LIVE
STAGING_ENDPOINT=mcp-git-staging.criandofacil.com.br
ROOT_MCP_ENDPOINT=mcp.criandofacil.com.br (reserved)
```

## Gate map

```text
[x] Gate 0  architecture freeze
[x] Gate 1  bootstrap repository + mirror + self-hosted CI
[x] Gate 2  ForgeProvider contract
[x] Gate 3  ForgejoProvider read
[x] Gate 4  ForgejoProvider write
[x] Gate 5  policy / idempotency / durable evidence
[x] Gate 6  semantic MCP adapter
[x] Gate 7  public staging deployment
[x] Gate 8  public MCP -> Forgejo E2E
[x] Gate 9  typed deployment control semantics
[x] Gate 10 production
[~] Gate 11 Forgejo source-of-truth cutover
```

Canonical implementation and evidence are maintained in `jaasielsantos/devos-forge-control-plane`.

## Gate 8 proof

```text
release_sha=c167a46518737165463655db82997ad52ddc569a
workflow_run=39978675219
workflow_job=120499913136
MCP_FORGEJO_READ_E2E=PASS
MCP_FORGEJO_WRITE_E2E=PASS
MCP_OPERATION_REPLAY=PASS
MCP_EVIDENCE_LINEAGE=PASS
FORGEJO_DIRECT_CLEANUP=PASS
GATE_8=COMPLETE
```

## Gate 9 proof

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

## Gate 10 proof

```text
implementation_pr=31
implementation_merge=d091daff4047194a52e62561ede3d0e2b153ebb7
closeout_pr=33
staging_refresh_run=40025339905
staging_refresh_job=120660007003
staging_release_tar_sha256=8971b5410d1a2066e29e5668f56eb0f2ac9b502b83912b19f36d2880da953de6
staged_semantic_artifact_digest=sha256:e947d425c4bba93e203280ab6703b01a3b92f02701507690e636c35034ae61ab
production_run=40025552767
production_job=120660713791
production_release_sha=d091daff4047194a52e62561ede3d0e2b153ebb7
staging_release_content_sha256=290b5a4c62da8493cbe5843218f89df1a232767d6faa8fa060b7960b26360853
production_release_content_sha256=290b5a4c62da8493cbe5843218f89df1a232767d6faa8fa060b7960b26360853
PRODUCTION_BOUNDARY_SEPARATE=PASS
PRODUCTION_TLS_HEALTH=PASS
PRODUCTION_ACTOR_POLICY=PASS
SAME_ARTIFACT_PROMOTED=PASS
PRODUCTION_DEPLOYMENT_OPERATION=PASS
PRODUCTION_IDEMPOTENCY=PASS
PRODUCTION_EVIDENCE_LINEAGE=PASS
BREAK_GLASS=DENIED
PRODUCTION_PUBLIC_HEALTH=PASS
GATE_10_E2E=PASS
GATE_10=COMPLETE
```

Gate 10 production boundary:

```text
service_identity=devos-cp-production
database=devos_cp_production
loopback_port=3188
actor=chatgpt-production
actor_grants=READ,WRITE,PRODUCTION
```

The exact staging release tree was copied into production and independently hashed on both sides. Equal `290b5a4c...` content digests prove promotion without rebuild.

Canonical evidence: `devos-forge-control-plane/docs/evidence/GATE-10-PRODUCTION.md`.

## Active Gate 11 — source-of-truth cutover

Gate 11 transfers authoritative write ownership from the temporary GitHub bootstrap path to Forgejo.

Required properties:

```text
final refs parity before cutover
single explicit write authority at every phase
Forgejo authoritative writable primary
production MCP becomes primary ChatGPT/DevOS operational path
complete Forgejo-native branch/PR/review/Actions/merge lifecycle
explicit GitHub secondary role and one-way sync direction
cutback proven before bootstrap credential retirement
bootstrap credentials retired/rotated after cutover
```

Exit evidence:

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

## Security boundary

- no raw Forgejo API passthrough;
- no arbitrary shell or SSH MCP tool;
- risk classification remains server-owned;
- staging actor grants are `READ,WRITE,RELEASE` only;
- production actor is separately scoped with explicit `PRODUCTION`;
- `BREAK_GLASS` stays default-denied and absent from MCP V1;
- GitHub stays temporary bootstrap primary only until the controlled Gate 11 authority cutover;
- Gate 11 must not create a dual-primary write interval or silent bidirectional mirror loop.
