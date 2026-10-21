# DevOS Forge — Phase 1 Deployment Baseline

## Purpose

Define the deployment shape we intend to validate on the VPS before making DevOS Forge a production dependency.

This is a deployment baseline, not yet a host-specific runbook. Existing VPS services must be inspected before binding ports, changing ingress, or allocating storage.

## Preflight — inspect before changing

Before deployment, capture the current VPS state:

- operating system/version;
- Docker/Compose availability and versions;
- current reverse proxy/ingress;
- services already bound to ports 22, 80, 443 and any candidate SSH-Git port;
- firewall policy;
- DNS currently pointing at the host;
- CPU/RAM capacity;
- free disk and filesystem layout;
- current Docker networks/volumes;
- current backup mechanism;
- monitoring/logging already in place.

Do not replace a working ingress stack merely because the reference design mentions another proxy.

## Target logical stack

```text
Internet
   |
   +--> HTTPS -------------------------+
   |                                   |
   +--> Git SSH -------------------+   |
                                   |   |
                                   v   v
                              +-------------+
                              |   Forgejo   |
                              +------+------+ 
                                     |
                      +--------------+--------------+
                      |                             |
                      v                             v
                +------------+                +-----------+
                | PostgreSQL |                | Git/Data  |
                +------------+                | Volumes   |
                                              +-----------+
                                     |
                                     v
                              +-------------+
                              |   Runner    |
                              +------+------+ 
                                     |
                                     v
                              isolated jobs
```

## Container model

Preferred initial packaging:

```text
compose project: devos-forge

services/
  forgejo
  postgres
  runner

external/integrated service:
  reverse proxy (reuse existing stack when appropriate)

operational jobs:
  backup
  health/smoke checks
```

The exact Compose file should be generated only after VPS preflight so that network names, ingress labels/configuration, ports, and storage paths match reality.

## Network model

Minimum conceptual networks:

```text
public/ingress network
       |
       v
    Forgejo
       |
       +---- private app/db network ---- PostgreSQL
       |
       `---- runner control path ------- Runner
```

PostgreSQL must not require a public host port.

## Storage model

Exact host paths are `TBD` after disk inspection.

Persist at minimum:

```text
forgejo-data
postgres-data
backup-staging (if used)
```

Runner workspaces should be treated as disposable unless a deliberate cache strategy is introduced.

## Domain model

Final hostname is `TBD`.

Desired properties:

- stable DNS name;
- valid TLS;
- no dependency on a workstation or local-only DNS;
- compatible with Git HTTPS and API callbacks;
- documented SSH clone endpoint.

## SSH Git strategy

The VPS may already use port 22 for host administration.

Before choosing Forgejo SSH exposure, inspect the current SSH setup and choose one of the supported operational patterns without causing a management lockout.

The resulting clone URL should be stable and documented for all migrated repositories.

## Database deployment

Initial model:

- dedicated PostgreSQL database/user for Forgejo;
- credentials injected as secrets/environment at runtime, never committed;
- persistent volume;
- no public exposure;
- scheduled logical dump in addition to filesystem-level backup where appropriate.

## Runner deployment

Start with one general runner only if that is sufficient for the pilot.

Requirements:

- registered only to our forge;
- labels documented;
- repository jobs isolated from Forgejo itself;
- no broad production credentials by default;
- controlled Docker access strategy;
- logs available for debugging;
- straightforward re-registration on replacement infrastructure.

Add privileged/deploy-specific runner capacity only when a real workflow requires it.

## Backup bootstrap

Before migrating a real source-of-truth repository:

1. configure repository/data backup;
2. configure PostgreSQL backup;
3. copy backup offsite;
4. document secret recovery;
5. restore into a clean test environment or replacement layout;
6. run Git + web + CI smoke test.

## Deployment sequence

```text
1. VPS preflight
2. resolve open architecture choices
3. prepare DNS
4. prepare persistent storage
5. deploy PostgreSQL
6. deploy Forgejo
7. integrate reverse proxy/TLS
8. validate web/API
9. validate Git SSH/HTTPS
10. deploy/register runner
11. execute CI smoke test
12. configure backups
13. perform restore rehearsal
14. import pilot repository
15. execute full lifecycle acceptance test
```

## Full lifecycle acceptance test

The deployment is not considered successful until this sequence passes:

```text
fresh clone from DevOS Forge
        ->
create branch
        ->
commit
        ->
push
        ->
open PR
        ->
run CI on our runner
        ->
review
        ->
merge
        ->
release/deploy test
```

Then test the operational side:

```text
backup
  ->
restore
  ->
repeat smoke test
```

## Cutover rule

Do not make Forgejo primary for multiple repositories immediately after first successful startup.

A pilot repository must survive normal use and at least one verified backup/restore cycle first.

## Deliverable after preflight

Once the actual VPS is inspected, this document should be complemented by a host-specific runbook containing:

- exact domain;
- exact paths;
- exact ports;
- Compose manifests;
- ingress configuration;
- firewall changes;
- secret names;
- backup commands/jobs;
- restore commands;
- smoke-test commands;
- rollback steps.

That runbook will move Phase 0 from architecture into executable infrastructure.