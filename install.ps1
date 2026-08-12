[CmdletBinding()]
param(
    [switch] $SkipPackages,
    [switch] $SkipFont,
    [switch] $SkipTerminalSettings,
    [switch] $DryRun,
    [string] $StateRoot = (Join-Path $env:LOCALAPPDATA 'PowerShellTerminalKit'),
    [string] $ProfilePath = $PROFILE.CurrentUserAllHosts,
    [string] $YaziKeymap = (Join-Path $env:APPDATA 'yazi\config\keymap.toml'),
    [string] $TerminalSettings = (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) { throw 'PowerShell Terminal Kit supports Windows only.' }
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'Run this installer with PowerShell 7: pwsh -File .\install.ps1' }

$repoRoot = $PSScriptRoot
$backupRoot = Join-Path $stateRoot ('backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$profileDirectory = Split-Path $profilePath
$moduleDestination = Join-Path $profileDirectory 'Modules\Fast-TerminalIcons\0.3.0'
$manifestEntries = [Collections.Generic.List[object]]::new()

$requiredAssets = @(
    'config\powershell\profile.ps1',
    'config\windows-terminal.fragment.json',
    'config\yazi\keymap.toml',
    'assets\fzf-icons\fzf.exe',
    'assets\Fast-TerminalIcons\0.3.0\Fast-TerminalIcons.dll',
    'uninstall.ps1',
    'verify.ps1'
)
foreach ($relative in $requiredAssets) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $relative) -PathType Leaf)) {
        throw "Repository asset is missing: $relative"
    }
}

function Write-Step([string] $Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Backup-Target([string] $Path, [string] $Name) {
    $exists = Test-Path -LiteralPath $Path
    $backupPath = Join-Path $backupRoot $Name
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path (Split-Path $backupPath) -Force | Out-Null
        if ($exists) { Copy-Item -LiteralPath $Path -Destination $backupPath -Recurse -Force }
    }
    $manifestEntries.Add([pscustomobject]@{ path = $Path; backup = $backupPath; existed = $exists })
}

function Set-ObjectProperty([object] $Object, [string] $Name, [object] $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Copy-FileIfChanged([string] $Source, [string] $Destination) {
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($sourceHash -eq $destinationHash) { return }
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Invoke-DownloadFile([string] $Uri, [string] $OutFile) {
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        try {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            Invoke-WebRequest -Uri $Uri -OutFile $OutFile
            if ((Get-Item -LiteralPath $OutFile).Length -eq 0) { throw 'The downloaded file is empty.' }
            return
        } catch {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            if ($attempt -eq 4) { throw }
            $delay = [math]::Pow(2, $attempt)
            Write-Warning "Download failed (attempt $attempt/4); retrying in $delay seconds."
            Start-Sleep -Seconds $delay
        }
    }
}

function Install-WinGetDependencies {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'WinGet is required. Install Microsoft App Installer and run again.'
    }

    $packages = @(
        'Microsoft.WindowsTerminal', 'Microsoft.PowerShell', 'Git.Git',
        'BurntSushi.ripgrep.MSVC', 'sharkdp.fd', 'ajeetdsouza.zoxide',
        'sxyazi.yazi', 'rsteube.Carapace', 'aristocratos.btop4win',
        'JesseDuffield.lazygit', 'bootandy.dust', 'jqlang.jq', 'Casey.Just'
    )
    if ($DryRun) {
        $packages | ForEach-Object { Write-Host "  WinGet $_" }
        return
    }

    $results = $packages | ForEach-Object -Parallel {
        $id = $_
        & winget list --id $id --exact --accept-source-agreements --disable-interactivity 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  WinGet $id (already installed)"
            return [pscustomobject]@{ Id = $id; ExitCode = 0; Output = '' }
        }

        Write-Host "  WinGet $id (installing)"
        $output = & winget install --id $id --exact --silent --accept-package-agreements `
            --accept-source-agreements --disable-interactivity 2>&1 | Out-String
        [pscustomobject]@{ Id = $id; ExitCode = $LASTEXITCODE; Output = $output }
    } -ThrottleLimit 4

    # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE: another process or stale
    # package metadata can reveal an existing current version after the list check.
    $failures = @($results | Where-Object ExitCode -notin 0, -1978335189)
    if ($failures.Count) {
        foreach ($failure in $failures) {
            if ($failure.Output) { Write-Host $failure.Output.TrimEnd() -ForegroundColor DarkGray }
            Write-Host "  WinGet $($failure.Id) failed (exit $($failure.ExitCode))." -ForegroundColor Red
        }
        throw "WinGet failed for: $($failures.Id -join ', ')."
    }
}

function Install-PowerShellModules {
    $modules = @(
        @{ Name = 'PSReadLine'; Version = [version]'2.4.5' },
        @{ Name = 'PSFzf'; Version = [version]'2.7.12' },
        @{ Name = 'CompletionPredictor'; Version = [version]'0.1.1' }
    )
    if ($DryRun) {
        $modules | ForEach-Object { Write-Host "  PSGallery $($_.Name) >= $($_.Version)" }
        return
    }

    $repository = Get-PSRepository PSGallery
    $oldPolicy = $repository.InstallationPolicy
    try {
        if ($oldPolicy -ne 'Trusted') { Set-PSRepository PSGallery -InstallationPolicy Trusted }
        foreach ($module in $modules) {
            $available = Get-Module -ListAvailable $module.Name |
                Where-Object Version -ge $module.Version | Select-Object -First 1
            if (-not $available) {
                Write-Host "  Installing $($module.Name)"
                Install-Module $module.Name -Scope CurrentUser -MinimumVersion $module.Version `
                    -Repository PSGallery -Force -AllowClobber -Confirm:$false
            }
        }
    } finally {
        if ($oldPolicy -ne 'Trusted') { Set-PSRepository PSGallery -InstallationPolicy $oldPolicy }
    }
}

