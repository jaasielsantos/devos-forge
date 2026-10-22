#!/usr/bin/env bash
set -Eeuo pipefail

# Repairs the specific Stage A failure where Forgejo cannot persist
# oauth2.JWT_SECRET because /etc/forgejo/app.ini is intentionally root-owned.
# Safe scope: stops/starts forgejo.service, appends a pre-generated
# [oauth2] JWT_SECRET when that section is absent, validates local health,
# and completes initial admin creation when it was not reached previously.

FORGEJO_BIN="/usr/local/bin/forgejo"
FORGEJO_CONFIG="/etc/forgejo/app.ini"
FORGEJO_USER="git"
FORGEJO_GROUP="git"
FORGEJO_HOME="/var/lib/forgejo"
FORGEJO_HTTP_ADDR="127.0.0.1"
FORGEJO_HTTP_PORT="3000"
ADMIN_USER="jaasielsantos"
ADMIN_EMAIL="jaasiel@localhost.invalid"
ADMIN_SECRET_FILE="/root/devos-forge-initial-admin.txt"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0" >&2
  exit 1
fi

[[ -x "$FORGEJO_BIN" ]] || { echo "Forgejo binary not found: $FORGEJO_BIN" >&2; exit 1; }
[[ -f "$FORGEJO_CONFIG" ]] || { echo "Forgejo config not found: $FORGEJO_CONFIG" >&2; exit 1; }
id "$FORGEJO_USER" >/dev/null 2>&1 || { echo "Forgejo OS user not found: $FORGEJO_USER" >&2; exit 1; }

if grep -Eq '^[[:space:]]*\[oauth2\][[:space:]]*$' "$FORGEJO_CONFIG"; then
  if awk '
    /^[[:space:]]*\[oauth2\][[:space:]]*$/ {in_oauth2=1; next}
    /^[[:space:]]*\[/ {in_oauth2=0}
    in_oauth2 && /^[[:space:]]*JWT_SECRET[[:space:]]*=/ {found=1}
    END {exit found ? 0 : 1}
  ' "$FORGEJO_CONFIG"; then
    echo "oauth2.JWT_SECRET is already configured; no config repair needed."
  else
    echo "[oauth2] exists but JWT_SECRET is missing; refusing automatic edit." >&2
    exit 1
  fi
else
  echo "Stopping forgejo.service to repair configuration..."
  systemctl stop forgejo || true

  OAUTH2_JWT_SECRET="$(sudo -u "$FORGEJO_USER" "$FORGEJO_BIN" generate secret JWT_SECRET)"
  printf '\n[oauth2]\nJWT_SECRET = %s\n' "$OAUTH2_JWT_SECRET" >> "$FORGEJO_CONFIG"
  unset OAUTH2_JWT_SECRET

  chown root:"$FORGEJO_GROUP" "$FORGEJO_CONFIG"
  chmod 0640 "$FORGEJO_CONFIG"
fi

echo "Starting forgejo.service..."
systemctl reset-failed forgejo || true
systemctl start forgejo

healthy=false
for _ in {1..30}; do
  if curl -fsS "http://${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}/api/healthz" >/dev/null 2>&1; then
    healthy=true
    break
  fi
  sleep 1
done

if ! $healthy; then
  echo "Forgejo did not become healthy. Recent service log:" >&2
  journalctl -u forgejo -n 80 --no-pager >&2
  exit 1
fi

echo "Forgejo health check passed at ${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}."

echo "Checking initial admin..."
if sudo -u "$FORGEJO_USER" "$FORGEJO_BIN" admin user list \
  --config "$FORGEJO_CONFIG" \
  --work-path "$FORGEJO_HOME" \
  | grep -q "$ADMIN_USER"; then
  echo "Initial admin already exists: ${ADMIN_USER}"
else
  ADMIN_PASS="$(openssl rand -base64 30 | tr -d '\n' | tr '/+' 'AZ')"
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
  unset ADMIN_PASS
  echo "Initial admin created. Secret stored root-only at ${ADMIN_SECRET_FILE}."
fi

echo
echo "===== FORGEJO STATUS ====="
systemctl --no-pager --full status forgejo | sed -n '1,22p'
echo
echo "===== LOCAL HEALTH ====="
curl -fsS "http://${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}/api/healthz"
echo
echo "Stage A repair/completion successful."
