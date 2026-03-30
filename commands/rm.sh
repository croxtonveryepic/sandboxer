#!/usr/bin/env bash
# boxer rm — Remove a container and optionally its volumes

cmd_rm() {
    local name=""
    local remove_volumes=false
    local force=false
    local all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --volumes|-V)   remove_volumes=true; shift ;;
            --force|-f)     force=true; shift ;;
            --all|-a)       all=true; shift ;;
            -h|--help)
                cat <<'HELP'
Usage: boxer rm <name> [options]

Options:
    --volumes, -V    Also remove persistent volumes (Claude config/data)
    --force, -f      Force remove even if running
    --all, -a        Remove all boxer containers
HELP
                return 0
                ;;
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

    require_docker

    if $all; then
        local containers
        containers="$(list_boxer_containers)"
        if [[ -z "$containers" ]]; then
            log_info "No boxer containers to remove."
            return 0
        fi
        while IFS= read -r c; do
            _remove_container "$c" "$force" "$remove_volumes"
        done <<< "$containers"
        log_success "All boxer containers removed."
        return 0
    fi

    if [[ -z "$name" ]]; then
        die "Usage: boxer rm <name> [--volumes] [--force]"
    fi

    require_boxer_container "$name"
    _remove_container "$name" "$force" "$remove_volumes"
}

_remove_container() {
    local name="$1"
    local force="$2"
    local remove_volumes="$3"

    # Stop if running
    if [[ "$(container_status "$name")" == "running" ]]; then
        if [[ "$force" != "true" ]]; then
            die "Container '$name' is running. Stop it first or use --force."
        fi
        docker stop "$name" >/dev/null
    fi

    docker rm "$name" >/dev/null

    if [[ "$remove_volumes" == "true" ]]; then
        local config_vol="${BOXER_VOLUME_PREFIX}-${name}-claude-config"
        local data_vol="${BOXER_VOLUME_PREFIX}-${name}-claude-data"

        docker volume rm "$config_vol" 2>/dev/null && log_info "Removed volume '$config_vol'" || true
        docker volume rm "$data_vol" 2>/dev/null && log_info "Removed volume '$data_vol'" || true
    fi

    log_success "Container '$name' removed."
}
