#!/usr/bin/env bash
# boxer build — Build or rebuild the boxer Docker image

cmd_build() {
    local no_cache=false
    local pull=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-cache) no_cache=true; shift ;;
            --pull)     pull=true; shift ;;
            -h|--help)
                echo "Usage: boxer build [--no-cache] [--pull]"
                echo ""
                echo "Options:"
                echo "  --no-cache    Build without using Docker cache"
                echo "  --pull        Pull the latest base image before building"
                return 0
                ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    require_docker

    # Copy claude-switch.py into Docker build context (Dockerfile COPY requires it).
    # Cleaned up after build via explicit rm (not trap EXIT, which leaks when sourced).
    local cs_src="$BOXER_ROOT/claude-switch.py"
    local cs_dest="$BOXER_ROOT/docker/claude-switch.py"
    if [[ -f "$cs_src" ]]; then
        cp "$cs_src" "$cs_dest"
    else
        log_warn "claude-switch.py not found at $cs_src — containers will not have 'cs' command"
    fi

    local build_args=()
    build_args+=(-t "$BOXER_IMAGE")
    build_args+=(-f "$BOXER_ROOT/docker/Dockerfile")

    if $no_cache; then
        build_args+=(--no-cache)
    fi

    if $pull; then
        build_args+=(--pull)
    fi

    build_args+=("$BOXER_ROOT/docker")

    log_info "Building boxer image..."
    local build_exit=0
    MSYS_NO_PATHCONV=1 docker build "${build_args[@]}" || build_exit=$?

    # Clean up build-context copy regardless of outcome
    rm -f "$cs_dest"

    if [[ $build_exit -ne 0 ]]; then
        die "Docker build failed (exit $build_exit)."
    fi

    log_success "Image '$BOXER_IMAGE' built successfully."
}
