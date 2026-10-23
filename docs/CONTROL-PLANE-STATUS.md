# DevOS Forge Control Plane — Status

## Current state

```text
CONTROL_PLANE_ARCHITECTURE=ACCEPTED
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
BOOTSTRAP_PRIMARY=GITHUB
FORGEJO_ROLE=PULL_MIRROR_UNTIL_CUTOVER
SELF_HOSTED_CI=PASS
PRODUCTION_ENDPOINT=mcp-git.criandofacil.com.br
STAGING_ENDPOINT=mcp-git-staging.criandofacil.com.br
ROOT_MCP_ENDPOINT=mcp.criandofacil.com.br (reserved)
```

## Completed

- architecture defined and accepted;
- standalone repository `jaasielsantos/devos-forge-control-plane` created;
- repository-local Prompt Zero, README, PROJECT-STATE and DECISIONS established;
- strict TypeScript baseline, dependency lockfile and deterministic quality commands established;
- initial ForgeProvider boundary created before MCP implementation;
- GitHub-hosted CI removed from the accepted Control Plane workflow;
- dedicated self-hosted runner `devos-cp-vps-01` registered on the existing `srv1805473` host;
- CI qualified on labels `[self-hosted, linux, x64, devos-control-plane]`;
- private GitHub -> Forgejo pull mirror created with 10 minute interval;
- GitHub/Forgejo branch and tag parity verified;
- exact `main` SHA parity verified at the Gate 1 acceptance snapshot;
- Forgejo Git object integrity verified with `git fsck --full --no-dangling`;
- mirror credential lifecycle documented without storing token values.

## Gate 1 evidence

Acceptance snapshot:

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
forgejo_mirror=PASS
CONTROL_PLANE_MIRROR=PASS
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
```

The canonical detailed evidence now lives in the Control Plane repository:

```text
docs/evidence/GATE-1-BOOTSTRAP.md
```

Gate 1 closeout was merged through Control Plane PR #3.

## Current gate

**Gate 2 — ForgeProvider contract**

The implementation now hardens the forge-agnostic provider contract before any Forgejo HTTP adapter or MCP tool surface is introduced.

Required provider areas:

```text
capabilities
repositories
files
branches
commits
issues
pullRequests
workflows
releases
deployments
```

Required properties:

- normalized pagination;
- normalized errors;
- typed preconditions;
- deterministic conflict handling;
- capability model;
- no MCP-specific types;
- no Forgejo REST paths or raw response shapes outside `src/providers/forgejo/`.

## Next exit evidence

```text
FORGE_PROVIDER_CONTRACT=PASS
```

After Gate 2, implementation proceeds to the ForgejoProvider read path.
