#!/usr/bin/env bash
# Boxer Docker helper functions

# Check if the boxer image exists locally
image_exists() {
    docker image inspect "$BOXER_IMAGE" &>/dev/null
}

# Build the boxer image if it doesn't exist, or if forced
ensure_image() {
    if image_exists; then
        return 0
    fi

    log_info "Boxer image not found. Building..."
    source "$BOXER_ROOT/commands/build.sh"
    cmd_build
}

# Get a label value from a container
get_label() {
    local name="$1"
    local label="$2"
    docker inspect --format "{{index .Config.Labels \"$label\"}}" "$name" 2>/dev/null
}

# List all boxer-managed container names
list_boxer_containers() {
    docker ps -a --filter "label=boxer.managed=true" --format '{{.Names}}'
}
