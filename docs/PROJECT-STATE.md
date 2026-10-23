# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo Runner validation  
**Implementation:** Stage A, Stage B, and Stage C complete; Stage D host preparation complete; repository-scoped runner registration next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Register the prepared Forgejo Runner at repository scope for `jaasielsantos/ssh-smoke`, keep capacity at 1 while the GitHub runner coexists, run jobs only in rootless Podman containers, and prove a minimal Forgejo Actions smoke workflow before migrating the `devos-forge` pilot.

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
- cgroup v2 exposes CPU, memory, IO and pids controllers;
- Forgejo Actions is enabled;
- Forgejo service is active/enabled and public health passes;
- existing GitHub Actions runner remains active;
- no conflicting public listeners were introduced.

### D2 — dedicated runner host setup COMPLETE

Applied and validated:

- Forgejo Runner v13.1.0 installed from the official Forgejo release and its OpenPGP signature verified;
- dedicated `forgejo-runner` account created as UID/GID 1002;
- password login for the service account locked;
- dedicated subordinate mappings created: `forgejo-runner:231072:65536` in both `/etc/subuid` and `/etc/subgid`;
- linger enabled (`Linger=yes`);
- rootless Podman socket enabled and listening at `/run/user/1002/podman/podman.sock`;
- Podman validated as `forgejo-runner` with `rootless=true`, cgroup v2 and systemd cgroup manager;
- version-matched generated configuration created at `/home/forgejo-runner/runner-config.yml` with mode `0600`;
- no registration token inserted and no runner daemon/service started during host preparation.

### D3 — repository-scoped runner registration NEXT

Use Forgejo 15 interactive registration at:

```text
jaasielsantos/ssh-smoke -> Settings -> Actions -> Runners -> Create new runner
```

The UI supplies a UUID and confidential token. Never paste the token into chat, Git, shell history, or command-line arguments.

`stage-d-runner-register-config.sh` writes the connection locally using hidden token input and locks the V1 policy to:

- `capacity: 1`;
- container-only `docker` label; no `host` label;
- rootless Podman as the runner container engine;
- `container.docker_host: "-"`, while the future systemd service supplies `DOCKER_HOST=unix:///run/user/1002/podman/podman.sock`; this lets the runner create job containers without mounting the Podman socket inside workflows;
- `privileged: false`;
- no allowed workflow bind mounts (`valid_volumes: []`);
- resource envelope of 1 GiB RAM, 0.75 CPU and 256 PIDs per job container;
- Actions cache disabled for this first Podman 4.9 smoke;
- IPv6 disabled for the initial rootless Podman smoke.

After registration configuration is written, the next gate is a hardened systemd service and online-runner validation, followed by the minimal Actions smoke workflow.

## Executable artifacts

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`
- `scripts/repair-stage-a-oauth2-secret.sh`
- `scripts/stage-b-nginx.sh`
- `scripts/stage-c-ssh-preflight.sh`
- `scripts/stage-d-runner-preflight.sh`
- `scripts/stage-d-runner-host-setup.sh`
- `scripts/stage-d-runner-register-config.sh`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/DEPLOYMENT.md`

## Security gate

The GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, certificate private keys, runner registration tokens, or private SSH keys.

Client SSH access is granted only through explicitly intended public keys stored in Forgejo. Temporary smoke credentials should be removed after their validation purpose is complete.

Forgejo Actions jobs must remain containerized through rootless Podman. Do not configure a `host` label for the V1 runner. Keep the initial runner registration at repository scope to minimize blast radius. Do not expose the Podman socket inside job containers.

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[x] Stage C  Git SSH auth + clone/push proven
[~] Stage D  preflight + host setup complete -> repo registration -> systemd -> Actions smoke
[ ] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Create a repository-scoped runner in the Forgejo UI for `jaasielsantos/ssh-smoke`, then run `scripts/stage-d-runner-register-config.sh` on the VPS and enter the UUID plus confidential token locally. Do not send the token through chat.
