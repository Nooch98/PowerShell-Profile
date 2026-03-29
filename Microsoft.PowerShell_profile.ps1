# ======================================================================
# 0. Init config and global preference
# ======================================================================

$savedSchemeName = [Environment]::GetEnvironmentVariable("TERM_SCHEME_NAME", "User")
if ($savedSchemeName) {
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path $settingsPath) {
        $schemes = (Get-Content $settingsPath -Raw | ConvertFrom-Json).schemes
        $s = $schemes | Where-Object { $_.name -eq $savedSchemeName }
        if ($s) {
            $osc = [char]27 + "]"
            $bel = [char]7
            Write-Host -NoNewline "${osc}10;$($s.foreground)${bel}${osc}11;$($s.background)${bel}"
            $ansi = @($s.black, $s.red, $s.green, $s.yellow, $s.blue, $s.purple, $s.cyan, $s.white)
            for ($i=0; $i -lt 8; $i++) { Write-Host -NoNewline "${osc}4;$i;$($ansi[$i])${bel}" }
        }
    }
}

$env:POWERSHELL_TELEMETRY_OUTPUT = 1
$env:POWERSHELL_UPDATECHECK = 'Off'

$ENV:FZF_DEFAULT_OPTS=@"
--color=bg+:#363A4F,bg:#24273A,spinner:#F4DBD6,hl:#ED8796
--color=fg:#CAD3F5,header:#ED8796,info:#C6A0F6,pointer:#F4DBD6
--color=marker:#B7BDF8,fg+:#CAD3F5,prompt:#C6A0F6,hl+:#ED8796
--color=selected-bg:#494D64
--color=border:#6E738D,label:#CAD3F5
"@

$ErrorActionsPreference = "Continue"
$WarningPreference = "Continue"
$ConfirmPreference = "High"

$canConnectToGithub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

# ========================================================================
# 1. Imports and modules load
# ------------------------------------------------------------------------
# This modules need load before configure the fzf options (PSFzf, PSReadLine).
# Terminal-Icons need load before use lsd
# ========================================================================

Import-Module Terminal-Icons
Import-Module -Name PSFzf -ErrorAction SilentlyContinue
Import-Module -Name PSReadLine -ErrorAction SilentlyContinue

Invoke-Expression (& { (zoxide init powershell | Out-String) })

oh-my-posh init pwsh --config C:\Users\Nooch\Documents\PowerShell\\craver.omp.json | Invoke-Expression

# ========================================================================
# 2. PSReadLine and FZF config (Input and colors) 
# ========================================================================

Set-PSFzfOption -PSReadLineChordProvider 'Ctrl+r' -PSReadLineChordReverseHistory 'Ctrl+h'
Set-PSFzfOption -ForegroundColor Green
Set-PSFzfOption -TabExpansion

Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionViewStyle ListView

Set-PSReadLineOption -Color @{
    "command" = [ConsoleColor]::Cyan
    "Parameter" = [ConsoleColor]::DarkBlue
    "Operator" = [ConsoleColor]::Magenta
    "Variable" = [ConsoleColor]::White
    "String" = [ConsoleColor]::Yellow
    "Number" = [ConsoleColor]::Blue
    "Type" = [ConsoleColor]::Green
    "Comment" = [ConsoleColor]::DarkGray
}

# ========================================================================
# 3. Personal Functions and Alias
# ------------------------------------------------------------------------
# Logic of functions
# ========================================================================

function l ($command) { eza.exe --icons}

function ll ($command) { eza.exe --icons -l}

function la ($command) { eza.exe --icons -la}

function lra ($command) { eza.exe --icons -lra}

function up {
    param([Parameter(Mandatory=$false)][int]$levels = 1)
    $path = $pwd.Path
    for ($i = 0; $i -lt $levels; $i++) {
        $path = Split-Path $path -Parent
        if ( -not $path) { Write-Warning "Already on root path"; return }
    }
    Set-Location $path
}

function mcd {
    param([Parameter(Mandatory=$true)][string]$Path)
    New-Item -Path $Path -ItemType Directory | Out-Null
    Set-Location -Path $Path
}

function uptime {
    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime
    Write-Host " 󱑍 Last Reboot: " -NoNewline; Write-Host $os.LastBootUpTime -ForegroundColor Cyan
    Write-Output "   Uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
}

function diskinfo {
    Get-CimInstance -ClassName Win32_LogicalDisk |
    Select-Object DeviceID, VolumeName, @{Name="Size (GB)"; Expression={"{0:N2}" -f ($_.Size / 1GB)}}, @{Name="Free (GB)"; Expression={"{0:N2}" -f ($_.FreeSpace / 1GB)}}, FileSystem
}

function reload { 
    $env:RELOADING = $true
    . $PROFILE
    $env:RELOADING = $null
    Write-Host "  🚀 Profile reloaded successfully!" -ForegroundColor Cyan 
}

function ep { code $PROFILE }

