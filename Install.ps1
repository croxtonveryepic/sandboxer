#Requires -Version 7.0
<#
.SYNOPSIS
    Install the boxer command for PowerShell.
.DESCRIPTION
    Creates a boxer.cmd wrapper in ~/bin so "boxer" works from any terminal.
    Also adds a PowerShell alias via the user's profile.
#>

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$BinDir = Join-Path $HOME "bin"
$CmdWrapper = Join-Path $BinDir "boxer.cmd"
$Ps1Wrapper = Join-Path $BinDir "boxer.ps1"

# Ensure ~/bin exists
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

# Create a .cmd wrapper so "boxer" works from CMD and PowerShell
@"
@echo off
pwsh -NoProfile -ExecutionPolicy Bypass -File "$ScriptDir\boxer.ps1" %*
"@ | Set-Content -Path $CmdWrapper -Encoding ASCII

# Create a .ps1 wrapper for direct PowerShell invocation
@"
# Thin wrapper - delegates to the real boxer script
& "$ScriptDir\boxer.ps1" @args
"@ | Set-Content -Path $Ps1Wrapper -Encoding UTF8

Write-Host "Installed: $CmdWrapper"
Write-Host "Installed: $Ps1Wrapper"

# Check if ~/bin is on PATH
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$BinDir*") {
    Write-Host ""
    Write-Host "NOTE: $BinDir is not on your PATH." -ForegroundColor Yellow
    Write-Host "Add it by running:" -ForegroundColor Yellow
    Write-Host "  [Environment]::SetEnvironmentVariable('PATH', `"$BinDir;`$env:PATH`", 'User')" -ForegroundColor Cyan
}

# Add PowerShell function to profile for seamless usage
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$functionBlock = @"

# Boxer - Claude Code sandbox manager
function boxer { & "$ScriptDir\boxer.ps1" @args }
"@

if (Test-Path $PROFILE) {
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -notmatch "function boxer") {
        Add-Content -Path $PROFILE -Value $functionBlock
        Write-Host "Added 'boxer' function to $PROFILE"
    }
    else {
        Write-Host "'boxer' function already exists in $PROFILE"
    }
}
else {
    Set-Content -Path $PROFILE -Value $functionBlock
    Write-Host "Created $PROFILE with 'boxer' function"
}

Write-Host ""
Write-Host "Run 'boxer --help' to get started." -ForegroundColor Green
Write-Host "You may need to restart your terminal or run '. `$PROFILE' first."
