#!/usr/bin/env bash
# Install as root-owned /usr/local/sbin/iatb-arch-ssh-gate (mode 0755).
# This is a forced command for a dedicated deploy-only SSH key.
set -Eeuo pipefail
if [[ "${SSH_ORIGINAL_COMMAND:-}" =~ ^deploy\ ([a-f0-9]{40})$ ]]; then
  exec sudo -n /usr/local/sbin/iatb-arch-deploy-root "${BASH_REMATCH[1]}"
fi
echo "Invalid deployment request" >&2
exit 2
