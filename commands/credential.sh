#!/usr/bin/env bash
# boxer credential — Manage Claude credentials and switcher across containers

# Resolve the claude-switch.py script on the host
_resolve_claude_switch_script() {
    local script="$BOXER_ROOT/claude-switch.py"
    if [[ -f "$script" ]]; then
        echo "$script"
    else
        echo ""
    fi
}

cmd_credential() {
    local subcmd="${1:-}"
    shift || true

    case "$subcmd" in
        sync)    cmd_credential_sync "$@" ;;
        install) cmd_credential_install "$@" ;;
        -h|--help|help|"")
            cat <<'HELP'
Usage: boxer credential <subcommand>

Subcommands:
    sync                    Sync profiles, config, and Claude Switcher
                            to all running boxer containers
    install <name>          Install/update Claude Switcher on a specific
                            running container

The sync command pushes all saved profiles, Claude Code config, and the
latest Claude Switcher (cs) into every running container. Stopped
containers will receive updates on their next start.

Active credentials are NOT synced — use 'cs use <profile>' inside each
container to select an identity.
HELP
            ;;
        *) die "Unknown subcommand: $subcmd. Run 'boxer credential --help' for usage." ;;
    esac
}

cmd_credential_sync() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) cmd_credential "help"; return 0 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    require_docker

    local containers
    containers="$(list_boxer_containers)"

    if [[ -z "$containers" ]]; then
        log_info "No boxer containers found."
        return 0
    fi

    # Depends on start.sh for _sync_claude_config
    # (sourced by the dispatcher in boxer before this file)

    local cs_script
    cs_script="$(_resolve_claude_switch_script)"

    local total=0
    local synced=0
    local skipped=0
    local failed=0

    while IFS= read -r name; do
        total=$((total + 1))
        local status
        status="$(container_status "$name")"

        if [[ "$status" != "running" ]]; then
            log_info "  $name: skipped (${status}, will sync on next start)"
            skipped=$((skipped + 1))
            continue
        fi

        log_info "  $name: syncing..."

        # Ensure ~/.claude directory exists
        docker exec "$name" mkdir -p "${BOXER_CONTAINER_HOME}/.claude" 2>/dev/null || true

        # Sync profiles and Claude Code config
        _sync_claude_config "$name" 2>/dev/null || true

        # Harden permissions on credential and profile files
        _harden_credential_permissions "$name"

        # Auto-install/update Claude Switcher
        if [[ -n "$cs_script" ]]; then
            _install_claude_switcher "$name" "$cs_script" 2>/dev/null || {
                log_warn "  $name: Claude Switcher install failed (non-fatal)"
            }
        fi

        synced=$((synced + 1))
    done <<< "$containers"

    log_success "Credential sync complete: $synced synced, $skipped skipped (stopped), $failed failed (of $total total)"
}

cmd_credential_install() {
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) cmd_credential "help"; return 0 ;;
            -*)  die "Unknown option: $1" ;;
            *)
                if [[ -z "$name" ]]; then
                    name="$1"
                else
                    die "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$name" ]]; then
        die "Usage: boxer credential install <name>"
    fi

    require_docker
    require_boxer_container "$name"

    local status
    status="$(container_status "$name")"
    if [[ "$status" != "running" ]]; then
        die "Container '$name' is not running (status: $status). Start it first with: boxer start $name"
    fi

    local cs_script
    cs_script="$(_resolve_claude_switch_script)"
    if [[ -z "$cs_script" ]]; then
        die "claude-switch.py not found at $BOXER_ROOT/claude-switch.py"
    fi

    _install_claude_switcher "$name" "$cs_script"
    log_success "Claude Switcher installed in '$name'. Use 'cs status' inside the container."
}

# Install or update claude-switch.py and the cs wrapper in a running container
_install_claude_switcher() {
    local name="$1"
    local script_path="$2"

    MSYS_NO_PATHCONV=1 docker cp "$script_path" "${name}:/usr/local/bin/claude-switch.py"

    docker exec "$name" bash -c '
        printf "#!/bin/sh\nexec python3 /usr/local/bin/claude-switch.py \"\$@\"\n" > /usr/local/bin/cs
        chmod +x /usr/local/bin/claude-switch.py /usr/local/bin/cs
    '

    docker exec "$name" chown "${BOXER_CONTAINER_USER}:${BOXER_CONTAINER_USER}" \
        /usr/local/bin/claude-switch.py /usr/local/bin/cs 2>/dev/null || true
}

# Set restrictive permissions on profile files
_harden_credential_permissions() {
    local name="$1"
    local dest_dir="${BOXER_CONTAINER_HOME}/.claude"

    docker exec "$name" bash -c "
        if [ -d '$dest_dir/profiles' ]; then
            find '$dest_dir/profiles' -name '*.json' -exec chmod 600 {} + 2>/dev/null || true
        fi
    "
}
