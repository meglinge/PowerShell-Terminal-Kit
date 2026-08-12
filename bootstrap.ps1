# PowerShell Terminal Kit network bootstrapper.
# Usage: irm https://raw.githubusercontent.com/meglinge/PowerShell-Terminal-Kit/main/bootstrap.ps1 | iex
$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'PowerShell Terminal Kit supports Windows only.'
}

$repository = 'meglinge/PowerShell-Terminal-Kit'
$reference = if ($env:PSTK_REF) { $env:PSTK_REF } else { 'main' }
$archiveUrl = "https://codeload.github.com/$repository/zip/refs/heads/$reference"
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('PowerShellTerminalKit-' + [guid]::NewGuid().ToString('N'))

try {
    Write-Host "Downloading PowerShell Terminal Kit ($reference)…" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    $archive = Join-Path $temporaryRoot 'PowerShell-Terminal-Kit.zip'
    $webRequest = @{ Uri = $archiveUrl; OutFile = $archive }
    if ($PSVersionTable.PSVersion.Major -lt 6) { $webRequest.UseBasicParsing = $true }
    Invoke-WebRequest @webRequest
    Expand-Archive -LiteralPath $archive -DestinationPath $temporaryRoot -Force

    $installer = Get-ChildItem -LiteralPath $temporaryRoot -Filter install.ps1 -File -Recurse |
        Where-Object FullName -notlike '*\__MACOSX\*' | Select-Object -First 1
    if (-not $installer) { throw 'Downloaded archive does not contain install.ps1.' }

    # CI and maintainers can validate the complete network bootstrap without changing the machine.
    if ($env:PSTK_BOOTSTRAP_TEST -eq '1') {
        $tokens = $null
        $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($installer.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if ($errors.Count) { throw ($errors | Out-String) }
        Write-Host 'Bootstrap download and installer validation passed.' -ForegroundColor Green
        return
    }

    if ($PSVersionTable.PSVersion.Major -ge 7) {
        & $installer.FullName
        if ($LASTEXITCODE) { throw "Installer failed with exit code $LASTEXITCODE." }
        return
    }

    $pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
            throw 'PowerShell 7 is missing and WinGet is unavailable. Install Microsoft App Installer first.'
        }
        Write-Host 'Installing PowerShell 7 first…' -ForegroundColor Cyan
        & winget.exe install --id Microsoft.PowerShell --exact --silent `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "WinGet could not install PowerShell 7 (exit $LASTEXITCODE)." }
        $pwsh = @(
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\WindowsApps\pwsh.exe"
        ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    }
    if (-not $pwsh) { throw 'PowerShell 7 was installed but pwsh.exe could not be located. Open a new terminal and retry.' }

    & $pwsh -NoProfile -ExecutionPolicy Bypass -File $installer.FullName
    if ($LASTEXITCODE -ne 0) { throw "Installer failed with exit code $LASTEXITCODE." }
} finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}
