# ADR-002 — DevOS Forge MCP / ChatGPT Control Plane

**Status:** Accepted  
**Date:** 2026-10-22

## Context

DevOS Forge has reached the point where Forgejo can host Git and execute Forgejo Actions, and the Forgejo-native pilot branch lifecycle has passed its branch creation/write gate (`FORGEJO_NATIVE_BRANCH=PASS`).

The remaining operational limitation is external control: ChatGPT currently has first-class operational access to GitHub through the GitHub connector, but does not yet have an equivalent direct control surface for the self-hosted Forgejo instance.

The objective is to remove that dependency without coupling DevOS core or ChatGPT directly to Forgejo implementation details.

## Decision

Build a separate service named **DevOS Forge Control Plane** with MCP as its first agent-facing adapter.

The architecture is:

```text
ChatGPT / DevOS / future clients
            |
            v
          MCP
            |
            v
DevOS Forge Control Plane
            |
            v
       ForgeProvider
            |
            v
     ForgejoProvider
            |
            v
         Forgejo
```

MCP is an adapter. It is not the domain layer and must not contain Forgejo-specific business logic.

## Bootstrap source-of-truth decision

During construction of the Control Plane, GitHub is allowed to remain the temporary primary development surface for the Control Plane repository because the existing ChatGPT connector provides the write path needed to bootstrap the replacement.

Forgejo mirrors the repository during this bootstrap interval.

After production validation, Forgejo becomes the primary source of truth and GitHub is demoted to a mirror/secondary role or removed from the critical path.

This temporary dependency is explicitly a bootstrap mechanism, not the target operating model.

## Repository decision

The Control Plane lives in a separate repository:

```text
devos-forge-control-plane
```

It is not embedded inside the `devos-forge` infrastructure repository.

This preserves independent release, credentials, CI/CD, rollback, and trust boundaries.

## Endpoint decision

Reserve:

```text
mcp.criandofacil.com.br
```

for a possible future root MCP surface for the broader CriandoFacil ecosystem.

The DevOS Forge Control Plane uses:

```text
Production: mcp-git.criandofacil.com.br
Staging:    mcp-git-staging.criandofacil.com.br
```

## Provider boundary

All application operations must pass through a small `ForgeProvider` contract.

Forgejo REST/API compatibility belongs inside `ForgejoProvider`.

No generic raw Forgejo API tool is exposed to the model.

## Policy decision

The Control Plane classifies operations into:

- READ;
- WRITE;
- RELEASE;
- PRODUCTION;
- BREAK_GLASS.

BREAK_GLASS operations are not exposed through MCP V1.

Authorization requires both:

```text
Control Plane policy
        +
Forgejo permissions
```

## Mutation safety

Material writes use optimistic concurrency and deterministic preconditions where applicable.

Force pushes are not part of the ordinary MCP V1 surface.

All mutations are idempotent through an operation ledger and produce structured evidence.

## Deployment decision

Staging and production deployment are semantic Control Plane operations backed by controlled Forgejo Actions/deployment workflows.

The MCP must not receive arbitrary root SSH or unrestricted production shell access.

Production promotes the exact immutable artifact already validated in staging whenever the target application supports artifact-based deployment.

## Environment separation

Staging and production Control Plane instances use separate:

- service processes;
- runtime state;
- databases where required;
- Forgejo credentials;
- policy scopes;
- deployment credentials.

## Consequences

### Positive

- ChatGPT can eventually operate Forgejo directly without GitHub connector dependence.
- DevOS core remains portable across forge implementations.
- Production authority is narrower and more auditable than a generic shell or raw API bridge.
- The same Control Plane can later serve DevOS CLI, APIs, other agents, or a CriandoFacil root MCP gateway.
- Audit/evidence becomes a natural foundation for PDS/PBI/PBP execution provenance.

### Costs

- The project must operate an additional service and persistent audit/idempotency state.
- Forgejo API differences must be normalized by the provider.
- Staging and production require separate operational configuration.
- The bootstrap period temporarily retains GitHub as a primary development dependency.

## Exit condition

This ADR is considered fully realized when:

1. staging Control Plane is reachable at `mcp-git-staging.criandofacil.com.br`;
2. MCP-to-Forgejo end-to-end tests pass;
3. production Control Plane is reachable at `mcp-git.criandofacil.com.br`;
4. ChatGPT/OpenAI can operate the Forgejo pilot through the Control Plane;
5. Forgejo becomes primary for `devos-forge-control-plane`;
6. GitHub is no longer required for normal Control Plane operation.
