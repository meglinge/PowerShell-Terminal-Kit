# PowerShell Terminal Kit - native PowerShell profile
$env:POWERSHELL_UPDATECHECK = 'Off'
$env:POWERSHELL_TELEMETRY_OPTOUT = '1'
$ProgressPreference = 'SilentlyContinue'
$OutputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()

$terminalKitRoot = Join-Path $env:LOCALAPPDATA 'PowerShellTerminalKit'
$terminalKitBin = Join-Path $terminalKitRoot 'bin'
if ((Test-Path -LiteralPath $terminalKitBin) -and $env:Path -notlike "*$terminalKitBin*") {
    $env:Path = "$terminalKitBin;$env:Path"
}

# Pick up newly installed per-user tools even if Windows Terminal was already open.
$currentPathEntries = @($env:Path -split ';')
foreach ($entry in ([Environment]::GetEnvironmentVariable('Path', 'User') -split ';')) {
    if ($entry -and $entry -notin $currentPathEntries) {
        $env:Path += ";$entry"
        $currentPathEntries += $entry
    }
}

$env:FZF_DEFAULT_OPTS = '--height=65% --layout=reverse --margin=1,2 --padding=0,1 --border=none --input-border=rounded --input-label=" Search " --list-border=rounded --list-label=" Files " --info=inline-right --prompt="❯ " --pointer="▌" --marker="✓" --scrollbar="│" --filepath-word --ghost="Type to filter" --color=dark,bg:#1a1b26,bg+:#283457,fg:#c0caf5,fg+:#c0caf5,hl:#bb9af7,hl+:#ff9e64,info:#565f89,prompt:#7dcfff,pointer:#7dcfff,marker:#9ece6a,spinner:#7dcfff,border:#3b4261,label:#7aa2f7,gutter:#1a1b26'
$env:FZF_CTRL_T_OPTS = '--walker-icons --walker-skip=.git,node_modules,target,dist,build,.cache,__pycache__,vendor,.venv,AppData'
Remove-Item Env:FZF_CTRL_T_COMMAND -ErrorAction SilentlyContinue

if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    if ($Host.UI.SupportsVirtualTerminal -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -Colors @{
        Command = '#7AA2F7'; Parameter = '#BB9AF7'; Operator = '#89DDFF'
        Variable = '#C0CAF5'; String = '#9ECE6A'; Number = '#FF9E64'
        Type = '#2AC3DE'; Comment = '#565F89'; Keyword = '#F7768E'
    }
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord
}

