# DevOS Forge — Project State

## Status

**Phase:** 0 → 1 transition  
**Implementation:** executable bootstrap prepared; not applied yet  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Bootstrap Forgejo locally on the selected VPS, expose it through the existing Nginx/TLS stack, register a Podman-backed Forgejo Runner, and prove the complete Git + CI lifecycle without operational GitHub dependency.

## Locked V1 topology

```text
Chat / CLI / Git / SSH / API
          |
          v
existing Nginx :443
          |
          v
Forgejo 15 LTS
native binary + systemd
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

V1 remains on one VPS. The second VPS is outside the initial runtime.

## Directed host inspection — completed

Confirmed on `criandofacil-vps`:

- Ubuntu 24.04 LTS family;
- 1 vCPU, ~3.8 GiB RAM, 2 GiB swap;
- ~32 GiB free disk at second capture;
- Nginx 1.24 active with valid configuration;
- Certbot active;
- PostgreSQL 16.15 active on loopback only;
- no existing Forgejo database/role;
- port 3000 free;
- existing GitHub Actions runner active under `cf-gh-runner`;
- Podman present;
- UFW active with inbound 22/80/443;
- OpenSSH active on port 22.

## Locked deployment decisions

- native Forgejo binary + systemd;
- Forgejo 15 LTS, bootstrap pinned to 15.0.10;
- reuse existing Nginx;
- reuse existing PostgreSQL 16 with dedicated `forgejo` DB/role;
- Forgejo HTTP on `127.0.0.1:3000` only;
- candidate hostname `git.criandofacil.com.br`;
- system OpenSSH port 22 for Git SSH;
- dedicated Forgejo Runner + rootless Podman;
- runner capacity 1 while GitHub runner coexists;
- target runner capacity 2 after GitHub runner retirement and load validation;
- no custom V1 UI;
- `devos-forge` is the pilot repository.

Durable decisions are captured in `docs/DECISIONS.md` (D-014 through D-019) and summarized in `docs/ADR-001-V1-DEPLOYMENT.md`.

## Executable artifacts

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`
- `docs/HOST-CRIANDOFACIL.md`

The bootstrap script is dry-run by default and Stage A does not alter Nginx, DNS, TLS, firewall, sshd, Forgejo Runner, or the existing GitHub runner.

## Security gate

The current GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, or generated Forgejo secrets. Runtime secrets stay on the VPS with restricted permissions.

## Phase 0 exit criteria

- [x] architecture/security/migration baseline documented;
- [x] both VPS hosts inspected;
- [x] V1 host and topology selected;
- [x] directed host inspection completed;
- [x] packaging, Nginx/PostgreSQL, Git SSH and runner model selected;
- [x] durable V1 host decisions documented;
- [x] pilot repository selected;
- [x] executable Stage A bootstrap prepared;
- [ ] Stage A dry-run reviewed;
- [ ] Stage A applied and local health validated.

## Phase 1 sequence

```text
Stage A  local Forgejo bootstrap
Stage B  DNS + Nginx + TLS
Stage C  Git SSH validation
Stage D  Forgejo Runner + Podman
Stage E  migrate devos-forge pilot
Stage F  backup + restore rehearsal
Stage G  Forgejo becomes source of truth
```

## Immediate next action

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/bootstrap-server-v1.sh | sudo bash
```

Review the dry-run. If clean, rerun explicitly with `--apply`.
