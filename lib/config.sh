#!/usr/bin/env bash
# Boxer configuration: INI-style config reader

BOXER_CONFIG_DIR="$HOME/.boxer"
BOXER_CONFIG_FILE="$BOXER_CONFIG_DIR/config"

# Read a config value: boxer_config <section> <key> [default]
boxer_config() {
    local section="$1"
    local key="$2"
    local default="${3:-}"

    if [[ ! -f "$BOXER_CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi

    local in_section=false
    local line k v
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip comments and leading/trailing whitespace
        line="${line%%#*}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [[ -z "$line" ]] && continue

        # Section header
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=true
            else
                in_section=false
            fi
            continue
        fi

        # Key=value in the target section
        if $in_section && [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
            k="${BASH_REMATCH[1]}"
            v="${BASH_REMATCH[2]}"
            # Trim whitespace
            k="${k#"${k%%[![:space:]]*}"}"; k="${k%"${k##*[![:space:]]}"}"
            v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"

            if [[ "$k" == "$key" ]]; then
                echo "$v"
                return
            fi
        fi
    done < "$BOXER_CONFIG_FILE"

    echo "$default"
}

# Ensure config directory exists with a default config if missing
ensure_config() {
    if [[ ! -d "$BOXER_CONFIG_DIR" ]]; then
        mkdir -p "$BOXER_CONFIG_DIR"
    fi

    if [[ ! -f "$BOXER_CONFIG_FILE" ]]; then
        cat > "$BOXER_CONFIG_FILE" <<'EOF'
# Boxer configuration
# See config/defaults.conf in the boxer install directory for all options.

[defaults]
cpu = 4
memory = 8g
network = restricted

[firewall]
# Comma-separated extra domains to allow through the firewall
extra_domains =

[mounts]
ssh = true
gitconfig = true

[sync]
# Copy Claude Code customization into containers on start
claude_config = true
EOF
        log_info "Created default config at $BOXER_CONFIG_FILE"
    fi
}

ensure_config
