#!/usr/bin/env bash
set -Eeuo pipefail

# DevOS Forge V1 bootstrap for criandofacil-vps.
# Safe by default: run without --apply to inspect the plan.
# This script deliberately does NOT touch Nginx, DNS, Certbot, UFW, SSHD,
# Forgejo Runner, or the existing GitHub Actions runner.

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

FORGEJO_VERSION="15.0.10"
FORGEJO_DOMAIN="git.criandofacil.com.br"
FORGEJO_HTTP_ADDR="127.0.0.1"
FORGEJO_HTTP_PORT="3000"
FORGEJO_USER="git"
FORGEJO_GROUP="git"
FORGEJO_HOME="/var/lib/forgejo"
FORGEJO_CONFIG="/etc/forgejo/app.ini"
FORGEJO_LOG="/var/log/forgejo"
FORGEJO_BIN="/usr/local/bin/forgejo"
DB_NAME="forgejo"
DB_USER="forgejo"
ADMIN_USER="jaasielsantos"
ADMIN_EMAIL="jaasiel@localhost.invalid"
ADMIN_SECRET_FILE="/root/devos-forge-initial-admin.txt"

say() { printf '\n==> %s\n' "$*"; }
run() {
  if $APPLY; then
    printf '+ %q ' "$@"; printf '\n'
    "$@"
  else
    printf '[dry-run] '; printf '%q ' "$@"; printf '\n'
  fi
}

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 [--apply]" >&2
  exit 1
fi

say "DevOS Forge V1 bootstrap"
echo "mode=$($APPLY && echo APPLY || echo DRY-RUN)"
echo "forgejo=${FORGEJO_VERSION}"
echo "domain=${FORGEJO_DOMAIN}"
echo "web=${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}"

say "Guard checks"
command -v nginx >/dev/null || { echo "nginx not found" >&2; exit 1; }
command -v psql >/dev/null || { echo "psql not found" >&2; exit 1; }
command -v git >/dev/null || { echo "git not found" >&2; exit 1; }
systemctl is-active --quiet nginx || { echo "nginx is not active" >&2; exit 1; }
systemctl is-active --quiet postgresql || systemctl is-active --quiet postgresql@16-main || { echo "postgresql is not active" >&2; exit 1; }

if ss -lnt | awk '{print $4}' | grep -Eq '(^|:)3000$'; then
  echo "Port 3000 is already in use; refusing to continue." >&2
  ss -lntp | grep ':3000' || true
  exit 1
fi

if [[ -e "$FORGEJO_CONFIG" || -e "$FORGEJO_BIN" ]]; then
  echo "Existing Forgejo files detected; refusing bootstrap to avoid overwriting an installation." >&2
  ls -l "$FORGEJO_CONFIG" "$FORGEJO_BIN" 2>/dev/null || true
  exit 1
fi

say "Plan"
cat <<EOF
1. Ensure download/verification tools exist.
2. Download and verify Forgejo v${FORGEJO_VERSION}.
3. Create dedicated OS user '${FORGEJO_USER}'.
4. Create dedicated PostgreSQL role/database.
5. Create root-owned Forgejo configuration with all required secrets pre-generated.
6. Install a systemd service bound only to ${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}.
7. Create one local admin user (${ADMIN_USER}) with a random initial password.
8. Start Forgejo and verify localhost health.

NOT touched in this stage:
- Nginx configuration
- DNS / TLS / Certbot
- firewall
- sshd
- existing GitHub runner
- Forgejo Runner / Podman runner socket
EOF

$APPLY || { echo; echo "Dry-run complete. Re-run with --apply to execute."; exit 0; }

say "Install prerequisites when missing"
export DEBIAN_FRONTEND=noninteractive
missing=()
for cmd in curl gpg openssl; do
  command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done
