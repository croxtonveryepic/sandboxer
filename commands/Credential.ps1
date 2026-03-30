# boxer credential - Manage Claude credentials and switcher across containers

function Resolve-ClaudeSwitchScript {
    $script = Join-Path $script:BOXER_ROOT "claude-switch.py"
    if (Test-Path $script) { return $script }
    return $null
}

function Invoke-BoxerCredential {
    param(
        [Parameter(Position = 0)]
        [string]$SubCommand,

        [Parameter(Position = 1)]
        [string]$Name,

        [switch]$Help
    )

    if ($Help -or [string]::IsNullOrWhiteSpace($SubCommand)) {
        Write-Host @"
Usage: boxer credential <subcommand>

Subcommands:
    sync                    Sync profiles, config, and Claude Switcher
                            to all running boxer containers
    install <name>          Install/update Claude Switcher on a specific
                            running container

The sync command pushes all saved profiles, Claude Code config, and the
latest Claude Switcher (cs) into every running container. Stopped
containers will receive updates on their next start.

Active credentials are NOT synced — use 'cs use <profile>' inside each
container to select an identity.
"@
        return
    }

    switch ($SubCommand) {
        "sync"    { Invoke-BoxerCredentialSync }
        "install" { Invoke-BoxerCredentialInstall -Name $Name }
        default   { Stop-BoxerWithError "Unknown subcommand: $SubCommand. Run 'boxer credential --help' for usage." }
    }
}

function Invoke-BoxerCredentialSync {
    Assert-DockerRunning

    $containers = docker ps -a --filter "label=boxer.managed=true" --format '{{.Names}}' 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($containers)) {
        Write-BoxerInfo "No boxer containers found."
        return
    }

    $csScript = Resolve-ClaudeSwitchScript
    $containerList = $containers -split "`n" | Where-Object { $_.Trim() -ne "" }

    $total = 0
    $synced = 0
    $skipped = 0
    $failed = 0

    foreach ($name in $containerList) {
        $name = $name.Trim()
        $total++

        $status = Get-ContainerStatus $name
        if ($status -ne "running") {
            Write-BoxerInfo "  ${name}: skipped (${status}, will sync on next start)"
            $skipped++
            continue
        }

        Write-BoxerInfo "  ${name}: syncing..."

        # Ensure ~/.claude directory exists
        docker exec $name mkdir -p "$($script:BOXER_CONTAINER_HOME)/.claude" 2>&1 | Out-Null

        # Sync profiles and Claude Code config
        try { Sync-BoxerClaudeConfig $name } catch { Write-BoxerWarn "  ${name}: config sync failed (non-fatal)" }
        try { Set-BoxerCredentialPermissions $name } catch {}

        if ($csScript) {
            try { Install-ClaudeSwitcher -Name $name -ScriptPath $csScript } catch {
                Write-BoxerWarn "  ${name}: Claude Switcher install failed (non-fatal)"
            }
        }

        $synced++
    }

    Write-BoxerSuccess "Credential sync complete: $synced synced, $skipped skipped (stopped), $failed failed (of $total total)"
}

function Invoke-BoxerCredentialInstall {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Stop-BoxerWithError "Usage: boxer credential install <name>"
    }

    Assert-DockerRunning
    Assert-BoxerContainer $Name

    $status = Get-ContainerStatus $Name
    if ($status -ne "running") {
        Stop-BoxerWithError "Container '$Name' is not running (status: $status). Start it first with: boxer start $Name"
    }

    $csScript = Resolve-ClaudeSwitchScript
    if (-not $csScript) {
        Stop-BoxerWithError "claude-switch.py not found at $(Join-Path $script:BOXER_ROOT 'claude-switch.py')"
    }

    Install-ClaudeSwitcher -Name $Name -ScriptPath $csScript
    Write-BoxerSuccess "Claude Switcher installed in '$Name'. Use 'cs status' inside the container."
}

function Install-ClaudeSwitcher {
    param(
        [string]$Name,
        [string]$ScriptPath
    )

    docker cp "$ScriptPath" "${Name}:/usr/local/bin/claude-switch.py"

    docker exec $Name bash -c '
        printf "#!/bin/sh\nexec python3 /usr/local/bin/claude-switch.py \"\$@\"\n" > /usr/local/bin/cs
        chmod +x /usr/local/bin/claude-switch.py /usr/local/bin/cs
    '

    docker exec $Name chown "$($script:BOXER_CONTAINER_USER):$($script:BOXER_CONTAINER_USER)" `
        /usr/local/bin/claude-switch.py /usr/local/bin/cs 2>&1 | Out-Null
}

function Set-BoxerCredentialPermissions {
    param([string]$Name)

    $destDir = "$($script:BOXER_CONTAINER_HOME)/.claude"

    docker exec $Name bash -c @"
        if [ -d '$destDir/profiles' ]; then
            find '$destDir/profiles' -name '*.json' -exec chmod 600 {} + 2>/dev/null || true
        fi
"@ 2>&1 | Out-Null
}
