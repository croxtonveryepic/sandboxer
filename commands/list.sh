#!/usr/bin/env bash
# boxer list — List all boxer containers

cmd_list() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: boxer list"
                echo ""
                echo "Lists all boxer-managed containers with their status."
                return 0
                ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    require_docker

    local containers
    containers="$(docker ps -a \
        --filter "label=boxer.managed=true" \
        --format '{{.Names}}\t{{.State}}\t{{.Label "boxer.repo.path"}}\t{{.Label "boxer.created.at"}}' \
    )"

    if [[ -z "$containers" ]]; then
        echo "No boxer containers found. Create one with: boxer create <repo-path> <name>"
        return 0
    fi

    # Print header
    printf "%-20s %-12s %-45s %s\n" "NAME" "STATUS" "REPO" "CREATED"
    printf "%-20s %-12s %-45s %s\n" "----" "------" "----" "-------"

    # Print rows
    while IFS=$'\t' read -r name state repo created; do
        # Truncate repo path if too long
        if [[ ${#repo} -gt 45 ]]; then
            repo="...${repo: -42}"
        fi
        # Format created date (strip time if present)
        created="${created%%T*}"
        printf "%-20s %-12s %-45s %s\n" "$name" "$state" "$repo" "$created"
    done <<< "$containers"
}
