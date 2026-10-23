#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_URL="https://github.com/jaasielsantos/devos-forge.git"
FORGEJO_HEALTH="https://git.criandofacil.com.br/api/healthz"
DEST_GIT_DIR="/var/lib/forgejo/data/forgejo-repositories/jaasielsantos/devos-forge.git"

section() { printf '\n===== %s =====\n' "$1"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "Run with sudo so the script can inspect the Forgejo repository as the git service account."
command -v git >/dev/null || fail "git is required"
command -v curl >/dev/null || fail "curl is required"
id git >/dev/null 2>&1 || fail "Forgejo service account 'git' not found"

section "STAGE E — MIRROR PARITY"
echo "source=${SOURCE_URL}"
echo "destination_git_dir=${DEST_GIT_DIR}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

section "FORGEJO HEALTH"
curl -fsS "$FORGEJO_HEALTH"
echo

section "DESTINATION PRESENCE"
[[ -d "$DEST_GIT_DIR" ]] || fail "Forgejo repository path does not exist yet: $DEST_GIT_DIR"
echo "destination_path_present=yes"

section "SOURCE REFS"
git ls-remote --heads --tags "$SOURCE_URL" \
  | awk '{print $1 "\t" $2}' \
  | sort > "$tmpdir/source.refs"
cat "$tmpdir/source.refs"

section "FORGEJO REFS"
runuser -u git -- git --git-dir="$DEST_GIT_DIR" for-each-ref \
  --format='%(objectname)%09%(refname)' refs/heads refs/tags \
  | sort > "$tmpdir/destination.refs"
cat "$tmpdir/destination.refs"

section "REF PARITY"
if diff -u "$tmpdir/source.refs" "$tmpdir/destination.refs"; then
  echo "refs_parity=PASS"
else
  fail "branch/tag refs differ between GitHub and Forgejo"
fi

section "MAIN HEAD"
source_main="$(git ls-remote "$SOURCE_URL" refs/heads/main | awk '{print $1}')"
dest_main="$(runuser -u git -- git --git-dir="$DEST_GIT_DIR" rev-parse refs/heads/main)"
echo "source_main=${source_main}"
echo "forgejo_main=${dest_main}"
[[ -n "$source_main" && "$source_main" == "$dest_main" ]] || fail "main branch commit differs"

section "OBJECT INTEGRITY"
runuser -u git -- git --git-dir="$DEST_GIT_DIR" fsck --full --no-dangling

echo
echo "PASS: GitHub and Forgejo branches/tags are identical, main points to the same commit, and Forgejo Git object integrity passes."
