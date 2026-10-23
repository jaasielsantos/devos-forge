# DevOS Forge Control Plane — Bootstrap Runbook

## Purpose

Bootstrap the separate `devos-forge-control-plane` repository while GitHub is temporarily the writable primary surface available to ChatGPT.

This runbook intentionally avoids using the existing `devos-forge` repository as the Control Plane codebase.

## Bootstrap invariant

```text
GitHub primary
    -> Forgejo mirror
```

until the Control Plane production cutover is complete.

## Repository

```text
jaasielsantos/devos-forge-control-plane
```

## Initial repository configuration

Recommended GitHub repository properties during bootstrap:

- visibility: private unless there is a specific reason to make the implementation public;
- default branch: `main`;
- initialize with README only if needed to create the repository;
- no generated secrets or `.env` files committed;
- branch workflow used for implementation changes;
- GitHub Actions may be used only as a temporary bootstrap aid when the Forgejo equivalent is not yet available for the new repository.

## Initial branch

After repository creation:

```text
bootstrap/control-plane-v1
```

## Initial file set

```text
00_PROMPT_ZERO.md
README.md
PROJECT-STATE.md
DECISIONS.md
.gitignore
package.json
package-lock.json
tsconfig.json
src/providers/forge-provider.ts
src/providers/types.ts
src/index.ts
tests/
```

## Initial package scripts

Required scripts:

```text
build
check
typecheck
lint
test
```

`check` should aggregate the non-mutating quality gates used in CI.

## ForgeProvider-first rule

The first implementation code must define stable provider types and interfaces before any MCP tool implementation.

No code outside `src/providers/forgejo/` may depend on Forgejo REST endpoint paths or raw Forgejo response shapes.

## Forgejo mirror creation

Once the GitHub repository contains the initial baseline:

1. create `jaasielsantos/devos-forge-control-plane` in Forgejo as a pull mirror from GitHub;
2. verify default branch and refs;
3. verify Git object integrity where appropriate;
4. record parity evidence;
5. keep GitHub primary during Control Plane implementation;
6. do not introduce Forgejo-only writes before the cutover gate.

Expected evidence shape:

```text
github_main=<sha>
forgejo_main=<sha>
refs_parity=PASS
CONTROL_PLANE_MIRROR=PASS
```

## Gate 1 completion

Gate 1 closes only when:

```text
repository_exists=PASS
baseline_files=PASS
typecheck=PASS
tests=PASS
forgejo_mirror=PASS
refs_parity=PASS
CONTROL_PLANE_REPO_BOOTSTRAP=PASS
```

## Current tooling note

The connected GitHub control surface used by this conversation can read and mutate content, branches, issues, pull requests, commits, and workflow state, but does not expose repository creation as an available operation.

Therefore repository creation is the one bootstrap boundary that may require an external GitHub repository-creation action before ChatGPT can take over the remaining repository bootstrap through the connector.

This limitation is precisely one of the dependencies the new Control Plane is designed to remove for Forgejo operations.
