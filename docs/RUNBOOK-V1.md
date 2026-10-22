# DevOS Forge — V1 executable runbook

## Status

Host-specific runbook for `criandofacil-vps` (`srv1805473`).

This file contains **no live secret values**. Secrets are generated on the host and must never be committed.

## Locked V1 architecture

```text
Internet
  |
  v
existing Nginx :80/:443
  |
  v
Forgejo v15 LTS
(native binary + systemd)
127.0.0.1:3000
  |
  +--> existing PostgreSQL 16 on loopback
  +--> system OpenSSH :22 for Git SSH
  +--> /var/lib/forgejo persistent data
  `--> Forgejo Actions
          |
          v
     Forgejo Runner
     rootless Podman
```

## Why this shape

The selected host already provides Nginx, PostgreSQL 16, Certbot, Git, OpenSSH and Podman. The V1 therefore minimizes change surface:

- do not deploy another reverse proxy;
- do not deploy another PostgreSQL instance;
- do not install Docker just for Forgejo;
- do not expose Forgejo's HTTP listener publicly;
- do not start Forgejo's built-in SSH server;
- do not replace the existing GitHub Actions runner during bootstrap.

## Version policy

Initial server line: **Forgejo 15 LTS**.

The bootstrap pins `15.0.10`. Patch upgrades within the LTS line are deliberate maintenance operations; major upgrades require release-note review and backup verification.

## Host paths

```text
binary:        /usr/local/bin/forgejo
config:        /etc/forgejo/app.ini
work/data:     /var/lib/forgejo
logs:          /var/log/forgejo
service:       /etc/systemd/system/forgejo.service
admin secret:  /root/devos-forge-initial-admin.txt   # host-only; never commit
```

## Network choices

```text
public HTTPS:  existing Nginx :443
public HTTP:   existing Nginx :80 (redirect / ACME)
Forgejo HTTP:  127.0.0.1:3000 only
Git SSH:       existing OpenSSH :22
PostgreSQL:    127.0.0.1:5432 / ::1:5432
```

V1 hostname:

```text
git.criandofacil.com.br
```

The hostname becomes externally usable only after DNS points to the VPS and TLS is issued.

## Database choices

Reuse PostgreSQL 16 with dedicated objects:

```text
database: forgejo
role:     forgejo
```

The database password was generated on-host during bootstrap and is stored only in the protected Forgejo configuration.

## Authentication baseline

V1 is private/headless-first:

- registration disabled;
- sign-in required to view the instance/API;
- initial administrator created locally through Forgejo CLI;
- initial admin password generated on-host and written to a root-only file;
- 2FA required for administrators;
- API tokens generated later with the smallest scopes required by DevOS.

## Stage A — local server bootstrap — COMPLETE

Stage A is healthy.

Acceptance passed:

```text
forgejo.service = active
127.0.0.1:3000 = listening
/api/healthz = healthy
PostgreSQL connection = healthy
initial admin = created
Nginx configuration = untouched by Stage A
existing GitHub runner = untouched
```

### Stage A incident / fix

The first apply exposed a bootstrap defect: Forgejo required `oauth2.JWT_SECRET` and attempted to persist it into the intentionally root-owned config.

Durable correction:

- bootstrap pre-generates `JWT_SECRET`;
- `[oauth2].JWT_SECRET` exists before first startup;
- `/etc/forgejo/app.ini` remains `root:git 0640`;
- the partial deployment was repaired through `scripts/repair-stage-a-oauth2-secret.sh`.

Do **not** paste `/root/devos-forge-initial-admin.txt` into chat.

## Stage B — DNS + Nginx + TLS

Stage B is split to keep certificate issuance separate from ingress configuration.

### Stage B1 — Nginx HTTP reverse proxy

Repository script:

```text
scripts/stage-b-nginx.sh
```

Preview:

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/stage-b-nginx.sh | sudo bash
```

Apply only after preview:

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/stage-b-nginx.sh | sudo bash -s -- --apply
```

The vhost follows Forgejo's documented Nginx proxy requirements:

- `merge_slashes off`;
- proxy to `http://127.0.0.1:3000`;
- preserve Host / forwarded headers;
- support connection upgrade;
- `client_max_body_size 512M`.

B1 does **not** touch DNS, TLS, firewall, sshd, or runners.

### Stage B2 — DNS

Create/verify DNS for:

```text
git.criandofacil.com.br
```

It must resolve to the selected VPS before Certbot is run.

Host-side checks:

```bash
getent ahostsv4 git.criandofacil.com.br
curl -I http://git.criandofacil.com.br/
```

### Stage B3 — TLS

After DNS is correct and HTTP reaches the new vhost:

```bash
sudo certbot --nginx -d git.criandofacil.com.br --redirect
```

Then validate:

```bash
sudo nginx -t
curl -fsS https://git.criandofacil.com.br/api/healthz
sudo certbot certificates
```

Forgejo itself remains plain HTTP on loopback; Nginx terminates TLS.

## Stage C — Git SSH

Use the existing OpenSSH service on port 22.

Forgejo runs with `START_SSH_SERVER = false` and manages the dedicated `git` user's authorized keys. Expected clone form:

```text
git@git.criandofacil.com.br:<owner>/<repo>.git
```

Do not open an additional SSH port unless the system-OpenSSH path proves incompatible.

## Stage D — Forgejo Runner

Use a dedicated runner OS account and the host's existing Podman runtime in rootless mode.

Do not execute Actions directly on the host.

Target shape:

```text
Forgejo Actions
     |
     v
forgejo-runner daemon
     |
     v
rootless Podman socket
     |
     v
isolated job containers
```

Concurrency policy:

```text
while GitHub runner remains active: runner.capacity = 1
after GitHub runner retirement + load validation: runner.capacity = 2
```

This preserves the desired two-job capability without accidentally allowing GitHub + Forgejo to create three competing jobs on a 1-vCPU host.

## Stage E — pilot migration

Pilot repository: **`devos-forge`**.

Migration progression:

```text
GitHub primary
   + Forgejo copy
        ->
Forgejo primary
   + GitHub mirror
        ->
Forgejo primary
   + GitHub optional
```

Acceptance test:

```text
clone
 -> branch
 -> commit
 -> push
 -> PR
 -> Actions job
 -> review
 -> merge
 -> backup
 -> restore rehearsal
```

## Backup gate

Before migrating additional repositories, backup must include:

- `/var/lib/forgejo`;
- `/etc/forgejo` excluding accidental plaintext export outside protected backup;
- PostgreSQL logical dump of the `forgejo` database;
- Nginx Forgejo vhost;
- systemd units;
- runner configuration/registration recovery procedure.

At least one copy must leave the primary VPS. GitHub remains a transition mirror until restore capability is proven.

## Rollback principle

Until cutover is complete, GitHub remains available as the known-good source.

If Forgejo fails, do not delete PostgreSQL or Forgejo data while diagnosing. Inspect:

```bash
sudo journalctl -u forgejo -n 200 --no-pager
sudo systemctl status forgejo --no-pager
```

## Definition of V1 done

V1 is complete when:

- Forgejo is reachable through HTTPS;
- Git SSH clone/push works through standard port 22;
- DevOS/API authentication works;
- Forgejo Runner executes containerized workflows through Podman;
- two-job capacity is validated or intentionally capped at one;
- `devos-forge` operates primarily from Forgejo;
- backup + restore smoke test succeeds;
- a GitHub outage no longer blocks normal DevOS Forge development.
