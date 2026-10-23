# DevOS Forge Control Plane — Status

## Current state

```text
CONTROL_PLANE_ARCHITECTURE=ACCEPTED
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
FORGE_PROVIDER_CONTRACT=PASS
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
- provider surface now covers repositories, files, branches, commits, issues, pull requests, workflows/runs, releases and deployments;
- no MCP-specific types or Forgejo REST/raw response shapes are present in the provider contract.

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

## Current gate

**Gate 3 — ForgejoProvider read path**

Required operations:

```text
server/version discovery
current identity/authentication verification
repository list/get
file read/tree
branch list/get
commit list/get/diff
issue list/get
pull request list/get
workflow/run inspection where supported
release read where supported
deployment read where supported
```

Required properties:

- staging-scoped Forgejo credential;
- actual Forgejo capability discovery;
- raw Forgejo response types contained inside `src/providers/forgejo/`;
- deterministic auth/permission/not-found/provider-unavailable errors;
- mocked unit tests;
- integration smoke against Forgejo.

## Next exit evidence

```text
FORGEJO_PROVIDER_READ=PASS
```
