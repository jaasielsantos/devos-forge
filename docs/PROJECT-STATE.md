# DevOS Forge — Project State

## Status

**Phase:** 1 — Bootstrap  
**Implementation:** Stage A partially applied; startup repair prepared  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Repair the Stage A Forgejo startup by pre-populating `oauth2.JWT_SECRET`, verify Forgejo locally on `127.0.0.1:3000`, then advance to DNS/Nginx/TLS, Git SSH, Forgejo Runner, pilot migration, and backup/restore validation.

## Locked V1 topology

```text
Chat / CLI / Git / SSH / API
          |
          v
existing Nginx :443
          |
          v
Forgejo 15 LTS
native binary + systemd
          |
    +-----+----------------+
    |                      |
PostgreSQL 16        Forgejo Actions
(existing)                 |
                           v
                    Forgejo Runner
                           |
                           v
                    rootless Podman
```

V1 remains on one VPS. The second VPS is outside the initial runtime.

## Directed host inspection — completed

Confirmed on `criandofacil-vps`:

- Ubuntu 24.04 LTS family;
- 1 vCPU, ~3.8 GiB RAM, 2 GiB swap;
- ~32 GiB free disk at second capture;
- Nginx 1.24 active with valid configuration;
- Certbot active;
- PostgreSQL 16.15 active on loopback only;
- no pre-existing Forgejo database/role before bootstrap;
- port 3000 free before bootstrap;
- existing GitHub Actions runner active under `cf-gh-runner`;
- Podman present;
- UFW active with inbound 22/80/443;
- OpenSSH active on port 22.

## Locked deployment decisions

- native Forgejo binary + systemd;
- Forgejo 15 LTS, bootstrap pinned to 15.0.10;
- reuse existing Nginx;
- reuse existing PostgreSQL 16 with dedicated `forgejo` DB/role;
- Forgejo HTTP on `127.0.0.1:3000` only;
- candidate hostname `git.criandofacil.com.br`;
- system OpenSSH port 22 for Git SSH;
- dedicated Forgejo Runner + rootless Podman;
- runner capacity 1 while GitHub runner coexists;
- target runner capacity 2 after GitHub runner retirement and load validation;
- no custom V1 UI;
- `devos-forge` is the pilot repository.

Durable decisions are captured in `docs/DECISIONS.md` (D-014 through D-019) and summarized in `docs/ADR-001-V1-DEPLOYMENT.md`.

## Executable artifacts

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`
- `scripts/repair-stage-a-oauth2-secret.sh`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/DEPLOYMENT.md`

## Stage A evidence

### Dry-run

Dry-run executed successfully on `criandofacil-vps` with no blocker.

### First apply

The first apply successfully completed:

- Forgejo 15.0.10 download and GPG verification;
- dedicated OS user/directories;
- PostgreSQL `forgejo` role/database creation;
- Forgejo configuration and primary secret generation;
- systemd unit installation and enablement.

The service then entered a restart loop before binding `127.0.0.1:3000`.

### Root cause

The journal reported:

```text
save oauth2.JWT_SECRET failed: failed to save "/etc/forgejo/app.ini": permission denied
```

This is a bootstrap defect, not a host-capacity, network, PostgreSQL, or port conflict.

`/etc/forgejo/app.ini` is intentionally protected as `root:git 0640`. Forgejo 15 requires `oauth2.JWT_SECRET` even when OAuth2 is not otherwise being configured; when absent, Forgejo attempts to generate and persist it. The service user `git` must not be given write access to the root-owned configuration merely to satisfy this bootstrap behavior.

### Durable fix

- `scripts/bootstrap-server-v1.sh` now pre-generates `JWT_SECRET` with `forgejo generate secret JWT_SECRET` and writes it into `[oauth2]` before startup;
- config ownership remains `root:git 0640`;
- `scripts/repair-stage-a-oauth2-secret.sh` repairs the already-created partial installation without regenerating the database password or weakening permissions.

## Security gate

The current GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, or generated Forgejo secrets. Runtime secrets stay on the VPS with restricted permissions.

## Phase 0 / Stage A exit criteria

- [x] architecture/security/migration baseline documented;
- [x] both VPS hosts inspected;
- [x] V1 host and topology selected;
- [x] directed host inspection completed;
- [x] packaging, Nginx/PostgreSQL, Git SSH and runner model selected;
- [x] durable V1 host decisions documented;
- [x] pilot repository selected;
- [x] executable Stage A bootstrap prepared;
- [x] Stage A dry-run reviewed;
- [~] Stage A applied — partial installation exists;
- [x] Stage A startup failure diagnosed;
- [x] bootstrap corrected in source;
- [x] targeted repair script prepared;
- [ ] repair applied and `forgejo.service` active;
- [ ] local health endpoint validated;
- [ ] initial admin creation completed.

## Phase 1 sequence

```text
Stage A  local Forgejo bootstrap / repair
Stage B  DNS + Nginx + TLS
Stage C  Git SSH validation
Stage D  Forgejo Runner + Podman
Stage E  migrate devos-forge pilot
Stage F  backup + restore rehearsal
Stage G  Forgejo becomes source of truth
```

## Immediate next action

Run only the targeted repair on `criandofacil-vps`:

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/repair-stage-a-oauth2-secret.sh | sudo bash
```

Do not rerun the full Stage A bootstrap against the partial installation. After repair, verify `forgejo.service` and `http://127.0.0.1:3000/api/healthz` before proceeding.
