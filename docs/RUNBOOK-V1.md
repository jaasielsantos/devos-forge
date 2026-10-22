# DevOS Forge — V1 executable runbook

## Status

Host-specific runbook for `criandofacil-vps` (`srv1805473`).

This file contains **no live secret values**. Secrets are generated on the host and must never be committed.

## Locked V1 architecture

```text
Internet
  |
  +--> HTTPS :443 --> existing Nginx / TLS
  |                    |
  |                    v
  |              127.0.0.1:3000
  |                    |
  |                    v
  |                 Forgejo
  |
  `--> SSH :22 --> existing OpenSSH --> git user --> Forgejo serv

Forgejo
  +--> existing PostgreSQL 16 on loopback
  +--> /var/lib/forgejo persistent data
  `--> Forgejo Actions
          |
          v
     Forgejo Runner
     rootless Podman
```

## Why this shape

The selected host already provides Nginx, PostgreSQL 16, Certbot, Git, OpenSSH and Podman. V1 therefore minimizes change surface:

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

Acceptance passed:

```text
forgejo.service = active
127.0.0.1:3000 = listening
/api/healthz = healthy
PostgreSQL connection = healthy
initial admin = created
```

### Stage A incident / fix

The first apply exposed a bootstrap defect: Forgejo required `oauth2.JWT_SECRET` and attempted to persist it into the intentionally root-owned config.

Durable correction:

- bootstrap pre-generates `JWT_SECRET`;
- `[oauth2].JWT_SECRET` exists before first startup;
- `/etc/forgejo/app.ini` remains `root:git 0640`;
- the partial deployment was repaired through `scripts/repair-stage-a-oauth2-secret.sh`.

Do **not** paste `/root/devos-forge-initial-admin.txt` into chat.

## Stage B — Nginx + DNS + TLS — COMPLETE

### B1 — Nginx reverse proxy

`scripts/stage-b-nginx.sh` was previewed and applied successfully.

Validated:

- dedicated vhost for `git.criandofacil.com.br`;
- proxy target `http://127.0.0.1:3000`;
- `merge_slashes off`;
- required proxy/forwarded headers;
- 512 MiB body-size ceiling;
- `nginx -t` passes.

### B2 — DNS

`git.criandofacil.com.br` resolves to the selected VPS.

### B3 — TLS

Certbot completed successfully using the existing Nginx integration.

Validated:

```text
HTTPS = healthy
nginx -t = pass
https://git.criandofacil.com.br/api/healthz = status pass
```

Final web path:

```text
https://git.criandofacil.com.br
       -> Nginx :443
       -> 127.0.0.1:3000
       -> Forgejo
```

Forgejo itself remains plain HTTP on loopback; Nginx terminates TLS.

## Stage C — Git SSH

Use the existing OpenSSH service on port 22.

Forgejo runs with `START_SSH_SERVER = false`. `SSH_PORT = 22` is the port shown in clone URLs. In this system-OpenSSH mode Forgejo manages the dedicated `git` user's `authorized_keys` file by default; `forgejo admin regenerate keys` can rebuild that file from public keys stored in Forgejo.

Expected clone form:

```text
git@git.criandofacil.com.br:<owner>/<repo>.git
```

Do not open an additional SSH port unless system OpenSSH proves incompatible.

### C1 — read-only preflight

Repository script:

```text
scripts/stage-c-ssh-preflight.sh
```

Run:

```bash
curl -fsSL https://raw.githubusercontent.com/jaasielsantos/devos-forge/main/scripts/stage-c-ssh-preflight.sh | sudo bash
```

It checks without modifying the host:

- HTTPS health;
- Forgejo service state;
- OpenSSH service and port 22 listener;
- effective `sshd` settings including `AuthorizedKeysFile` and `StrictModes`;
- `git` OS account/home;
- `.ssh` / `authorized_keys` existence and permissions;
- non-secret Forgejo SSH settings;
- count/shape of Forgejo-managed authorized-key entries;
- DNS resolution.

### C2 — client key enrollment

Add **one explicitly intended client public key** to the `jaasielsantos` Forgejo account.

Never upload or paste a private SSH key. Do not automatically reuse arbitrary keys found on the VPS.

After the public key is stored in Forgejo, if needed rebuild the managed file:

```bash
sudo -u git /usr/local/bin/forgejo admin regenerate keys \
  --config /etc/forgejo/app.ini \
  --work-path /var/lib/forgejo
```

Then inspect only metadata/counts, not private material.

### C3 — SSH authentication test

From the intended client machine:

```bash
ssh -T git@git.criandofacil.com.br
```

A Forgejo-specific authenticated response is success; an interactive shell is neither expected nor desired.

### C4 — repository clone/push test

After a pilot repository exists in Forgejo:

```text
clone via SSH
 -> branch
 -> commit
 -> push
```

Stage C is complete only after SSH authentication and a real Git push both succeed.

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
