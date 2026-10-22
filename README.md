# DevOS Forge

> Private, self-hosted software forge for the DevOS ecosystem.

DevOS Forge exists to remove operational dependence on third-party Git hosting and CI infrastructure while preserving standard Git workflows.

The project starts pragmatically: **Forgejo provides the mature forge substrate; DevOS adds orchestration, intent, policy, provenance, and agent-native execution over time.**

## V1 operating model

V1 is **headless-first**. Chat/CLI/Git/SSH/API are the primary interfaces. Forgejo's native web UI remains available as an administrative/manual fallback, but no custom DevOS Forge UI is being built initially.

Selected runtime:

```text
criandofacil-vps
   |
   +-- existing Nginx / TLS
   +-- Forgejo 15 LTS (native + systemd)
   +-- existing PostgreSQL 16
   +-- system OpenSSH :22
   `-- Forgejo Runner -> rootless Podman
```

The goal is **not** to recreate GitHub feature-for-feature. The goal is to own the forge capabilities we actually depend on and evolve them toward an agent-native development environment.

## Long-term direction

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

Git remains the source-control substrate. The differentiated layer belongs above it.

## Architectural principle

**Do not rewrite mature forge infrastructure until real usage proves that we need to.**

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

## Repository map

- [`00_PROMPT_ZERO.md`](00_PROMPT_ZERO.md) — operating contract for AI-assisted work
- [`docs/PROJECT-STATE.md`](docs/PROJECT-STATE.md) — live checkpoint and next action
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — architecture and trust boundaries
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — durable project decisions
- [`docs/ADR-001-V1-DEPLOYMENT.md`](docs/ADR-001-V1-DEPLOYMENT.md) — accepted V1 host deployment ADR
- [`docs/RUNBOOK-V1.md`](docs/RUNBOOK-V1.md) — executable deployment sequence
- [`scripts/bootstrap-server-v1.sh`](scripts/bootstrap-server-v1.sh) — guarded Stage A bootstrap
- [`docs/HOST-CRIANDOFACIL.md`](docs/HOST-CRIANDOFACIL.md) — selected host evidence summary
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — deployment entrypoint
- [`docs/MIGRATION.md`](docs/MIGRATION.md) — GitHub-to-Forgejo transition strategy
- [`docs/OPERATIONS.md`](docs/OPERATIONS.md) — backup/recovery baseline
- [`docs/SECURITY.md`](docs/SECURITY.md) — security posture

## Current phase

**Phase 0 → Phase 1 transition.**

The host-specific deployment design is locked and the Stage A bootstrap is ready in dry-run mode. See `docs/PROJECT-STATE.md` for the current checkpoint.
