#!/usr/bin/env bash
set -Eeuo pipefail
# Exécution MANUELLE sur le VPS, après validation des changements.
SOURCE_DIR="${1:-/srv/iatb-architecture/workspace/site}"
TARGET_DIR="/srv/iatb-architecture/site"
BACKUP_DIR="/srv/iatb-architecture/backups"
[[ -f "$SOURCE_DIR/index.html" ]] || { echo "ERREUR: site/index.html introuvable"; exit 1; }
[[ -d "$TARGET_DIR" ]] || { echo "ERREUR: destination absente"; exit 1; }
command -v rsync >/dev/null || { echo "Installer rsync avant de deployer"; exit 1; }
umask 077
mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
tar -C "$TARGET_DIR" -czf "$BACKUP_DIR/site-$STAMP.tar.gz" .
echo "Sauvegarde: $BACKUP_DIR/site-$STAMP.tar.gz"
echo "Apercu des changements (aucune suppression automatique) :"
rsync -avnc -- "$SOURCE_DIR/" "$TARGET_DIR/"
read -r -p "Taper DEPLOY pour copier les fichiers : " APPROVAL
[[ "$APPROVAL" == "DEPLOY" ]] || { echo "Annule"; exit 1; }
rsync -avc -- "$SOURCE_DIR/" "$TARGET_DIR/"
echo "Deploiement termine. Tester https://architecture.iatb.duckdns.org"