function updateposh { winget upgrade JanDeDobbeleer.OhMyPosh -s winget }

function Update-PowerShell {
    if (-not $global:canConnectToGithub) { return }

    try {
        Write-Host "  󰚰  Checking for PowerShell Preview updates..." -ForegroundColor Gray
         
        $currentVersion = $PSVersionTable.PSVersion
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases"

        $allReleases = Invoke-RestMethod -Uri $gitHubApiUrl -UserAgent "PostmanRuntime/7.28.4" -ErrorAction SilentlyContinue
        
        if ($null -eq $allReleases) {
            Write-Host "  󰅚  Update check failed (GitHub API unreachable)" -ForegroundColor DarkYellow
            return
        }

        $latestPreview = $allReleases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        $tag = $latestPreview.tag_name

        $cleanLatest = $tag.TrimStart('v') -replace "-preview\.", "."
        $latestVerObj = [version]$cleanLatest

        $cleanCurrent = $currentVersion.ToString() -replace "-preview\.", "."
        $currentVerObj = [version]$cleanCurrent

        if ($currentVerObj -lt $latestVerObj) {
            Write-Host "  󱧘  New Preview available: $tag" -ForegroundColor Magenta
            Write-Host "  󰇚  Updating via WinGet (Preview Channel)..." -ForegroundColor Cyan

            winget update --id Microsoft.PowerShell.Preview --silent --accept-source-agreements --accept-package-agreements
            
            Write-Host "  󰠄  Update complete. Please restart your terminal." -ForegroundColor Green
        } else {
            Write-Host "  󰄬  PowerShell Preview is up to date ($tag)" -ForegroundColor DarkGray
        }

    } catch {
        Write-Host "  󰅚  Could not complete update check." -ForegroundColor DarkRed
    }
}

function Invoke-Fzf {
    $selectitem = & 'fzf' --reverse --preview-window=up:50% --preview='bat --color=always --style=numbers {1}'
    if ($selectitem) { Set-Clipboard -Value $selectitem }
}

function activate {
    param([string]$Name = "")
    if ($Name) { $path = Get-ChildItem -Path ".\$Name\Scripts\activate.ps1" -ErrorAction SilentlyContinue}
    else { $path = Get-ChildItem -Path ".\venv\Scripts\activate.ps1", ".\.venv\Scripts\activate.ps1" -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($path) {
        Write-Host "Activating virtual env: $($path.Directory.Parent.Name)..." -ForegroundColor Blue
        & $path.FullName
        Write-Host "Env activated. You can press Ctrl+l for clean" -ForegroundColor Green
    } else { Write-Host "Any virtual env found (venv, .venv, o $Name) in the actual path" -ForegroundColor Red}
}

function Select-Fzf { $input | fzf --reverse --height 50% --border --prompt='Select > ' | Out-String}

function Remove-ModuleFzf {
    Write-Host "Select the modules to uninstall (Ctrl+Space to select)" -ForegroundColor Yellow
    $modules = Get-InstalledModule | Select-Object -ExpandProperty Name
    $selectModules = $modules | fzf --multi --reverse --border --prompt='Modules to uninstall > '
    if ($selectModules) {
        foreach ($ModuleName in $selectModules -split "`n") {
            Write-Host "Uninstalling $ModuleName..." -ForegroundColor Cyan; Uninstall-Module -Name $ModuleName -Force -ErrorAction Stop
        }
        Write-Host "Uninstall complete. Reload your shell." -ForegroundColor Green
    } else { Write-Host "Operation canceled." -ForegroundColor Red}
}

function find-command {
    param([string]$query = "")
    Get-Content $PROFILE | 
        Where-Object { $_ -match "function\s+\w+|Set-Alias" } | 
        fzf --reverse --header "My Shortcuts & Functions" --height 40%
}

function sql {
    param([string]$db)
    Write-Host "Executing python script to show data base: $db" -ForegroundColor Green
    python $env:USERPROFILE\Documents\PowerShell\Scripts\.\sql.py $db
}

function info {
    $scriptDir = "$env:USERPROFILE\Documents\PowerShell\Scripts"
    $scriptPath = Join-Path $scriptDir "SysInfo.ps1"
    $url = "https://raw.githubusercontent.com/Nooch98/SysInfo/refs/heads/main/SysInfo.ps1"

    if (-not (Test-Path $scriptDir)) {
        New-Item -Path $scriptDir -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path $scriptPath)) {
        if ($global:canConnectToGithub) {
            Write-Host " 󰇚 SysInfo.ps1 not found. Downloading from GitHub..." -ForegroundColor Yellow
            try {
                Invoke-WebRequest -Uri $url -OutFile $scriptPath -ErrorAction Stop
                Write-Host " ✅ Download complete." -ForegroundColor Green
            } catch {
                Write-Host " ❌ Failed to download SysInfo.ps1: $($_.Exception.Message)" -ForegroundColor Red
                return
            }
        } else {
            Write-Host " ❌ SysInfo.ps1 is missing and you are OFFLINE." -ForegroundColor Red
            return
        }
    }

    & $scriptPath
}

