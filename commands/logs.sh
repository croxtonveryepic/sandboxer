#!/usr/bin/env bash
# boxer logs — Show container logs

cmd_logs() {
    local name=""
    local follow=false
    local tail=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --follow|-f)    follow=true; shift ;;
            --tail|-n)      tail="$2"; shift 2 ;;
            -h|--help)
                cat <<'HELP'
Usage: boxer logs <name> [options]

Options:
    --follow, -f     Follow log output
    --tail, -n <N>   Show last N lines
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
        die "Usage: boxer logs <name>"
    fi

    require_docker
    require_boxer_container "$name"

    local cmd=(docker logs)

    if $follow; then
        cmd+=(-f)
    fi

    if [[ -n "$tail" ]]; then
        cmd+=(--tail "$tail")
    fi

    cmd+=("$name")
    "${cmd[@]}"
}
