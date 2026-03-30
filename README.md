# Boxer

Quickly spin up isolated Docker containers for running Claude Code CLI with `--dangerously-skip-permissions`.

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
boxer create /repo/path project-name
boxer start project-name                             #      it's that easy!
/workspace$ claude --dangerously-skip-permissions    # <--- this is safe!
```

Sandboxer ships with `claude-switch.py`, which can optionally be used as a credential manager. To use it in a box, run `boxer credential install project-name` and (it will be aliased as `cs`). Then on your host machine:

```powershell
cs save profile-name
boxer credential sync
```

This will save the OAuth token, email, and org name from your currently-signed-in Claude Code session as a `cs` profile, then copy your `cs` profiles into your running containers. Then to copy the profiles to the place where Claude Code looks for them, run in your box:

```bash
cs use profile-name
```

...and now you don't have to deal with the login flow in a container with no browser. As the name implies, `claude-switch.py` lets you save multiple profiles, if you have Anthropic accounts for both work and personal use.

## Commands

| Command                      | Description                                                            |
| ---------------------------- | ---------------------------------------------------------------------- |
| `boxer create <repo> <name>` | Create a new sandbox container                                         |
| `boxer start <name>`         | Start a Claude Code session                                            |
| `boxer stop <name>`          | Stop a container (`--all` for all)                                     |
| `boxer rm <name>`            | Remove a container (`--volumes` to delete data)                        |
| `boxer list`                 | List all boxer containers                                              |
| `boxer status <name>`        | Show container details and resource usage                              |
| `boxer logs <name>`          | Show container logs (`--follow`, `--tail`)                             |
| `boxer build`                | Build/rebuild the sandbox Docker image (auto-builds on first `create`) |

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