function Update-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "🛠️ Starting Scoop update..." -ForegroundColor Cyan
        scoop update *
        Write-Host "✅ Scoop update completed." -ForegroundColor Green
    } else {
        Write-Host "⚠️ Scoop is not installed. The update cannot be run." -ForegroundColor Yellow
    }
}

function Update-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "🛠️ Starting Winget update..." -ForegroundColor Cyan
        winget upgrade --all --silent
        Write-Host "✅ Winget update completed." -ForegroundColor Green
    } else {
        Write-Host "⚠️ Winget is not installed. The update cannot be run." -ForegroundColor Yellow
    }
}

function Update-Choco {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "🛠️ Starting Chocolatey update..." -ForegroundColor Cyan
        choco upgrade all -y
        Write-Host "✅ Chocolatey update completed." -ForegroundColor Green
    } else {
        Write-Host "⚠️ Chocolatey is not installed. The update cannot be run." -ForegroundColor Yellow
    }
}

# ========================================================================
# 4. KEY HANDLERS (Shortcuts)
# ------------------------------------------------------------------------
# Assign of shortcuts to functions of PSReadLine
# ========================================================================

Set-PSReadLineKeyHandler -Key 'Ctrl+t' -ScriptBlock { Invoke-Fzf }

Set-PSReadLineKeyHandler -Key 'Ctrl+g' -ScriptBlock {
    $dir = Invoke-Expression "zoxide query -l | fzf --height 40% --layout=reverse --border --prompt='zoxide> '"
    if ($dir) { Set-Location $dir }
}

Set-PSReadLineKeyHandler -Key 'Ctrl+u' -ScriptBlock {
    param($key, $arg)

    $buffer = [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState()
    $line = $buffer.Line

    $urlRegex = '(?i)\b((?:[a-z][\w-]+:(?:/{1,3}|[a-z0-9%])|www\d{0,3}[.]|[a-z0-9.\-]+[.][a-z]{2,4}/)(?:[^\s()<>]+|\(([^\s()<>]+|(\([^\s()<>]+\)))*\))+(?:\(([^\s()<>]+|(\([^\s()<>]+\)))*\)|[^\s`!()\[\]{};:\''".,<>?«»“”‘’]))'

    $match = $line | Select-String -Pattern $urlRegex -AllMatches

    if ($match) {
        $urltocopy = $match.Matches[-1].Value
        Set-Clipboard -Value $urltocopy
        Write-Host "✅ URL Copy: $urltocopy" -ForegroundColor Green
    } else {
        Write-Host "❌ No URL was found in the current command line." -ForegroundColor Red
    }
}

function Invoke-FuzzyOpen {
    $selection = eza --icons --all --color=always | 
                 fzf --ansi --reverse --preview 'bat --color=always --style=numbers --line-range=:500 {2}'

    $file = ($selection -split "\s+")[-1]

    if ($file -and (Test-Path $file)) {
        code $file
    }
}

function Get-NetworkPorts {
    Get-NetTCPConnection -State Listen | 
    Select-Object LocalPort, OwningProcess, State | 
    Sort-Object LocalPort
}

function Set-ExtractFile {
    param([Parameter(Mandatory=$true)][string]$file)
    if (Test-Path $file) {
        $ext = (Get-Item $file).Extension.ToLower()
        switch ($ext) {
            ".zip"  { Expand-Archive $file -DestinationPath . }
            ".tar"  { tar -xvf $file }
            ".gz"   { tar -xvzf $file }
            ".rar"  { unrar x $file }
            ".7z"   { 7z x $file }
            default { Write-Warning "Formato '$ext' no soportado." }
        }
    }
}

function find-text {
    param([string]$query = "")

    if (-not (Get-Command rg -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Ripgrep (rg) no instalado." -ForegroundColor Red; return
    }

    $result = rg --line-number --color=always --smart-case "$query" . `
        --glob '!.git/*' `
        --glob '!.venv/*' `
        --glob '!__pycache__/*' | 
        fzf --ansi --height 80% --preview 'bat --color=always --style=numbers --highlight-line {2} {1}'
    
    if ($result) {
        $parts = $result -split ":"
        $file = $parts[0].Trim()
        $line = $parts[1].Trim()
        code --goto "${file}:${line}"
    }
}

function Get-ProfileConfig {
    $configPath = Join-Path (Split-Path $PROFILE) "config.json"
    $config = if (Test-Path $configPath) { Get-Content $configPath | ConvertFrom-Json } else { @{} }
    $updated = $false

    if (-not $config.projectRoot) {
        Write-Host "📂 Setup: Projects folder path" -ForegroundColor Yellow
        $path = Read-Host "Enter FULL path (e.g. C:\Users\Nooch\Desktop\Projects)"
        $config.projectRoot = $path
        $updated = $true
    }

    if (-not $config.weatherCity) {
        Write-Host "🌤️ Setup: Weather City" -ForegroundColor Yellow
        $city = Read-Host "Enter your city (e.g. Madrid)"
        $config.weatherCity = $city
        $updated = $true
    }

    if ($updated) {
        $config | ConvertTo-Json | Set-Content $configPath
        Write-Host "✅ Configuration updated in $configPath`n" -ForegroundColor Green
    }

    return $config
}

function p {
    param([string]$query = "")
    
    $config = Get-ProfileConfig
    $projectRoot = $config.projectRoot

    if (-not (Test-Path $projectRoot)) {
        Write-Host "❌ Project folder not found at: $projectRoot" -ForegroundColor Red
        return
    }

    $selected = Get-ChildItem -Path $projectRoot -Directory | 
                Select-Object -ExpandProperty Name | 
                fzf --reverse --height 40% --border --header "📂 PROJECT NAVIGATOR" --query "$query" --preview "eza --icons --tree --level 1 $projectRoot\{}"

    if ($selected) {
        $fullPath = Join-Path $projectRoot $selected
        Set-Location $fullPath
        Clear-Host
        welcome
        Write-Host "󰚝 Switched to Project: $selected" -ForegroundColor Cyan
        if (Test-Path (Join-Path $fullPath ".venv")) {
            Write-Host "💡 Tip: This project has a .venv. Type 'va' to activate." -ForegroundColor Yellow
        }
    }
}

function tasks {
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string]$task
    )
    
    $todoFile = "$HOME\.todo.txt"

    if ($task) {
        $task | Out-File -FilePath $todoFile -Append -Encoding utf8
        Write-Host "  󰄲 Task added: $task" -ForegroundColor Green
        return
    } 

    if (Test-Path $todoFile) {
        $content = Get-Content $todoFile | Where-Object { $_ -match '\S' }

        Write-Host "`n  󰏫  CURRENT TASKS:" -ForegroundColor Magenta
        Write-Host "  ------------------" -ForegroundColor DarkGray
        
        $i = 1
        foreach ($line in $content) {
            Write-Host "  $i. " -ForegroundColor DarkGray -NoNewline
            Write-Host "󰄱 " -ForegroundColor Yellow -NoNewline
            Write-Host " $line" -ForegroundColor White
            $i++
        }
        
        Write-Host "`n  [Enter] to manage/delete | [Ctrl+C] to exit" -ForegroundColor DarkGray
        $null = Read-Host

        $toRemove = $content | fzf --multi --reverse --header "SELECT TASKS TO DISCARD (Tab to mark, Enter to confirm)" --prompt="Finish > "

        if ($toRemove) {
            $newContent = $content | Where-Object { $_ -notin $toRemove }
            
            if ($newContent) {
                $newContent | Out-File -FilePath $todoFile -Encoding utf8
            } else {
                Remove-Item $todoFile
            }
            
            Write-Host "  󰄭  $(($toRemove | Measure-Object).Count) tasks completed/removed!" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  󰚙  No pending tasks. You're free!" -ForegroundColor DarkGray
    }
}