if ((${#missing[@]})); then
  apt-get update
  apt-get install -y curl ca-certificates gnupg openssl
fi

say "Download and verify Forgejo"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"
arch="$(uname -m)"
case "$arch" in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac
base="https://codeberg.org/forgejo/forgejo/releases/download/v${FORGEJO_VERSION}"
bin="forgejo-${FORGEJO_VERSION}-linux-${arch}"
curl -fL --retry 3 -o forgejo "${base}/${bin}"
curl -fL --retry 3 -o forgejo.asc "${base}/${bin}.asc"
gpg --keyserver hkps://keys.openpgp.org --recv EB114F5E6C0DC2BCDD183550A4B61A2DC5923710
gpg --verify forgejo.asc forgejo
install -m 0755 forgejo "$FORGEJO_BIN"
"$FORGEJO_BIN" --version

say "Create Forgejo OS account and directories"
if ! id "$FORGEJO_USER" >/dev/null 2>&1; then
  useradd --system --create-home --home-dir "$FORGEJO_HOME" --shell /bin/bash --user-group "$FORGEJO_USER"
fi
install -d -o "$FORGEJO_USER" -g "$FORGEJO_GROUP" -m 0750 "$FORGEJO_HOME"
install -d -o "$FORGEJO_USER" -g "$FORGEJO_GROUP" -m 0750 "$FORGEJO_HOME/data" "$FORGEJO_HOME/custom"
install -d -o "$FORGEJO_USER" -g "$FORGEJO_GROUP" -m 0750 "$FORGEJO_HOME/.ssh"
install -d -o "$FORGEJO_USER" -g "$FORGEJO_GROUP" -m 0750 "$FORGEJO_LOG"
install -d -o root -g "$FORGEJO_GROUP" -m 0750 /etc/forgejo

say "Create PostgreSQL role/database"
DB_PASS="$(openssl rand -hex 32)"
sudo -u postgres psql -v ON_ERROR_STOP=1 --set=db_user="$DB_USER" --set=db_name="$DB_NAME" --set=db_pass="$DB_PASS" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_user', :'db_pass')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user') \gexec
SELECT format('CREATE DATABASE %I OWNER %I TEMPLATE template0 ENCODING ''UTF8''', :'db_name', :'db_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'db_name') \gexec
SQL
PGPASSWORD="$DB_PASS" psql -h 127.0.0.1 -U "$DB_USER" -d "$DB_NAME" -Atqc 'SELECT 1' | grep -qx 1

say "Generate Forgejo secrets and configuration"
SECRET_KEY="$(sudo -u "$FORGEJO_USER" "$FORGEJO_BIN" generate secret SECRET_KEY)"
INTERNAL_TOKEN="$(sudo -u "$FORGEJO_USER" "$FORGEJO_BIN" generate secret INTERNAL_TOKEN)"
OAUTH2_JWT_SECRET="$(sudo -u "$FORGEJO_USER" "$FORGEJO_BIN" generate secret JWT_SECRET)"
cat > "$FORGEJO_CONFIG" <<EOF
APP_NAME = DevOS Forge
RUN_USER = ${FORGEJO_USER}
RUN_MODE = prod
WORK_PATH = ${FORGEJO_HOME}

[server]
DOMAIN = ${FORGEJO_DOMAIN}
ROOT_URL = https://${FORGEJO_DOMAIN}/
HTTP_ADDR = ${FORGEJO_HTTP_ADDR}
HTTP_PORT = ${FORGEJO_HTTP_PORT}
PROTOCOL = http
START_SSH_SERVER = false
SSH_DOMAIN = ${FORGEJO_DOMAIN}
SSH_PORT = 22
APP_DATA_PATH = ${FORGEJO_HOME}/data

[database]
DB_TYPE = postgres
HOST = 127.0.0.1:5432
NAME = ${DB_NAME}
USER = ${DB_USER}
PASSWD = ${DB_PASS}
SSL_MODE = disable

[repository]
ROOT = ${FORGEJO_HOME}/data/forgejo-repositories

[log]
MODE = console,file
ROOT_PATH = ${FORGEJO_LOG}
LEVEL = Info

[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = true

[actions]
ENABLED = true

[security]
INSTALL_LOCK = true
SECRET_KEY = ${SECRET_KEY}
INTERNAL_TOKEN = ${INTERNAL_TOKEN}
GLOBAL_TWO_FACTOR_REQUIREMENT = admin

[oauth2]
JWT_SECRET = ${OAUTH2_JWT_SECRET}
EOF
chown root:"$FORGEJO_GROUP" "$FORGEJO_CONFIG"
chmod 0640 "$FORGEJO_CONFIG"

say "Install systemd unit"
cat > /etc/systemd/system/forgejo.service <<EOF
[Unit]
Description=Forgejo
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=${FORGEJO_USER}
Group=${FORGEJO_GROUP}
WorkingDirectory=${FORGEJO_HOME}
Environment=USER=${FORGEJO_USER}
Environment=HOME=${FORGEJO_HOME}
ExecStart=${FORGEJO_BIN} web --config ${FORGEJO_CONFIG} --work-path ${FORGEJO_HOME}
Restart=always
RestartSec=2s
TimeoutSec=300
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now forgejo

say "Wait for Forgejo local endpoint"
for _ in {1..30}; do
  if curl -fsS "http://${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}/api/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
curl -fsS "http://${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}/api/healthz" >/dev/null

say "Create initial local admin"
ADMIN_PASS="$(openssl rand -base64 30 | tr -d '\n' | tr '/+' 'AZ')"
if ! sudo -u "$FORGEJO_USER" "$FORGEJO_BIN" admin user list --config "$FORGEJO_CONFIG" --work-path "$FORGEJO_HOME" | grep -q "$ADMIN_USER"; then
  sudo -u "$FORGEJO_USER" "$FORGEJO_BIN" admin user create \
    --config "$FORGEJO_CONFIG" \
    --work-path "$FORGEJO_HOME" \
    --username "$ADMIN_USER" \
    --password "$ADMIN_PASS" \
    --email "$ADMIN_EMAIL" \
    --admin
  umask 077
  cat > "$ADMIN_SECRET_FILE" <<EOF
DevOS Forge initial local admin
username: ${ADMIN_USER}
email: ${ADMIN_EMAIL}
password: ${ADMIN_PASS}

Do not paste this file into chat or commit it to Git.
Change the email/password after first login/API setup.
EOF
  chmod 0600 "$ADMIN_SECRET_FILE"
fi

say "Validation"
systemctl --no-pager --full status forgejo | sed -n '1,25p'
ss -lntp | grep ":${FORGEJO_HTTP_PORT}" || true
curl -fsS "http://${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}/api/healthz" && echo

echo
echo "Forgejo local bootstrap complete."
echo "Local endpoint: http://${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}"
echo "Initial admin secret file (root-only): ${ADMIN_SECRET_FILE}"
echo "Next stage: DNS + Nginx + TLS, then Forgejo Runner registration."
