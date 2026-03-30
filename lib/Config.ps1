# Boxer configuration: INI-style config reader

$script:BOXER_CONFIG_DIR = Join-Path $HOME ".boxer"
$script:BOXER_CONFIG_FILE = Join-Path $script:BOXER_CONFIG_DIR "config"

function Get-BoxerConfig {
    param(
        [string]$Section,
        [string]$Key,
        [string]$Default = ""
    )

    if (-not (Test-Path $script:BOXER_CONFIG_FILE)) {
        return $Default
    }

    $inSection = $false
    foreach ($rawLine in Get-Content $script:BOXER_CONFIG_FILE) {
        # Strip comments and trim
        $line = ($rawLine -replace '#.*$', '').Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        # Section header
        if ($line -match '^\[([^\]]+)\]$') {
            $inSection = ($Matches[1] -eq $Section)
            continue
        }

        # Key=value in the target section
        if ($inSection -and $line -match '^([^=]+)=(.*)$') {
            $k = $Matches[1].Trim()
            $v = $Matches[2].Trim()
            if ($k -eq $Key) {
                return $v
            }
        }
    }

    return $Default
}

function Initialize-BoxerConfig {
    if (-not (Test-Path $script:BOXER_CONFIG_DIR)) {
        New-Item -ItemType Directory -Path $script:BOXER_CONFIG_DIR -Force | Out-Null
    }

    if (-not (Test-Path $script:BOXER_CONFIG_FILE)) {
        @"
# Boxer configuration
# See config/defaults.conf in the boxer install directory for all options.

[defaults]
cpu = 4
memory = 8g
network = restricted

[firewall]
# Comma-separated extra domains to allow through the firewall
extra_domains =

[mounts]
ssh = true
gitconfig = true

[sync]
# Copy Claude Code customization into containers on start
claude_config = true
"@ | Set-Content -Path $script:BOXER_CONFIG_FILE -Encoding UTF8

        Write-BoxerInfo "Created default config at $($script:BOXER_CONFIG_FILE)"
    }
}

# Run on import
Initialize-BoxerConfig
