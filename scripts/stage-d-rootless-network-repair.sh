#!/usr/bin/env bash
set -Eeuo pipefail

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true
RUNNER_USER="forgejo-runner"
RUNNER_UID="$(id -u "$RUNNER_USER" 2>/dev/null || true)"
RUNNER_HOME="/home/${RUNNER_USER}"

say() { printf '\n==> %s\n' "$*"; }

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 [--apply]" >&2
  exit 1
fi

say "Stage D — repair rootless networking helper"
echo "mode=$($APPLY && echo APPLY || echo DRY-RUN)"

echo "Problem addressed: Podman rootless job startup fails when slirp4netns is absent."
echo "This step installs only the Ubuntu package slirp4netns and validates it for the dedicated runner user."

if command -v slirp4netns >/dev/null 2>&1; then
  echo "slirp4netns already present: $(command -v slirp4netns)"
  slirp4netns --version || true
  exit 0
fi

if ! $APPLY; then
  echo
  echo "Dry-run complete. Re-run with --apply to install slirp4netns."
  exit 0
fi

say "Install slirp4netns"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y slirp4netns

say "Validate host helper"
command -v slirp4netns
slirp4netns --version

if [[ -n "$RUNNER_UID" ]]; then
  say "Validate rootless container startup as ${RUNNER_USER}"
  sudo -u "$RUNNER_USER" env \
    HOME="$RUNNER_HOME" \
    XDG_RUNTIME_DIR="/run/user/${RUNNER_UID}" \
    podman run --rm docker.io/library/node:20-bookworm node --version
fi

echo
echo "Rootless networking helper repair complete."
echo "No Forgejo, runner credential, Nginx, SSHD, firewall, or repository configuration was changed."
echo "Next gate: re-run the failed Forgejo Actions smoke job."
