# boxer list - List all boxer containers

function Invoke-BoxerList {
    param([switch]$Help)

    if ($Help) {
        Write-Host "Usage: boxer list"
        Write-Host ""
        Write-Host "Lists all boxer-managed containers with their status."
        return
    }

    Assert-DockerRunning

    $raw = docker ps -a `
        --filter "label=boxer.managed=true" `
        --format '{{.Names}}\t{{.State}}\t{{.Label "boxer.repo.path"}}\t{{.Label "boxer.created.at"}}' 2>&1

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) {
        Write-Host "No boxer containers found. Create one with: boxer create <repo-path> <name>"
        return
    }

    # Print header
    "{0,-20} {1,-12} {2,-45} {3}" -f "NAME", "STATUS", "REPO", "CREATED" | Write-Host
    "{0,-20} {1,-12} {2,-45} {3}" -f "----", "------", "----", "-------" | Write-Host

    foreach ($line in $raw -split "`n") {
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $parts = $line -split "`t"
        $name    = $parts[0]
        $state   = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        $repo    = if ($parts.Count -gt 2) { $parts[2] } else { "" }
        $created = if ($parts.Count -gt 3) { $parts[3] } else { "" }

        # Truncate repo path if too long
        if ($repo.Length -gt 45) {
            $repo = "..." + $repo.Substring($repo.Length - 42)
        }
        # Strip time from created date
        if ($created -match '^([^T]+)T') {
            $created = $Matches[1]
        }

        "{0,-20} {1,-12} {2,-45} {3}" -f $name, $state, $repo, $created | Write-Host
    }
}
