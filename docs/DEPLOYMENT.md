# DevOS Forge — Deployment

## Status

The generic deployment baseline has been superseded by the host-specific V1 runbook after the two VPS preflights and the directed inspection of `criandofacil-vps`.

Use:

- `docs/RUNBOOK-V1.md` — executable V1 deployment sequence;
- `docs/ADR-001-V1-DEPLOYMENT.md` — accepted host/packaging/runtime decisions;
- `docs/HOST-CRIANDOFACIL.md` — collected-host baseline and directed inspection procedure;
- `docs/PROJECT-STATE.md` — live checkpoint.

## Locked deployment shape

```text
Internet
  |
  v
existing Nginx :80/:443
  |
  v
Forgejo 15 LTS
native binary + systemd
  |
  +--> existing PostgreSQL 16
  +--> system OpenSSH :22
  +--> persistent Forgejo/Git data
  `--> Forgejo Actions
          |
          v
     Forgejo Runner
          |
          v
     rootless Podman
```

## Execution sequence

```text
Stage A  local Forgejo bootstrap
Stage B  DNS + Nginx + TLS
Stage C  Git SSH validation
Stage D  Forgejo Runner + Podman
Stage E  devos-forge pilot migration
Stage F  backup + restore rehearsal
Stage G  Forgejo becomes source of truth
```

The Stage A bootstrap lives at:

```text
scripts/bootstrap-server-v1.sh
```

It is dry-run by default and requires explicit `--apply` to mutate the host.

## Non-negotiable deployment gates

- Forgejo HTTP remains loopback-only behind Nginx.
- PostgreSQL remains non-public.
- no runtime secret is committed to this repository.
- generic Actions do not run directly on the host.
- GitHub remains a transition fallback until backup/restore is proven.
- broad repository migration begins only after the `devos-forge` pilot passes the complete lifecycle.
