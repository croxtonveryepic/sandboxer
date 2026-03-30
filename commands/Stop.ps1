# boxer stop - Stop a running container

function Invoke-BoxerStop {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [Alias("a")]
        [switch]$All,

        [switch]$Help
    )

    if ($Help) {
        Write-Host "Usage: boxer stop <name> [--all]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  --all, -a    Stop all boxer containers"
        return
    }

    Assert-DockerRunning

    if ($All) {
        $containers = Get-BoxerContainerNames
        if ($containers.Count -eq 0) {
            Write-BoxerInfo "No boxer containers to stop."
            return
        }
        $count = 0
        foreach ($c in $containers) {
            if ((Get-ContainerStatus $c) -eq "running") {
                $null = docker stop $c
                if ($LASTEXITCODE -ne 0) { Write-BoxerWarn "Failed to stop '$c'" ; continue }
                Write-BoxerInfo "Stopped '$c'"
                $count++
            }
        }
        Write-BoxerSuccess "Stopped $count container(s)."
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Stop-BoxerWithError "Usage: boxer stop <name> [--all]"
    }

    Assert-BoxerContainer $Name

    if ((Get-ContainerStatus $Name) -ne "running") {
        Write-BoxerInfo "Container '$Name' is not running."
        return
    }

    $null = docker stop $Name
    if ($LASTEXITCODE -ne 0) {
        Stop-BoxerWithError "Failed to stop container '$Name'."
    }
    Write-BoxerSuccess "Container '$Name' stopped."
}
