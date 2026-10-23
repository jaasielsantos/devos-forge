# DevOS Forge Control Plane — Status

## Current state

```text
CONTROL_PLANE_ARCHITECTURE=ACCEPTED
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
FORGE_PROVIDER_CONTRACT=PASS
FORGEJO_PROVIDER_READ=PASS
BOOTSTRAP_PRIMARY=GITHUB
FORGEJO_ROLE=PULL_MIRROR_UNTIL_CUTOVER
SELF_HOSTED_CI=PASS
PRODUCTION_ENDPOINT=mcp-git.criandofacil.com.br
STAGING_ENDPOINT=mcp-git-staging.criandofacil.com.br
ROOT_MCP_ENDPOINT=mcp.criandofacil.com.br (reserved)
```

## Completed

- Control Plane architecture accepted;
- standalone `jaasielsantos/devos-forge-control-plane` repository bootstrapped;
- GitHub-hosted runner removed from the accepted workflow;
- dedicated self-hosted runner `devos-cp-vps-01` qualified on `srv1805473`;
- private GitHub -> Forgejo pull mirror created with 10 minute interval;
- GitHub/Forgejo refs and `main` SHA parity verified at Gate 1 acceptance;
- Forgejo Git object integrity verified;
- forge-agnostic `ForgeProvider` contract completed before Forgejo/MCP implementation;
- normalized pagination, provider errors, typed preconditions, deterministic conflicts and explicit capabilities implemented;
- provider surface covers repositories, files, branches, commits, issues, pull requests, workflows/runs, releases and deployments;
- real `ForgejoProvider` read adapter implemented with Forgejo-specific paths/raw shapes isolated under `src/providers/forgejo/`;
- authenticated read smoke passed against Forgejo 15.0.10 using the private Control Plane mirror plus the Forgejo-native `devos-forge` repository;
- no MCP-specific types are present in the provider layer.

## Gate 1 evidence

```text
self_hosted_runner=devos-cp-vps-01
self_hosted_ci_run=39889609853
self_hosted_ci_job=120205953195
SELF_HOSTED_CI=PASS
mirror_create_http=201
mirror_interval=10m
refs_parity=PASS
github_main=4ba159f14faf44c4cf563ea87581989006286163
forgejo_main=4ba159f14faf44c4cf563ea87581989006286163
object_integrity=PASS
CONTROL_PLANE_MIRROR=PASS
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
```

Canonical evidence: `devos-forge-control-plane/docs/evidence/GATE-1-BOOTSTRAP.md`.

## Gate 2 evidence

```text
implementation_pr=5
implementation_commit=0906a554f99d75be22886aa250d54f29c533582d
self_hosted_ci_run=39893097006
self_hosted_ci_job=120217168484
lint=PASS
typecheck=PASS
tests=PASS
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
forgejo_version=15.0.10+gitea-1.22.0
authentication=PASS
capability_discovery=PASS
private_mirror_repository_get=PASS
file_read=PASS
branches_read=PASS
tree_read=PASS
commits_read=PASS
native_repository_get=PASS
issues_read=PASS
releases_read=PASS
FORGEJO_PROVIDER_READ_AUTHENTICATED_SMOKE=PASS
FORGEJO_PROVIDER_READ=PASS
```

Current repository/instance units returning deterministic `NOT_FOUND` during the smoke are treated as unavailable capabilities:

```text
pull_requests_read=SKIP_REPOSITORY_OR_INSTANCE_CAPABILITY
workflows_read=SKIP_REPOSITORY_OR_INSTANCE_CAPABILITY
runs_read=SKIP_REPOSITORY_OR_INSTANCE_CAPABILITY
```

Canonical evidence: `devos-forge-control-plane/docs/evidence/GATE-3-FORGEJO-READ.md`.

## Current gate

**Gate 4 — ForgejoProvider write path**

Required operations:

```text
repository create
file write/delete
branch create/delete
issue create/update/comment
pull request create/review/merge when the repository unit is available
workflow dispatch when the repository/instance capability is available
release create
```

Required properties:

- mutations carry `operationId`;
- expected SHA/blob preconditions are enforced before conflicting writes;
- no default force-push path;
- deterministic `REF_CONFLICT`, `RESOURCE_CONFLICT` and `PRECONDITION_FAILED` behavior;
- raw Forgejo mutation shapes remain contained inside `src/providers/forgejo/`;
- writes are exercised first against a dedicated staging/scratch repository;
- no production repository mutation is part of Gate 4 validation.

## Next exit evidence

```text
FORGEJO_PROVIDER_WRITE=PASS
```
