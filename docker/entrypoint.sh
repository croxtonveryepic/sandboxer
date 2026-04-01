#!/bin/bash
set -euo pipefail

echo "[boxer:entrypoint] Starting entrypoint (pid=$$, uid=$(id -u), user=$(whoami))"
echo "[boxer:entrypoint] Args: $*"

# Run firewall setup as root (requires NET_ADMIN capability)
if [[ "$(id -u)" == "0" ]]; then
    echo "[boxer:entrypoint] Running firewall setup as root..."
    firewall_ok=true
    /usr/local/bin/firewall-init.sh 2>&1 || {
        firewall_ok=false
        echo "[boxer:entrypoint] Warning: firewall setup failed (exit=$?), may lack NET_ADMIN capability"
    }

    # Copy SSH keys from staging mount and fix permissions (must run as root).
    # The staging dir is a read-only bind mount from the host's .ssh, placed
    # under /root/ so the agent user cannot access the 777-permed originals.
    if [[ -d /root/.ssh-staging ]]; then
        /usr/local/bin/copy-ssh-keys.sh /root/.ssh-staging 2>&1
    fi

    # Signal readiness — warn prominently if firewall failed in restricted mode
    if [[ "$firewall_ok" == "false" && "${BOXER_NETWORK:-}" == "restricted" ]]; then
        echo "============================================================"
        echo "[boxer] WARNING: Firewall initialization FAILED — container network is NOT restricted!"
        echo "============================================================"
    fi
    touch /tmp/.boxer-ready
    echo "[boxer:entrypoint] Readiness signal written to /tmp/.boxer-ready"

    # Fix git "dubious ownership" for the bind-mounted workspace.
    # The repo is owned by root but git runs as agent (uid 1000).
    # The host .gitconfig is read-only, so we inject into /etc/gitconfig.
    git config --system safe.directory "${BOXER_WORKSPACE:-/workspace}"

    # If .gitconfig is a read-only bind mount (legacy containers), it may
    # contain Windows-path safe.directory entries that spam warnings on
    # every git command. Copy to a writable location, strip them, and
    # redirect git's global config via /etc/profile.d.
    gitconfig="/home/agent/.gitconfig"
    if [[ -f "$gitconfig" ]] && ! test -w "$gitconfig" 2>/dev/null; then
        filtered="/tmp/.gitconfig-filtered"
        cp "$gitconfig" "$filtered"
        git config --file "$filtered" --unset-all safe.directory 2>/dev/null || true
        chown agent:agent "$filtered"
        echo "export GIT_CONFIG_GLOBAL=$filtered" > /etc/profile.d/boxer-git.sh
        # Also inject into .bashrc for non-login interactive shells
        if ! grep -q "boxer-gitconfig-redirect" /home/agent/.bashrc 2>/dev/null; then
            echo "# boxer-gitconfig-redirect" >> /home/agent/.bashrc
            echo "export GIT_CONFIG_GLOBAL=$filtered" >> /home/agent/.bashrc
            chown agent:agent /home/agent/.bashrc
        fi
        echo "[boxer:entrypoint] Redirected .gitconfig to filtered copy (stripped Windows safe.directory entries)"
    fi

    # One-time hint about Claude Switcher — append to agent's .bashrc so it
    # surfaces on interactive shell login (not just in docker logs)
    if [[ -f /usr/local/bin/cs ]] && ! grep -q "boxer-cs-hint" /home/agent/.bashrc 2>/dev/null; then
        cat >> /home/agent/.bashrc <<'HINT'
# boxer-cs-hint
if [ ! -f /tmp/.cs-hint-shown ] && command -v cs >/dev/null 2>&1; then
    echo "Tip: Use 'cs status' to see Claude profiles, 'cs use <name>' to switch"
    touch /tmp/.cs-hint-shown
fi
HINT
        chown agent:agent /home/agent/.bashrc
    fi

    # Auto-freshen active profile on shell login (captures token rotation).
    # Uses flock to serialise concurrent freshen from multiple shells.
    if [[ -f /usr/local/bin/cs ]] && ! grep -q "boxer-auto-freshen" /home/agent/.bashrc 2>/dev/null; then
        cat >> /home/agent/.bashrc <<'FRESHEN'
# boxer-auto-freshen
if command -v cs >/dev/null 2>&1; then
    ( flock -n 9 && cs freshen --quiet 2>/dev/null; ) 9>/tmp/.cs-freshen.lock &
fi
FRESHEN
        chown agent:agent /home/agent/.bashrc
    fi
else
    echo "[boxer:entrypoint] Not root (uid=$(id -u)), skipping firewall setup"
fi

# Drop to agent user for all subsequent commands
cmd=$(printf '%q ' "$@")
echo "[boxer:entrypoint] Dropping to agent user, exec: $cmd"
exec su agent -s /bin/bash -c "exec $cmd"
