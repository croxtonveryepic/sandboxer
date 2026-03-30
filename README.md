# Boxer

Isolated Docker containers for running Claude Code CLI with `--dangerously-skip-permissions` in a network-restricted sandbox.

## Prerequisites

- **Docker Desktop** (running)
- **PowerShell 7+** (`pwsh`)

## Installation

```powershell
.\Install.ps1
```

This installs the `boxer` command to your PowerShell profile and `~/bin`. Restart your terminal or run `. $PROFILE` to load it.

## Quick Start

```powershell
# Build the sandbox image (auto-builds on first use)
boxer build

# Create a sandbox from a Git repo
boxer create ~\my-project my-sandbox

# Start an interactive Claude session
boxer start my-sandbox

# Open a debug shell in the container
boxer shell my-sandbox

# Stop when done
boxer stop my-sandbox
```

## Commands

| Command | Description |
|---------|-------------|
| `boxer create <repo> <name>` | Create a new sandbox container |
| `boxer start <name>` | Start a Claude Code session |
| `boxer stop <name>` | Stop a container (`--all` for all) |
| `boxer rm <name>` | Remove a container (`--volumes` to delete data) |
| `boxer shell <name>` | Open a bash shell in a container |
| `boxer list` | List all boxer containers |
| `boxer status <name>` | Show container details and resource usage |
| `boxer logs <name>` | Show container logs (`--follow`, `--tail`) |
| `boxer build` | Build/rebuild the sandbox Docker image |

### Create Options

```
--cpu <n>           CPU cores (default: 4)
--memory <size>     Memory limit (default: 8g)
--network <mode>    restricted, none, or host (default: restricted)
--no-ssh            Don't mount SSH keys
--no-git-config     Don't mount .gitconfig
--env <KEY=VALUE>   Extra environment variable (repeatable)
--domains <list>    Comma-separated extra firewall domains
--start             Start a Claude session immediately after creation
```

## Configuration

Boxer creates a config file at `~/.boxer/config` on first run:

```ini
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
```

CLI flags override config file values.

## Network Restrictions

In `restricted` mode (default), outbound traffic is limited to:

- **Anthropic** — api.anthropic.com, console.anthropic.com, claude.ai, statsig.anthropic.com
- **GitHub** — github.com (HTTPS + SSH), api.github.com
- **Package registries** — registry.npmjs.org, pypi.org, files.pythonhosted.org
- **DNS** — container's configured resolvers only
- **Custom domains** — via `--domains` flag or `extra_domains` config

All other outbound connections are dropped by iptables firewall rules.
