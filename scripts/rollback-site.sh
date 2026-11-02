#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ "$(id -u)" -eq 0 ]] || { echo "Requires sudo"; exit 2; }
BACKUPS="/srv/iatb-architecture/backups"
LIVE="/srv/iatb-architecture/site"
FILE="${1:-}"
[[ "$FILE" == "$BACKUPS"/site-*.tar.gz && -f "$FILE" && ! -L "$FILE" ]] || { echo "Provide exact existing backup path under $BACKUPS"; exit 2; }
exec 9>/run/lock/iatb-architecture-deploy.lock
flock -n 9 || { echo "Another deploy/rollback in progress"; exit 1; }
# Reject archives containing absolute paths, traversal, or links.
python3 - "$FILE" <<'PY'
import tarfile,sys
from pathlib import PurePosixPath
with tarfile.open(sys.argv[1],"r:gz") as a:
    for m in a:
        p=PurePosixPath(m.name)
        if p.is_absolute() or ".." in p.parts or not (m.isfile() or m.isdir()):
            raise SystemExit("Unsafe backup entry: "+m.name)
print("Backup archive safe")
PY
TMP="$(mktemp -d /tmp/iatb-arch-rollback.XXXXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
tar -xzf "$FILE" -C "$TMP" --no-same-owner
[[ -f "$TMP/index.html" ]] || { echo "Backup missing index.html"; exit 1; }
echo "Rollback source: $FILE"
read -r -p "Type ROLLBACK to restore: " CONFIRM
[[ "$CONFIRM" == "ROLLBACK" ]] || exit 1
rsync -rc --delete -- "$TMP/" "$LIVE/"
echo "ROLLBACK_DONE"
