#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_URL="https://github.com/jaasielsantos/devos-forge.git"
FORGEJO_URL="https://git.criandofacil.com.br"
OWNER="jaasielsantos"
REPO="devos-forge"
REPO_ROOT="/var/lib/forgejo/data/forgejo-repositories"
DEST_PATH="${REPO_ROOT}/${OWNER}/${REPO}.git"

section() { printf '\n===== %s =====\n' "$1"; }

section "STAGE E — MIGRATION PREFLIGHT"
echo "source=${SOURCE_URL}"
echo "destination=${FORGEJO_URL}/${OWNER}/${REPO}"
echo "mode=recommended pull mirror (GitHub primary -> Forgejo secondary)"

section "FORGEJO HEALTH"
curl -fsS "${FORGEJO_URL}/api/healthz"
echo

section "SOURCE REPOSITORY REACHABILITY"
git ls-remote --symref "$SOURCE_URL" HEAD

section "SOURCE BRANCHES"
git ls-remote --heads "$SOURCE_URL" | sed 's#refs/heads/##'

section "SOURCE TAGS"
tags="$(git ls-remote --tags "$SOURCE_URL")"
if [[ -n "$tags" ]]; then
  printf '%s\n' "$tags" | sed 's#refs/tags/##'
else
  echo "no tags"
fi

section "DESTINATION FILESYSTEM CHECK"
if [[ -e "$DEST_PATH" ]]; then
  echo "BLOCKED: destination repository path already exists: $DEST_PATH"
  exit 2
else
  echo "destination_path_absent=yes"
fi

section "MIRROR SUPPORT CONTEXT"
echo "Forgejo pull mirrors must be selected during repository migration/creation."
echo "Do not create a normal empty devos-forge repository first."
echo "Because the GitHub source is public, Git clone authentication is not required for Git data mirroring."

section "PREFLIGHT RESULT"
echo "PASS: source Git refs are reachable, Forgejo is healthy, and no destination Git path exists."
echo "Next gate: Forgejo UI -> New Migration -> Git -> source URL -> check 'This repository will be a mirror' -> owner jaasielsantos -> repository name devos-forge."
