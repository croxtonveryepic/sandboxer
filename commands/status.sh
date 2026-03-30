#!/usr/bin/env bash
# boxer status — Show detailed status for a container

cmd_status() {
    local name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: boxer status <name>"
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
        die "Usage: boxer status <name>"
    fi

    require_docker
    require_boxer_container "$name"

    local state repo_path created network version
    state="$(container_status "$name")"
    repo_path="$(get_label "$name" "boxer.repo.path")"
    created="$(get_label "$name" "boxer.created.at")"
    network="$(get_label "$name" "boxer.network")"
    version="$(get_label "$name" "boxer.version")"

    echo "Container:  $name"
    echo "Status:     $state"
    echo "Repo:       $repo_path"
    echo "Network:    ${network:-restricted}"
    echo "Created:    $created"
    echo "Version:    ${version:-unknown}"

    # Show resource limits
    local cpus mem
    cpus="$(docker inspect --format '{{.HostConfig.NanoCpus}}' "$name" 2>/dev/null)"
    mem="$(docker inspect --format '{{.HostConfig.Memory}}' "$name" 2>/dev/null)"

    if [[ -n "$cpus" ]] && [[ "$cpus" != "0" ]]; then
        echo "CPU Limit:  $(awk "BEGIN {printf \"%.1f\", $cpus / 1000000000}") cores"
    fi
    if [[ -n "$mem" ]] && [[ "$mem" != "0" ]]; then
        echo "Mem Limit:  $(( mem / 1024 / 1024 ))MB"
    fi

    # Show volumes
    echo ""
    echo "Volumes:"
    docker inspect --format '{{range .Mounts}}  {{.Type}}: {{.Source}} -> {{.Destination}} ({{.Mode}}){{"\n"}}{{end}}' "$name" 2>/dev/null

    # Show live resource usage if running
    if [[ "$state" == "running" ]]; then
        echo "Live Usage:"
        docker stats --no-stream --format "  CPU: {{.CPUPerc}}  Memory: {{.MemUsage}}" "$name" 2>/dev/null
    fi
}
