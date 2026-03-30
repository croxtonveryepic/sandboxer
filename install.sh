#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK_TARGET="$HOME/bin/boxer"

mkdir -p "$HOME/bin"

if [[ -e "$LINK_TARGET" ]] || [[ -L "$LINK_TARGET" ]]; then
    echo "Removing existing boxer at $LINK_TARGET"
    rm "$LINK_TARGET"
fi

chmod +x "$SCRIPT_DIR/boxer"

# Windows Git Bash doesn't support true symlinks reliably.
# Write a thin wrapper script that execs the real boxer.
cat > "$LINK_TARGET" <<WRAPPER
#!/usr/bin/env bash
# Thin wrapper — delegates to the real boxer script
exec "$SCRIPT_DIR/boxer" "\$@"
WRAPPER
chmod +x "$LINK_TARGET"

echo "Installed: boxer -> $SCRIPT_DIR/boxer"
echo "Run 'boxer --help' to get started."
