# DevOS Forge — Decisions

This file records durable project decisions. Each decision should remain understandable even if the surrounding implementation changes.

---

## D-001 — Self-host the forge

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

DevOS Forge will run on infrastructure we control rather than depend on a third-party forge as the primary operational platform.

### Why

The project exists to preserve the ability to clone, push, review, run CI, and deploy even when an external provider is unavailable, rate-limited, expensive, or strategically undesirable.

### Consequences

We become responsible for availability, patching, backups, recovery, authentication, and runner security.

---

## D-002 — Use Forgejo as the initial forge engine

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

Use Forgejo as the initial implementation for repository hosting, collaboration, API, Actions, packages, and related forge capabilities.

### Why

Reimplementing mature forge infrastructure before learning from real usage would create high cost with little differentiated value.

### Consequences

The first production milestone focuses on deployment and integration, not custom forge internals.

---

## D-003 — Git remains the source-control substrate

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

Do not invent a new version-control protocol. Preserve standard Git interoperability.

### Why

The problem we want to solve is ownership and agent-native orchestration, not version control itself.

### Consequences

Existing Git clients and workflows remain usable. Migration in and out stays practical.

---

## D-004 — DevOS must access the forge through a provider boundary

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

DevOS should depend on a small forge-provider contract rather than spread Forgejo-specific assumptions throughout the core.

### Why

This preserves optionality for future adapters or native components without forcing a full-system rewrite.

### Consequences

Provider interfaces must be driven by real operations and kept smaller than the complete Forgejo API.

---

## D-005 — VPS is the initial runtime home

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

The initial forge and its core services will run on our VPS infrastructure.

### Why

The system should remain available independently of a personal workstation and should be reachable by developers and agents when needed.

### Consequences

The initial deployment accepts a single-VPS runtime failure domain. Recoverability and offsite backup are mandatory; high availability is not.

---

## D-006 — Runners are self-hosted

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

CI/CD execution will use runners we control.

### Why

This removes metered hosted-runner dependency and gives us control over capacity, software, cache, networking, and execution policy.

### Consequences

Runner isolation becomes our security responsibility. Repository-defined jobs must not automatically receive unrestricted access to the host or production credentials.

---

## D-007 — Migrate incrementally

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

Do not move all repositories at once. Validate the complete lifecycle with a pilot repository first.

### Migration sequence

```text
GitHub primary + Forgejo validation
        ->
Forgejo primary + GitHub mirror
        ->
Forgejo primary + GitHub optional
```

### Why

Independence should reduce risk, not create a migration event that can strand active projects.

---

## D-008 — Do not build a custom forge engine yet

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

A native DevOS forge engine is explicitly deferred.

### Trigger for reconsideration

Revisit only when real operational evidence shows that Forgejo materially blocks one or more core DevOS goals and the limitation cannot be cleanly solved above or beside Forgejo.

### Why

The differentiated idea is not another GitHub clone. It is:

> Git + agentic execution + explicit human intent.

---

## D-009 — Agent-native semantics belong above the forge substrate first

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

PDS, PBI, PBP, intent, provenance, agent identity, policy evidence, and execution lineage should initially be modeled by DevOS rather than added by modifying Forgejo internals.

### Why

This lets us prove the semantics independently and keeps the mature Git layer replaceable.

### Consequences

Future native integration remains possible after the model is validated.

---

## D-010 — Recovery is part of independence

**Status:** Accepted  
**Date:** 2026-10-20

### Decision

A deployment is not considered independent until its repositories, database, configuration, and required secrets can be restored on replacement infrastructure.

### Why

Moving from an external forge to a single unbacked VPS would exchange vendor dependency for hardware/provider dependency.

### Consequences

Backup verification and restore drills are release criteria for the infrastructure, not post-launch housekeeping.

---

## D-011 — V1 is headless-first; no custom user interface

**Status:** Accepted  
**Date:** 2026-10-22

### Decision

Do not build a custom DevOS Forge web interface in the initial phases.

The primary interaction model will be:

```text
Human
  |
  v
Chat / CLI / DevOS commands
  |
  v
ForgeProvider / Forgejo API / Git / SSH
  |
  v
DevOS Forge
```

Forgejo's native web interface remains available as an administrative and diagnostic fallback, but it is not the primary product surface and will not be customized initially.

### Why

The installation is private, initially operated by a single primary user, and most routine actions can be performed more efficiently through Git, SSH, APIs, automation, and assistant-driven commands.

### Consequences

- prioritize API completeness and automation over visual customization;
- keep operational actions scriptable and machine-readable;
- document common commands and DevOS operations rather than designing dashboards;
- use Forgejo's native UI only when manual inspection, administration, review, or emergency access is useful;
- reconsider a custom interface only when real multi-user or visual workflow requirements appear.

