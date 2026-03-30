# boxer status - Show detailed status for a container

function Invoke-BoxerStatus {
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$Help
    )

    if ($Help) {
        Write-Host "Usage: boxer status <name>"
        return
    }

    if ([string]::IsNullOrWhiteSpace($Name)) {
        Stop-BoxerWithError "Usage: boxer status <name>"
    }

    Assert-DockerRunning
    Assert-BoxerContainer $Name

    $state    = Get-ContainerStatus $Name
    $repoPath = Get-ContainerLabel $Name "boxer.repo.path"
    $created  = Get-ContainerLabel $Name "boxer.created.at"
    $network  = Get-ContainerLabel $Name "boxer.network"
    $version  = Get-ContainerLabel $Name "boxer.version"

    Write-Host "Container:  $Name"
    Write-Host "Status:     $state"
    Write-Host "Repo:       $repoPath"
    Write-Host "Network:    $(if ($network) { $network } else { 'restricted' })"
    Write-Host "Created:    $created"
    Write-Host "Version:    $(if ($version) { $version } else { 'unknown' })"

    # Show resource limits
    $cpus = docker inspect --format '{{.HostConfig.NanoCpus}}' $Name 2>&1
    $mem  = docker inspect --format '{{.HostConfig.Memory}}' $Name 2>&1

    if ($cpus -and $cpus -ne "0") {
        $cpuCores = [math]::Round([long]$cpus / 1000000000, 1)
        Write-Host "CPU Limit:  $cpuCores cores"
    }
    if ($mem -and $mem -ne "0") {
        $memMB = [math]::Round([long]$mem / 1024 / 1024)
        Write-Host "Mem Limit:  ${memMB}MB"
    }

    # Show volumes
    Write-Host ""
    Write-Host "Volumes:"
    $mounts = docker inspect --format '{{range .Mounts}}  {{.Type}}: {{.Source}} -> {{.Destination}} ({{.Mode}}){{"\n"}}{{end}}' $Name 2>&1
    Write-Host $mounts

    # Show live resource usage if running
    if ($state -eq "running") {
        Write-Host "Live Usage:"
        docker stats --no-stream --format "  CPU: {{.CPUPerc}}  Memory: {{.MemUsage}}" $Name
    }
}
