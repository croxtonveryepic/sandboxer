# boxer open - Open the firewall on a container (allow all outbound)

function Invoke-BoxerOpen {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$Help
    )

    if ($Help) {
        Write-Host @"
Usage: boxer open <name>

Open the outbound firewall on a running container, allowing
unrestricted internet access. Use 'boxer close <name>' to
restore the restricted allowlist.
"@
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Stop-BoxerWithError "Usage: boxer open <name>"
    }

    Assert-DockerRunning
    Assert-BoxerContainer $Name

    if ((Get-ContainerStatus $Name) -ne "running") {
        Stop-BoxerWithError "Container '$Name' is not running. Start it first with 'boxer start $Name'."
    }

    Write-BoxerInfo "Opening firewall on '$Name'..."

    docker exec --user root $Name bash -c 'iptables -F OUTPUT 2>/dev/null || true; iptables -P OUTPUT ACCEPT'
    if ($LASTEXITCODE -ne 0) {
        Stop-BoxerWithError "Failed to open firewall on '$Name'."
    }

    Write-BoxerSuccess "Firewall opened on '$Name' — all outbound traffic allowed."
    Write-BoxerWarn "Run 'boxer close $Name' to restore the restricted allowlist."
}
