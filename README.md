# DevOS Forge

> Private, self-hosted software forge for the DevOS ecosystem.

DevOS Forge exists to remove operational dependence on third-party Git hosting and CI infrastructure while preserving the Git workflow we already use.

The project starts pragmatically: **Forgejo provides the mature Git forge layer; DevOS adds orchestration, intent, policy, provenance, and agent-native execution over time.**

## Why this exists

Today, a large part of the development workflow depends on external infrastructure for repository hosting, pull requests, CI/CD, runners, APIs, and availability.

DevOS Forge changes the ownership boundary:

```text
Before

Developer / Agent
      |
      v
External Forge
      |
      +-- repositories
      +-- pull requests
      +-- CI/CD
      +-- runners
      +-- releases

After

Developer / Agent
      |
      v
DevOS Forge on our VPS
      |
      +-- repositories
      +-- pull requests
      +-- CI/CD
      +-- our runners
      +-- releases
      +-- DevOS integration
```

The goal is **not** to recreate GitHub feature-for-feature.

The goal is to own the subset of forge capabilities we actually depend on and evolve that foundation toward an agent-native development environment.

## Initial scope

The first production baseline is intentionally conventional and boring:

- Forgejo
- Git over SSH and HTTPS
- private repositories
- users and access control
- branches, commits, tags and releases
- issues and pull requests
- webhooks and API
- Forgejo Actions
- self-hosted Forgejo Runner
- Docker-based deployment
- PostgreSQL
- reverse proxy + TLS
- persistent storage
- automated backups
- observability and recovery procedures

## Long-term direction

The long-term opportunity is not "a smaller GitHub".

It is a forge where Git history is connected to human intent and agent execution:

```text
Human Intent
     |
     v
    PDS
     |
     v
Explicit Human Choices
     |
     v
    PBI
     |
     v
    PBP
     |
     v
Agent Execution
     |
     v
Tests / Policies / Evidence
     |
     v
Commit / Review / Merge
```

Over time, DevOS Forge may understand first-class concepts such as:

- intent
- decisions
- PDS / PBI / PBP
- agent identity
- execution lineage
- policies
- test evidence
- provenance
- approvals
- releases

Git remains the source-control substrate. The innovation belongs above it.

## Architectural principle

**Do not rewrite mature forge infrastructure until real usage proves that we need to.**

The initial architecture therefore separates DevOS from the forge implementation:

```text
DevOS
  |
  v
Forge Provider Contract
  |
  +--> Forgejo Adapter --> Forgejo
  |
  `--> Future adapters / native components
```

This keeps Forgejo replaceable without making replacement a current objective.

## Repository map

- [`00_PROMPT_ZERO.md`](00_PROMPT_ZERO.md) — operating contract for AI-assisted work in this repository
- [`docs/PROJECT-STATE.md`](docs/PROJECT-STATE.md) — current state and next actions
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — target architecture and boundaries
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — architectural decisions and rationale
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — staged implementation plan
- [`docs/PREFLIGHT.md`](docs/PREFLIGHT.md) — read-only VPS discovery checklist
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — Phase 1 deployment baseline and host-specific runbook target
- [`docs/MIGRATION.md`](docs/MIGRATION.md) — GitHub-to-Forgejo transition strategy
- [`docs/OPERATIONS.md`](docs/OPERATIONS.md) — operational model, backup and recovery baseline
- [`docs/SECURITY.md`](docs/SECURITY.md) — minimum security posture

## Current phase

**Phase 0 — Foundation and design.**

No custom forge engine is being built yet. The immediate objective is to inspect the target VPS, resolve host-specific deployment choices, deploy and validate a private Forgejo-based forge, and prove the complete lifecycle before any broad migration.

See [`docs/PROJECT-STATE.md`](docs/PROJECT-STATE.md) for the live checkpoint.