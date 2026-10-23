# DevOS Forge — Project State

## Status

**Phase:** 1 — Pilot migration  
**Implementation:** Stage A, Stage B, Stage C, and Stage D complete; Stage E preflight complete; Forgejo pull-mirror creation next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Create `jaasielsantos/devos-forge` in Forgejo as a pull mirror of the current GitHub primary, verify exact Git ref/object parity, then prove the repository lifecycle on Forgejo before changing the source of truth.

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
- dedicated `forgejo-runner` UID/GID 1002 with dedicated subuid/subgid `231072:65536`;
- linger and rootless Podman socket active;
- Forgejo Runner v13.1.0 installed and signature verified;
- repository-scoped runner registered for `jaasielsantos/ssh-smoke`;
- capacity `1`, `docker` label only, no `host` label;
- `privileged: false`, `valid_volumes: []`, engine socket not exposed to workflow containers;
- per-job envelope: 1 GiB RAM, 0.75 CPU, 256 PIDs;
- `forgejo-runner.service` enabled and active;
- missing `slirp4netns` and stale rootless-netns runtime state discovered and repaired;
- durable host setup now verifies rootless networking before registration.

Final Forgejo Actions proof:

```text
FORGEJO_ACTIONS_SMOKE=PASS
```

## Stage E — migrate `devos-forge` pilot ACTIVE

Migration progression remains:

```text
GitHub primary + Forgejo copy
  -> Forgejo primary + GitHub mirror
  -> Forgejo primary + GitHub optional
```

### E1 — migration preflight COMPLETE

Read-only preflight validated:

- Forgejo health = pass;
- GitHub source reachable at `https://github.com/jaasielsantos/devos-forge.git`;
- source default branch = `main`;
- source `main` at preflight commit `1dde1856cbffa9072561c2127393bc33da5dfb9e`;
- source had one branch (`main`) and no tags at capture;
- Forgejo destination repository path did not yet exist;
- no Git clone authentication is required for the public GitHub source.

The selected first migration mode is a Forgejo pull mirror while GitHub remains primary. Do not create a normal empty `devos-forge` repository before the migration.

### E2 — create pull mirror NEXT

Use Forgejo UI migration:

```text
New Migration -> Git
source: https://github.com/jaasielsantos/devos-forge.git
owner: jaasielsantos
repository: devos-forge
This repository will be a mirror: enabled
```

After creation, run `scripts/stage-e-mirror-parity.sh` with sudo on the VPS. It compares GitHub and Forgejo branch/tag refs, confirms the `main` commit matches, and runs `git fsck --full --no-dangling` against the Forgejo repository.

### Stage E exit criteria

- [ ] import `jaasielsantos/devos-forge` to Forgejo with full Git history
- [ ] verify branches/tags/history parity
- [ ] verify SSH clone/push on the pilot after leaving pull-mirror mode
- [ ] create and push a pilot branch
- [ ] open a Forgejo Pull Request
- [ ] run Forgejo Actions on the pilot
- [ ] review and merge in Forgejo
- [ ] confirm GitHub transition mirror remains current
- [ ] document the migration procedure

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
- `scripts/stage-e-migration-preflight.sh`
- `scripts/stage-e-mirror-parity.sh`
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
[~] Stage E  preflight complete -> create pull mirror -> parity -> lifecycle proof
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Create `jaasielsantos/devos-forge` through Forgejo `New Migration -> Git` with `This repository will be a mirror` enabled. Then run `sudo bash scripts/stage-e-mirror-parity.sh` (or download the raw script to `/tmp`) and require exact ref/object parity before proceeding.
