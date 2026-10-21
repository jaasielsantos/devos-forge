# DevOS Forge — VPS Preflight

This preflight is intentionally **read-only**. Its purpose is to map the current VPS before any Forgejo deployment decision is made.

Do not install, remove, restart, reconfigure, expose, or stop anything during this phase.

## Goal

Collect enough evidence to safely decide:

- whether the VPS has enough CPU, RAM and disk;
- what is already bound to ports 22/80/443 and other relevant ports;
- whether Docker and Docker Compose are already present;
- what reverse proxy is already in use;
- what Docker networks, volumes and containers already exist;
- whether PostgreSQL is already running somewhere;
- how firewalling is currently handled;
- what backup tooling already exists;
- what deployment topology will avoid collisions with existing services.

## Run this block on the VPS

```bash
set +e

echo '===== DEVOS FORGE PREFLIGHT ====='
date -Is
printf '\n===== HOST =====\n'
hostnamectl 2>/dev/null || true
printf '\nKernel: '; uname -a
printf '\nUptime:\n'; uptime

printf '\n===== CPU =====\n'
command -v lscpu >/dev/null && lscpu | sed -n '1,30p'

printf '\n===== MEMORY =====\n'
free -h

printf '\n===== DISK =====\n'
df -hT
printf '\nBlock devices:\n'
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS 2>/dev/null || true

printf '\n===== OS =====\n'
cat /etc/os-release 2>/dev/null || true

printf '\n===== NETWORK ADDRESSES =====\n'
ip -brief address 2>/dev/null || ip addr

printf '\n===== LISTENING PORTS =====\n'
ss -lntup 2>/dev/null || netstat -lntup 2>/dev/null || true

printf '\n===== DOCKER =====\n'
docker --version 2>/dev/null || echo 'Docker: not found'
docker info --format 'ServerVersion={{.ServerVersion}} Driver={{.Driver}} CgroupDriver={{.CgroupDriver}}' 2>/dev/null || true

printf '\n===== DOCKER COMPOSE =====\n'
docker compose version 2>/dev/null || docker-compose --version 2>/dev/null || echo 'Compose: not found'

printf '\n===== DOCKER CONTAINERS =====\n'
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null || true

printf '\n===== DOCKER NETWORKS =====\n'
docker network ls 2>/dev/null || true

printf '\n===== DOCKER VOLUMES =====\n'
docker volume ls 2>/dev/null || true

printf '\n===== REVERSE PROXY / WEB SERVER =====\n'
for x in caddy nginx traefik apache2 httpd; do
  if command -v "$x" >/dev/null 2>&1; then
    printf '%s: ' "$x"
    "$x" version 2>&1 | head -n 2
  fi
done

printf '\nPotential proxy containers:\n'
docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | grep -Ei 'caddy|nginx|traefik|apache|haproxy|proxy' || true

printf '\n===== POSTGRESQL =====\n'
psql --version 2>/dev/null || echo 'psql client: not found'
docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' 2>/dev/null | grep -Ei 'postgres|timescale' || true

printf '\n===== FIREWALL =====\n'
ufw status verbose 2>/dev/null || true
printf '\nnftables summary:\n'
nft list ruleset 2>/dev/null | sed -n '1,120p' || true
printf '\niptables summary:\n'
iptables -S 2>/dev/null | sed -n '1,120p' || true

printf '\n===== SSH =====\n'
ss -lntp 2>/dev/null | grep -E '(:22\b|sshd)' || true
sshd -T 2>/dev/null | grep -E '^(port|passwordauthentication|permitrootlogin|pubkeyauthentication) ' || true

printf '\n===== STORAGE HOTSPOTS =====\n'
du -xh --max-depth=1 /var/lib/docker 2>/dev/null | sort -h | tail -n 20 || true
du -xh --max-depth=1 /opt 2>/dev/null | sort -h | tail -n 20 || true

printf '\n===== COMMON DEPLOYMENT DIRECTORIES =====\n'
for d in /opt /srv /var/lib /var/backups /home; do
  printf '\n-- %s --\n' "$d"
  ls -lah "$d" 2>/dev/null | sed -n '1,80p'
done

printf '\n===== BACKUP TOOLS =====\n'
for x in restic borg rclone rsync duplicity; do
  if command -v "$x" >/dev/null 2>&1; then
    printf '%s: ' "$x"
    "$x" version 2>&1 | head -n 2
  fi
done

printf '\n===== SYSTEMD RELEVANT SERVICES =====\n'
systemctl --no-pager --type=service --state=running 2>/dev/null | grep -Ei 'docker|containerd|caddy|nginx|traefik|apache|postgres|ssh|fail2ban|crowdsec' || true

printf '\n===== CRON / TIMERS HINTS =====\n'
systemctl list-timers --all --no-pager 2>/dev/null | grep -Ei 'backup|restic|borg|rclone|snapshot|renew|cert' || true

printf '\n===== PREFLIGHT COMPLETE =====\n'
```

## Safety notes

The block above:

- does **not** install packages;
- does **not** change firewall rules;
- does **not** restart services;
- does **not** edit files;
- does **not** create containers;
- does **not** change DNS;
- does **not** expose ports.

Some sections may return `permission denied` or partial output when the current user lacks privileges. That is acceptable; do not elevate privileges solely to satisfy the preflight unless we explicitly decide to do so.

## Secrets hygiene

Before sharing output, quickly scan it for accidental secrets. The commands are designed not to print environment variables, Docker inspect payloads, configuration files, database contents, private keys, tokens, or credentials.

If an existing service name or path itself is sensitive, redact that specific value while preserving the surrounding technical information.

## What happens after collection

The preflight output is analyzed against these decision areas:

| Area | Decision to make |
|---|---|
| Compute | Can Forgejo + PostgreSQL + runner coexist safely? |
| Disk | Where should repositories, DB, artifacts and backups live? |
| Ports | Which ingress and SSH strategy avoids conflicts? |
| Proxy | Reuse existing proxy or deploy a dedicated one? |
| Docker | Reuse existing Docker runtime/network conventions? |
| Database | Dedicated PostgreSQL container or existing service? |
| Runner | Same host, isolated Docker execution, limits and labels |
| Firewall | Minimum external exposure required |
| Backup | Local staging + offsite destination + retention |
| Recovery | Exact restore order and RPO/RTO assumptions |

Only after this analysis should `docs/DEPLOYMENT.md` become an executable deployment runbook.

## Preflight exit criteria

- [ ] host/OS mapped;
- [ ] CPU/RAM mapped;
- [ ] storage and mount points mapped;
- [ ] listening ports mapped;
- [ ] Docker/Compose state mapped;
- [ ] running containers mapped;
- [ ] proxy/web stack identified;
- [ ] PostgreSQL conflicts identified;
- [ ] firewall state understood;
- [ ] SSH exposure understood;
- [ ] backup tooling identified;
- [ ] safe deployment topology proposed.
