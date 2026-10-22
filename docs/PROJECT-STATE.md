# DevOS Forge — Project State

## Status

**Phase:** 1 — Git SSH validation  
**Implementation:** Stage A and Stage B complete; Stage C preflight clean; client key enrollment next  
**Selected V1 host:** `criandofacil-vps` (`srv1805473`)  
**Pilot repository:** `devos-forge`

## Current objective

Enroll one explicitly intended client public SSH key into the `jaasielsantos` Forgejo account, validate authentication through the existing system OpenSSH service on port 22, then prove clone/push before moving to Forgejo Runner + rootless Podman.

## Locked V1 topology

```text
Chat / CLI / Git / SSH / API
          |
          v
Nginx :443 + TLS
          |
          v
Forgejo 15 LTS
native binary + systemd
127.0.0.1:3000
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

Git SSH uses the existing OpenSSH daemon on port 22 with the dedicated OS user `git`. V1 remains on one VPS.

## Locked deployment decisions

- native Forgejo binary + systemd;
- Forgejo 15 LTS, pinned to 15.0.10 for bootstrap;
- reuse existing Nginx and Certbot;
- reuse existing PostgreSQL 16 with dedicated `forgejo` DB/role;
- Forgejo HTTP on `127.0.0.1:3000` only;
- public hostname `git.criandofacil.com.br`;
- public HTTPS through Nginx on 443;
- system OpenSSH port 22 for Git SSH;
- dedicated Forgejo Runner + rootless Podman;
- runner capacity 1 while GitHub runner coexists;
- target runner capacity 2 after GitHub runner retirement and load validation;
- no custom V1 UI;
- `devos-forge` is the pilot repository.

## Stage A — completed

Validated:

- `forgejo.service` active and enabled;
- Forgejo listens only on `127.0.0.1:3000`;
- `/api/healthz` returns `status: pass`;
- cache and PostgreSQL health pass;
- initial local administrator created.

The first apply exposed a missing `oauth2.JWT_SECRET`. The durable bootstrap now pre-generates it while preserving `/etc/forgejo/app.ini` as `root:git 0640`.

## Stage B — completed

Validated:

- dedicated Nginx vhost installed for `git.criandofacil.com.br`;
- upstream remains `http://127.0.0.1:3000`;
- DNS points the hostname to the selected VPS;
- Certbot issued TLS and configured HTTPS redirect;
- `nginx -t` passes;
- `https://git.criandofacil.com.br/api/healthz` returns `status: pass`.

Existing unrelated `doxa-upload` Nginx warnings remain non-blocking and unchanged.

## Stage C — Git SSH

Forgejo uses system OpenSSH rather than its built-in SSH server.

Official Forgejo behavior for this model:

- `START_SSH_SERVER = false`;
- `SSH_PORT = 22` controls the clone URL;
- when the internal SSH server is disabled, Forgejo manages the dedicated `git` user's `authorized_keys` file by default;
- the file is expected to contain only Forgejo-managed keys/commands;
- `forgejo admin regenerate keys` can rebuild it from keys stored in Forgejo.

### C1 — preflight COMPLETE

Validated on the target host:

- HTTPS health = pass;
- `forgejo.service` active/enabled;
- OpenSSH active and listening on IPv4/IPv6 port 22;
- `PubkeyAuthentication yes`;
- `AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2`;
- `StrictModes yes`;
- `PermitRootLogin no`;
- dedicated `git` account exists with home `/var/lib/forgejo`;
- `/var/lib/forgejo/.ssh` ownership and modes are correct;
- `/var/lib/forgejo/.ssh/authorized_keys` exists as `git:git 0600`;
- Forgejo SSH configuration points to `git.criandofacil.com.br:22` with built-in SSH disabled;
- DNS resolves to the selected VPS;
- authorized key count is currently zero, which is expected before first client enrollment.

### C2 — next gate: enroll intended client key

Add one explicitly intended **public** SSH key to the `jaasielsantos` Forgejo account. Never copy/import arbitrary VPS keys and never expose a private key.

After enrollment, Forgejo should manage the corresponding entry in `/var/lib/forgejo/.ssh/authorized_keys`. Regenerate only if needed:

```bash
sudo -u git /usr/local/bin/forgejo admin regenerate keys \
  --config /etc/forgejo/app.ini \
  --work-path /var/lib/forgejo
```

Then test from the intended client:

```bash
ssh -T git@git.criandofacil.com.br
```

Stage C completes only after a real SSH clone and push succeed.

## Executable artifacts

- `docs/RUNBOOK-V1.md`
- `docs/ADR-001-V1-DEPLOYMENT.md`
- `scripts/bootstrap-server-v1.sh`
- `scripts/repair-stage-a-oauth2-secret.sh`
- `scripts/stage-b-nginx.sh`
- `scripts/stage-c-ssh-preflight.sh`
- `docs/HOST-CRIANDOFACIL.md`
- `docs/DEPLOYMENT.md`

## Security gate

The GitHub repository is public. Never commit runtime passwords, tokens, private keys, database credentials, generated Forgejo secrets, certificate private keys, or private SSH keys.

Client SSH access must be granted only by adding an explicitly intended **public** key to the Forgejo account. Do not reuse or copy arbitrary host keys merely because they already exist on the VPS.

## Phase 1 sequence

```text
[x] Stage A  local Forgejo bootstrap + health
[x] Stage B  Nginx + DNS + TLS
[~] Stage C  SSH preflight clean; key enrollment/auth/clone-push pending
[ ] Stage D  Forgejo Runner + Podman
[ ] Stage E  migrate devos-forge pilot
[ ] Stage F  backup + restore rehearsal
[ ] Stage G  Forgejo becomes source of truth
```

## Immediate next action

On the intended client computer, identify or create one Ed25519 SSH keypair. Add only the `.pub` key to the `jaasielsantos` Forgejo account, then validate:

```bash
ssh -T git@git.criandofacil.com.br
```

Do not proceed to Forgejo Runner until SSH authentication and a real clone/push operation are confirmed.
