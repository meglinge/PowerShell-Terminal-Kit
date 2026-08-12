[CmdletBinding()]
param(
    [switch] $RepositoryOnly,
    [switch] $InstalledOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Failures = 0

function Test-Check([string] $Name, [scriptblock] $Check) {
    try {
        $result = & $Check
        if ($result -eq $false) { throw 'check returned false' }
        Write-Host "PASS  $Name" -ForegroundColor Green
    } catch {
        $script:Failures++
        Write-Host "FAIL  $Name — $_" -ForegroundColor Red
    }
}

function Test-PowerShellSyntax([string] $Path) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count) { throw ($errors | Out-String) }
}

$repoRoot = $PSScriptRoot
if (-not $InstalledOnly) {
Test-Check 'PowerShell profile syntax' { Test-PowerShellSyntax (Join-Path $repoRoot 'config\powershell\profile.ps1') }
Test-Check 'Network bootstrap syntax' { Test-PowerShellSyntax (Join-Path $repoRoot 'bootstrap.ps1') }
Test-Check 'Installer syntax' { Test-PowerShellSyntax (Join-Path $repoRoot 'install.ps1') }
Test-Check 'Uninstaller syntax' { Test-PowerShellSyntax (Join-Path $repoRoot 'uninstall.ps1') }
Test-Check 'Verifier syntax' { Test-PowerShellSyntax (Join-Path $repoRoot 'verify.ps1') }
Test-Check 'Windows Terminal fragment JSON' {
    $null = Get-Content (Join-Path $repoRoot 'config\windows-terminal.fragment.json') -Raw | ConvertFrom-Json
}
Test-Check 'No machine-specific paths or common token prefixes' {
    $text = Get-ChildItem $repoRoot -Recurse -File |
        Where-Object { $_.Extension -in '.ps1', '.json', '.toml', '.md' -and $_.Name -ne 'verify.ps1' } |
        Get-Content -Raw | Out-String
    if ($text -match 'QiaoHao|D:\\MegAiTools|gh[opsu]_[A-Za-z0-9]') { throw 'personal path or token-like text detected' }
}
Test-Check 'fzf-icons checksum' {
    (Get-FileHash (Join-Path $repoRoot 'assets\fzf-icons\fzf.exe') -Algorithm SHA256).Hash -eq
        '127763E2F3785939C11149BCA42EA97B25A54C9963762D859885FA3653598428'
}
Test-Check 'Fast-TerminalIcons checksum' {
    (Get-FileHash (Join-Path $repoRoot 'assets\Fast-TerminalIcons\0.3.0\Fast-TerminalIcons.dll') -Algorithm SHA256).Hash -eq
        'F5E8293490FA77C1F17614D9950025303CA9E1E270AE7D9E3B0E96DE9066A844'
}
Test-Check 'Bundled fzf exposes walker icons' {
    $fzf = Join-Path $repoRoot 'assets\fzf-icons\fzf.exe'
    (& $fzf --version) -match '-icons' -and ((& $fzf --help) -match '--walker-icons')
}
Test-Check 'Fast-TerminalIcons binary imports and renders a border' {
    $dll = Join-Path $repoRoot 'assets\Fast-TerminalIcons\0.3.0\Fast-TerminalIcons.dll'
    Import-Module $dll -Force
    $rendered = Get-Item $repoRoot | Format-FastTerminalTable
    $rendered.Contains('╭') -and $rendered.Contains('╯')
}
Test-Check 'Installer deploys and merges in an isolated target' {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('PowerShellTerminalKit-verify-' + [guid]::NewGuid().ToString('N'))
    try {
        $targetProfile = Join-Path $temp 'PowerShell\profile.ps1'
        $targetYazi = Join-Path $temp 'yazi\keymap.toml'
        $targetTerminal = Join-Path $temp 'Terminal\settings.json'
        New-Item -ItemType Directory -Path (Split-Path $targetTerminal) -Force | Out-Null
        '{"profiles":{"defaults":{},"list":[{"guid":"{keep-me}","name":"Existing"}]},"schemes":[{"name":"Existing Scheme"}]}' |
            Set-Content $targetTerminal -Encoding utf8NoBOM
        & (Join-Path $repoRoot 'install.ps1') -SkipPackages -SkipFont `
            -StateRoot (Join-Path $temp 'state') -ProfilePath $targetProfile `
            -YaziKeymap $targetYazi -TerminalSettings $targetTerminal | Out-Null
        $firstBackup = Get-ChildItem (Join-Path $temp 'state\backups') -Directory | Sort-Object Name | Select-Object -First 1
        $settings = Get-Content $targetTerminal -Raw | ConvertFrom-Json
        if (-not (Test-Path $targetProfile) -or -not (Test-Path $targetYazi)) { throw 'configuration files were not deployed' }
        if (-not (Test-Path (Join-Path $temp 'state\bin\fzf.exe'))) { throw 'fzf-icons was not deployed' }
        if ('{keep-me}' -notin $settings.profiles.list.guid) { throw 'existing Terminal profile was lost' }
        if ('Existing Scheme' -notin $settings.schemes.name) { throw 'existing Terminal scheme was lost' }
        if ($settings.profiles.defaults.colorScheme -ne 'Tokyo Night') { throw 'Terminal defaults were not merged' }
        Import-Module (Join-Path (Split-Path $targetProfile) 'Modules\Fast-TerminalIcons\0.3.0\Fast-TerminalIcons.dll') -Force
        & (Join-Path $repoRoot 'install.ps1') -SkipPackages -SkipFont `
            -StateRoot (Join-Path $temp 'state') -ProfilePath $targetProfile `
            -YaziKeymap $targetYazi -TerminalSettings $targetTerminal | Out-Null
        & (Join-Path $repoRoot 'uninstall.ps1') -StateRoot (Join-Path $temp 'state') `
            -ProfilePath $targetProfile -Backup $firstBackup.FullName | Out-Null
        $restored = Get-Content $targetTerminal -Raw | ConvertFrom-Json
        if (Test-Path $targetProfile) { throw 'new profile was not removed during rollback' }
        if (Test-Path $targetYazi) { throw 'new Yazi keymap was not removed during rollback' }
        if ($restored.profiles.list.Count -ne 1 -or $restored.profiles.list[0].guid -ne '{keep-me}') {
            throw 'Terminal settings were not restored exactly enough'
        }
    } finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
}

if (-not $RepositoryOnly) {
    $profilePath = $PROFILE.CurrentUserAllHosts
    Test-Check 'Installed profile exists and parses' { Test-PowerShellSyntax $profilePath }
    Test-Check 'Fresh PowerShell loads profile commands' {
        $output = & pwsh -NoLogo -NonInteractive -Command `
            "Get-Command ls, lso, ya, j, Format-FastTerminalTable | Select-Object -ExpandProperty Name"
        @('ls', 'lso', 'ya', 'j', 'Format-FastTerminalTable') |
            Where-Object { $_ -notin $output } | ForEach-Object { throw "missing command $_" }
    }
    Test-Check 'Installed fzf is the icon build' {
        (& (Join-Path $env:LOCALAPPDATA 'PowerShellTerminalKit\bin\fzf.exe') --version) -match '-icons'
    }
    Test-Check 'Yazi keymap is loaded' {
        $debug = & yazi --debug 2>&1 | Out-String
        $debug -match [regex]::Escape((Join-Path $env:APPDATA 'yazi\config\keymap.toml'))
    }
    Test-Check 'Windows Terminal uses Tokyo Night and PowerShell' {
        $path = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
        $settings = Get-Content $path -Raw | ConvertFrom-Json
        $settings.defaultProfile -eq '{574e775e-4f2a-5b96-ac1e-a2962a402336}' -and
            $settings.profiles.defaults.colorScheme -eq 'Tokyo Night' -and
            $settings.profiles.defaults.font.face -eq 'Maple Mono NF CN'
    }
}

if ($script:Failures) {
    Write-Host "`n$script:Failures check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "`nAll checks passed." -ForegroundColor Green
