# DevOS Forge — Project State

## Status

**Phase:** 1 — Pilot migration  
**Implementation:** Stage A, Stage B, Stage C, and Stage D complete; Stage E pull mirror created and Git parity proven; mirror conversion next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Convert the validated Forgejo pull mirror of `jaasielsantos/devos-forge` into a regular Forgejo repository, then prove SSH write, branch, Pull Request, Actions, review, and merge lifecycle before moving source-of-truth responsibility away from GitHub.

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

GitHub remains primary at this gate.

### E3 — Git parity COMPLETE

Parity verification completed successfully after mirror creation:

```text
source_main=3b883b7cd352886a8e7ab33c462638b726d5599e
forgejo_main=3b883b7cd352886a8e7ab33c462638b726d5599e
refs_parity=PASS
```

Forgejo object integrity also passes:

```text
Checking objects: 100% (273/273), done.
Verifying commits in commit graph: 100% (73/73), done.
```

Proof:

- destination bare Git repository exists;
- GitHub and Forgejo branch/tag ref sets are identical;
- `main` points to the same commit on both forges;
- Forgejo `git fsck --full --no-dangling` passes.

### E4 — convert mirror to regular repository NEXT

The next gate is intentionally one-way: convert the validated pull mirror into a regular Forgejo repository so writes/PRs can be tested. This does not delete Git history, but pull-mirror mode cannot simply be restored on the same repository afterward; rollback before source-of-truth cutover remains GitHub as the still-valid primary.

After conversion, prove:

1. Forgejo repository is no longer marked as a pull mirror;
2. `main` still points to the validated commit;
3. SSH clone works;
4. SSH push of a new pilot branch works;
5. no direct change is made to GitHub by that Forgejo-only branch yet.

### Stage E remaining lifecycle gates

- [x] import `jaasielsantos/devos-forge` to Forgejo with full Git history
- [x] verify branches/tags/history parity
- [ ] convert pull mirror to a regular Forgejo repository
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
[~] Stage E  mirror + parity complete -> convert -> lifecycle proof
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

In Forgejo, open `jaasielsantos/devos-forge -> Settings -> Repository`, locate the mirror conversion control in the repository settings/Danger Zone, convert the validated mirror to a regular repository, and confirm the repository remains at `main=3b883b7cd352886a8e7ab33c462638b726d5599e` before beginning the SSH write test.
