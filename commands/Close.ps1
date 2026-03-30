# boxer close - Restore the restricted firewall on a container

function Invoke-BoxerClose {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$Help
    )

    if ($Help) {
        Write-Host @"
Usage: boxer close <name>

Restore the restricted outbound firewall on a running container,
re-applying the domain allowlist. Reverses 'boxer open <name>'.
"@
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Stop-BoxerWithError "Usage: boxer close <name>"
    }

    Assert-DockerRunning
    Assert-BoxerContainer $Name

    if ((Get-ContainerStatus $Name) -ne "running") {
        Stop-BoxerWithError "Container '$Name' is not running. Start it first with 'boxer start $Name'."
    }

    Write-BoxerInfo "Restoring firewall on '$Name'..."

    docker exec --user root $Name /usr/local/bin/firewall-init.sh
    if ($LASTEXITCODE -ne 0) {
        Stop-BoxerWithError "Failed to restore firewall on '$Name'."
    }

    Write-BoxerSuccess "Firewall restored on '$Name' — outbound restricted to allowlist."
}
