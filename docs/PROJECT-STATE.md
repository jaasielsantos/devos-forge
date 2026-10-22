# DevOS Forge — Project State

## Status

**Phase:** 0 — Foundation and design  
**Implementation:** not deployed yet  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Primary objective:** convert the selected host baseline into an executable Forgejo + runner deployment and validate the complete Git + CI lifecycle without GitHub dependency.

## Current thesis

DevOS Forge should begin as infrastructure ownership, not as a custom forge rewrite.

The near-term system is:

```text
Human / DevOS / Agent
        |
        v
Chat / CLI / Git / SSH / API
        |
        v
  DevOS Forge endpoint
        |
        v
     Forgejo
        |
   +----+-------------------+
   |                        |
   v                        v
Git repositories        Forgejo Actions
                            |
                            v
                    Self-hosted runner(s)
```

The initial operating model is headless-first. No custom DevOS Forge UI will be built in V1. Forgejo's native web interface remains available only as an administrative, diagnostic, and manual-review fallback.

The long-term differentiator belongs above the mature Git layer:

```text
human intent
  -> PDS
  -> explicit choices
  -> PBI
  -> PBP
  -> agent execution
  -> evidence / policy
  -> Git history
```

## Confirmed decisions

- Use Git as the source-control substrate.
- Use Forgejo as the initial forge implementation.
- Host the V1 forge on `criandofacil-vps` (`srv1805473`).
- Keep V1 on one VPS rather than splitting control and execution across two hosts.
- Reuse the host's existing Nginx/PostgreSQL infrastructure where appropriate.
- Use self-hosted runners under our control.
- Design the runner layer for up to two concurrent jobs, subject to resource validation.
- Keep the second VPS out of the initial runtime; reserve it for future runner capacity, backup, or disaster recovery if needed.
- Keep the initial scope private and sized for our own projects, not public internet scale.
- Preserve a provider abstraction between DevOS and the forge implementation.
- Avoid building a custom forge engine until real operational evidence justifies it.
- Migrate away from GitHub incrementally, using a pilot repository first.
- Operate V1 headless-first through Chat/CLI/Git/SSH/API; do not build a custom UI.
- Keep Forgejo's native UI available as fallback rather than as the primary interaction surface.

See `docs/DECISIONS.md` for durable decision records.

## VPS evidence collected

Both available VPS hosts were inspected read-only.

### Selected: `criandofacil-vps` / `srv1805473`

Observed baseline:

- Ubuntu 24.04 LTS family;
- 1 vCPU;
- ~3.8 GiB RAM with ~3.2 GiB available at capture time;
- 2 GiB swap;
- ~34 GiB free disk;
- active Nginx on ports 80/443;
- active PostgreSQL 16 on loopback;
- Certbot timer present;
- existing application services already using local ports;
- evidence of an existing GitHub Actions runner account/home;
- Docker/Compose not present during the initial inspection.

### Deferred: second VPS / `srv1979180`

The second VPS already has Docker/Compose and runner-oriented infrastructure, but using both hosts in V1 was intentionally rejected to minimize distributed-system complexity.

It remains available as an expansion target if real usage justifies it.

## Foundation pack completed

The repository now contains:

- `00_PROMPT_ZERO.md`;
- `README.md`;
- `docs/ARCHITECTURE.md`;
- `docs/DECISIONS.md`;
- `docs/ROADMAP.md`;
- `docs/PREFLIGHT.md`;
- `docs/HOST-CRIANDOFACIL.md`;
- `docs/DEPLOYMENT.md`;
- `docs/MIGRATION.md`;
- `docs/OPERATIONS.md`;
- `docs/SECURITY.md`.

These documents establish the project boundary, phased strategy, security posture, recovery requirement, migration model, VPS discovery procedure, selected host baseline, and future agent-native direction.

## Open decisions

These must be resolved before production deployment:

- [ ] final hostname/domain for the forge;
- [x] V1 host selected: `criandofacil-vps`;
- [x] V1 topology selected: one VPS first;
- [x] reverse proxy family selected: reuse existing Nginx unless directed inspection exposes a blocker;
- [x] database family selected: reuse existing PostgreSQL 16 with a dedicated Forgejo DB/user unless directed inspection exposes a blocker;
- [ ] Forgejo packaging: native binary/systemd vs container;
- [ ] exact Forgejo localhost web port;
- [ ] Git-over-SSH exposure strategy;
- [ ] storage layout and capacity allocation;
- [ ] offsite backup destination;
- [ ] backup retention policy;
- [ ] runner runtime/isolation model;
- [ ] exact initial runner concurrency after validation;
- [ ] authentication policy and initial users;
- [ ] mail/notification strategy, if required;
- [ ] first pilot repository;
- [ ] GitHub mirror policy during transition.

## Phase 0 exit criteria

Phase 0 is complete when we have:

- [x] initial production topology selected;
- [x] deployment topology baseline documented;
- [x] security baseline documented;
- [x] backup and restore strategy baseline documented;
- [x] migration plan documented;
- [x] read-only VPS preflight procedure documented;
- [x] both candidate VPS hosts inspected and compared;
- [x] V1 host selected;
- [x] initial interaction model decided: headless-first, no custom V1 UI;
- [ ] directed `criandofacil-vps` inspection completed;
- [ ] host-specific deployment runbook ready to execute;
- [ ] one pilot repository selected.

## Phase 1 target

Deploy Forgejo and complete this circuit entirely on our infrastructure:

```text
create/import repository
        ->
clone via SSH
        ->
create branch
        ->
push
        ->
open pull request through API/automation when practical
        ->
trigger CI
        ->
execute on self-hosted runner
        ->
merge
        ->
release or deploy
```

## Non-goals right now

- competing with GitHub as a public platform;
- supporting massive multi-tenant scale;
- building our own Git protocol implementation;
- recreating social features;
- building a marketplace;
- building or customizing a dedicated DevOS Forge web UI;
- splitting V1 across multiple VPS hosts without demonstrated need;
- replacing Forgejo internals prematurely;
- designing agent-native features before the base forge is operational.

## Immediate next action

Run the directed read-only inspection in `docs/HOST-CRIANDOFACIL.md` on:

```bash
ssh criandofacil-vps
```

The directed inspection resolves only the remaining host-specific questions: Nginx integration, PostgreSQL integration, Forgejo packaging, Git SSH, existing runner topology, runner isolation, storage, and backup integration.

After that evidence is reviewed, convert `docs/DEPLOYMENT.md` into the executable V1 runbook and begin installation.

## Checkpoint rule

Update this file when a meaningful phase, decision, deployment state, blocker, or next action changes. Avoid turning it into a chronological activity log.