function Install-MapleMono {
    $fontRegistry = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $fontDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $installed = Get-ItemProperty $fontRegistry -ErrorAction SilentlyContinue
    if ($installed -and $installed.PSObject.Properties.Name -match '^Maple Mono NF CN Regular') {
        Write-Host '  Maple Mono NF CN is already installed.'
        return
    }
    $localFonts = @(Get-ChildItem $fontDirectory -Filter 'MapleMono-NF-CN-*.ttf' -File -ErrorAction SilentlyContinue)
    if ($localFonts.BaseName -contains 'MapleMono-NF-CN-Regular') {
        foreach ($font in $localFonts) {
            $style = $font.BaseName -replace '^MapleMono-NF-CN-', ''
            New-ItemProperty $fontRegistry -Name "Maple Mono NF CN $style (TrueType)" `
                -Value $font.FullName -PropertyType String -Force | Out-Null
        }
        Write-Host '  Maple Mono NF CN is already installed; repaired its registry entries.'
        return
    }
    if ($DryRun) { Write-Host '  Download MapleMono-NF-CN-unhinted.zip from the latest stable release.'; return }

    $release = Invoke-RestMethod 'https://api.github.com/repos/subframe7536/maple-font/releases/latest'
    $asset = $release.assets | Where-Object name -eq 'MapleMono-NF-CN-unhinted.zip' | Select-Object -First 1
    if (-not $asset) { throw 'The latest stable Maple Mono release has no NF-CN unhinted asset.' }
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('PowerShellTerminalKit-font-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $temp | Out-Null
        $archive = Join-Path $temp $asset.name
        Invoke-DownloadFile $asset.browser_download_url $archive
        Expand-Archive $archive (Join-Path $temp 'font')
        New-Item -ItemType Directory -Path $fontDirectory -Force | Out-Null
        foreach ($font in Get-ChildItem (Join-Path $temp 'font') -Filter 'MapleMono-NF-CN-*.ttf' -Recurse) {
            $destination = Join-Path $fontDirectory $font.Name
            # Installed fonts can remain locked by Windows Terminal for the lifetime of
            # the process. Keep an existing file and repair its per-user registry entry
            # instead of trying to overwrite it and aborting an otherwise safe rerun.
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                Copy-Item $font.FullName $destination
            }
            $style = $font.BaseName -replace '^MapleMono-NF-CN-', ''
            New-ItemProperty $fontRegistry -Name "Maple Mono NF CN $style (TrueType)" `
                -Value $destination -PropertyType String -Force | Out-Null
        }
    } finally {
        Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Merge-WindowsTerminalSettings {
    $fragment = Get-Content (Join-Path $repoRoot 'config\windows-terminal.fragment.json') -Raw | ConvertFrom-Json
    if (Test-Path -LiteralPath $terminalSettings) {
        try { $settings = Get-Content $terminalSettings -Raw | ConvertFrom-Json }
        catch { throw "Windows Terminal settings are not valid JSON; backup was kept and merge was stopped: $_" }
    } else {
        $settings = [pscustomobject]@{}
    }

    $special = @('profileDefaults', 'powerShellProfile', 'scheme')
    foreach ($property in $fragment.PSObject.Properties | Where-Object Name -notin $special) {
        Set-ObjectProperty $settings $property.Name $property.Value
    }
    if (-not $settings.PSObject.Properties['profiles']) {
        Set-ObjectProperty $settings 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() })
    }
    if (-not $settings.profiles.PSObject.Properties['defaults']) {
        Set-ObjectProperty $settings.profiles 'defaults' ([pscustomobject]@{})
    }
    foreach ($property in $fragment.profileDefaults.PSObject.Properties) {
        Set-ObjectProperty $settings.profiles.defaults $property.Name $property.Value
    }
    if (-not $settings.profiles.PSObject.Properties['list']) { Set-ObjectProperty $settings.profiles 'list' @() }
    $pwshProfile = $settings.profiles.list | Where-Object guid -eq $fragment.powerShellProfile.guid | Select-Object -First 1
    if (-not $pwshProfile) {
        $pwshProfile = [pscustomobject]@{}
        $settings.profiles.list = @($settings.profiles.list) + $pwshProfile
    }
    foreach ($property in $fragment.powerShellProfile.PSObject.Properties) {
        Set-ObjectProperty $pwshProfile $property.Name $property.Value
    }
    if (-not $settings.PSObject.Properties['schemes']) { Set-ObjectProperty $settings 'schemes' @() }
    $settings.schemes = @($settings.schemes | Where-Object name -ne $fragment.scheme.name) + $fragment.scheme

    New-Item -ItemType Directory -Path (Split-Path $terminalSettings) -Force | Out-Null
    $settings | ConvertTo-Json -Depth 100 | Set-Content $terminalSettings -Encoding utf8NoBOM
}

