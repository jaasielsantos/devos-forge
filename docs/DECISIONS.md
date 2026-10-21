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