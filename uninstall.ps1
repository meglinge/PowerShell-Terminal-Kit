[CmdletBinding()]
param(
    [string] $Backup,
    [switch] $KeepRuntime,
    [string] $StateRoot = (Join-Path $env:LOCALAPPDATA 'PowerShellTerminalKit'),
    [string] $ProfilePath = $PROFILE.CurrentUserAllHosts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'PowerShell Terminal Kit supports Windows only.' }

if (-not $Backup) {
    $original = Get-ChildItem (Join-Path $stateRoot 'backups') -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name | Where-Object { Test-Path (Join-Path $_.FullName 'manifest.json') } |
        Select-Object -First 1
    if (-not $original) { throw 'No installation backup manifest was found.' }
    $Backup = $original.FullName
}

$manifestPath = if (Test-Path $Backup -PathType Container) { Join-Path $Backup 'manifest.json' } else { $Backup }
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$safetyBackup = Join-Path $stateRoot ('uninstall-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $safetyBackup -Force | Out-Null

foreach ($entry in $manifest.entries) {
    if (Test-Path -LiteralPath $entry.path) {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try {
            $name = [BitConverter]::ToString(
                $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$entry.path))
            ).Replace('-', '') + '.current'
        } finally {
            $sha256.Dispose()
        }
        Copy-Item -LiteralPath $entry.path -Destination (Join-Path $safetyBackup $name) -Recurse -Force
        Remove-Item -LiteralPath $entry.path -Recurse -Force
    }
    if ($entry.existed) {
        New-Item -ItemType Directory -Path (Split-Path $entry.path) -Force | Out-Null
        Copy-Item -LiteralPath $entry.backup -Destination $entry.path -Recurse -Force
    }
}

if (-not $KeepRuntime) {
    Remove-Item (Join-Path $stateRoot 'bin') -Recurse -Force -ErrorAction SilentlyContinue
    $module = Join-Path (Split-Path $ProfilePath) 'Modules\Fast-TerminalIcons\0.3.0'
    Remove-Item $module -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'PowerShell Terminal Kit configuration was restored.' -ForegroundColor Green
Write-Host "Pre-uninstall safety copy: $safetyBackup"
Write-Host 'Installed shared applications, PowerShell modules, and fonts were intentionally retained.'
