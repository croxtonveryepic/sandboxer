#!/bin/bash
set -euo pipefail

# Copy SSH keys from a staging directory into the agent user's home,
# setting correct permissions. This replaces bind-mounting ~/.ssh which
# exposes keys as world-readable (777) on Windows 9p mounts.
#
# Usage: copy-ssh-keys.sh <staging-dir>
#   staging-dir: temporary mount point containing the host's .ssh files

STAGING="${1:-/root/.ssh-staging}"
TARGET="/home/agent/.ssh"

if [[ ! -d "$STAGING" ]]; then
    echo "[boxer:ssh] No SSH staging directory found, skipping key copy"
    exit 0
fi

# Count files to copy
file_count=$(find "$STAGING" -maxdepth 1 -type f | wc -l)
if [[ "$file_count" -eq 0 ]]; then
    echo "[boxer:ssh] SSH staging directory is empty, skipping"
    exit 0
fi

mkdir -p "$TARGET"

# Copy all files from staging into the real .ssh directory
cp -a "$STAGING"/. "$TARGET"/

# Fix ownership
chown -R agent:agent "$TARGET"

# Fix permissions: directory 700, private keys 600, public keys / config 644
chmod 700 "$TARGET"
find "$TARGET" -maxdepth 1 -type f | while read -r f; do
    case "$(basename "$f")" in
        *.pub|known_hosts|known_hosts.old|config|authorized_keys)
            chmod 644 "$f"
            ;;
        *)
            chmod 600 "$f"
            ;;
    esac
done

echo "[boxer:ssh] Copied $file_count file(s) with correct permissions"
