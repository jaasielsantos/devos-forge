#!/usr/bin/env bash
set -Eeuo pipefail

# Repairs the specific Stage A failure where Forgejo cannot persist
# oauth2.JWT_SECRET because /etc/forgejo/app.ini is intentionally root-owned.
# Safe scope: only stops/starts forgejo.service and appends a pre-generated
# [oauth2] JWT_SECRET when that section is absent.

FORGEJO_BIN="/usr/local/bin/forgejo"
FORGEJO_CONFIG="/etc/forgejo/app.ini"
FORGEJO_USER="git"
FORGEJO_GROUP="git"
FORGEJO_HTTP_ADDR="127.0.0.1"
FORGEJO_HTTP_PORT="3000"

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
    echo "oauth2.JWT_SECRET is already configured; nothing to repair."
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

for _ in {1..30}; do
  if curl -fsS "http://${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}/api/healthz" >/dev/null 2>&1; then
    echo "Forgejo health check passed at ${FORGEJO_HTTP_ADDR}:${FORGEJO_HTTP_PORT}."
    systemctl --no-pager --full status forgejo | sed -n '1,22p'
    exit 0
  fi
  sleep 1
done

echo "Forgejo did not become healthy. Recent service log:" >&2
journalctl -u forgejo -n 80 --no-pager >&2
exit 1
