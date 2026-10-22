# DevOS Forge — Project State

## Status

**Phase:** 1 — Bootstrap / ingress  
**Implementation:** Stage A complete; Stage B Nginx HTTP dry-run next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Expose the healthy local Forgejo instance through the existing Nginx stack, then complete DNS/TLS, validate Git SSH, register Forgejo Runner with rootless Podman, migrate the `devos-forge` pilot, and prove backup/restore.

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
127.0.0.1:3000
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

## Locked deployment decisions

- native Forgejo binary + systemd;
- Forgejo 15 LTS, pinned to 15.0.10 for bootstrap;
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

Durable decisions are captured in `docs/DECISIONS.md` and summarized in `docs/ADR-001-V1-DEPLOYMENT.md`.

## Stage A — completed

Stage A is now healthy on `criandofacil-vps`.

Validated evidence:

- `forgejo.service` is active and enabled;
- Forgejo is listening only on `127.0.0.1:3000`;
- `GET /api/healthz` returns `status: pass`;
- cache health passes;
- PostgreSQL health passes;
- the initial local administrator was created by the repair/completion script;
- Nginx, DNS/TLS, firewall, sshd, the existing GitHub runner, and Forgejo Runner remain untouched by Stage A.

### Stage A incident and durable fix

The first apply failed because Forgejo attempted to persist a missing `oauth2.JWT_SECRET` into the intentionally root-owned `/etc/forgejo/app.ini`.

The durable fix is now in source:

- `scripts/bootstrap-server-v1.sh` pre-generates and writes `[oauth2].JWT_SECRET` before startup;
- config permissions remain `root:git 0640`;
- `scripts/repair-stage-a-oauth2-secret.sh` repaired the already-created partial installation without weakening permissions or regenerating database credentials.

## Stage B — Nginx + DNS + TLS

Stage B is intentionally split:

```text
B1  install HTTP Nginx reverse proxy
B2  create/verify DNS for git.criandofacil.com.br
B3  request TLS with existing Certbot workflow
```

The repository contains a guarded B1 script:

```text
scripts/stage-b-nginx.sh
```

It is dry-run by default and follows the Forgejo reverse-proxy requirements, including `merge_slashes off`, proxy headers, and a 512 MiB body-size ceiling.

## Executable artifacts

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`
- `scripts/repair-stage-a-oauth2-secret.sh`
- `scripts/stage-b-nginx.sh`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/DEPLOYMENT.md`

## Security gate

The current GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, or certificate private keys. Runtime secrets stay on the VPS with restricted permissions.

The Forgejo web listener must remain loopback-only. Public access is through Nginx on ports 80/443.

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[ ] Stage B  DNS + Nginx + TLS
[ ] Stage C  Git SSH validation
[ ] Stage D  Forgejo Runner + Podman
[ ] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Preview Stage B1 on `criandofacil-vps`:

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/stage-b-nginx.sh | sudo bash
```

If the dry-run is clean, apply explicitly with `--apply`. Do not request a certificate until DNS for `git.criandofacil.com.br` resolves to the selected VPS.
