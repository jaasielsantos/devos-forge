# DevOS Forge — Project State

## Status

**Phase:** 1 — Pilot migration  
**Implementation:** Stage A, Stage B, Stage C, and Stage D complete; Stage E migration of `devos-forge` next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Migrate `devos-forge` to Forgejo as the pilot repository while keeping GitHub as a transition mirror. Prove the repository lifecycle on Forgejo before changing the source of truth.

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
      forgejo-runner.service
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

### Stage D — Forgejo Runner + rootless Podman COMPLETE

Validated end to end on `srv1805473`:

- Podman 4.9.3 rootless;
- cgroup v2 + systemd cgroup manager;
- dedicated `forgejo-runner` account UID/GID 1002;
- dedicated subuid/subgid `231072:65536`;
- linger enabled;
- rootless Podman socket active at `/run/user/1002/podman/podman.sock`;
- Forgejo Runner v13.1.0 installed and OpenPGP signature verified;
- repository-scoped runner registered for `jaasielsantos/ssh-smoke`;
- `capacity: 1` while GitHub runner coexists;
- label `docker` only; no `host` label;
- `privileged: false`;
- `valid_volumes: []`;
- engine socket is not exposed inside workflow containers;
- per-job envelope: 1 GiB RAM, 0.75 CPU, 256 PIDs;
- `forgejo-runner.service` enabled and active;
- runner declared successfully and poller launched.

First Actions execution exposed two rootless networking issues:

1. `slirp4netns` was missing from the host;
2. after the initial failed network setup, stale rootless netns runtime state remained under `/run/user/1002`.

The host was repaired by installing `slirp4netns`, cleaning the stale rootless-netns runtime state for the dedicated runner user, validating a direct rootless Podman container, and re-running the workflow.

The durable host-setup script now installs/verifies `slirp4netns` and runs a disposable rootless Podman networking smoke before registration.

Final Forgejo Actions proof:

```text
FORGEJO_ACTIONS_SMOKE=PASS
```

This proves the complete path:

```text
Forgejo repository
  -> Forgejo Actions
  -> repository-scoped Forgejo Runner
  -> rootless Podman
  -> isolated job container
  -> successful workflow result
```

## Stage E — migrate `devos-forge` pilot NEXT

Migration strategy remains incremental:

```text
GitHub primary + Forgejo copy
  -> Forgejo primary + GitHub mirror
  -> Forgejo primary + GitHub optional
```

Before any source-of-truth change, Stage E must prove on `devos-forge`:

- repository imported with full Git history;
- SSH clone/push works;
- branch workflow works;
- Forgejo Pull Request workflow works;
- Forgejo Actions executes on the rootless Podman runner;
- review/merge path works;
- GitHub remains available as transition mirror.

## Security gate

The GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, certificate private keys, runner UUID/token values, or private SSH keys.

Forgejo Actions remain container-only through rootless Podman. Do not configure a V1 `host` runner label and do not expose the Podman socket inside workflow containers.

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
[x] Stage D  Forgejo Runner + rootless Podman + Actions smoke
[~] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Prepare the Stage E pilot migration plan for `jaasielsantos/devos-forge`, preserving full history and keeping GitHub as the transition mirror until the Forgejo PR/CI/merge path and backup/restore gates are proven.
