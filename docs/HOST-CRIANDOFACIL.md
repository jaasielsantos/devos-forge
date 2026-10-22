# DevOS Forge — Host Baseline: `criandofacil-vps`

## Purpose

Record the selected V1 host and the evidence collected from the completed read-only inspection.

## Selected host

- SSH alias: `criandofacil-vps`
- hostname: `srv1805473`
- role: DevOS Forge V1 single-host runtime
- OS: Ubuntu 24.04 LTS family
- virtualization: KVM
- architecture: x86-64

## Capacity snapshot

Observed during the directed preflight:

- 1 vCPU;
- ~3.8 GiB RAM;
- ~3.2 GiB memory available at capture time;
- 2 GiB swap;
- ~32 GiB free on `/`;
- very low host load.

## Existing infrastructure confirmed

### Nginx / TLS

- Nginx 1.24 active;
- current configuration syntax valid;
- ports 80/443 already bound;
- existing Criando Fácil and Doxa Upload virtual hosts;
- Certbot installed with active renewal timer.

Decision: reuse existing Nginx and Certbot model.

### PostgreSQL

- PostgreSQL 16.15 active;
- cluster `16/main` online;
- listens only on loopback;
- only default `postgres` database/role existed at inspection time.

Decision: create dedicated `forgejo` role/database in the existing cluster.

### SSH / firewall

- OpenSSH active on port 22;
- UFW active;
- inbound 22/80/443 allowed;
- root SSH login disabled;
- public-key authentication enabled.

Decision: reuse system OpenSSH port 22 for Git SSH; do not expose a separate Forgejo SSH port in V1.

### Runner/runtime

- existing GitHub Actions runner active under `cf-gh-runner`;
- Podman installed;
- no Docker installation required for the selected V1 design.

Decision: dedicated Forgejo Runner account with rootless Podman job isolation.

Concurrency transition:

```text
GitHub runner active     -> Forgejo capacity 1
GitHub runner retired    -> validate and target capacity 2
```

### Storage

Candidate Forgejo paths are free and small relative to available disk.

Locked paths are documented in `docs/RUNBOOK-V1.md`.

### Backup

Existing host backup timers prove systemd-timer patterns are already used. DevOS Forge gets its own backup procedure after the pilot server/runner lifecycle works.

An off-host copy remains mandatory before broad migration.

## Result

The directed preflight is complete. No blocker was found for the selected one-VPS V1 architecture.

The implementation now proceeds through:

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`

Historical raw command output is intentionally not committed because it contains unnecessary host detail and the current GitHub repository is public.
