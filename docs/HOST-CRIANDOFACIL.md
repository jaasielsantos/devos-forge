# DevOS Forge — Host Baseline: `criandofacil-vps`

## Purpose

Record the selected V1 host, known facts from the initial read-only preflight, and the exact second inspection required before installation.

This document is evidence-driven. Do not infer unobserved host configuration.

## Selected host

- SSH alias used operationally: `criandofacil-vps`
- current hostname: `srv1805473`
- role: DevOS Forge V1 single-host runtime
- operating system: Ubuntu 24.04 LTS family
- virtualization: KVM
- architecture: x86-64

## Initial capacity snapshot

Observed during the first preflight:

- 1 vCPU;
- approximately 3.8 GiB RAM;
- approximately 3.2 GiB memory available at capture time;
- 2 GiB swap;
- approximately 34 GiB free on the root filesystem;
- low host load at capture time.

These values are a baseline, not capacity guarantees.

## Existing infrastructure observed

### Ingress / TLS

- Nginx is installed and active.
- ports 80 and 443 are already bound.
- Certbot timer exists.

Implication: reuse the existing Nginx/TLS model unless the directed inspection finds a blocking constraint.

### PostgreSQL

- PostgreSQL 16 is installed and active.
- the database listens on loopback (`127.0.0.1:5432` / `::1:5432`) rather than a public interface.

Implication: prefer a dedicated Forgejo database and database user in the existing PostgreSQL instance instead of deploying a second PostgreSQL stack.

### Existing applications

The initial preflight observed local application listeners, including services bound to loopback ports. DevOS Forge must not reuse an occupied port or alter existing upstreams without explicit review.

### Docker

Docker and Docker Compose were not present in the initial preflight.

This is not yet a decision to install Docker. The directed inspection must first identify existing runner/service patterns and then choose between:

1. Forgejo as a native binary + systemd, with Docker introduced only for runner job isolation; or
2. Forgejo containerized, if doing so provides a clear operational benefit without duplicating the host's existing Nginx/PostgreSQL stack.

The preferred default is the smaller change surface.

### Existing runner evidence

A `cf-gh-runner` home directory exists, indicating GitHub Actions runner infrastructure is or was present on this host.

The second inspection must identify how that runner is installed and managed without printing credentials, tokens, or secret environment values.

## V1 target topology

```text
Internet
   |
   v
existing Nginx :80/:443
   |
   v
Forgejo (localhost-only web upstream)
   |
   +--> existing PostgreSQL 16
   |
   +--> persistent Forgejo/Git data
   |
   `--> Forgejo Actions
            |
            +--> runner capacity (target: up to 2 concurrent jobs)
```

The exact Forgejo web port, SSH Git exposure, service packaging, storage paths, and runner isolation are still pending the directed inspection.

## Safety boundary for second inspection

The commands below are discovery-only.

Do not:

- install packages;
- modify Nginx;
- reload or restart services;
- modify PostgreSQL;
- create users/databases;
- install Docker;
- expose ports;
- edit firewall rules;
- change DNS;
- print secret files, tokens, private keys, database passwords, or environment variable values.

## Directed preflight — run on `criandofacil-vps`

Connect first:

```bash
ssh criandofacil-vps
```

Then run:

```bash
set +e

echo '===== DEVOS FORGE DIRECTED PREFLIGHT: CRIANDOFACIL ====='
date -Is
hostnamectl 2>/dev/null | sed -n '1,20p'

printf '\n===== CAPACITY NOW =====\n'
uptime
free -h
df -hT /

printf '\n===== NGINX VERSION / SERVICE =====\n'
nginx -v 2>&1 || true
systemctl --no-pager --full status nginx 2>/dev/null | sed -n '1,35p' || true

printf '\n===== NGINX CONFIG VALIDATION (READ ONLY) =====\n'
sudo nginx -t 2>&1 || true

printf '\n===== NGINX ENABLED SITES =====\n'
find /etc/nginx/sites-enabled -maxdepth 1 -type l -printf '%f -> %l\n' 2>/dev/null | sort || true

printf '\n===== NGINX SERVER/UPSTREAM MAP =====\n'
sudo nginx -T 2>/dev/null \
  | grep -E '^[[:space:]]*(server_name|listen|proxy_pass|upstream)[[:space:]]' \
  | sed -E 's/(proxy_pass[[:space:]]+https?:\/\/)[^;[:space:]]+/\1<upstream>/g' \
  | sed -n '1,240p' || true

printf '\n===== CERTBOT / CERTIFICATES =====\n'
certbot --version 2>/dev/null || true
sudo certbot certificates 2>/dev/null \
  | grep -E 'Certificate Name:|Domains:|Expiry Date:|Certificate Path:' \
  | sed -n '1,160p' || true
systemctl list-timers --all --no-pager 2>/dev/null | grep -i certbot || true

