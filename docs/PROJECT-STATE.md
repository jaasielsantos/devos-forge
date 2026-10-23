# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo Runner validation  
**Implementation:** Stage A, Stage B, and Stage C complete; Stage D runner registered and service active; Actions smoke next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Prove a minimal Forgejo Actions workflow end to end on the repository-scoped `ssh-smoke` runner, using rootless Podman containers only. After that, migrate the `devos-forge` pilot.

## Locked V1 topology

```text
Internet
   |
   v
Nginx :443 + TLS
   |
   v
Forgejo 15.0.10
native binary + systemd
127.0.0.1:3000
   |
   +--> PostgreSQL 16
   |
   `--> Forgejo Actions
          |
          v
      Forgejo Runner v13.1.0
      service: forgejo-runner.service
          |
          v
      rootless Podman
      /run/user/1002/podman/podman.sock
```

Git-over-SSH uses the existing system OpenSSH service on port 22 with the dedicated `git` account.

## Completed stages

### Stage A — Forgejo bootstrap COMPLETE

- Forgejo service active/enabled.
- HTTP bound only to `127.0.0.1:3000`.
- PostgreSQL 16 integration healthy.
- initial admin created.
- OAuth2 JWT bootstrap defect fixed durably.
- repository root `/var/lib/forgejo/data/forgejo-repositories` created durably with correct ownership.

### Stage B — public HTTPS COMPLETE

- Nginx reverse proxy installed.
- `git.criandofacil.com.br` DNS points to the selected VPS.
- TLS issued by Certbot.
- public `/api/healthz` passes.

### Stage C — Git SSH COMPLETE

- system OpenSSH integration validated.
- dedicated client key authentication succeeds as `jaasielsantos`.
- shell access is correctly refused.
- real SSH clone/commit/push succeeded against `jaasielsantos/ssh-smoke`.
- smoke commit: `bcbfee5` (`test: validate Forgejo SSH push`).
- temporary VPS smoke key removed after validation.

## Stage D — Forgejo Runner + rootless Podman ACTIVE

### D1 — preflight COMPLETE

Validated on `srv1805473`:

- Ubuntu 24.04.4 LTS / kernel 6.8;
- 1 vCPU;
- 3.8 GiB RAM, 2 GiB swap;
- ~32 GiB free disk at capture;
- Podman 4.9.3 functional rootless;
- cgroup v2 + systemd cgroup manager;
- unprivileged user namespaces available;
- Forgejo Actions enabled;
- existing GitHub Actions runner coexistence confirmed.

Capacity remains locked to `1` while the GitHub runner coexists.

### D2 — dedicated runner host COMPLETE

- Forgejo Runner v13.1.0 installed from official release and OpenPGP signature verified.
- dedicated `forgejo-runner` account created as UID/GID 1002.
- password login locked.
- dedicated subordinate mappings: `231072:65536` for both subuid/subgid.
- linger enabled.
- rootless Podman socket active at `/run/user/1002/podman/podman.sock`.
- runner config stored at `/home/forgejo-runner/runner-config.yml` mode `0600`.

### D3 — repository-scoped registration COMPLETE

The runner was created at repository scope for `jaasielsantos/ssh-smoke` using Forgejo 15 interactive registration and local secret entry.

Locked runner policy:

- `capacity: 1`;
- only `docker` label;
- no `host` label;
- `privileged: false`;
- `valid_volumes: []`;
- `docker_host: "-"` so the engine socket is not mounted inside workflow containers;
- runner process receives `DOCKER_HOST=unix:///run/user/1002/podman/podman.sock` only through systemd;
- per-job envelope: 1 GiB RAM, 0.75 CPU, 256 PIDs;
- cache disabled for the initial Podman 4.9 smoke;
- IPv6 disabled for the initial smoke.

### D4 — runner service COMPLETE

`forgejo-runner.service` is installed, enabled and active.

Validated startup:

```text
runner: devos-forge-smoke-runner, with version: v13.1.0, with labels: [docker], ephemeral: false, declared successfully
[poller] launched
```

The daemon runs as `forgejo-runner` with:

```text
/usr/local/bin/forgejo-runner daemon -c /home/forgejo-runner/runner-config.yml
```

The service supplies only the runner process with:

```text
DOCKER_HOST=unix:///run/user/1002/podman/podman.sock
```

### D5/D6 — next gate: online validation + Actions smoke

1. Confirm `devos-forge-smoke-runner` appears Online/Idle under:

```text
ssh-smoke -> Settings -> Actions -> Runners
```

2. Add `.forgejo/workflows/smoke.yml` to `ssh-smoke` using the reference workflow stored at:

```text
examples/forgejo-actions-smoke.yml
```

3. Verify a job with `runs-on: docker` executes successfully inside the configured container image.

4. Required smoke assertions:

- Node/runtime executes;
- job is containerized;
- `/var/run/docker.sock` is absent;
- `/run/user/1002/podman/podman.sock` is absent;
- cgroup memory/CPU/PID limits are visible;
- final marker `FORGEJO_ACTIONS_SMOKE=PASS` is emitted.

## Security gate

The GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, certificate private keys, runner UUID/token values, or private SSH keys.

Forgejo Actions must remain container-only through rootless Podman. Do not configure a V1 `host` runner label and do not expose the Podman socket inside workflow containers.

## Executable artifacts

- `scripts/bootstrap-server-v1.sh`
- `scripts/repair-stage-a-oauth2-secret.sh`
- `scripts/stage-b-nginx.sh`
- `scripts/stage-c-ssh-preflight.sh`
- `scripts/stage-d-runner-preflight.sh`
- `scripts/stage-d-runner-host-setup.sh`
- `scripts/stage-d-runner-register-config.sh`
- `scripts/stage-d-runner-service.sh`
- `examples/forgejo-actions-smoke.yml`
- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/DEPLOYMENT.md`

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[x] Stage C  Git SSH auth + clone/push
[~] Stage D  runner registered + service active -> Actions smoke
[ ] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Confirm the repository-scoped runner is Online/Idle in the Forgejo UI, create `.forgejo/workflows/smoke.yml` in `jaasielsantos/ssh-smoke` from `examples/forgejo-actions-smoke.yml`, and inspect the first Forgejo Actions run.
