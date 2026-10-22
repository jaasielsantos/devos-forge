# ADR-001 — DevOS Forge V1 host deployment

**Status:** Accepted  
**Date:** 2026-10-22

## Context

Two VPS hosts were inspected. `criandofacil-vps` (`srv1805473`) was selected for the initial single-host deployment because it already provides a low-load Ubuntu host with Nginx, PostgreSQL 16, Certbot, OpenSSH, Podman, swap, and sufficient initial disk/memory capacity.

The objective is to reach GitHub-independent Git + CI operation quickly while minimizing new infrastructure and preserving a clean path to future scale-out.

## Decision

### Server packaging

Install Forgejo as a **native binary managed by systemd** rather than containerizing the Forgejo application.

Reason: the host's ingress/database/service model is already native, while the installed Podman version is useful for isolated CI jobs. Native Forgejo therefore creates the smallest change surface.

### Forgejo release line

Start on **Forgejo 15 LTS**, initially pinned to `15.0.10` by the bootstrap script.

Patch upgrades are explicit maintenance events. Major upgrades require release-note review and verified backup.

### HTTP ingress

Forgejo listens only on:

```text
127.0.0.1:3000
```

The existing Nginx service remains the only public HTTP(S) ingress.

Candidate hostname:

```text
git.criandofacil.com.br
```

### Database

Reuse the existing PostgreSQL 16 instance with dedicated objects:

```text
role:     forgejo
database: forgejo
```

Do not deploy a second PostgreSQL server.

### Git SSH

Reuse the existing system OpenSSH server on port 22.

Forgejo's built-in SSH server remains disabled. Forgejo manages authorized keys for its dedicated `git` operating-system account.

### Runner isolation

Create a dedicated Forgejo Runner account and execute workflows through **rootless Podman containers**.

Do not run generic Actions jobs directly on the host.

### Concurrency transition

While the existing GitHub Actions runner remains active:

```text
Forgejo runner.capacity = 1
```

After the GitHub runner is retired and resource behavior is validated:

```text
Forgejo runner.capacity = 2
```

This preserves the desired two-job working style without allowing accidental three-way contention on a 1-vCPU host during migration.

### Interaction model

V1 remains **headless-first**. Chat/CLI/Git/SSH/API are the primary interfaces. Forgejo's native UI is an administrative/manual fallback only.

### Pilot repository

The first repository migrated through the complete lifecycle is:

```text
devos-forge
```

This lets the forge prove that it can host its own infrastructure repository before production projects depend on it.

## Consequences

### Positive

- minimal new infrastructure;
- no Docker installation required for V1;
- no duplicate reverse proxy or database;
- standard Git SSH URLs on port 22;
- CI isolation through the already installed container runtime;
- easy future runner scale-out to the second VPS;
- lower operational complexity during migration.

### Accepted risks

- one VPS remains a runtime failure domain;
- Forgejo and runner workloads initially share CPU/RAM;
- the existing GitHub runner coexists temporarily;
- offsite restore capability must be proven before broad cutover.

## Implementation references

- `docs/RUNBOOK-V1.md`
- `scripts/bootstrap-server-v1.sh`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/PROJECT-STATE.md`
