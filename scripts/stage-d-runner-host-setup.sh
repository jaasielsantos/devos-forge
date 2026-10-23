#!/usr/bin/env bash
set -Eeuo pipefail

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

RUNNER_VERSION="13.1.0"
RUNNER_USER="forgejo-runner"
RUNNER_HOME="/home/${RUNNER_USER}"
RUNNER_BIN="/usr/local/bin/forgejo-runner"
RUNNER_CONFIG="${RUNNER_HOME}/runner-config.yml"

say() { printf '\n==> %s\n' "$*"; }
run() {
  if $APPLY; then
    printf '+ '; printf '%q ' "$@"; printf '\n'
    "$@"
  else
    printf '[dry-run] '; printf '%q ' "$@"; printf '\n'
  fi
}

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo bash $0 [--apply]" >&2
  exit 1
fi

say "Stage D — Forgejo Runner host setup"
echo "mode=$($APPLY && echo APPLY || echo DRY-RUN)"
echo "runner_version=${RUNNER_VERSION}"
echo "runner_user=${RUNNER_USER}"
echo "runner_home=${RUNNER_HOME}"

say "Guard checks"
for cmd in curl gpg git podman systemctl loginctl; do
  command -v "$cmd" >/dev/null || { echo "Required command missing: $cmd" >&2; exit 1; }
done
systemctl is-active --quiet forgejo || { echo "forgejo.service is not active" >&2; exit 1; }
curl -fsS https://git.criandofacil.com.br/api/healthz >/dev/null || { echo "Forgejo public health check failed" >&2; exit 1; }
[[ "$(stat -fc %T /sys/fs/cgroup)" == "cgroup2fs" ]] || { echo "cgroup v2 required" >&2; exit 1; }

say "Plan"
cat <<EOF
1. Install Forgejo Runner v${RUNNER_VERSION} from the official Forgejo release URL and verify its OpenPGP signature.
2. Create a dedicated local account '${RUNNER_USER}' with its own home and user namespace mappings.
3. Lock password login for '${RUNNER_USER}'.
4. Enable lingering so the user's rootless Podman socket survives logout/reboot.
5. Enable the rootless Podman user socket for '${RUNNER_USER}'.
6. Generate a version-matched runner-config.yml if absent.
7. Stop before Forgejo registration, server UUID/token insertion, runner service creation, or workflow execution.

NOT touched by this step:
- Forgejo app.ini
- Nginx / DNS / TLS
- SSHD / UFW
- GitHub Actions runner
- Forgejo repository data
- runner registration secrets
- Forgejo Runner system service
EOF

$APPLY || { echo; echo "Dry-run complete. Re-run with --apply to execute."; exit 0; }

say "Download and verify Forgejo Runner"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
arch="$(uname -m)"
case "$arch" in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
esac
url="https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}/forgejo-runner-${RUNNER_VERSION}-linux-${arch}"
curl -fL --retry 3 -o "${tmpdir}/forgejo-runner" "$url"
curl -fL --retry 3 -o "${tmpdir}/forgejo-runner.asc" "${url}.asc"
gpg --keyserver hkps://keys.openpgp.org --recv EB114F5E6C0DC2BCDD183550A4B61A2DC5923710
gpg --verify "${tmpdir}/forgejo-runner.asc" "${tmpdir}/forgejo-runner"
install -m 0755 "${tmpdir}/forgejo-runner" "$RUNNER_BIN"
"$RUNNER_BIN" -v

say "Create dedicated runner account"
if ! id "$RUNNER_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$RUNNER_USER"
fi
passwd -l "$RUNNER_USER" >/dev/null 2>&1 || true
install -d -o "$RUNNER_USER" -g "$RUNNER_USER" -m 0750 "$RUNNER_HOME"

say "Verify subordinate UID/GID mappings"
subuid="$(awk -F: -v u="$RUNNER_USER" '$1==u{print $0; exit}' /etc/subuid || true)"
subgid="$(awk -F: -v u="$RUNNER_USER" '$1==u{print $0; exit}' /etc/subgid || true)"
[[ -n "$subuid" ]] || { echo "No /etc/subuid mapping was created for $RUNNER_USER; refusing to continue." >&2; exit 1; }
[[ -n "$subgid" ]] || { echo "No /etc/subgid mapping was created for $RUNNER_USER; refusing to continue." >&2; exit 1; }
echo "subuid=${subuid}"
echo "subgid=${subgid}"

say "Enable linger and rootless Podman socket"
loginctl enable-linger "$RUNNER_USER"
runner_uid="$(id -u "$RUNNER_USER")"
# Give systemd-logind a moment to materialize the per-user runtime directory.
for _ in {1..20}; do
  [[ -d "/run/user/${runner_uid}" ]] && break
  sleep 0.25
done
[[ -d "/run/user/${runner_uid}" ]] || { echo "Missing /run/user/${runner_uid}" >&2; exit 1; }
systemctl --user -M "${RUNNER_USER}@" enable --now podman.socket

socket="/run/user/${runner_uid}/podman/podman.sock"
for _ in {1..20}; do
  [[ -S "$socket" ]] && break
  sleep 0.25
done
[[ -S "$socket" ]] || { echo "Podman socket not found at $socket" >&2; exit 1; }

say "Verify Podman as dedicated user"
sudo -u "$RUNNER_USER" env HOME="$RUNNER_HOME" XDG_RUNTIME_DIR="/run/user/${runner_uid}" \
  podman info --format 'rootless={{.Host.Security.Rootless}} cgroupVersion={{.Host.CgroupsVersion}} cgroupManager={{.Host.CgroupManager}} graphRoot={{.Store.GraphRoot}} runRoot={{.Store.RunRoot}}'

say "Generate runner configuration"
if [[ ! -s "$RUNNER_CONFIG" ]]; then
  sudo -u "$RUNNER_USER" env HOME="$RUNNER_HOME" XDG_RUNTIME_DIR="/run/user/${runner_uid}" \
    "$RUNNER_BIN" generate-config > "$RUNNER_CONFIG"
  chown "$RUNNER_USER:$RUNNER_USER" "$RUNNER_CONFIG"
  chmod 0600 "$RUNNER_CONFIG"
fi

say "Validation"
id "$RUNNER_USER"
loginctl show-user "$RUNNER_USER" -p Linger -p RuntimePath -p State
systemctl --user -M "${RUNNER_USER}@" --no-pager status podman.socket | sed -n '1,14p'
ls -l "$RUNNER_BIN" "$RUNNER_CONFIG"
echo "podman_socket=${socket}"

echo
echo "Stage D host preparation complete."
echo "No runner was registered and no runner daemon/service was started."
echo "Next gate: create a repository-scoped runner in Forgejo for jaasielsantos/ssh-smoke, then insert its URL/UUID/token into runner-config.yml together with capacity=1, labels, Podman socket, and resource limits."
