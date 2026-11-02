#!/usr/bin/env bash
# Manually approved, SHA-pinned deploy from a dedicated checkout on VPS.
# This script does NOT grant an unattended runner control of the production host.
set -Eeuo pipefail
umask 077
REPO="/home/iatbadmin/iatb-architecture-workspace"
LIVE="/srv/iatb-architecture/site"
BACKUPS="/srv/iatb-architecture/backups"
LOCK="/run/lock/iatb-architecture-deploy.lock"
APPROVED_SHA="${1:-}"
if [[ ! "$APPROVED_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Usage: sudo bash scripts/deploy-approved.sh <40-char approved commit SHA>" >&2; exit 2
fi
if [[ "$(id -u)" -ne 0 ]]; then echo "Requires sudo after explicit human approval" >&2; exit 2; fi
exec 9>"$LOCK"
flock -n 9 || { echo "Deploy already in progress"; exit 1; }
[[ -d "$LIVE" && -f "$LIVE/index.html" ]] || { echo "Production site missing"; exit 1; }
[[ -d "$REPO/.git" ]] || { echo "Approved checkout not found"; exit 1; }
command -v rsync >/dev/null && command -v curl >/dev/null || { echo "Missing rsync/curl"; exit 1; }
# Git is never run as root. This requires the existing VPS Git Deploy Key.
runuser -u iatbadmin -- git -C "$REPO" fetch origin main
HEAD="$(runuser -u iatbadmin -- git -C "$REPO" rev-parse refs/remotes/origin/main)"
[[ "$HEAD" == "$APPROVED_SHA" ]] || { echo "Approved SHA != origin/main ($HEAD)"; exit 1; }
# Export an immutable commit into temporary staging; no uncommitted files are deployed.
STAGE="$(mktemp -d /tmp/iatb-architecture-deploy.XXXXXXXX)"
RESTORE="$(mktemp -d /tmp/iatb-architecture-restore.XXXXXXXX)"
cleanup(){ rm -rf -- "$STAGE" "$RESTORE"; }
trap cleanup EXIT
runuser -u iatbadmin -- git -C "$REPO" archive "$APPROVED_SHA" site | tar -x -C "$STAGE"
[[ -f "$STAGE/site/index.html" ]] || { echo "Approved commit missing site"; exit 1; }
# Validate the actual pinned snapshot, not the current working tree.
python3 - "$STAGE/site/index.html" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1])
s=p.read_text(encoding="utf-8")
assert s.lower().startswith("<!doctype html") and "Architecture" in s and "IA-TB" in s
print("Pinned snapshot smoke check passed")
PY
install -d -m 700 "$BACKUPS"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="$BACKUPS/site-$STAMP-before-$APPROVED_SHA.tar.gz"
tar -czf "$ARCHIVE" -C "$LIVE" .
echo "BACKUP=$ARCHIVE"
echo "RELEASE=$APPROVED_SHA"
rsync -rcn --delete -- "$STAGE/site/" "$LIVE/"
read -r -p "Type DEPLOY to apply this exact commit: " CONFIRM
[[ "$CONFIRM" == "DEPLOY" ]] || { echo "Not approved"; exit 1; }
rollback() {
  echo "Health check failed: restoring previous site" >&2
  tar -xzf "$ARCHIVE" -C "$RESTORE"
  rsync -rc --delete -- "$RESTORE/" "$LIVE/"
}
rsync -rc --delete -- "$STAGE/site/" "$LIVE/"
if ! curl -fsS --max-time 15 https://architecture.iatb.duckdns.org/ | grep -q 'IA-TB'; then
  rollback
  exit 1
fi
echo "$APPROVED_SHA" > "$BACKUPS/last-successful-sha"
echo "DEPLOY_SUCCESS=$APPROVED_SHA"
echo "To rollback later, use: sudo bash scripts/rollback-site.sh $ARCHIVE"
