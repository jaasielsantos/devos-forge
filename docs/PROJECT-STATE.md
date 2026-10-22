# DevOS Forge — Project State

## Status

**Phase:** 1 — Git SSH validation  
**Implementation:** Stage A and Stage B complete; Stage C authentication proven; clone/push smoke next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Complete Stage C by proving a real Git clone/push over SSH through the existing system OpenSSH service on port 22. After that, move to Forgejo Runner + rootless Podman, migrate the `devos-forge` pilot, and prove backup/restore.

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

A later SSH test exposed that the configured repository root did not yet exist. The bootstrap now explicitly creates:

```text
/var/lib/forgejo/data/forgejo-repositories
```

with `git:git` ownership before first startup.

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

### C1 — preflight COMPLETE

Validated on the target host:

- HTTPS health = pass;
- `forgejo.service` active/enabled;
- OpenSSH active and listening on IPv4/IPv6 port 22;
- `PubkeyAuthentication yes`;
- expected `AuthorizedKeysFile`;
- `StrictModes yes`;
- `PermitRootLogin no`;
- dedicated `git` account exists with home `/var/lib/forgejo`;
- `/var/lib/forgejo/.ssh` ownership and modes are correct;
- Forgejo SSH configuration points to `git.criandofacil.com.br:22` with built-in SSH disabled;
- DNS resolves to the selected VPS.

### C2 — client key + authentication COMPLETE

A dedicated Ed25519 key named `devos-forge` was enrolled in the `jaasielsantos` Forgejo account.

The host fingerprint was verified before trust was accepted by the client.

`ssh -T git@git.criandofacil.com.br` now returns successful Forgejo authentication for `jaasielsantos` and correctly refuses shell access. The earlier `Unable to access repository path` message disappeared after creating the configured repository root.

### C3 — next gate: real Git operation

Stage C completes only after a real SSH clone and push succeed against a Forgejo repository.

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

Client SSH access is granted only through explicitly intended public keys stored in Forgejo.

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[~] Stage C  SSH auth proven; clone/push smoke pending
[ ] Stage D  Forgejo Runner + Podman
[ ] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Create a small Forgejo smoke repository and prove:

```text
SSH clone -> local commit -> SSH push
```

Do not proceed to Forgejo Runner until a real clone/push operation is confirmed.
