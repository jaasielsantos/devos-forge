#!/usr/bin/env bash
set -Eeuo pipefail

section() { printf '\n===== %s =====\n' "$1"; }
cmd() {
  printf '$'
  printf ' %q' "$@"
  printf '\n'
  "$@" || true
}

section "HOST"
cmd hostname
cmd uname -a
cmd sh -c '. /etc/os-release && printf "%s %s\\n" "$PRETTY_NAME" "$VERSION_ID"'
cmd nproc
cmd free -h
cmd df -h /
cmd uptime

section "REQUIRED TOOLS"
for tool in git curl gpg jq podman systemctl loginctl; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%-12s MISSING\n' "$tool"
  fi
done

section "PODMAN"
if command -v podman >/dev/null 2>&1; then
  cmd podman --version
  cmd podman info --format 'rootless={{.Host.Security.Rootless}} cgroupVersion={{.Host.CgroupsVersion}} cgroupManager={{.Host.CgroupManager}} graphRoot={{.Store.GraphRoot}} runRoot={{.Store.RunRoot}}'
  cmd podman system connection list
else
  echo "podman: MISSING"
fi

section "USER NAMESPACES"
printf 'current_user=%s uid=%s gid=%s\n' "$(id -un)" "$(id -u)" "$(id -g)"
cmd sysctl kernel.unprivileged_userns_clone
cmd sysctl user.max_user_namespaces
printf '\n/etc/subuid entries:\n'
grep -E "^($(id -un)|runner|forgejo-runner):" /etc/subuid 2>/dev/null || echo "no matching entries"
printf '\n/etc/subgid entries:\n'
grep -E "^($(id -un)|runner|forgejo-runner):" /etc/subgid 2>/dev/null || echo "no matching entries"

section "CGROUP"
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
  echo "cgroup_v2=yes"
  printf 'controllers='; cat /sys/fs/cgroup/cgroup.controllers
else
  echo "cgroup_v2=no"
fi
cmd mountpoint /sys/fs/cgroup

section "SYSTEMD USER / LINGER"
cmd loginctl show-user "$(id -un)" -p Linger -p RuntimePath -p State
runtime_dir="/run/user/$(id -u)"
printf 'expected_runtime_dir=%s\n' "$runtime_dir"
if [[ -d "$runtime_dir" ]]; then
  cmd ls -ld "$runtime_dir"
else
  echo "runtime_dir=absent"
fi

section "PODMAN USER SOCKET (CURRENT USER)"
if command -v systemctl >/dev/null 2>&1; then
  XDG_RUNTIME_DIR="$runtime_dir" systemctl --user status podman.socket --no-pager 2>&1 | sed -n '1,20p' || true
fi
if [[ -S "$runtime_dir/podman/podman.sock" ]]; then
  echo "podman_socket=$runtime_dir/podman/podman.sock"
else
  echo "podman_socket=not-present"
fi

section "EXISTING RUNNERS / PROCESSES"
ps -eo user,pid,ppid,%cpu,%mem,etime,cmd \
  | grep -Ei 'Runner.Listener|Runner.Worker|forgejo-runner|act_runner' \
  | grep -v grep || echo "no matching runner processes"

printf '\nSystemd units matching runner:\n'
systemctl list-unit-files --type=service 2>/dev/null \
  | grep -Ei 'runner|forgejo' || true

section "KNOWN GITHUB RUNNER PATH"
if [[ -d /home/cf-gh-runner ]]; then
  cmd ls -ld /home/cf-gh-runner
  if [[ -f /home/cf-gh-runner/.runner ]]; then
    echo "/home/cf-gh-runner/.runner exists (content intentionally not displayed)"
  fi
else
  echo "/home/cf-gh-runner not present"
fi

section "FORGEJO SERVICE / ACTIONS CONFIG"
cmd systemctl is-active forgejo
cmd systemctl is-enabled forgejo
if [[ -r /etc/forgejo/app.ini ]]; then
  awk '
    /^\[actions\]/{show=1; print; next}
    /^\[/{if (show) exit}
    show {print}
  ' /etc/forgejo/app.ini
else
  sudo awk '
    /^\[actions\]/{show=1; print; next}
    /^\[/{if (show) exit}
    show {print}
  ' /etc/forgejo/app.ini 2>/dev/null || echo "unable to read non-secret actions section"
fi

section "FORGEJO HEALTH"
cmd curl -fsS https://git.criandofacil.com.br/api/healthz

section "PORT / LISTENER SNAPSHOT"
ss -lntup 2>/dev/null | sed -n '1,80p' || true

section "PREFLIGHT COMPLETE"
echo "Read-only Stage D snapshot complete. No users, sockets, services, packages, or runner registrations were changed."
