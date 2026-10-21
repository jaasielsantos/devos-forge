# DevOS Forge — Project State

## Status

**Phase:** 0 — Foundation and design  
**Implementation:** not deployed yet  
**Primary objective:** establish a private Forgejo-based forge on our VPS and validate the complete Git + CI + runner lifecycle without GitHub dependency.

## Current thesis

DevOS Forge should begin as infrastructure ownership, not as a custom forge rewrite.

The near-term system is:

```text
Users / DevOS / Agents
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

See `docs/DECISIONS.md` for durable decision records.

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

- [ ] production architecture agreed;
- [ ] deployment topology documented;
- [ ] security baseline documented;
- [ ] backup and restore strategy documented;
- [ ] migration plan documented;
- [ ] first deployment plan ready to execute;
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
open pull request
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
- replacing Forgejo internals prematurely;
- designing agent-native features before the base forge is operational.

## Immediate next action

Produce the deployable infrastructure baseline for Phase 1:

1. define the final VPS topology;
2. choose ingress/reverse proxy integration;
3. define persistent volumes and backup paths;
4. define Forgejo + PostgreSQL + Runner deployment;
5. validate disaster-recovery assumptions;
6. deploy a pilot instance;
7. migrate one real repository and run the complete lifecycle.

## Checkpoint rule

Update this file when a meaningful phase, decision, deployment state, blocker, or next action changes. Avoid turning it into a chronological activity log.