---

## D-012 — V1 runs on one VPS: `criandofacil-vps`

**Status:** Accepted  
**Date:** 2026-10-22

### Decision

The first production-shaped DevOS Forge deployment will run on a single VPS, accessed through the local SSH alias `criandofacil-vps` and currently identified by the host as `srv1805473`.

The second VPS is intentionally excluded from the initial runtime.

### Why

The objective is operational independence with the smallest reliable architecture. Splitting control-plane and runner workloads across two hosts before real load requires it would add networking, deployment, recovery, and debugging complexity without immediate benefit.

The selected host already provides useful baseline infrastructure, including Nginx, PostgreSQL 16, TLS automation through Certbot, swap, and sufficient free memory/disk for the initial private workload.

### Initial logical topology

```text
criandofacil-vps
|
+-- existing Nginx / TLS
+-- Forgejo
+-- existing PostgreSQL 16 (dedicated Forgejo DB/user)
+-- Forgejo Actions
+-- self-hosted runner capacity
+-- persistent Git / Forgejo data
`-- backup / restore jobs
```

### Consequences

- prefer integration with existing Nginx and PostgreSQL instead of duplicating them;
- keep the second VPS available for future backup, disaster recovery, or additional runner capacity;
- accept a single-host runtime failure domain in V1;
- require offsite backup and a documented restore path before broad migration;
- scale out only when measurements or operational pain justify it.

---

## D-013 — Initial runner target allows up to two concurrent jobs

**Status:** Accepted with validation requirement  
**Date:** 2026-10-22

### Decision

Design the V1 runner layer so it can support up to two concurrent jobs, matching the existing working style, but validate CPU and memory behavior on `criandofacil-vps` before making two-way concurrency the permanent default.

### Why

The host has limited CPU capacity, while normal workflows may benefit from two jobs in parallel. The right policy is therefore to preserve the capability without assuming that all workloads should always run concurrently.

### Consequences

- runner concurrency must be configurable;
- start with controlled workloads and observe load;
- heavy jobs may be serialized if contention is excessive;
- a second VPS may later provide extra runner capacity without moving Forgejo itself.

---

## D-014 — Forgejo V1 uses native binary + systemd

**Status:** Accepted  
**Date:** 2026-10-22

### Decision

Run the Forgejo server as a native binary managed by systemd rather than as a container.

### Why

The selected host already uses native Nginx, PostgreSQL and systemd services. Native Forgejo minimizes change surface and avoids introducing Docker solely for the server application.

Podman remains reserved for runner job isolation.

---

## D-015 — Reuse existing Nginx and PostgreSQL 16

**Status:** Accepted  
**Date:** 2026-10-22

### Decision

Reuse the host's existing Nginx and PostgreSQL 16 services.

Forgejo receives a dedicated `forgejo` PostgreSQL role/database and listens for HTTP only on `127.0.0.1:3000` behind Nginx.

### Consequences

- no public PostgreSQL listener;
- no duplicate reverse proxy;
- no second database server;
- Forgejo's local HTTP port remains inaccessible from the public network.

---

## D-016 — Git SSH uses the existing OpenSSH server on port 22

**Status:** Accepted  
**Date:** 2026-10-22

### Decision

Do not start Forgejo's built-in SSH server in V1.

Use the existing host OpenSSH service on port 22 and a dedicated Forgejo `git` operating-system account whose authorized keys are managed by Forgejo.

### Why

This preserves standard Git SSH clone URLs without opening another public port or changing the host administration SSH port.

---

## D-017 — Runner jobs use rootless Podman

**Status:** Accepted  
**Date:** 2026-10-22

### Decision

Run Forgejo Actions jobs through a dedicated Forgejo Runner account backed by rootless Podman containers.

Generic workflows must not execute directly on the host.

### Concurrency transition

While the existing GitHub Actions runner remains active, keep Forgejo `runner.capacity = 1`.

After the GitHub runner is retired and host load is validated, raise the target to `runner.capacity = 2`.

---

## D-018 — `devos-forge` is the pilot repository

**Status:** Accepted  
**Date:** 2026-10-22

### Decision

Use this repository as the first end-to-end migration pilot.

### Why

The forge should prove that it can host and operate its own infrastructure repository before production applications become dependent on it.

The pilot must pass clone, branch, push, PR, Actions, merge, backup and restore checks before broader migration.

---

## D-019 — Candidate V1 hostname is `git.criandofacil.com.br`

**Status:** Accepted for V1 unless DNS ownership/operations expose a blocker  
**Date:** 2026-10-22

### Decision

Use `git.criandofacil.com.br` as the default V1 public hostname.

Nginx and TLS configuration happen only after the local Forgejo bootstrap passes and DNS is pointed correctly.
