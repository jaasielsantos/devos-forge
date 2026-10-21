# DevOS Forge — Roadmap

## Guiding rule

Each phase must produce a usable capability before the next layer is added.

The roadmap deliberately separates **infrastructure independence** from **agent-native differentiation**.

---

## Phase 0 — Foundation and design

**Goal:** define the operating model before touching production infrastructure.

### Deliverables

- [x] project mission;
- [x] Prompt Zero;
- [x] architecture baseline;
- [x] foundational decisions;
- [x] migration strategy baseline;
- [x] security baseline;
- [x] operations/recovery baseline;
- [ ] final deployment topology;
- [ ] domain/hostname choice;
- [ ] existing VPS ingress compatibility check;
- [ ] pilot repository selection.

### Exit condition

We can describe exactly what will be deployed, where data lives, how CI runs, and how the service is restored.

---

## Phase 1 — Forgejo bootstrap

**Goal:** run a private forge on our VPS.

### Deliverables

- [ ] Forgejo deployed;
- [ ] PostgreSQL deployed;
- [ ] persistent storage mounted;
- [ ] HTTPS endpoint working;
- [ ] SSH Git working;
- [ ] admin and user access configured;
- [ ] registration policy locked down;
- [ ] first self-hosted runner online;
- [ ] basic monitoring/health checks;
- [ ] backup job running.

### Acceptance test

A new private repository can be created, cloned, committed to, pushed, and viewed without using GitHub.

---

## Phase 2 — Complete development loop

**Goal:** prove the full workflow on one real project.

### Deliverables

- [ ] pilot repository imported;
- [ ] branches and pull requests validated;
- [ ] review/merge flow validated;
- [ ] Forgejo Actions workflow working;
- [ ] self-hosted runner executes tests/build;
- [ ] secrets injected safely;
- [ ] release or deployment path validated;
- [ ] API and webhook access validated.

### Acceptance test

```text
clone
-> branch
-> commit
-> push
-> PR
-> CI
-> runner
-> merge
-> release/deploy
```

The entire circuit works with GitHub unavailable.

---

## Phase 3 — Recovery and operational hardening

**Goal:** prove that self-hosting is recoverable, not merely functional.

### Deliverables

- [ ] database backup verified;
- [ ] repository backup verified;
- [ ] configuration backup verified;
- [ ] offsite copy verified;
- [ ] restore on clean environment rehearsed;
- [ ] recovery time observed and documented;
- [ ] patch/upgrade procedure documented;
- [ ] runner isolation reviewed;
- [ ] logs and disk-growth behavior reviewed.

### Acceptance test

The forge can be recreated on replacement infrastructure from documented manifests and backups.

---

## Phase 4 — Make Forgejo primary

**Goal:** move daily development ownership to our forge.

### Deliverables

- [ ] selected active repositories moved;
- [ ] local Git remotes updated;
- [ ] CI moved to Forgejo Actions where appropriate;
- [ ] deployment integrations updated;
- [ ] GitHub changed from primary to mirror/secondary;
- [ ] documentation updated to reference DevOS Forge as source of truth.

### Acceptance test

Normal development no longer requires GitHub availability.

---

## Phase 5 — DevOS forge adapter

**Goal:** stop treating the forge as a human-only UI and expose it as a first-class DevOS capability.

### Deliverables

- [ ] define minimal `ForgeProvider` contract;
- [ ] implement Forgejo adapter;
- [ ] repository discovery;
- [ ] issue/PR operations;
- [ ] branch/commit/diff operations;
- [ ] workflow dispatch/status;
- [ ] webhook/event ingestion;
- [ ] deterministic error model.

### Acceptance test

DevOS can inspect and operate a project through the provider contract without embedding Forgejo-specific behavior into core logic.

---

## Phase 6 — Agent-native metadata

**Goal:** connect Git history to DevOS intent and execution.

### Candidate capabilities

- [ ] PDS links;
- [ ] explicit-choice records;
- [ ] PBI links;
- [ ] PBP links;
- [ ] execution IDs;
- [ ] agent identity;
- [ ] policy evaluations;
- [ ] test evidence;
- [ ] provenance chain;
- [ ] commit/PR/release lineage.

### Target model

```text
Human Intent
     |
     v
PDS + choices
     |
     v
PBI
     |
     v
PBP
     |
     v
Execution
     |
     v
Evidence / Policy
     |
     v
Commit / PR / Merge / Release
```

---

## Phase 7 — Native DevOS Forge evaluation

**Goal:** decide whether any custom forge engine component is justified.

This phase is an evaluation, not a commitment to rewrite Forgejo.

### Questions

- What Forgejo limitations are actually blocking us?
- Can the limitation be solved in the DevOS layer?
- Can it be solved by an adapter, plugin, webhook, sidecar, or extension?
- Is replacing a component cheaper than maintaining the integration?
- Would a native component materially improve agent execution, provenance, determinism, or security?

### Possible outcomes

```text
A) Forgejo remains the substrate indefinitely
B) selected components become DevOS-native
C) a custom forge engine becomes justified
```

All three are valid outcomes.

---

## Explicitly deferred

Until evidence changes the decision, do not prioritize:

- public multi-tenant hosting;
- social coding features;
- marketplace;
- billing;
- public discovery/search;
- massive horizontal scaling;
- custom Git protocol;
- a feature-for-feature GitHub clone.