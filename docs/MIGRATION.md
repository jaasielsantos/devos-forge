# DevOS Forge — Migration Strategy

## Objective

Move operational ownership from GitHub to DevOS Forge without creating an all-or-nothing migration event.

The migration must prove three things independently:

1. Git data is complete;
2. development workflows work;
3. CI/deployment works on our infrastructure.

## Migration stages

### Stage A — Validation

```text
GitHub = primary
Forgejo = secondary/test
```

Actions:

- deploy Forgejo;
- create/import one pilot repository;
- validate clone/fetch/pull/push;
- validate branches and pull requests;
- validate Actions and runner;
- validate API/webhooks;
- validate backup and restore.

No project should depend on the new forge yet.

### Stage B — Dual presence

```text
Forgejo = candidate primary
GitHub = secondary/mirror
```

Actions:

- set Forgejo as the main remote for the pilot project;
- keep GitHub synchronized where useful;
- run daily development on Forgejo;
- exercise failure/recovery procedures;
- observe missing features and friction.

The purpose of this stage is to learn from real usage before broad migration.

### Stage C — Forgejo primary

```text
Forgejo = source of truth
GitHub = mirror / publication target / backup convenience
```

Actions:

- move selected active repositories;
- update local remotes;
- move CI/CD;
- update deployment hooks;
- update project documentation;
- stop treating GitHub Issues/PRs as authoritative for migrated projects.

### Stage D — GitHub optional

```text
DevOS Forge = operational dependency
GitHub = optional external integration
```

Possible uses for GitHub after migration:

- public mirrors;
- open-source distribution;
- external collaboration;
- additional remote copy;
- projects that specifically require GitHub ecosystem integration.

GitHub availability must no longer determine whether private development can continue.

## Pilot cutover discipline

For the `devos-forge` pilot, the first copy is created as a Forgejo pull mirror while GitHub remains primary. Exact branch/tag/object parity must be proven before leaving mirror mode.

After converting the validated pull mirror to a regular Forgejo repository, perform one final intentional fast-forward from the still-primary GitHub `main` into Forgejo `main` before creating any Forgejo-native branch. This captures documentation or other commits made on GitHub after the parity snapshot.

After that final catch-up:

- avoid further GitHub writes during the Forgejo-native lifecycle proof;
- create the pilot branch only on Forgejo;
- prove Pull Request, Actions, review, and merge on Forgejo;
- only then establish the GitHub transition mirror in the Forgejo -> GitHub direction.

This prevents accidental dual-primary divergence during the handoff.

## Repository migration checklist

For each repository:

- [ ] create/import repository in Forgejo;
- [ ] verify all branches;
- [ ] verify all tags;
- [ ] verify full commit history;
- [ ] verify LFS objects if used;
- [ ] verify releases/artifacts that matter;
- [ ] configure access permissions;
- [ ] configure deploy keys/tokens as needed;
- [ ] migrate required CI secrets securely;
- [ ] migrate/adapt workflows;
- [ ] validate runner labels;
- [ ] validate webhooks;
- [ ] validate deployment;
- [ ] change developer/agent remotes;
- [ ] define GitHub mirror behavior;
- [ ] mark Forgejo as source of truth in project docs.

## Git remote model

During transition, a local repository may temporarily use both endpoints:

```text
origin  -> DevOS Forge
mirror  -> GitHub
```

The exact push policy must be explicit. Avoid silent bidirectional synchronization that can create conflicting sources of truth.

## What must not be assumed migratable automatically

Git objects are portable, but forge metadata is not necessarily identical across platforms.

Review explicitly:

- issues;
- pull requests;
- review comments;
- labels;
- milestones;
- Actions secrets;
- workflow semantics;
- release assets;
- package registries;
- branch/ruleset protections;
- webhook integrations;
- deploy keys;
- external app integrations.

The migration goal is functional continuity, not perfect historical replication of every GitHub feature.

## Rollback

Until a repository passes its migration acceptance test, GitHub should remain usable as a fallback.

Rollback means restoring the previous primary remote/workflow, not attempting emergency data reconstruction.

## Migration acceptance test

A repository is considered successfully migrated when:

```text
1. fresh clone from DevOS Forge works
2. complete expected Git history is present
3. push works
4. PR/review/merge works
5. CI executes on our runner
6. required secrets are available securely
7. deployment/release works
8. backup covers the repository and its forge metadata
9. restore procedure has a valid path
10. GitHub can be unavailable without blocking normal development
```

## Principle

Migration is complete when **dependency** moved, not merely when a copy of the repository exists elsewhere.
