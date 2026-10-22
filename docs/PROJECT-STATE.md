# DevOS Forge — Project State

## Status

**Phase:** 0 → 1 transition  
**Implementation:** executable bootstrap prepared; not applied yet  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Bootstrap Forgejo locally on the selected VPS, expose it safely through the existing Nginx/TLS stack, register a Podman-backed Forgejo Runner, and prove the complete Git + CI lifecycle without operational GitHub dependency.

## Locked V1 topology

```text
Human / DevOS / Agent
        |
        v
Chat / CLI / Git / SSH / API
        |
        v
existing Nginx :443
        |
        v
Forgejo 15 LTS
native binary + systemd
        |
   +----+--------------------+
   |                         |
   v                         v
PostgreSQL 16           Forgejo Actions
(existing)                   |
                              v
                       Forgejo Runner
                              |
                              v
                       rootless Podman
```

V1 remains on one VPS. The second VPS is not part of the initial runtime.

## Directed host inspection — completed

The second read-only inspection of `criandofacil-vps` confirmed:

- Ubuntu 24.04 LTS family;
- 1 vCPU;
- ~3.8 GiB RAM with ~3.2 GiB available at capture time;
- 2 GiB swap;
- ~32 GiB free disk at second capture;
- Nginx 1.24 active and configuration valid;
- existing sites for Criando Fácil and Doxa Upload;
- Certbot active with automatic renewal timer;
- PostgreSQL 16.15 active on loopback only;
- no existing Forgejo database/role;
- ports 3000 and standard Forgejo candidate paths currently free;
- existing GitHub Actions runner active under `cf-gh-runner`;
- Podman 4.9 present;
- UFW active with inbound 22/80/443 only;
- host OpenSSH active on port 22;
- existing backup timer infrastructure.

## Deployment decisions now locked

- Forgejo server: **native binary + systemd**.
- Initial Forgejo line: **15 LTS**, pinned by bootstrap to `15.0.10`.
- Reverse proxy: reuse existing **Nginx**.
- Database: reuse existing **PostgreSQL 16** with dedicated `forgejo` role/database.
- Local web listener: **127.0.0.1:3000** only.
- Candidate public hostname: **`git.criandofacil.com.br`**.
- Git SSH: reuse existing **OpenSSH on port 22**; do not start Forgejo built-in SSH server.
- Runner isolation: dedicated Forgejo Runner user + **rootless Podman**.
- During GitHub/Forgejo coexistence: `runner.capacity = 1`.
- After GitHub runner retirement and load validation: target `runner.capacity = 2`.
- Custom DevOS Forge UI: none in V1; headless-first remains the operating model.
- Pilot migration: **this `devos-forge` repository**.

## Executable artifacts

- `docs/RUNBOOK-V1.md` — host-specific deployment/runbook.
- `scripts/bootstrap-server-v1.sh` — guarded Stage A bootstrap.
- `docs/HOST-CRIANDOFACIL.md` — evidence and directed preflight procedure.

The bootstrap script is **dry-run by default** and deliberately does not touch Nginx, DNS, TLS, firewall, sshd, Forgejo Runner, or the existing GitHub Actions runner during Stage A.

## Security note

The current GitHub repository is public. No passwords, tokens, private keys, database credentials, or generated Forgejo secrets may be committed here.

Runtime secrets are generated and stored on the VPS with restricted permissions. The repository should become private before operational details expand further, or remain strictly secret-free until Forgejo becomes primary.

## Phase 0 exit criteria

- [x] architecture baseline documented;
- [x] security baseline documented;
- [x] migration baseline documented;
- [x] both VPS hosts inspected;
- [x] V1 host selected;
- [x] directed host inspection completed;
- [x] Forgejo packaging selected;
- [x] Nginx/PostgreSQL integration selected;
- [x] Git SSH strategy selected;
- [x] runner runtime/isolation selected;
- [x] concurrency transition policy selected;
- [x] pilot repository selected;
- [x] executable Stage A bootstrap prepared;
- [ ] Stage A dry-run reviewed;
- [ ] Stage A bootstrap applied and local health validated.

## Phase 1 sequence

```text
Stage A  local Forgejo bootstrap
   ↓
Stage B  DNS + Nginx + TLS
   ↓
Stage C  Git SSH validation
   ↓
Stage D  Forgejo Runner + Podman
   ↓
Stage E  migrate devos-forge pilot
   ↓
backup / restore rehearsal
   ↓
Forgejo becomes source of truth
```

## Immediate next action

Run the Stage A bootstrap in **dry-run mode** on `criandofacil-vps`:

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/bootstrap-server-v1.sh | sudo bash
```

If the guard checks and plan are clean, apply the same script explicitly with `--apply`.

## Checkpoint rule

Update this file only when a meaningful phase, decision, deployment state, blocker, or next action changes. Do not use it as a chronological activity log.
