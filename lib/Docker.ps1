# Boxer Docker helper functions

function Test-BoxerImageExists {
    $null = docker image inspect $script:BOXER_IMAGE 2>&1
    return $LASTEXITCODE -eq 0
}

function Initialize-BoxerImage {
    if (Test-BoxerImageExists) { return }

    Write-BoxerInfo "Boxer image not found. Building..."
    . "$script:BOXER_ROOT\commands\Build.ps1"
    Invoke-BoxerBuild
}

function Get-ContainerLabel {
    param(
        [string]$Name,
        [string]$Label
    )

    $value = docker inspect --format "{{index .Config.Labels `"$Label`"}}" $Name 2>&1
    if ($LASTEXITCODE -ne 0) { return $null }
    return $value.Trim()
}

function Get-BoxerContainerNames {
    $names = docker ps -a --filter "label=boxer.managed=true" --format '{{.Names}}' 2>&1
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($names | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