Write-Step 'Plan and backup'
Write-Host "  Profile: $profilePath"
Write-Host "  Yazi:    $yaziKeymap"
Write-Host "  Terminal:$terminalSettings"
Backup-Target $profilePath 'profile.ps1'
Backup-Target $yaziKeymap 'yazi\keymap.toml'
if (-not $SkipTerminalSettings) { Backup-Target $terminalSettings 'terminal\settings.json' }

if (-not $SkipPackages) {
    Write-Step 'Install command-line dependencies'
    Install-WinGetDependencies
    Write-Step 'Install PowerShell modules'
    Install-PowerShellModules
}
if (-not $SkipFont) {
    Write-Step 'Install Maple Mono NF CN for the current user'
    Install-MapleMono
}

Write-Step 'Install bundled native components and configuration'
if (-not $DryRun) {
    New-Item -ItemType Directory -Path (Join-Path $stateRoot 'bin'), $moduleDestination,
        (Split-Path $profilePath), (Split-Path $yaziKeymap) -Force | Out-Null
    Copy-FileIfChanged (Join-Path $repoRoot 'assets\fzf-icons\fzf.exe') (Join-Path $stateRoot 'bin\fzf.exe')
    foreach ($moduleFile in Get-ChildItem (Join-Path $repoRoot 'assets\Fast-TerminalIcons\0.3.0') -File) {
        Copy-FileIfChanged $moduleFile.FullName (Join-Path $moduleDestination $moduleFile.Name)
    }
    Copy-FileIfChanged (Join-Path $repoRoot 'uninstall.ps1') (Join-Path $stateRoot 'uninstall.ps1')
    Copy-FileIfChanged (Join-Path $repoRoot 'verify.ps1') (Join-Path $stateRoot 'verify.ps1')
    Copy-Item (Join-Path $repoRoot 'config\powershell\profile.ps1') $profilePath -Force
    Copy-Item (Join-Path $repoRoot 'config\yazi\keymap.toml') $yaziKeymap -Force
    if (-not $SkipTerminalSettings) { Merge-WindowsTerminalSettings }

    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    [pscustomobject]@{
        created = (Get-Date).ToString('o')
        repository = $repoRoot
        entries = $manifestEntries
    } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $backupRoot 'manifest.json') -Encoding utf8NoBOM
}

Write-Step 'Complete'
if ($DryRun) { Write-Host 'Dry run only; no files or packages were changed.' -ForegroundColor Yellow }
else {
    Write-Host "Backup: $backupRoot"
    Write-Host 'Close all Windows Terminal windows, reopen Terminal, then run: Test-TerminalKit'
}