function myip {
    $public = if ($global:canConnectToGithub) { curl.exe -s https://api.ipify.org } else { "Offline" }
    Write-Host "`n  󰩟 Network Info:" -ForegroundColor Magenta
    Write-Host "  --------------" -ForegroundColor DarkGray
    Write-Host "  Local IP  : " -NoNewline; Write-Host (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi", "Ethernet" | Select-Object -First 1).IPAddress -ForegroundColor Cyan
    Write-Host "  Public IP : " -NoNewline; Write-Host $public -ForegroundColor Cyan
    Write-Host "  DNS       : " -NoNewline; Write-Host (Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses -First 1) -ForegroundColor Cyan
}

function remind {
    param(
        [Parameter(Mandatory=$true)] [int]$minutes, 
        [Parameter(Mandatory=$true)] [string]$msg
    )
    
    Write-Host "  󰄭  Timer set for $minutes minutes: $msg" -ForegroundColor Yellow

    Start-Job -ScriptBlock {
        param($m, $message)
        Start-Sleep -Seconds ($m * 60)

        $notification = New-Object -ComObject WScript.Shell
        $notification.Popup($message, 10, "⏰ Timer Up!", 64) | Out-Null
        
    } -ArgumentList $minutes, $msg | Out-Null
}

function Get-RepoStats {
    param([string]$repoName = "")

    $token = $env:GITHUB
    if (-not $token) {
        Write-Host "❌ Error: `$env:GITHUB` variable not found." -ForegroundColor Red
        return
    }

    $headers = @{ 
        "Authorization" = "token $token"
        "Accept"        = "application/vnd.github.v3+json"
        "User-Agent"    = "PowerShell-CLI"
    }

    if (-not $repoName) {
        Write-Host "🔍 Searching your repositories..." -ForegroundColor Cyan
        try {
            $myRepos = Invoke-RestMethod -Uri "https://api.github.com/user/repos?per_page=100&sort=updated" -Headers $headers
            $repoName = $myRepos | Select-Object -ExpandProperty full_name | fzf --reverse --header "Select a repository"
            if (-not $repoName) { return }
        } catch {
            Write-Host "❌ Error listing repos: $($_.Exception.Message)" -ForegroundColor Red
            return
        }
    }

    Write-Host "📊 Fetching data for $repoName..." -ForegroundColor Yellow
    
    try {
        $mainInfo      = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName" -Headers $headers
        $trafficClones = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/traffic/clones" -Headers $headers
        $trafficViews  = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/traffic/views" -Headers $headers
        $releases      = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/releases" -Headers $headers
        
        $lastPush = "N/A"
        if ($mainInfo.pushed_at) {
            $lastPush = ([DateTime]$mainInfo.pushed_at).ToString("MM/dd/yyyy HH:mm")
        }

        $totalDownloads = 0
        if ($releases) {
            foreach ($rel in $releases) {
                foreach ($asset in $rel.assets) {
                    $totalDownloads += $asset.download_count
                }
            }
        }

        Clear-Host
        Write-Host "`n  🚀 REPOSITORY STATISTICS" -ForegroundColor Magenta
        Write-Host "  " + ("=" * 40) -ForegroundColor DarkGray
        Write-Host "  📦 Repository : " -NoNewline; Write-Host $repoName -ForegroundColor Cyan
        Write-Host "  " + ("-" * 40) -ForegroundColor DarkGray

        $stats = @(
            @{ Icon = "⭐"; Label = "Stars      "; Value = $mainInfo.stargazers_count; Color = "Yellow" }
            @{ Icon = "🍴"; Label = "Forks      "; Value = $mainInfo.forks_count; Color = "Blue" }
            @{ Icon = "👀"; Label = "Views (14d)"; Value = "$($trafficViews.count) ($($trafficViews.uniques) unique)"; Color = "Green" }
            @{ Icon = "👥"; Label = "Clones(14d)"; Value = "$($trafficClones.count) ($($trafficClones.uniques) unique)"; Color = "Magenta" }
            @{ Icon = "📥"; Label = "Downloads  "; Value = $totalDownloads; Color = "White" }
            @{ Icon = "📅"; Label = "Last Push  "; Value = $lastPush; Color = "Cyan" }
        )

        foreach ($s in $stats) {
            Write-Host "  $($s.Icon) $($s.Label) : " -NoNewline
            Write-Host $s.Value -ForegroundColor $s.Color
        }
        Write-Host "  " + ("=" * 40) -ForegroundColor DarkGray
        Write-Host ""

    } catch {
        Write-Host "❌ Detailed Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-TerminalScheme {
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if (-not (Test-Path $settingsPath)) {
        Write-Host "❌ settings.json not found!" -ForegroundColor Red
        return
    }

    try {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $schemes = $settings.schemes

        $selectedName = $schemes.name | fzf --reverse --height 40% --header "📺 SELECT TERMINAL SCHEME" --border
        
        if (-not $selectedName) { return }

        $s = $schemes | Where-Object { $_.name -eq $selectedName }

        $osc = [char]27 + "]"
        $bel = [char]7
        
        Write-Host -NoNewline "${osc}10;$($s.foreground)${bel}"
        Write-Host -NoNewline "${osc}11;$($s.background)${bel}"
        Write-Host -NoNewline "${osc}12;$($s.cursorColor)${bel}"
        
        $ansiColors = @($s.black, $s.red, $s.green, $s.yellow, $s.blue, $s.purple, $s.cyan, $s.white)
        for ($i = 0; $i -lt $ansiColors.Count; $i++) {
            Write-Host -NoNewline "${osc}4;$i;$($ansiColors[$i])${bel}"
        }

        $settings.profiles.defaults.colorScheme = $selectedName

        $psProfile = $settings.profiles.list | Where-Object { $_.name -eq "PowerShell" }
        if ($psProfile) {
            $psProfile.colorScheme = $selectedName
        }

        $settings | ConvertTo-Json -Depth 100 | Set-Content $settingsPath

        [Environment]::SetEnvironmentVariable("TERM_SCHEME_NAME", $selectedName, "User")
        
        Write-Host "🎨 Scheme '$selectedName' applied and saved permanently!" -ForegroundColor Cyan

    } catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function history-exec {
    $cmd = Get-History | Select-Object -ExpandProperty CommandLine -Unique | fzf --reverse --header "EXECUTE FROM HISTORY"
    if ($cmd) { 
        Write-Host " 🚀 Running: $cmd" -ForegroundColor Cyan
        Invoke-Expression $cmd 
    }
}

function edit-fast {
    $file = Get-ChildItem -File | Select-Object -ExpandProperty Name | fzf --reverse --header "EDIT FILE"
    if ($file) { code $file }
}

function get-weather-full {
    $config = Get-ProfileConfig
    curl.exe -s "wttr.in/$($config.weatherCity)?m2" 
}

function help-system {
    Clear-Host
    Write-Host "`n  󰞷  TERMINAL COMMAND CENTER - USER GUIDE" -ForegroundColor Magenta
    Write-Host "  ================================================================" -ForegroundColor DarkGray

    $commands = @(
        # Navigation & Files
        @{ Cmd = "l / ll / la"; Desc = "List files (eza) with icons/details" },
        @{ Cmd = ".. [n]";     Desc = "Go up 'n' levels in directories (default 1)" },
        @{ Cmd = "mcd <dir>";   Desc = "Create directory and enter it immediately" },
        @{ Cmd = "ff";          Desc = "Fuzzy search files and open in VS Code" },
        @{ Cmd = "extr <file>"; Desc = "Extract compressed files (zip, rar, 7z, tar...)" },
        
        # System & Info
        @{ Cmd = "welcome";     Desc = "Show system dashboard / Neofetch style" },
        @{ Cmd = "info";        Desc = "Run detailed system info script" },
        @{ Cmd = "uptime / di"; Desc = "Show system boot time / Disk usage" },
        @{ Cmd = "myip";        Desc = "Show Local, Public IP and DNS info" },
        @{ Cmd = "ports";       Desc = "List all active listening network ports" },
        
        # Development & Python
        @{ Cmd = "p <query>";   Desc = "Project Navigator: Search and jump to projects" },
        @{ Cmd = "va [name]";   Desc = "Activate Python Virtual Environment (venv/.venv)" },
        @{ Cmd = "sql <db>";    Desc = "Execute python SQL viewer script" },
        @{ Cmd = "rs";          Desc = "GitHub Repository Stats (Stars, Views, Clones)" },
        
        # Productivity & Tools
        @{ Cmd = "t [task]";    Desc = "To-Do List: Add task or manage pending ones" },
        @{ Cmd = "remind <m> <msg>"; Desc = "Set a timer for 'm' minutes with popup" },
        @{ Cmd = "fp <text>";   Desc = "Fuzzy Find text inside files (ripgrep + bat)" },
        @{ Cmd = "st";          Desc = "Interactive Terminal Theme/Scheme selector" },
        
        # Maintenance
        @{ Cmd = "reload / ep"; Desc = "Reload $PROFILE / Edit $PROFILE in Code" },
        @{ Cmd = "us/uw/uc";    Desc = "Update managers: Scoop / Winget / Choco" },
        @{ Cmd = "rmmodf";      Desc = "Fuzzy uninstall PowerShell modules" }
    )

    Write-Host "  CMD             DESCRIPTION" -ForegroundColor Cyan
    Write-Host "  ---             -----------" -ForegroundColor DarkGray

    foreach ($c in $commands) {
        $cmdText = "  $($c.Cmd)".PadRight(18)
        Write-Host $cmdText -ForegroundColor Green -NoNewline
        Write-Host $c.Desc -ForegroundColor White
    }

    Write-Host "`n  󰌌  KEYBOARD SHORTCUTS:" -ForegroundColor Magenta
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  [Ctrl + T] " -ForegroundColor Yellow -NoNewline; Write-Host "Fuzzy file search & copy path"
    Write-Host "  [Ctrl + G] " -ForegroundColor Yellow -NoNewline; Write-Host "Interactive folder navigation (zoxide + fzf)"
    Write-Host "  [Ctrl + R] " -ForegroundColor Yellow -NoNewline; Write-Host "Smart history search"
    Write-Host "  [Ctrl + U] " -ForegroundColor Yellow -NoNewline; Write-Host "Extract and copy URL from current line"
    Write-Host "  [Ctrl + L] " -ForegroundColor Yellow -NoNewline; Write-Host "Clear screen (Native)"

    Write-Host "`n  󰚌  EXTRA PROTOCOLS:" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  w         " -ForegroundColor Yellow -NoNewline; Write-Host "Full 3-day weather forecast"
    Write-Host "  ed        " -ForegroundColor Yellow -NoNewline; Write-Host "Quick-edit file in VS Code using FZF"
    Write-Host "  hix       " -ForegroundColor Yellow -NoNewline; Write-Host "Search history and EXECUTE immediately"
    Write-Host "  matrix    " -ForegroundColor Yellow -NoNewline; Write-Host "Enter digital rain mode (requires cmatrix)"
    
    Write-Host "`n  Type 'help' anytime to see this menu.`n" -ForegroundColor DarkGray
}

function welcome {
    Clear-Host
    $config = Get-ProfileConfig
    $user = $env:USERNAME
    $computer = $env:COMPUTERNAME

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $totalThemes = 0
    if (Test-Path $settingsPath) {
        $st = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $totalThemes = ($st.schemes | Measure-Object).Count
    }

    $osInfo = Get-CimInstance Win32_OperatingSystem
    $os = $osInfo.Caption.Replace("Microsoft ", "")
    $cpu = (Get-CimInstance Win32_Processor).Name.Replace("(TM)", "").Replace("(R)", "").Trim()
    $gpuList = (Get-CimInstance Win32_VideoController).Name | Where-Object { $_ -notmatch "Virtual|Meta" }
    $gpu = $gpuList -join ", "
    
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $diskFree = [Math]::Round($disk.FreeSpace / 1GB, 1)
    $diskTotal = [Math]::Round($disk.Size / 1GB, 0)

    $totalRam = [Math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 0)
    $usedRam = [Math]::Round(($osInfo.TotalVisibleMemorySize - $osInfo.FreePhysicalMemory) / 1MB, 1)
    $percentRam = [Math]::Round(($usedRam / $totalRam) * 100, 0)
    $barLength = 10
    $filledLength = [Math]::Round(($percentRam / 100) * $barLength)
    $bar = ("█" * $filledLength) + ("░" * ($barLength - $filledLength))
    
    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi", "Ethernet" | Select-Object -First 1).IPAddress
    $uptimeObj = (Get-Date) - $osInfo.LastBootUpTime
    $uptimeStr = "$($uptimeObj.Days)d $($uptimeObj.Hours)h $($uptimeObj.Minutes)m"
    $wslStatusRaw = if (Get-Process "wslhost" -ErrorAction SilentlyContinue) { "Running" } else { "Stopped" }
    $wslStatus = "󰟈 $wslStatusRaw"

    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $wmiMonitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams
    $displayInfo = @()
    for ($i = 0; $i -lt $screens.Count; $i++) {
        $res = "$($screens[$i].Bounds.Width)x$($screens[$i].Bounds.Height)"
        if ($wmiMonitors[$i].InstanceName -match 'DISPLAY\\(?<model>[^\\]+)\\') { $model = $Matches['model'] } else { $model = "Display" }
        $displayInfo += "$model ($res)"
    }
    $displayStr = $displayInfo -join ", "

    $weatherCity = $config.weatherCity 
    $weatherClean = "Unknown" 
    if ($global:canConnectToGithub) {
        try {
            $weatherRaw = curl.exe -s "wttr.in/$($weatherCity)?format=3" --connect-timeout 2
            if ($weatherRaw -and $weatherRaw -notmatch "HTML") {
                $weatherClean = $weatherRaw.Replace("┬░", "°").Replace("Â", "").Trim()
            }
        } catch { $weatherClean = "N/A" }
    }

    $currentScheme = [Environment]::GetEnvironmentVariable("TERM_SCHEME_NAME", "User") ?? "Default"

    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $bannerStyles = @(
        @'
    .---.  .---. .-.     .---.  .---. .-.  .-. .---. 
    | |  \ | |-  | |__   | |    | | | | |/\| | | |-  
    `---'  `---' `----'  `---'  `---' `__n__n' `---' 
    >> SYSTEM_ACCESS_GRANTED_
'@,
        @'
     ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄▄     ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄ 
    █       █       █       █       █       █       █       █
    █▄▄▄▄▄▄▄█    ▄▄▄█    ▄▄▄█       █   ▄   █   ▄   █    ▄▄▄█
    █       █   █▄▄▄█   █▄▄▄█      ▄█  █ █  █  █ █  █   █▄▄▄ 
    █▄▄▄▄▄▄▄█    ▄▄▄█    ▄▄▄█     █▄█  █▄█  █  █▄█  █    ▄▄▄█
    █       █   █▄▄▄█   █▄▄▄█       █       █       █   █▄▄▄ 
    █▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█▄▄▄▄▄▄▄█
'@,
       @'
    [#] --------------------------------------------- [#]
    [#]  USER : $USER //  HOST : $HOST  //  LVL: 01  [#]
    [#]  IPV4 : $IP   //  WSL  : $WSL   //  NET: ON  [#]
    [#] --------------------------------------------- [#]
'@,
        @'
      _/_/_/  _/_/_/_/  _/          _/_/_/    _/_/    _/      _/  _/_/_/_/
    _/        _/        _/        _/        _/    _/  _/_/  _/_/  _/      
    _/        _/_/_/    _/        _/        _/    _/  _/  _/  _/  _/_/_/  
    _/        _/        _/        _/        _/    _/  _/      _/  _/      
      _/_/_/  _/_/_/_/  _/_/_/_/    _/_/_/    _/_/    _/      _/  _/_/_/_/
'@,
        @'
    /==========\----------------------------------/==========\
     |  UP-TIME : $UPTIME                        |
     |  STATUS  : ONLINE                          |
     |  KERNEL  : $SHELL                        |
    \==========/----------------------------------\==========/
'@
    )

    $replacements = @{
        '$USER'   = $user.ToUpper().PadRight(8).Substring(0,8)
        '$HOST'   = $computer.ToUpper().PadRight(7).Substring(0,7)
        '$IP'     = $ip.PadRight(13).Substring(0,13)
        '$WSL'    = $wslStatusRaw.ToUpper().PadRight(5).Substring(0,5)
        '$UPTIME' = $uptimeStr.PadRight(25)
        '$SHELL'  = "pwsh $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)".PadRight(25)
    }

    $rawBanner = $bannerStyles | Get-Random
    $lines = $rawBanner -split '\r?\n' | Where-Object { $_ -match '\S' }
    $bannerColor = ("Cyan", "Magenta", "Yellow", "Green") | Get-Random
    
    Write-Host ""
    foreach ($line in $lines) {
        $newLine = $line
        foreach ($key in $replacements.Keys) { $newLine = $newLine.Replace($key, $replacements[$key]) }
        Write-Host "    $newLine" -ForegroundColor $bannerColor
    }

    Write-Host "`n    $user@$computer" -ForegroundColor Cyan
    Write-Host "    ---------------------------------------" -ForegroundColor DarkGray

    $infoLayout = @(
        @{ Label = "    OS      "; Value = $os; Color = "White" }
        @{ Label = "    CPU     "; Value = $cpu; Color = "Cyan" }
        @{ Label = "  󰢮  GPU     "; Value = $gpu; Color = "Green" }
        @{ Label = "  󰍹  Displays"; Value = $displayStr; Color = "Red" }
        @{ Label = "    RAM      "; Value = "[$bar] $usedRam GB / $totalRam GB ($percentRam%)"; Color = "Yellow" }
        @{ Label = "  󰋊  Disk (C)"; Value = "$diskFree GB Free / $diskTotal GB Total"; Color = "Cyan" }
        @{ Label = "  󰩟  Local IP "; Value = $ip; Color = "Green" }
        @{ Label = "  󱑍  Uptime   "; Value = $uptimeStr; Color = "Magenta" }
        @{ Label = "    Shell    "; Value = "pwsh $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"; Color = "Blue" }
        @{ Label = "    Weather  "; Value = $weatherClean; Color = "White" }
        @{ Label = "  󰟈 WSL       "; Value = $wslStatus; Color = "Cyan" }
    )

    foreach ($item in $infoLayout) {
        Write-Host "    $($item.Label)" -ForegroundColor DarkGray -NoNewline
        Write-Host " : " -ForegroundColor White -NoNewline
        Write-Host $item.Value -ForegroundColor $item.Color
    }

    if (Test-Path "$HOME\.todo.txt") {
        $allTasks = Get-Content "$HOME\.todo.txt" | Where-Object { $_ -match '\S' }
        if ($allTasks) {
            $taskCount = ($allTasks | Measure-Object).Count
            Write-Host "`n    󰏫  Tasks ($taskCount total):" -ForegroundColor Magenta
            $allTasks | Select-Object -First 3 | ForEach-Object { 
                Write-Host "      󰄱  $_" -ForegroundColor Gray 
            }
        }
    }

    $lastSysEvent = (Get-WinEvent -LogName System -MaxEvents 1 -ErrorAction SilentlyContinue).TimeCreated
    if ($lastSysEvent) {
        Write-Host "    󰒃 System Handshake: $($lastSysEvent.ToString('dd/MM HH:mm'))" -ForegroundColor DarkGray
    }
    Write-Host "`n    " -NoNewline
    $colors = @("DarkRed", "DarkGreen", "DarkYellow", "DarkBlue", "DarkMagenta", "DarkCyan", "Gray")
    foreach ($c in $colors) { Write-Host "󰮯 " -ForegroundColor $c -NoNewline }

    Write-Host "  󰸌  $currentScheme " -ForegroundColor Magenta -NoNewline
    Write-Host "($totalThemes available)" -ForegroundColor DarkGray
    Write-Host ""

}

# ========================================================================
# 5. ALIASES
# ------------------------------------------------------------------------
# Assign of short names to commmands or functions
# ========================================================================

Set-Alias .. up
Set-Alias di diskinfo
Set-Alias sf Select-Fzf
Set-Alias rmmodf Remove-ModuleFzf
Set-Alias va activate
Set-Alias cat bat
Set-Alias grep findstr
Set-Alias touch New-Item
Set-Alias g git
Set-Alias net netstat
Set-Alias us Update-Scoop
Set-Alias uw Update-Winget
Set-Alias uc Update-Choco
Set-Alias ff Invoke-FuzzyOpen
Set-Alias ports Get-NetworkPorts
Set-Alias extr Set-ExtractFile
Set-Alias fp find-text
Set-Alias t tasks
Set-Alias rs Get-RepoStats
Set-Alias st Set-TerminalScheme
Set-Alias h help-system
Set-Alias help help-system
Set-Alias w get-weather-full
Set-Alias ed edit-fast
Set-Alias hix history-exec

# ========================================================================
# 6. Execute in Start and Exit
# ------------------------------------------------------------------------
# Commands to execute in the start and exit of shell
# ========================================================================
welcome
if ($null -eq $env:RELOADING) {
    Start-Job -ScriptBlock { 
        Update-PowerShell 
    } | Out-Null
}
