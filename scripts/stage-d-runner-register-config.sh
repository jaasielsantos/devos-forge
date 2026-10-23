#!/usr/bin/env bash
set -Eeuo pipefail

RUNNER_USER="forgejo-runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_CONFIG="${RUNNER_HOME}/runner-config.yml"
FORGEJO_URL="https://git.criandofacil.com.br/"
CONNECTION_NAME="ssh-smoke"
PODMAN_SOCKET="/run/user/$(id -u "$RUNNER_USER" 2>/dev/null || echo 0)/podman/podman.sock"

say() { printf '\n==> %s\n' "$*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "Run with sudo: sudo bash $0"
id "$RUNNER_USER" >/dev/null 2>&1 || fail "Missing runner user: $RUNNER_USER"
[[ -x /usr/local/bin/forgejo-runner ]] || fail "Missing /usr/local/bin/forgejo-runner"
[[ -S "$PODMAN_SOCKET" ]] || fail "Missing Podman socket: $PODMAN_SOCKET"

say "Stage D — configure repository-scoped runner connection"
echo "forgejo_url=${FORGEJO_URL}"
echo "connection=${CONNECTION_NAME}"
echo "runner_user=${RUNNER_USER}"
echo "podman_socket=${PODMAN_SOCKET}"
echo
echo "Obtain UUID + Token from:"
echo "  ssh-smoke -> Settings -> Actions -> Runners -> Create new runner"
echo "Do NOT paste the token into chat, Git, shell history, or command-line arguments."

read -r -p "Runner UUID: " RUNNER_UUID
read -r -s -p "Runner Token (hidden): " RUNNER_TOKEN
printf '\n'

[[ "$RUNNER_UUID" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]] \
  || fail "Runner UUID does not look like a UUID."
[[ -n "$RUNNER_TOKEN" ]] || fail "Runner token is empty."

say "Back up generated configuration"
if [[ -f "$RUNNER_CONFIG" ]]; then
  backup="${RUNNER_CONFIG}.generated.$(date -u +%Y%m%dT%H%M%SZ)"
  cp -a "$RUNNER_CONFIG" "$backup"
  echo "backup=${backup}"
fi

say "Write locked V1 runner configuration"
tmp="$(mktemp)"
trap 'rm -f "$tmp"; unset RUNNER_TOKEN' EXIT
umask 077
cat > "$tmp" <<EOF
log:
  level: info
  job_level: info

runner:
  capacity: 1
  timeout: 3h
  shutdown_timeout: 10m
  insecure: false
  labels:
    - docker:docker://docker.io/library/node:20-bookworm

cache:
  enabled: false

container:
  network: ""
  enable_ipv6: false
  privileged: false
  options: "--memory=1g --cpus=0.75 --pids-limit=256"
  workdir_parent:
  valid_volumes: []
  # The runner daemon gets DOCKER_HOST from systemd. Keeping this '-' prevents
  # Forgejo Runner from mounting the Podman socket inside workflow containers.
  docker_host: "-"
  force_pull: true
  force_rebuild: false

server:
  connections:
    ${CONNECTION_NAME}:
      url: "${FORGEJO_URL}"
      uuid: "${RUNNER_UUID}"
      token: "${RUNNER_TOKEN}"
EOF

install -o "$RUNNER_USER" -g "$RUNNER_USER" -m 0600 "$tmp" "$RUNNER_CONFIG"
unset RUNNER_TOKEN

say "Validate non-secret policy settings"
grep -E '^(runner:|  capacity:|  labels:|    - docker:|container:|  enable_ipv6:|  privileged:|  options:|  valid_volumes:|  docker_host:|  force_pull:|server:|  connections:|    ssh-smoke:|      url:|      uuid:)' "$RUNNER_CONFIG" \
  | sed -E 's/(uuid:).*/\1 <redacted>/'

echo
printf 'config_mode='; stat -c '%a %U:%G' "$RUNNER_CONFIG"
echo "podman_socket=${PODMAN_SOCKET}"

echo
echo "Runner connection configuration written successfully."
echo "The runner daemon/service has NOT been started by this script."
echo "Next gate: install the hardened systemd unit with DOCKER_HOST=${PODMAN_SOCKET}, start it, and verify the runner appears online in ssh-smoke."
