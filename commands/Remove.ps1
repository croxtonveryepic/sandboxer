# boxer rm - Remove a container and optionally its volumes

function Invoke-BoxerRemove {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [Alias("V")]
        [switch]$Volumes,

        [Alias("f")]
        [switch]$Force,

        [Alias("a")]
        [switch]$All,

        [switch]$Help
    )

    if ($Help) {
        Write-Host @"
Usage: boxer rm <name> [options]

Options:
    --volumes, -V    Also remove persistent volumes (Claude config/data)
    --force, -f      Force remove even if running
    --all, -a        Remove all boxer containers
"@
        return
    }

    Assert-DockerRunning

    if ($All) {
        $containers = Get-BoxerContainerNames
        if ($containers.Count -eq 0) {
            Write-BoxerInfo "No boxer containers to remove."
            return
        }
        foreach ($c in $containers) {
            Remove-SingleContainer -Name $c -Force:$Force -Volumes:$Volumes
        }
        Write-BoxerSuccess "All boxer containers removed."
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Stop-BoxerWithError "Usage: boxer rm <name> [--volumes] [--force]"
    }

    Assert-BoxerContainer $Name
    Remove-SingleContainer -Name $Name -Force:$Force -Volumes:$Volumes
}

function Remove-SingleContainer {
    param(
        [string]$Name,
        [switch]$Force,
        [switch]$Volumes
    )

    # Stop if running
    if ((Get-ContainerStatus $Name) -eq "running") {
        if (-not $Force) {
            Stop-BoxerWithError "Container '$Name' is running. Stop it first or use --force."
        }
        $null = docker stop $Name
        if ($LASTEXITCODE -ne 0) {
            Stop-BoxerWithError "Failed to stop container '$Name'."
        }
    }

    $null = docker rm $Name
    if ($LASTEXITCODE -ne 0) {
        Stop-BoxerWithError "Failed to remove container '$Name'."
    }

    if ($Volumes) {
        $configVol = "$($script:BOXER_VOLUME_PREFIX)-${Name}-claude-config"
        $dataVol   = "$($script:BOXER_VOLUME_PREFIX)-${Name}-claude-data"

        $null = docker volume rm $configVol 2>&1
        if ($LASTEXITCODE -eq 0) { Write-BoxerInfo "Removed volume '$configVol'" }

        $null = docker volume rm $dataVol 2>&1
        if ($LASTEXITCODE -eq 0) { Write-BoxerInfo "Removed volume '$dataVol'" }
    }

    Write-BoxerSuccess "Container '$Name' removed."
}
