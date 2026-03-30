# boxer logs - Show container logs

function Invoke-BoxerLogs {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [Alias("F")]
        [switch]$Follow,

        [Alias("n")]
        [string]$Tail,

        [switch]$Help
    )

    if ($Help) {
        Write-Host @"
Usage: boxer logs <name> [options]

Options:
    --follow, -F     Follow log output
    --tail, -n <N>   Show last N lines
"@
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Stop-BoxerWithError "Usage: boxer logs <name>"
    }

    Assert-DockerRunning
    Assert-BoxerContainer $Name

    $cmd = @("logs")

    if ($Follow) { $cmd += "-f" }
    if (-not [string]::IsNullOrWhiteSpace($Tail)) {
        $cmd += "--tail"
        $cmd += $Tail
    }

    $cmd += $Name
    & docker @cmd
}
