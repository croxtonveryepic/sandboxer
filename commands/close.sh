#!/usr/bin/env bash
# boxer close — Restore the restricted firewall on a container

cmd_close() {
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<'HELP'
Usage: boxer close <name>

Restore the restricted outbound firewall on a running container,
re-applying the domain allowlist. Reverses 'boxer open <name>'.
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

    if [[ -z "$name" ]]; then
        die "Usage: boxer close <name>"
    fi

    require_docker
    require_boxer_container "$name"

    local status
    status="$(container_status "$name")"
    if [[ "$status" != "running" ]]; then
        die "Container '$name' is not running (status: $status). Start it first with 'boxer start $name'."
    fi

    log_info "Restoring firewall on '$name'..."

    docker exec --user root "$name" /usr/local/bin/firewall-init.sh

    log_success "Firewall restored on '$name' — outbound restricted to allowlist."
}
