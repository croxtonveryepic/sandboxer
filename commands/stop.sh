#!/usr/bin/env bash
# boxer stop — Stop a running container

cmd_stop() {
    local name=""
    local all=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a)   all=true; shift ;;
            -h|--help)
                echo "Usage: boxer stop <name> [--all]"
                echo ""
                echo "Options:"
                echo "  --all, -a    Stop all boxer containers"
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
            log_info "No boxer containers to stop."
            return 0
        fi
        local count=0
        while IFS= read -r c; do
            if [[ "$(container_status "$c")" == "running" ]]; then
                docker stop "$c" >/dev/null
                log_info "Stopped '$c'"
                ((count++))
            fi
        done <<< "$containers"
        log_success "Stopped $count container(s)."
        return 0
    fi

    if [[ -z "$name" ]]; then
        die "Usage: boxer stop <name> [--all]"
    fi

    require_boxer_container "$name"

    if [[ "$(container_status "$name")" != "running" ]]; then
        log_info "Container '$name' is not running."
        return 0
    fi

    docker stop "$name" >/dev/null
    log_success "Container '$name' stopped."
}
