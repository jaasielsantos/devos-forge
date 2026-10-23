# DevOS Forge — Project State

## Status

**Phase:** 1 — Forgejo pilot proven through native branch creation; Control Plane bootstrap now active  
**Implementation:** Stage A-D complete; Stage E mirror/import/parity/conversion/final catch-up/Forgejo-native branch proof complete through `FORGEJO_NATIVE_BRANCH=PASS`; Forgejo PR/Actions/review/merge proof intentionally paused while the DevOS Forge Control Plane is bootstrapped  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`  
**Control Plane target repository:** `devos-forge-control-plane`

## Current objective

Build the **DevOS Forge MCP / ChatGPT Control Plane** so ChatGPT and DevOS can operate Forgejo directly without depending operationally on the GitHub connector.

The accepted bootstrap strategy temporarily allows GitHub to remain the writable primary for Control Plane development because the existing connector gives ChatGPT a reliable write path today. Forgejo remains the target forge and should mirror the bootstrap repository until the Control Plane passes staging, end-to-end and production gates. After that, Forgejo becomes primary and GitHub is demoted to mirror/secondary or removed from the critical path.

Accepted Control Plane endpoints:

```text
Production: mcp-git.criandofacil.com.br
Staging:    mcp-git-staging.criandofacil.com.br
Reserved:   mcp.criandofacil.com.br
```

`mcp.criandofacil.com.br` is intentionally reserved for a possible future CriandoFacil root MCP gateway.

## Locked V1 Forgejo topology

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
- durable host setup verifies rootless networking before registration.

Final Forgejo Actions proof:

```text
FORGEJO_ACTIONS_SMOKE=PASS
```

## Stage E — migrate `devos-forge` pilot PAUSED AFTER NATIVE BRANCH PROOF

Migration progression remains the long-term target:

```text
GitHub primary + Forgejo validation
  -> Forgejo primary + GitHub mirror
  -> Forgejo primary + GitHub optional
```

A temporary bootstrap exception is now active while the Control Plane is built: GitHub may remain writable primary so ChatGPT can operate the bootstrap repository through the existing connector. This does not change the final source-of-truth target.

### E1 — migration preflight COMPLETE

Read-only preflight validated Forgejo health, GitHub source reachability, source default branch `main`, source ref inventory, and absence of an existing Forgejo destination.

### E2 — Forgejo pull mirror COMPLETE

`jaasielsantos/devos-forge` was imported to Forgejo from GitHub.

### E3 — Git parity COMPLETE

Parity verification completed successfully and Forgejo object integrity passed `git fsck --full --no-dangling`.

### E4 — convert mirror to regular repository COMPLETE

The validated pull mirror was converted in Forgejo to a regular writable repository with Git history preserved.

### E5 — final catch-up + Forgejo-native SSH branch proof COMPLETE

The final GitHub -> Forgejo catch-up and native write path were exercised far enough to prove that a Forgejo-only branch can exist without being created in GitHub.

Recorded evidence:

```text
forgejo_branch=eaddbb259fc710cafbecefa658912e8f9047752f
github_branch=ABSENT
FORGEJO_NATIVE_BRANCH=PASS
```

This proves the key native branch/write boundary. The remaining Forgejo lifecycle proof is intentionally paused while the Control Plane is built.

### Stage E remaining lifecycle gates

- [x] import `jaasielsantos/devos-forge` to Forgejo with full Git history
- [x] verify branches/tags/history parity
- [x] convert pull mirror to a regular Forgejo repository
- [x] final fast-forward catch-up from GitHub primary to Forgejo
- [x] verify SSH write path on the pilot
- [x] create and push a Forgejo-only pilot branch
- [ ] open a Forgejo Pull Request
- [ ] run Forgejo Actions on the pilot PR
- [ ] review and merge in Forgejo
- [ ] establish final source-of-truth direction after Control Plane production cutover
- [ ] document final migration/cutover procedure

## Control Plane architecture — ACCEPTED

Canonical documents:

- `docs/CONTROL-PLANE-ARCHITECTURE.md`
- `docs/ADR-002-CONTROL-PLANE.md`
- `docs/CONTROL-PLANE-IMPLEMENTATION-PLAN.md`
- `docs/CONTROL-PLANE-BOOTSTRAP.md`
- `docs/CONTROL-PLANE-STATUS.md`

Accepted architecture:

```text
ChatGPT / DevOS / future clients
            |
            v
           MCP
            |
            v
