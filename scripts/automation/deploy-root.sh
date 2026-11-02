#!/usr/bin/env bash
# Root-owned deployer, installed outside Git working tree at /usr/local/sbin.
# No general command execution, no configurable target path, no root git.
set -Eeuo pipefail
umask 077
SHA="${1:-}"
[[ "$#" == 1 && "$SHA" =~ ^[a-f0-9]{40}$ ]] || { echo "Full SHA required"; exit 2; }
[[ "$(id -u)" -eq 0 ]] || { echo "root required"; exit 2; }
REPO="/home/iatbadmin/iatb-architecture-workspace"
LIVE="/srv/iatb-architecture/site"
BACKUPS="/srv/iatb-architecture/backups"
DOMAIN="https://architecture.iatb.duckdns.org/"
exec 9>/run/lock/iatb-architecture-deploy.lock
flock -n 9 || { echo "Deployment already in progress"; exit 1; }
test -f "$LIVE/index.html"
runuser -u iatbadmin -- git -C "$REPO" fetch origin main
REMOTE="$(runuser -u iatbadmin -- git -C "$REPO" rev-parse refs/remotes/origin/main)"
[[ "$SHA" == "$REMOTE" ]] || { echo "SHA is not origin/main"; exit 1; }
STAGE="$(mktemp -d /tmp/iatb-arch-stage.XXXXXXXX)"
RESTORE="$(mktemp -d /tmp/iatb-arch-restore.XXXXXXXX)"
cleanup() { rm -rf -- "$STAGE" "$RESTORE"; }
trap cleanup EXIT
# Extract the pinned commit: refuse links and files outside the expected site tree.
runuser -u iatbadmin -- git -C "$REPO" archive "$SHA" site |
  tar -x -C "$STAGE" --no-same-owner
python3 - "$STAGE/site" <<'PY'
from pathlib import Path
from html.parser import HTMLParser
import sys
site = Path(sys.argv[1])
files = list(site.rglob('*'))
if not files or any(p.is_symlink() for p in files):
    raise SystemExit('Invalid or symlinked site')
if len(files)>200 or any(p.is_file() and p.stat().st_size>2_000_000 for p in files):
    raise SystemExit('Excessive site contents')
page=site/'index.html'
if not page.is_file() or page.is_symlink():
    raise SystemExit('Missing index.html')
s=page.read_text(encoding='utf-8')
if not s.lower().startswith('<!doctype html') or 'IA-TB' not in s or 'Architecture' not in s:
    raise SystemExit('Invalid Architecture site')
print('VALIDATION_OK')
PY
install -d -m 700 "$BACKUPS"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="$BACKUPS/site-$STAMP-before-$SHA.tar.gz"
tar -czf "$ARCHIVE" -C "$LIVE" .
echo "BACKUP=$ARCHIVE"
rollback() {
  echo "ROLLBACK_START"
  tar -xzf "$ARCHIVE" -C "$RESTORE" --no-same-owner
  rsync -rc --delete -- "$RESTORE/" "$LIVE/"
  echo "ROLLBACK_DONE"
}
echo "DEPLOY_SHA=$SHA"
rsync -rc --delete -- "$STAGE/site/" "$LIVE/" || { rollback; exit 1; }
if ! curl -fsS --max-time 15 "$DOMAIN" | grep -q 'IA-TB'; then
  rollback; exit 1
fi
printf '%s\n' "$SHA" > "$BACKUPS/last-successful-sha"
printf '%s\t%s\t%s\n' "$STAMP" "$SHA" "$ARCHIVE" >> "$BACKUPS/deploy-history.tsv"
echo "DEPLOY_SUCCESS=$SHA"