# Generate Carapace only on the first Tab press and batch native completer registration.
$carapacePath = (Get-Command carapace -ErrorAction SilentlyContinue).Source
if (-not $carapacePath) {
    $carapacePath = (Get-Item "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\rsteube.Carapace_*\carapace.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1).FullName
}
if ($carapacePath) {
    $carapaceDirectory = Split-Path $carapacePath
    if ($env:Path -notlike "*$carapaceDirectory*") { $env:Path = "$carapaceDirectory;$env:Path" }
    function Enable-Carapace {
        if ($global:CarapaceLoaded) { return }
        $carapaceCache = Join-Path $env:LOCALAPPDATA 'carapace\powershell-init-optimized.ps1'
        if (-not (Test-Path $carapaceCache) -or (Get-Item $carapacePath).LastWriteTimeUtc -gt (Get-Item $carapaceCache).LastWriteTimeUtc) {
            New-Item (Split-Path $carapaceCache) -ItemType Directory -Force | Out-Null
            $generated = @(& $carapacePath _carapace powershell)
            $registrationIndex = 0..($generated.Count - 1) |
                Where-Object { $generated[$_] -match '^Register-ArgumentCompleter' } |
                Select-Object -First 1
            if ($null -ne $registrationIndex) {
                $commandNames = $generated[$registrationIndex..($generated.Count - 1)] |
                    ForEach-Object { [regex]::Matches($_, "'([^']+)'") } |
                    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
                $quotedNames = $commandNames | ForEach-Object { "'$_'" }
                $optimized = @($generated[0..($registrationIndex - 1)])
                $optimized += "Register-ArgumentCompleter -Native -ScriptBlock `$_carapace_completer -CommandName @($($quotedNames -join ','))"
                $temporaryCache = "$carapaceCache.$PID.tmp"
                try {
                    $optimized | Set-Content $temporaryCache -Encoding utf8
                    Move-Item $temporaryCache $carapaceCache -Force
                } finally { Remove-Item $temporaryCache -Force -ErrorAction SilentlyContinue }
            }
        }
        if (Test-Path $carapaceCache) { . $carapaceCache; $global:CarapaceLoaded = $true }
    }
    Set-PSReadLineKeyHandler -Key Tab -ScriptBlock {
        Enable-Carapace
        [Microsoft.PowerShell.PSConsoleReadLine]::MenuComplete()
    }
}

if (Get-Module -ListAvailable PSFzf) {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock {
        Import-Module PSFzf
        Invoke-FzfPsReadlineHandlerProvider
    }
    Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock {
        Import-Module PSFzf
        Invoke-FzfPsReadlineHandlerHistory
    }
}

# Native PowerShell recreation of Oh My Zsh's robbyrussell prompt.
function global:prompt {
    $lastSuccess = $?
    $currentPath = $PWD.Path.TrimEnd('\')
    $displayPath = if ($currentPath -eq $HOME.TrimEnd('\')) { '~' }
        elseif ($currentPath -match '^[A-Za-z]:$') { "$currentPath\" }
        else { Split-Path $currentPath -Leaf }

    $gitBranch = $null
    $gitDirty = $false
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitBranch = git branch --show-current 2>$null
        if (-not $gitBranch) { $gitBranch = git rev-parse --short HEAD 2>$null }
        if ($gitBranch) { $gitDirty = [bool](git status --porcelain 2>$null) }
    }

    if ($lastSuccess) { Write-Host '➜  ' -ForegroundColor Green -NoNewline }
    else { Write-Host '➜  ' -ForegroundColor Red -NoNewline }
    Write-Host $displayPath -ForegroundColor Cyan -NoNewline
    if ($gitBranch) {
        Write-Host ' git:(' -ForegroundColor Blue -NoNewline
        Write-Host $gitBranch -ForegroundColor Red -NoNewline
        Write-Host ')' -ForegroundColor Blue -NoNewline
        if ($gitDirty) { Write-Host ' ✗' -ForegroundColor Yellow -NoNewline }
    }
    return ' '
}

$zoxidePath = (Get-Command zoxide -ErrorAction SilentlyContinue).Source
if (-not $zoxidePath) {
    $zoxidePath = (Get-Item "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\ajeetdsouza.zoxide_*\zoxide.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1).FullName
}
if ($zoxidePath) {
    $zoxideDirectory = Split-Path $zoxidePath
    if ($env:Path -notlike "*$zoxideDirectory*") { $env:Path = "$zoxideDirectory;$env:Path" }
    & $zoxidePath init powershell --cmd j | Out-String | Invoke-Expression
}

$yaziPath = (Get-Command yazi -ErrorAction SilentlyContinue).Source
if (-not $yaziPath) {
    $yaziPath = (Get-Item "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\sxyazi.yazi_*\yazi-x86_64-pc-windows-msvc\yazi.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1).FullName
}
if ($yaziPath) {
    $yaziDirectory = Split-Path $yaziPath
    if ($env:Path -notlike "*$yaziDirectory*") { $env:Path = "$yaziDirectory;$env:Path" }
    function ya {
        $cwdFile = New-TemporaryFile
        try {
            & yazi @args "--cwd-file=$cwdFile"
            $cwd = Get-Content -LiteralPath $cwdFile -Raw -ErrorAction SilentlyContinue
            if ($cwd) { $cwd = $cwd.TrimEnd("`r", "`n") }
            if ($cwd -and $cwd -ne $PWD.Path -and (Test-Path -LiteralPath $cwd -PathType Container)) {
                Set-Location -LiteralPath $cwd
            }
        } finally { Remove-Item -LiteralPath $cwdFile -Force -ErrorAction SilentlyContinue }
    }
}

$moduleRoot = Join-Path (Split-Path $PROFILE.CurrentUserAllHosts) 'Modules'
$fastTerminalIconsPath = Join-Path $moduleRoot 'Fast-TerminalIcons\0.3.0\Fast-TerminalIcons.dll'
function Enable-FastTerminalIcons {
    if (-not (Get-Module Fast-TerminalIcons) -and (Test-Path -LiteralPath $fastTerminalIconsPath)) {
        Import-Module $fastTerminalIconsPath -Global
    }
}

# Warm optional modules after the first prompt; keep startup responsive.
foreach ($subscription in @($global:TerminalIconsWarmupSubscription, $global:ShellWarmupSubscription)) {
    if ($subscription) {
        Unregister-Event -SubscriptionId $subscription.Id -ErrorAction SilentlyContinue
        Remove-Job -Id $subscription.Id -Force -ErrorAction SilentlyContinue
    }
}
Remove-Variable TerminalIconsWarmupSubscription -Scope Global -ErrorAction SilentlyContinue
if (-not (Get-Module Fast-TerminalIcons) -or -not (Get-Module PSFzf) -or -not (Get-Module CompletionPredictor)) {
    $global:ShellWarmupSubscription = Register-EngineEvent `
        -SourceIdentifier PowerShell.OnIdle `
        -MaxTriggerCount 1 `
        -Action {
            if (Test-Path -LiteralPath $fastTerminalIconsPath) {
                Import-Module $fastTerminalIconsPath -Global -ErrorAction SilentlyContinue
            }
            Import-Module PSFzf -Global -ErrorAction SilentlyContinue
            Import-Module CompletionPredictor -Global -ErrorAction SilentlyContinue
        }
}

Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
function lso { Get-ChildItem @args }
function ls { Enable-FastTerminalIcons; Get-ChildItem @args | Format-FastTerminalTable }
function ll { Enable-FastTerminalIcons; Get-ChildItem -Force @args | Format-FastTerminalTable }
function la { Enable-FastTerminalIcons; Get-ChildItem -Force @args | Format-FastTerminalTable }
if (-not (Get-Command btop -ErrorAction SilentlyContinue) -and (Get-Command btop4win -ErrorAction SilentlyContinue)) {
    Set-Alias btop btop4win
}
function which($Name) { Get-Command $Name -All | Select-Object CommandType, Name, Version, Source }
function touch($Path) {
    if (Test-Path -LiteralPath $Path) { (Get-Item -LiteralPath $Path).LastWriteTime = Get-Date }
    else { New-Item -ItemType File -Path $Path | Out-Null }
}
function mkcd($Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null; Set-Location $Path }
function up([int]$Levels = 1) { Set-Location (('..' + [IO.Path]::DirectorySeparatorChar) * $Levels) }
function ports { Get-NetTCPConnection -State Listen | Sort-Object LocalPort | Format-Table LocalAddress, LocalPort, OwningProcess }
function path { $env:Path -split ';' | Where-Object { $_ } }
function reload-profile { . $PROFILE.CurrentUserAllHosts }
function edit-profile { code $PROFILE.CurrentUserAllHosts }
if (Get-Command nvim -ErrorAction SilentlyContinue) { Set-Alias vim nvim }
function edit-nvim { nvim (Join-Path $env:LOCALAPPDATA 'nvim') }
function Update-TerminalKit {
    $bootstrap = Invoke-RestMethod 'https://raw.githubusercontent.com/meglinge/PowerShell-Terminal-Kit/main/bootstrap.ps1'
    Invoke-Expression $bootstrap
}
function Test-TerminalKit { & (Join-Path $terminalKitRoot 'verify.ps1') -InstalledOnly }
function Uninstall-TerminalKit { & (Join-Path $terminalKitRoot 'uninstall.ps1') }

if (Get-Command winget -ErrorAction SilentlyContinue) {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()
        winget complete --word="$wordToComplete" --commandline "$commandAst" --position $cursorPosition |
            ForEach-Object { [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
