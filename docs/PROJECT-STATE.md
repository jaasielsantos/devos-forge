# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo Runner validation  
**Implementation:** Stage A, Stage B, and Stage C complete; Stage D preflight clean; dedicated runner host setup next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Install and register a dedicated Forgejo Runner using rootless Podman, keep runner capacity at 1 while the GitHub runner coexists, and prove a minimal Forgejo Actions smoke workflow before migrating the `devos-forge` pilot.

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

## Stage C — Git SSH COMPLETED

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

`ssh -T git@git.criandofacil.com.br` returns successful Forgejo authentication for `jaasielsantos` and correctly refuses shell access. The earlier `Unable to access repository path` message disappeared after creating the configured repository root.

### C3 — real Git operation COMPLETE

A dedicated temporary smoke key was used from the VPS to validate a real repository operation without modifying the locked-down work PC.

Validated against Forgejo repository `jaasielsantos/ssh-smoke`:

```text
SSH authentication -> SSH clone -> local commit -> SSH push
```

The push completed successfully on `main` with commit `bcbfee5` (`test: validate Forgejo SSH push`). This proves the Git-over-SSH read/write path end to end.

The temporary VPS smoke key and local smoke credential material were removed after validation.

## Stage D — Forgejo Runner + rootless Podman ACTIVE

### D1 — preflight COMPLETE

Validated on `srv1805473`:

- Ubuntu 24.04.4 LTS, kernel 6.8;
- 1 vCPU;
- 3.8 GiB RAM with roughly 3.0 GiB available during capture;
- 2 GiB swap, unused during capture;
- root filesystem 48 GiB with roughly 32 GiB free;
- very low host load during capture;
- `git`, `curl`, `gpg`, `jq`, `podman`, `systemctl`, and `loginctl` are installed;
- Podman 4.9.3 is functional as an unprivileged user;
- Podman reports `rootless=true`;
- Podman uses cgroup v2 with the systemd cgroup manager;
- user namespaces are enabled;
- current administrative user has subordinate UID/GID ranges;
- cgroup v2 exposes CPU, memory, IO and pids controllers;
- Forgejo Actions is enabled;
- Forgejo service is active/enabled and public health passes;
- existing GitHub Actions runner remains active;
- no conflicting public listeners were introduced.

The first Podman check failed only because the shell's current working directory had been deleted during smoke cleanup. After returning to a valid directory, Podman passed normally.

### D2 — locked runner setup

- create a dedicated `forgejo-runner` OS account rather than reuse `jaasielpadilha`;
- ensure that account receives its own subordinate UID/GID mappings;
- lock password login for the service account;
- enable linger for persistent user services;
- run a rootless Podman socket for that account;
- install and verify Forgejo Runner v13.1.0;
- generate a version-matched `runner-config.yml`;
- set runner capacity to 1 while the GitHub runner coexists;
- use container execution through Podman only; do not introduce a generic `host` runner label;
- initially register the runner at repository scope for `jaasielsantos/ssh-smoke`;
- use the Forgejo 15 interactive registration flow (`URL + UUID + token`) rather than the deprecated `.runner` registration flow;
- run a minimal Actions workflow before widening scope or migrating the pilot repository.

A dedicated host-preparation script is available at `scripts/stage-d-runner-host-setup.sh`. It deliberately stops before inserting registration credentials or starting a runner daemon/service.

## Executable artifacts

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`
- `scripts/repair-stage-a-oauth2-secret.sh`
- `scripts/stage-b-nginx.sh`
- `scripts/stage-c-ssh-preflight.sh`
- `scripts/stage-d-runner-preflight.sh`
- `scripts/stage-d-runner-host-setup.sh`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/DEPLOYMENT.md`

## Security gate

The GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, certificate private keys, runner registration tokens, or private SSH keys.

Client SSH access is granted only through explicitly intended public keys stored in Forgejo. Temporary smoke credentials should be removed after their validation purpose is complete.

Forgejo Actions jobs must remain containerized through rootless Podman. Do not configure a `host` label for the V1 runner. Keep the initial runner registration at repository scope to minimize blast radius.

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[x] Stage C  Git SSH auth + clone/push proven
[~] Stage D  preflight complete -> dedicated runner host setup -> repo-scoped registration -> Actions smoke
[ ] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Run `scripts/stage-d-runner-host-setup.sh` first in dry-run mode and then with `--apply` after reviewing the plan. The script will prepare the dedicated service account, rootless Podman socket, verified Forgejo Runner v13.1.0 binary, and generated configuration file without registering or starting the runner.
