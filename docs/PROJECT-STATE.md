# DevOS Forge — Project State

## Status

**Phase:** 1 — Ingress complete / Git SSH validation  
**Implementation:** Stage A and Stage B complete; Stage C preflight next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Validate Forgejo Git-over-SSH through the existing system OpenSSH service on port 22, then register Forgejo Runner with rootless Podman, migrate the `devos-forge` pilot, and prove backup/restore.

## Locked V1 topology

```text
Chat / CLI / Git / SSH / API
          |
          v
Nginx :443 + TLS
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

Git SSH uses the existing OpenSSH daemon on port 22 with the dedicated OS user `git`. V1 remains on one VPS.

## Locked deployment decisions

- native Forgejo binary + systemd;
- Forgejo 15 LTS, pinned to 15.0.10 for bootstrap;
- reuse existing Nginx and Certbot;
- reuse existing PostgreSQL 16 with dedicated `forgejo` DB/role;
- Forgejo HTTP on `127.0.0.1:3000` only;
- public hostname `git.criandofacil.com.br`;
- public HTTPS through Nginx on 443;
- system OpenSSH port 22 for Git SSH;
- dedicated Forgejo Runner + rootless Podman;
- runner capacity 1 while GitHub runner coexists;
- target runner capacity 2 after GitHub runner retirement and load validation;
- no custom V1 UI;
- `devos-forge` is the pilot repository.

## Stage A — completed

Validated:

- `forgejo.service` active and enabled;
- Forgejo listens only on `127.0.0.1:3000`;
- `/api/healthz` returns `status: pass`;
- cache and PostgreSQL health pass;
- initial local administrator created.

The first apply exposed a missing `oauth2.JWT_SECRET`. The durable bootstrap now pre-generates it while preserving `/etc/forgejo/app.ini` as `root:git 0640`.

## Stage B — completed

Validated:

- dedicated Nginx vhost installed for `git.criandofacil.com.br`;
- upstream remains `http://127.0.0.1:3000`;
- DNS points the hostname to the selected VPS;
- Certbot issued TLS and configured HTTPS redirect;
- `nginx -t` passes;
- `https://git.criandofacil.com.br/api/healthz` returns `status: pass`.

Existing unrelated `doxa-upload` Nginx warnings remain non-blocking and unchanged.

## Stage C — Git SSH

Forgejo uses system OpenSSH rather than its built-in SSH server.

Official Forgejo behavior for this model:

- `START_SSH_SERVER = false`;
- `SSH_PORT = 22` controls the clone URL;
- when the internal SSH server is disabled, Forgejo can manage the dedicated `git` user's `authorized_keys` file;
- `forgejo admin regenerate keys` can rebuild that file from keys stored in Forgejo.

A read-only preflight is now available:

```text
scripts/stage-c-ssh-preflight.sh
```

It validates HTTPS health, sshd effective settings, port 22, the `git` OS account, `.ssh` permissions, non-secret Forgejo SSH configuration, and an `authorized_keys` summary. It does not add keys or change sshd.

## Executable artifacts

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`
- `scripts/repair-stage-a-oauth2-secret.sh`
- `scripts/stage-b-nginx.sh`
- `scripts/stage-c-ssh-preflight.sh`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/DEPLOYMENT.md`

## Security gate

The GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, certificate private keys, or private SSH keys.

Client SSH access must be granted only by adding an explicitly intended **public** key to the Forgejo account. Do not reuse or copy arbitrary host keys merely because they already exist on the VPS.

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[ ] Stage C  Git SSH validation
[ ] Stage D  Forgejo Runner + Podman
[ ] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Run the read-only Stage C preflight on `criandofacil-vps`:

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/stage-c-ssh-preflight.sh | sudo bash
```

After that evidence is reviewed, add one intended client public SSH key to the `jaasielsantos` Forgejo account and validate `ssh -T git@git.criandofacil.com.br` before testing clone/push.
