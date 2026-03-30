#Requires -Version 7.0
<#
.SYNOPSIS
    boxer - Isolated Docker containers for Claude Code CLI
.DESCRIPTION
    Create, manage, and run Claude Code inside network-restricted Docker sandboxes.
#>

$ErrorActionPreference = "Stop"

# Resolve script root
$script:BOXER_ROOT = $PSScriptRoot

# Source libraries
. "$script:BOXER_ROOT\lib\Constants.ps1"
. "$script:BOXER_ROOT\lib\Utils.ps1"
. "$script:BOXER_ROOT\lib\Config.ps1"
. "$script:BOXER_ROOT\lib\Docker.ps1"

function Show-Usage {
    Write-Host @"
boxer - Isolated Docker containers for Claude Code CLI

Usage:
    boxer <command> [options]

Commands:
    create <repo-path> <name>   Create a new sandbox container
    start <name>                Start a container and open a shell
    claude <name>               Launch Claude Code in a container
    stop <name>                 Stop a container
    rm <name>                   Remove a container
    list                        List all boxer containers
    status <name>               Show container details
    logs <name>                 Show container logs
    build                       Build/rebuild the boxer image
    open <name>                 Open the firewall (allow all outbound)
    close <name>                Restore the restricted firewall
    credential sync             Sync credentials to all running containers
    credential install <name>   Install Claude Switcher on a container

Options:
    -h, --help                  Show this help
    -v, --version               Show version
    --verbose                   Enable debug logging (or set BOXER_DEBUG=1)

Examples:
    boxer create ~\my-project my-sandbox
    boxer start my-sandbox          # shell
    boxer claude my-sandbox         # Claude Code
    boxer stop my-sandbox
    boxer rm my-sandbox --volumes
"@
}

# --- Argument parsing ---
# PowerShell scripts invoked via a wrapper function receive $args.
# We parse the first positional arg as the command, then forward the rest.

# Check for global --verbose flag before command parsing
$script:BoxerVerbose = $false
$filteredArgs = @()
foreach ($a in $args) {
    if ($a -eq "--verbose") {
        $script:BoxerVerbose = $true
    } else {
        $filteredArgs += $a
    }
}
if ($env:BOXER_DEBUG -eq "1") { $script:BoxerVerbose = $true }

$command = $filteredArgs[0]
$remaining = @()
if ($filteredArgs.Count -gt 1) {
    $remaining = $filteredArgs[1..($filteredArgs.Count - 1)]
}

# Convert remaining args: translate --long-flags to PowerShell parameters
function Invoke-BoxerDispatch {
    param(
        [scriptblock]$Command,
        [array]$RawArgs,
        [string[]]$PositionalNames = @("Name")
    )

    $params = @{}
    $positional = [System.Collections.ArrayList]::new()
    $i = 0

    while ($i -lt $RawArgs.Count) {
        $arg = [string]$RawArgs[$i]
        switch -Regex ($arg) {
            '^(-h|--help)$'       { $params["Help"] = $true }
            '^--no-cache$'        { $params["NoCache"] = $true }
            '^--pull$'            { $params["Pull"] = $true }
            '^--cpu$'             { $i++; $params["Cpu"] = $RawArgs[$i] }
            '^--memory$'          { $i++; $params["Memory"] = $RawArgs[$i] }
            '^--network$'         { $i++; $params["Network"] = $RawArgs[$i] }
            '^--no-ssh$'          { $params["NoSsh"] = $true }
            '^--no-git-config$'   { $params["NoGitConfig"] = $true }
            '^--env$'             {
                $i++
                if (-not $params.ContainsKey("Env")) { $params["Env"] = @() }
                $params["Env"] += $RawArgs[$i]
            }
            '^--domains$'         { $i++; $params["Domains"] = $RawArgs[$i] }
            '^--start$'           { $params["Start"] = $true }
            '^--resume$'          { $params["Resume"] = $true }
            '^--print$'           { $params["Print"] = $true }
            '^--prompt$'          { $i++; $params["Prompt"] = $RawArgs[$i] }
            '^--model$'           { $i++; $params["Model"] = $RawArgs[$i] }
            '^(--follow|-F)$'     { $params["Follow"] = $true }
            '^(--tail|-n)$'       { $i++; $params["Tail"] = $RawArgs[$i] }
            '^(--volumes|-V)$'    { $params["Volumes"] = $true }
            '^(--force|-f)$'      { $params["Force"] = $true }
            '^(--all|-a)$'        { $params["All"] = $true }
            default               { [void]$positional.Add($arg) }
        }
        $i++
    }

    # Explicitly assign positional args to named parameters
    for ($p = 0; $p -lt [Math]::Min($positional.Count, $PositionalNames.Count); $p++) {
        $params[$PositionalNames[$p]] = $positional[$p]
    }

    & $Command @params
}

switch ($command) {
    "create" {
        . "$script:BOXER_ROOT\commands\Create.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerCreate} -RawArgs $remaining -PositionalNames @("RepoPath", "Name")
    }
    { $_ -in "start", "shell", "sh" } {
        . "$script:BOXER_ROOT\commands\Start.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerStart} -RawArgs $remaining -PositionalNames @("Name")
    }
    "claude" {
        . "$script:BOXER_ROOT\commands\Start.ps1"
        . "$script:BOXER_ROOT\commands\Claude.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerClaude} -RawArgs $remaining -PositionalNames @("Name")
    }
    "stop" {
        . "$script:BOXER_ROOT\commands\Stop.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerStop} -RawArgs $remaining -PositionalNames @("Name")
    }
    { $_ -in "rm", "remove" } {
        . "$script:BOXER_ROOT\commands\Remove.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerRemove} -RawArgs $remaining -PositionalNames @("Name")
    }
    { $_ -in "list", "ls" } {
        . "$script:BOXER_ROOT\commands\List.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerList} -RawArgs $remaining
    }
    "status" {
        . "$script:BOXER_ROOT\commands\Status.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerStatus} -RawArgs $remaining -PositionalNames @("Name")
    }
    "logs" {
        . "$script:BOXER_ROOT\commands\Logs.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerLogs} -RawArgs $remaining -PositionalNames @("Name")
    }
    "build" {
        . "$script:BOXER_ROOT\commands\Build.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerBuild} -RawArgs $remaining
    }
    "open" {
        . "$script:BOXER_ROOT\commands\Open.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerOpen} -RawArgs $remaining -PositionalNames @("Name")
    }
    "close" {
        . "$script:BOXER_ROOT\commands\Close.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerClose} -RawArgs $remaining -PositionalNames @("Name")
    }
    { $_ -in "credential", "cred" } {
        . "$script:BOXER_ROOT\commands\Start.ps1"
        . "$script:BOXER_ROOT\commands\Credential.ps1"
        Invoke-BoxerDispatch -Command ${function:Invoke-BoxerCredential} -RawArgs $remaining -PositionalNames @("SubCommand", "Name")
    }
    { $_ -in "-h", "--help", "help" } {
        Show-Usage
    }
    { $_ -in "-v", "--version" } {
        Write-Host "boxer $($script:BOXER_VERSION)"
    }
    "" {
        Show-Usage
        exit 1
    }
    $null {
        Show-Usage
        exit 1
    }
    default {
        Stop-BoxerWithError "Unknown command: $command. Run 'boxer --help' for usage."
    }
}