printf '\n===== POSTGRESQL VERSION / CLUSTERS =====\n'
psql --version 2>/dev/null || true
pg_lsclusters 2>/dev/null || true
systemctl --no-pager --full status postgresql@16-main 2>/dev/null | sed -n '1,35p' || true

printf '\n===== POSTGRESQL LISTENING =====\n'
ss -lntp 2>/dev/null | grep ':5432' || true

printf '\n===== POSTGRESQL DATABASE NAMES ONLY =====\n'
sudo -u postgres psql -Atqc "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" 2>/dev/null || true

printf '\n===== POSTGRESQL ROLE NAMES ONLY =====\n'
sudo -u postgres psql -Atqc "SELECT rolname FROM pg_roles ORDER BY rolname;" 2>/dev/null || true

printf '\n===== CURRENT LISTENERS =====\n'
ss -lntup 2>/dev/null | sed -n '1,200p'

printf '\n===== EXISTING RUNNER PROCESSES =====\n'
ps -eo user,pid,ppid,etimes,cmd \
  | grep -Ei 'actions-runner|Runner.Listener|Runner.Worker|forgejo.*runner|act_runner' \
  | grep -v grep \
  | sed -E 's/(--token|--registration-token|token=)[^[:space:]]+/\1<redacted>/gi' \
  | sed -n '1,120p' || true

printf '\n===== RUNNER SERVICE UNIT NAMES =====\n'
systemctl list-unit-files --no-pager 2>/dev/null \
  | grep -Ei 'runner|actions' \
  | sed -n '1,120p' || true
systemctl --no-pager --type=service --all 2>/dev/null \
  | grep -Ei 'runner|actions' \
  | sed -n '1,120p' || true

printf '\n===== RUNNER HOME STRUCTURE (NAMES ONLY) =====\n'
sudo find /home/cf-gh-runner -maxdepth 2 \
  -mindepth 1 \
  -printf '%y %p\n' 2>/dev/null \
  | grep -Ev '/(_diag|_work)(/|$)' \
  | sed -n '1,160p' || true

printf '\n===== DOCKER / CONTAINER RUNTIME CHECK =====\n'
command -v docker || true
command -v podman || true
command -v nerdctl || true
command -v containerd || true
systemctl list-unit-files --no-pager 2>/dev/null \
  | grep -Ei 'docker|podman|containerd' \
  | sed -n '1,80p' || true

printf '\n===== FIREWALL / SECURITY SERVICES =====\n'
sudo ufw status verbose 2>/dev/null || true
systemctl --no-pager --type=service --state=running 2>/dev/null \
  | grep -Ei 'fail2ban|crowdsec|ufw|nftables' || true

printf '\n===== SSH EFFECTIVE NON-SECRET SETTINGS =====\n'
sudo sshd -T 2>/dev/null \
  | grep -E '^(port|listenaddress|passwordauthentication|pubkeyauthentication|permitrootlogin|maxauthtries|maxsessions) ' || true

printf '\n===== CANDIDATE STORAGE LOCATIONS =====\n'
for d in /opt /srv /var/lib /var/backups; do
  echo "-- $d --"
  sudo du -sh "$d"/* 2>/dev/null | sort -h | tail -n 30
  echo
done

printf '\n===== EXISTING BACKUP SERVICES/TIMERS =====\n'
systemctl list-unit-files --no-pager 2>/dev/null \
  | grep -Ei 'backup|restic|borg|rclone|snapshot' \
  | sed -n '1,120p' || true
systemctl list-timers --all --no-pager 2>/dev/null \
  | grep -Ei 'backup|restic|borg|rclone|snapshot' \
  | sed -n '1,120p' || true

printf '\n===== RELEVANT PACKAGE PRESENCE =====\n'
dpkg-query -W -f='${binary:Package}\t${Version}\n' 2>/dev/null \
  | grep -Ei '^(nginx|postgresql|certbot|fail2ban|docker|containerd|podman|git|openssh-server)' \
  | sed -n '1,160p' || true

printf '\n===== DIRECTED PREFLIGHT COMPLETE =====\n'
```

## What this inspection will decide

After reviewing the output, lock these items:

1. Forgejo packaging: native binary/systemd vs container;
2. exact local web bind address and port;
3. Nginx vhost/upstream pattern;
4. Forgejo database name/user and connection path;
5. Git-over-SSH strategy without disturbing administrative SSH;
6. runner runtime/isolation strategy;
7. initial concurrency setting (up to two jobs);
8. persistent data paths;
9. backup integration and offsite destination;
10. exact deployment and rollback sequence.

## Exit condition

This host-preflight stage is complete when `docs/DEPLOYMENT.md` can be converted from a generic baseline into commands and files that are specific to `criandofacil-vps`, with no unresolved port, ingress, database, runner, or storage collisions.
