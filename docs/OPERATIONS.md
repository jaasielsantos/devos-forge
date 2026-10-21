# DevOS Forge — Operations

## Objective

Self-hosting only creates independence if the service can be operated, upgraded, backed up, and recovered predictably.

This document defines the minimum operational baseline.

## Service inventory

Initial logical services:

- Forgejo application;
- PostgreSQL;
- reverse proxy / TLS layer;
- Forgejo Runner(s);
- backup process;
- monitoring/health checks.

The exact deployment units may change, but each responsibility must remain visible.

## Health model

A healthy forge means more than the web page returning HTTP 200.

Minimum checks:

- [ ] HTTPS endpoint responds;
- [ ] login works;
- [ ] database connectivity works;
- [ ] repository page can be read;
- [ ] SSH Git endpoint accepts expected authentication;
- [ ] test clone works;
- [ ] runner is registered and available;
- [ ] scheduled backup completed recently;
- [ ] storage has safe free capacity;
- [ ] TLS certificate is valid;
- [ ] recent error logs show no persistent failure loop.

## Backup scope

Back up all state required to reconstruct the service:

### Git/Forge data

- repository data;
- attachments/assets that matter;
- package/registry data if enabled;
- Forgejo configuration.

### Database

- PostgreSQL logical backup;
- database role/schema information required for restore.

### Infrastructure

- deployment manifests;
- environment variable templates without secret values;
- reverse-proxy configuration;
- runner configuration;
- documented secret inventory and secure recovery source.

## Backup topology

Minimum desired model:

```text
Primary VPS
   |
   +--> local backup set / snapshot
   |
   `--> independent offsite copy
```

An offsite copy must not depend on the same single storage failure domain as the primary VPS.

## Backup policy

Exact retention is `TBD` before production.

The policy must eventually define:

- backup frequency;
- retention tiers;
- encryption policy;
- offsite destination;
- integrity verification;
- alerting on failed backups;
- deletion lifecycle.

## Restore procedure

The documented restore path must support a clean replacement host.

High-level sequence:

```text
provision replacement VPS
        ->
install runtime prerequisites
        ->
restore deployment configuration
        ->
restore PostgreSQL
        ->
restore Forgejo repositories/data
        ->
restore required secrets securely
        ->
start services
        ->
validate web/API/SSH
        ->
register/restore runner capability
        ->
perform clone + push + CI smoke test
```

A backup is not considered validated until a restore has been rehearsed.

## Recovery objectives

`RPO` and `RTO` are intentionally not invented yet.

Before production migration, decide:

- acceptable amount of Git/metadata loss (`RPO`);
- acceptable service recovery time (`RTO`).

These values should drive backup frequency and recovery automation.

## Upgrade policy

For Forgejo, PostgreSQL, runner, and supporting infrastructure:

1. read release notes for material changes;
2. confirm backup health;
3. capture current versions;
4. upgrade one layer at a time where practical;
5. run smoke tests;
6. verify runner execution;
7. verify backup still works;
8. document meaningful compatibility changes.

Avoid unpinned surprise upgrades in production.

## Smoke test

After deploy, restore, or major upgrade:

```text
login
-> open repository
-> clone
-> create branch
-> commit
-> push
-> open PR
-> trigger CI
-> runner succeeds
-> merge
```

A reduced automated variant should eventually be implemented.

## Capacity management

Monitor at least:

- disk use;
- repository growth;
- database growth;
- package/artifact growth;
- backup size;
- Docker image/cache growth;
- runner work directory growth;
- CPU and memory saturation during CI.

For a small private forge, capacity exhaustion is more likely than distributed-scale problems.

## Incident classes

### Forge web unavailable

Check proxy, application health, database, disk, and logs.

### Git SSH unavailable

Check SSH endpoint exposure, Forgejo SSH configuration, keys, firewall, and port conflicts.

### Runner unavailable

Development should still allow Git operations. CI may queue until runner capacity returns.

### Database failure

Treat as a service outage. Do not initialize a fresh empty database over existing repository data without recovery analysis.

### VPS loss

Activate clean-host restore procedure from offsite backup.

### External GitHub outage

Once migration is complete, this should not be an internal development incident.

## Operational ownership principle

Every critical component must answer three questions:

1. How do we know it is healthy?
2. How do we back it up?
3. How do we restore it?

If one answer is missing, the component is not production-ready.