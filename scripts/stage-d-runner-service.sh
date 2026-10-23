#!/usr/bin/env bash
set -Eeuo pipefail

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

RUNNER_USER="forgejo-runner"
RUNNER_GROUP="forgejo-runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_BIN="/usr/local/bin/forgejo-runner"
RUNNER_CONFIG="${RUNNER_HOME}/runner-config.yml"
SERVICE_FILE="/etc/systemd/system/forgejo-runner.service"

say() { printf '\n==> %s\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 [--apply]" >&2
  exit 1
fi

say "Stage D — Forgejo Runner systemd service"
echo "mode=$($APPLY && echo APPLY || echo DRY-RUN)"
echo "runner_user=${RUNNER_USER}"
echo "runner_config=${RUNNER_CONFIG}"

say "Guard checks"
id "$RUNNER_USER" >/dev/null 2>&1 || { echo "Missing runner user: $RUNNER_USER" >&2; exit 1; }
[[ -x "$RUNNER_BIN" ]] || { echo "Missing runner binary: $RUNNER_BIN" >&2; exit 1; }
[[ -s "$RUNNER_CONFIG" ]] || { echo "Missing runner config: $RUNNER_CONFIG" >&2; exit 1; }

runner_uid="$(id -u "$RUNNER_USER")"
runner_gid="$(id -g "$RUNNER_USER")"
runtime_dir="/run/user/${runner_uid}"
podman_socket="${runtime_dir}/podman/podman.sock"

[[ -S "$podman_socket" ]] || { echo "Podman socket not found: $podman_socket" >&2; exit 1; }

owner="$(stat -c '%U:%G' "$RUNNER_CONFIG")"
mode="$(stat -c '%a' "$RUNNER_CONFIG")"
[[ "$owner" == "${RUNNER_USER}:${RUNNER_GROUP}" ]] || { echo "Unexpected config owner: $owner" >&2; exit 1; }
[[ "$mode" == "600" ]] || { echo "Unexpected config mode: $mode" >&2; exit 1; }

grep -Eq '^[[:space:]]*capacity:[[:space:]]*1[[:space:]]*$' "$RUNNER_CONFIG" || { echo "runner.capacity must be 1" >&2; exit 1; }
grep -Eq '^[[:space:]]*-[[:space:]]+docker:docker://' "$RUNNER_CONFIG" || { echo "Expected docker container label not found" >&2; exit 1; }
grep -Eq '^[[:space:]]*docker_host:[[:space:]]*"?-"?[[:space:]]*$' "$RUNNER_CONFIG" || { echo "container.docker_host must remain '-'" >&2; exit 1; }
grep -Eq '^[[:space:]]*privileged:[[:space:]]*false[[:space:]]*$' "$RUNNER_CONFIG" || { echo "container.privileged must be false" >&2; exit 1; }
# Validate that a connection token exists without printing it.
awk '
  /^[[:space:]]*token:[[:space:]]*/ {
    line=$0
    sub(/^[[:space:]]*token:[[:space:]]*/, "", line)
    gsub(/^"|"$/, "", line)
    if (length(line) > 0) found=1
  }
  END { exit(found ? 0 : 1) }
' "$RUNNER_CONFIG" || { echo "Runner token is missing from config" >&2; exit 1; }

say "Plan"
cat <<EOF
1. Install /etc/systemd/system/forgejo-runner.service.
2. Run Forgejo Runner as the dedicated '${RUNNER_USER}' account.
3. Provide only the runner process with:
   DOCKER_HOST=unix://${podman_socket}
4. Keep container.docker_host='-' so the Podman socket is not mounted into workflow containers.
5. Start the runner with:
   ${RUNNER_BIN} daemon -c ${RUNNER_CONFIG}
6. Enable automatic restart and boot startup.
7. Validate service state and recent logs without printing runner credentials.

NOT touched:
- Forgejo app.ini
- Nginx / DNS / TLS / SSHD / UFW
- GitHub Actions runner
- repository data
- runner UUID/token values
- Podman socket configuration
EOF

$APPLY || { echo; echo "Dry-run complete. Re-run with --apply to execute."; exit 0; }

say "Install systemd unit"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Forgejo Runner (rootless Podman)
Documentation=https://forgejo.org/docs/v15.0/admin/actions/installation/binary/
After=network-online.target forgejo.service user@${runner_uid}.service
Wants=network-online.target

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_GROUP}
WorkingDirectory=${RUNNER_HOME}
Environment=HOME=${RUNNER_HOME}
Environment=XDG_RUNTIME_DIR=${runtime_dir}
Environment=DOCKER_HOST=unix://${podman_socket}
ExecStart=${RUNNER_BIN} daemon -c ${RUNNER_CONFIG}
Restart=always
RestartSec=5s
TimeoutStopSec=30s
KillSignal=SIGTERM
UMask=0077

[Install]
WantedBy=multi-user.target
EOF
chmod 0644 "$SERVICE_FILE"

say "Start and enable service"
systemctl daemon-reload
systemctl enable --now forgejo-runner.service

sleep 2

say "Validation"
systemctl is-enabled forgejo-runner.service
systemctl is-active forgejo-runner.service
systemctl --no-pager --full status forgejo-runner.service | sed -n '1,18p'

echo
journalctl -u forgejo-runner.service -n 25 --no-pager \
  | sed -E 's/(token|secret|uuid)=([^[:space:]]+)/\1=<redacted>/Ig'

echo
echo "Stage D runner service installed and started."
echo "Next gate: verify the repository-scoped runner appears online in jaasielsantos/ssh-smoke, then execute the minimal container-only Forgejo Actions smoke workflow."
