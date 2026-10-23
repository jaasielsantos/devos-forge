# DevOS Forge — Project State

## Status

**Phase:** 1 — Pilot migration  
**Implementation:** Stage A, Stage B, Stage C, and Stage D complete; Stage E mirror import, parity, and conversion complete; final GitHub -> Forgejo catch-up next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Perform one final fast-forward from the still-primary GitHub repository into the now-writable Forgejo repository so both `main` branches start the native Forgejo lifecycle test from the exact same commit. Then prove SSH clone/push, branch, Pull Request, Actions, review, and merge on Forgejo before moving source-of-truth responsibility away from GitHub.

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

## Completed infrastructure stages

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
- temporary VPS smoke key removed after validation.

### Stage D — Forgejo Runner + rootless Podman COMPLETE

Validated end to end on `srv1805473`:

- Podman 4.9.3 rootless;
- cgroup v2 + systemd cgroup manager;
- dedicated `forgejo-runner` account UID/GID 1002 with dedicated subuid/subgid `231072:65536`;
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

Read-only preflight validated Forgejo health, GitHub source reachability, source default branch `main`, source ref inventory, and absence of an existing Forgejo destination.

### E2 — Forgejo pull mirror COMPLETE

`jaasielsantos/devos-forge` was created in Forgejo as a pull mirror of:

```text
https://github.com/jaasielsantos/devos-forge.git
```

GitHub remained primary at this gate.

### E3 — Git parity COMPLETE

Parity verification completed successfully after mirror creation:

```text
source_main=3b883b7cd352886a8e7ab33c462638b726d5599e
forgejo_main=3b883b7cd352886a8e7ab33c462638b726d5599e
refs_parity=PASS
```

Forgejo object integrity also passed `git fsck --full --no-dangling`.

### E4 — convert mirror to regular repository COMPLETE

The validated pull mirror was converted in Forgejo to a regular writable repository. Git history was preserved and the repository is no longer operating in pull-mirror mode.

Because project documentation changed on GitHub after the parity snapshot, the next gate is one intentional final fast-forward from GitHub `main` into Forgejo `main` before any Forgejo-native branch is created. After that catch-up, avoid further GitHub writes until the pilot branch/PR lifecycle is established, preventing accidental dual-primary divergence.

### E5 — final catch-up + SSH write NEXT

Required sequence:

1. create an intended temporary SSH credential on the VPS and enroll only its public key in Forgejo;
2. clone current GitHub `main` to a disposable working directory;
3. add Forgejo as a second remote;
4. fast-forward push GitHub `main` to Forgejo `main` with no force;
5. verify GitHub and Forgejo `main` are identical;
6. create `stage-e/pilot-lifecycle` from that synchronized head;
7. make one small Stage E proof commit and push only that branch to Forgejo;
8. keep GitHub unchanged by the pilot branch.

### Stage E remaining lifecycle gates

- [x] import `jaasielsantos/devos-forge` to Forgejo with full Git history
- [x] verify branches/tags/history parity
- [x] convert pull mirror to a regular Forgejo repository
- [ ] final fast-forward catch-up from GitHub primary to Forgejo
- [ ] verify SSH clone/push on the pilot
- [ ] create and push a pilot branch
- [ ] open a Forgejo Pull Request
- [ ] run Forgejo Actions on the pilot
- [ ] review and merge in Forgejo
- [ ] establish GitHub transition mirror in Forgejo-primary direction
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
- `docs/MIGRATION.md`
- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[x] Stage C  Git SSH auth + clone/push
[x] Stage D  Forgejo Runner + rootless Podman + Actions smoke
[~] Stage E  mirror + parity + conversion complete -> final catch-up -> lifecycle proof
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

Create a temporary Stage E SSH key on the VPS, enroll only its public key in Forgejo, then use a disposable clone of the current GitHub primary to fast-forward Forgejo `main` once. Verify both `main` refs match before creating the Forgejo-only pilot branch.
