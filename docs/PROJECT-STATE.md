# DevOS Forge — Project State

## Status

**Phase:** 0 — Foundation and design  
**Implementation:** not deployed yet  
**Primary objective:** establish a private Forgejo-based forge on our VPS and validate the complete Git + CI + runner lifecycle without GitHub dependency.

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
                       Our Runner(s)
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
- Host the forge in our own VPS infrastructure.
- Use self-hosted runners under our control.
- Keep the initial scope private and sized for our own projects, not public internet scale.
- Preserve a provider abstraction between DevOS and the forge implementation.
- Avoid building a custom forge engine until real operational evidence justifies it.
- Migrate away from GitHub incrementally, using a pilot repository first.
- Operate V1 headless-first through Chat/CLI/Git/SSH/API; do not build a custom UI.
- Keep Forgejo's native UI available as fallback rather than as the primary interaction surface.

See `docs/DECISIONS.md` for durable decision records.

## Foundation pack completed

The repository now contains:

- `00_PROMPT_ZERO.md`;
- `README.md`;
- `docs/ARCHITECTURE.md`;
- `docs/DECISIONS.md`;
- `docs/ROADMAP.md`;
- `docs/PREFLIGHT.md`;
- `docs/DEPLOYMENT.md`;
- `docs/MIGRATION.md`;
- `docs/OPERATIONS.md`;
- `docs/SECURITY.md`.

These documents establish the project boundary, phased strategy, security posture, recovery requirement, migration model, VPS discovery procedure, and future agent-native direction.

## Open decisions

These must be resolved before production deployment:

- [ ] final hostname/domain for the forge;
- [ ] reverse proxy implementation compatible with the existing VPS stack;
- [ ] PostgreSQL deployment details;
- [ ] storage layout and capacity allocation;
- [ ] offsite backup destination;
- [ ] backup retention policy;
- [ ] runner topology and isolation model;
- [ ] authentication policy and initial users;
- [ ] mail/notification strategy, if required;
- [ ] first pilot repository;
- [ ] GitHub mirror policy during transition.

## Phase 0 exit criteria

Phase 0 is complete when we have:

- [ ] production architecture agreed after VPS preflight;
- [x] deployment topology baseline documented;
- [x] security baseline documented;
- [x] backup and restore strategy baseline documented;
- [x] migration plan documented;
- [x] read-only VPS preflight procedure documented;
- [x] initial interaction model decided: headless-first, no custom V1 UI;
- [ ] VPS preflight evidence collected and analyzed;
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
- replacing Forgejo internals prematurely;
- designing agent-native features before the base forge is operational.

## Immediate next action

**Complete the directed inspection of `criandofacil-vps` and convert the generic deployment baseline into a host-specific runbook.**

The selected initial topology is intentionally simple: one VPS first. The second VPS remains outside the initial runtime and can later be used for backup, disaster recovery, or extra runner capacity if real usage justifies it.

After evidence is collected, resolve the open deployment choices and generate the host-specific ingress/Forgejo/PostgreSQL/runner/backup/restore runbook.

## Checkpoint rule

Update this file when a meaningful phase, decision, deployment state, blocker, or next action changes. Avoid turning it into a chronological activity log.