DevOS Forge Control Plane
            |
            v
       ForgeProvider
            |
            v
     ForgejoProvider
            |
            v
         Forgejo
```

Key constraints:

- MCP is an adapter, not the domain layer;
- `ForgeProvider` remains the portability boundary;
- no raw Forgejo API passthrough MCP tool;
- no unrestricted shell/SSH MCP tool;
- policy classes separate READ / WRITE / RELEASE / PRODUCTION / BREAK_GLASS;
- BREAK_GLASS is not exposed through MCP V1;
- writes use optimistic concurrency where applicable;
- mutations are idempotent and produce structured evidence;
- staging and production use separate credentials/state;
- production promotion should use the same artifact validated in staging.

## Control Plane implementation gates

```text
[x] Gate 0  architecture freeze
[~] Gate 1  bootstrap repository
[ ] Gate 2  ForgeProvider contract
[ ] Gate 3  ForgejoProvider read path
[ ] Gate 4  ForgejoProvider write path
[ ] Gate 5  Control Plane core: policy / idempotency / evidence
[ ] Gate 6  MCP adapter
[ ] Gate 7  staging deployment
[ ] Gate 8  MCP -> Forgejo end-to-end proof
[ ] Gate 9  deployment control semantics
[ ] Gate 10 production Control Plane
[ ] Gate 11 Forgejo source-of-truth cutover / GitHub dependency removal
```

## Gate 1 — current bootstrap boundary

Target repository:

```text
jaasielsantos/devos-forge-control-plane
```

Temporary bootstrap flow:

```text
ChatGPT
   |
   v
GitHub connector
   |
   v
GitHub primary
   |
   v
Forgejo mirror
```

The currently connected GitHub control surface can operate repository content, branches, commits, issues, pull requests and workflow state, but does **not** expose repository creation. Therefore creation of the new GitHub repository object is the single current bootstrap boundary before ChatGPT can take over the remaining repository bootstrap through the connector.

## Security gate

The existing `devos-forge` GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, certificate private keys, runner UUID/token values, or private SSH keys.

Control Plane credentials must remain server-side and must never be returned through MCP responses, audit records or evidence payloads.

Forgejo Actions remain container-only through rootless Podman. Do not configure a generic V1 `host` runner label and do not expose the Podman socket inside workflow containers.

## Executable artifacts

Infrastructure:

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

Control Plane architecture/bootstrap:

- `docs/CONTROL-PLANE-ARCHITECTURE.md`
- `docs/ADR-002-CONTROL-PLANE.md`
- `docs/CONTROL-PLANE-IMPLEMENTATION-PLAN.md`
- `docs/CONTROL-PLANE-BOOTSTRAP.md`
- `docs/CONTROL-PLANE-STATUS.md`

## Phase sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[x] Stage C  Git SSH auth + clone/push
[x] Stage D  Forgejo Runner + rootless Podman + Actions smoke
[~] Stage E  native branch proof passed; PR/Actions/merge proof paused for Control Plane bootstrap
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth

[x] Control Plane Gate 0  architecture
[~] Control Plane Gate 1  repository bootstrap
```

## Immediate next action

Create the GitHub repository `jaasielsantos/devos-forge-control-plane` with default branch `main`. Once the repository object exists, continue Gate 1 through the connected GitHub control surface: create the baseline files and branch, establish the ForgeProvider-first TypeScript skeleton, then configure/verify the Forgejo mirror before Gate 2.
