# boxer build - Build or rebuild the boxer Docker image

function Invoke-BoxerBuild {
    param(
        [switch]$NoCache,
        [switch]$Pull,
        [switch]$Help
    )

    if ($Help) {
        Write-Host "Usage: boxer build [--no-cache] [--pull]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  --no-cache    Build without using Docker cache"
        Write-Host "  --pull        Pull the latest base image before building"
        return
    }

    Assert-DockerRunning

    # Copy claude-switch.py into Docker build context (Dockerfile COPY requires it)
    $csSrc = Join-Path $script:BOXER_ROOT "claude-switch.py"
    $csDest = Join-Path $script:BOXER_ROOT "docker\claude-switch.py"
    if (Test-Path $csSrc) {
        Copy-Item $csSrc $csDest
    } else {
        Write-BoxerWarn "claude-switch.py not found at $csSrc - containers will not have 'cs' command"
    }

    try {
        $buildArgs = @(
            "build"
            "-t", $script:BOXER_IMAGE
            "-f", "$script:BOXER_ROOT\docker\Dockerfile"
        )

        if ($NoCache) { $buildArgs += "--no-cache" }
        if ($Pull)    { $buildArgs += "--pull" }

        $buildArgs += "$script:BOXER_ROOT\docker"

        Write-BoxerInfo "Building boxer image..."
        & docker @buildArgs
        if ($LASTEXITCODE -ne 0) {
            Stop-BoxerWithError "Docker build failed."
        }
        Write-BoxerSuccess "Image '$($script:BOXER_IMAGE)' built successfully."
    } finally {
        if (Test-Path $csDest) { Remove-Item $csDest -Force }
    }
}
