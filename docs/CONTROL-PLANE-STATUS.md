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
BOOTSTRAP_PRIMARY=GITHUB
FORGEJO_ROLE=PULL_MIRROR_UNTIL_CUTOVER
SELF_HOSTED_CI=PASS
ACTIVE_GATE=10_PRODUCTION
ACTIVE_ISSUE=devos-forge-control-plane#29
PRODUCTION_ENDPOINT=mcp-git.criandofacil.com.br
STAGING_ENDPOINT=mcp-git-staging.criandofacil.com.br
ROOT_MCP_ENDPOINT=mcp.criandofacil.com.br (reserved)
```

## Completed gates

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
[~] Gate 10 production
[ ] Gate 11 Forgejo source-of-truth cutover
```

Canonical implementation and evidence are maintained in `jaasielsantos/devos-forge-control-plane`.

## Gate 8 proof

```text
release_sha=c167a46518737165463655db82997ad52ddc569a
workflow_run=39978675219
workflow_job=120499913136
MCP_PUBLIC_AUTHENTICATED_DISCOVERY=PASS
MCP_FORGEJO_READ_E2E=PASS
MCP_FORGEJO_WRITE_E2E=PASS
MCP_OPERATION_REPLAY=PASS
MCP_EVIDENCE_LINEAGE=PASS
FORGEJO_DIRECT_CLEANUP=PASS
GATE_8=COMPLETE
```

## Gate 9 proof

```text
implementation_pr=28
implementation_merge=ea7bf22900b1c12b5b13964d96ef19fb9a4b8380
staging_release_sha=ea7bf22900b1c12b5b13964d96ef19fb9a4b8380
staging_release_sha256=3f44573b695718d1574d067c869806b2568a7ce27012e2c24ab126955c4bc23b
workflow_run=39989576496
workflow_job=120537536119
artifact_digest=sha256:2deda67b9c59ae72c89cc830e5531614cd2f1d7776ab80bf642c8e17380c89a3
unit_tests=63/63 PASS
DEPLOYMENT_SEMANTICS_TYPED=PASS
BUILD_ONCE_ARTIFACT_IDENTITY=PASS
STAGING_DEPLOYMENT_OPERATION=PASS
DEPLOYMENT_IDEMPOTENCY=PASS
SAME_ARTIFACT_PROMOTION_MODEL=PASS
DEPLOYMENT_EVIDENCE_LINEAGE=PASS
production_mutation=DISABLED
GATE_9=COMPLETE
```

Gate 9 established deployment as a semantic Control Plane operation rather than a workflow/shell passthrough. Artifact identity is bound to exact source SHA + digest. Promotion eligibility requires the exact healthy staging artifact; rebuild/digest drift is rejected.

## Active Gate 10 — production

Gate 10 must create a **separate production boundary** before any production mutation is allowed.

Required properties:

```text
separate production service identity
separate production PostgreSQL state
separate production Forgejo credential
separate production MCP bearer / policy identity
loopback-only application bind
Nginx/TLS at mcp-git.criandofacil.com.br
explicit PRODUCTION risk grant only on the production path
same artifact already proven in staging
operation_id + exact preconditions + append-only evidence
BREAK_GLASS remains denied
```

Exit evidence:

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

## Security boundary

- no raw Forgejo API passthrough;
- no arbitrary shell or SSH MCP tool;
- risk classification remains server-owned;
- staging actor grants are `READ,WRITE,RELEASE` only;
- `PRODUCTION` is not granted to staging;
- `BREAK_GLASS` stays default-denied and absent from MCP V1;
- GitHub remains temporary bootstrap primary until Gate 11;
- production deployment must not rebuild the Gate 9 artifact.
