#!/usr/bin/env bash
set -Eeuo pipefail

# DevOS Forge Stage B1: configure the existing Nginx instance as the HTTP
# reverse proxy for Forgejo. Safe by default: run without --apply to preview.
# This stage does NOT request TLS certificates or change DNS/firewall/sshd.

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

DOMAIN="git.criandofacil.com.br"
UPSTREAM="http://127.0.0.1:3000"
SITE_AVAILABLE="/etc/nginx/sites-available/devos-forge"
SITE_ENABLED="/etc/nginx/sites-enabled/devos-forge"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 [--apply]" >&2
  exit 1
fi

say() { printf '\n==> %s\n' "$*"; }

say "DevOS Forge Stage B1 — Nginx reverse proxy"
echo "mode=$($APPLY && echo APPLY || echo DRY-RUN)"
echo "domain=${DOMAIN}"
echo "upstream=${UPSTREAM}"

say "Guard checks"
command -v nginx >/dev/null || { echo "nginx not found" >&2; exit 1; }
systemctl is-active --quiet nginx || { echo "nginx is not active" >&2; exit 1; }
systemctl is-active --quiet forgejo || { echo "forgejo is not active" >&2; exit 1; }
curl -fsS "${UPSTREAM}/api/healthz" >/dev/null || { echo "Forgejo local health check failed" >&2; exit 1; }
nginx -t >/dev/null

if grep -RqsE "server_name[[:space:]]+${DOMAIN//./\\.}([[:space:];]|$)" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null; then
  echo "An enabled Nginx server_name for ${DOMAIN} already exists; refusing to overwrite." >&2
  grep -RnsE "server_name[[:space:]]+${DOMAIN//./\\.}([[:space:];]|$)" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null || true
  exit 1
fi

say "Planned Nginx vhost"
cat <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    merge_slashes off;

    location / {
        proxy_pass ${UPSTREAM};
        proxy_set_header Connection \$http_connection;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 512M;
    }
}
EOF

$APPLY || {
  echo
  echo "Dry-run complete. Re-run with --apply to install this HTTP vhost."
  echo "TLS is intentionally a separate step after DNS resolves correctly."
  exit 0
}

say "Install Nginx vhost"
cat > "$SITE_AVAILABLE" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    merge_slashes off;

    location / {
        proxy_pass ${UPSTREAM};
        proxy_set_header Connection \$http_connection;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        client_max_body_size 512M;
    }
}
EOF
chmod 0644 "$SITE_AVAILABLE"
ln -s "$SITE_AVAILABLE" "$SITE_ENABLED"

say "Validate and reload Nginx"
nginx -t
systemctl reload nginx

say "Local Host-header smoke test"
curl -fsS -H "Host: ${DOMAIN}" http://127.0.0.1/api/healthz
printf '\n'

echo
echo "Stage B1 complete."
echo "Next: create/verify DNS for ${DOMAIN}, then request TLS with Certbot."
