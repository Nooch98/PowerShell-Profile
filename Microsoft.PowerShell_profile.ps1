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

function Get-InstallMethod {
    param([Parameter(Mandatory=$true)] [string]$AppName)

    Write-Host " 🔍 Searching installation source for: '$AppName'..." -ForegroundColor Gray
    $found = $false

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $scoopCheck = scoop list $AppName | Select-String $AppName
        if ($scoopCheck) { 
            Write-Host " 📦 [SCOOP]: Found '$AppName'. Uninstall with 'scoop uninstall $AppName'" -ForegroundColor Cyan
            $found = $true
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetCheck = winget list --query $AppName | Select-String $AppName
        if ($wingetCheck) {
            Write-Host " 📦 [WINGET]: Found '$AppName'. Uninstall with 'winget uninstall $AppName'" -ForegroundColor Blue
            $found = $true
        }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $chocoCheck = choco list --local-only $AppName | Select-String $AppName
        if ($chocoCheck) {
            Write-Host " 📦 [CHOCO]: Found '$AppName'. Uninstall with 'choco uninstall $AppName'" -ForegroundColor Green
            $found = $true
        }
    }

    if (-not $found) {
        $regPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        $regCheck = Get-ItemProperty $regPaths | Where-Object { $_.DisplayName -match $AppName } | Select-Object DisplayName, DisplayVersion
        
        if ($regCheck) {
            foreach ($app in $regCheck) {
                Write-Host " 🖥️  [NORMAL EXE]: Found '$($app.DisplayName)' (v$($app.DisplayVersion))" -ForegroundColor Yellow
                Write-Host "    Use Control Panel or 'Apps & Features' to manage it." -ForegroundColor DarkGray
            }
            $found = $true
        }
    }

    if (-not $found) {
        Write-Host " ❌ No installation found for '$AppName' in known managers or registry." -ForegroundColor Red
    }
}

Set-Alias "whereis" Get-InstallMethod

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
    $urlRegex = '(https?://[^\s"''<>]+)'

    $currentLine = ""
    $cursor = 0
    [Microsoft.PowerShell.PSReadLine]::GetBufferState([ref]$currentLine, [ref]$cursor)
    
    $historyText = Get-History -Count 20 | Select-Object -ExpandProperty CommandLine

    $allText = @($currentLine) + $historyText
    $matches = $allText | ForEach-Object { 
        [regex]::Matches($_, $urlRegex) | ForEach-Object { $_.Value.TrimEnd(')', ']', '.', ',', ';') }
    } | Select-Object -Unique

    if (-not $matches) {
        $matches = [Microsoft.PowerShell.PSConsoleReadLine]::GetKeyHandlers() | Out-Null
        Write-Host "`n  󰅚 No URLs found in history or current line." -ForegroundColor Red
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        return
    }

    $selectedUrl = $matches | fzf --reverse --height 40% --header "󰖟 SELECT URL TO COPY" --border

    if ($selectedUrl) {
        Set-Clipboard -Value $selectedUrl.Trim()
        Write-Host "`n  ✅ Copied: $selectedUrl" -ForegroundColor Green
    }
    
    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
}

function Get-ConsoleScreenBuffer {
    param([int]$MaxLines = 100)
    $hostUI = $Host.UI.RawUI
    $rect = New-Object Management.Automation.Host.Rectangle
    $rect.Left = 0
    $rect.Top = [Math]::Max(0, $hostUI.CursorPosition.Y - $MaxLines)
    $rect.Right = $hostUI.BufferSize.Width
    $rect.Bottom = $hostUI.CursorPosition.Y
    
    $buffer = $hostUI.GetBufferContents($rect)
    $text = ""
    for ($y = 0; $y -lt $buffer.GetUpperBound(0); $y++) {
        for ($x = 0; $x -lt $buffer.GetUpperBound(1); $x++) {
            $text += $buffer[$y, $x].Character
        }
        $text += "`n"
    }
    return $text
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
    Write-Host "`n  󱘖  LISTENING NETWORK PORTS" -ForegroundColor Magenta
    Write-Host "  ================================================================" -ForegroundColor DarkGray

    $ports = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
        $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Port     = $_.LocalPort
            Process  = if ($proc) { $proc.ProcessName } else { "Unknown" }
            PID      = $_.OwningProcess
            Protocol = $_.AppliedSetting 
        }
    } | Sort-Object Port -Unique

    Write-Host "    PORT".PadRight(10) + "PROCESS".PadRight(25) + "PID".PadRight(10) -ForegroundColor Cyan
    Write-Host "    ----".PadRight(10) + "-------".PadRight(25) + "---".PadRight(10) -ForegroundColor DarkGray

    foreach ($p in $ports) {
        $color = "White"
        if ($p.Port -in @(80, 443, 3000, 5000, 8080, 8443)) { $color = "Yellow" }
        if ($p.Port -eq 5432 -or $p.Port -eq 3306) { $color = "Cyan" }

        $portStr = "    $($p.Port)".PadRight(10)
        $procStr = "$($p.Process)".PadRight(25)
        $pidStr  = "$($p.PID)".PadRight(10)

        Write-Host $portStr -ForegroundColor $color -NoNewline
        Write-Host "│ " -ForegroundColor DarkGray -NoNewline
        Write-Host $procStr -ForegroundColor White -NoNewline
        Write-Host "│ " -ForegroundColor DarkGray -NoNewline
        Write-Host $pidStr -ForegroundColor Gray
    }
    Write-Host "`n  Total active listeners: $($ports.Count)`n" -ForegroundColor DarkGray
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

function Invoke-Zap {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
        [string]$Target
    )

    process {
        if (!(Test-Path $Target)) {
            Write-Host " ❌ Error: Target '$Target' not found." -ForegroundColor Red
            return
        }

        $fullPath = (Resolve-Path $Target).Path
        $isDir = Test-Path $fullPath -PathType Container
        $type = if ($isDir) { "DIRECTORY" } else { "FILE" }

        Write-Host "`n ⚠️  DANGER: You are about to permanently delete ${type}: " -NoNewline -ForegroundColor Yellow
        Write-Host $fullPath -ForegroundColor White
        $confirm = Read-Host "    Are you sure? (y/N)"
        if ($confirm -ne "y") { Write-Host "  Aborted." -ForegroundColor Gray; return }

        Write-Host "`n 󰆴 Starting Atomic Delete..." -ForegroundColor Cyan

        try {
            if ($isDir) {
                Get-ChildItem -Path $fullPath -Recurse -Force | ForEach-Object {
                    Write-Host "    󰆴 Deleting: $($_.FullName)" -ForegroundColor DarkGray
                    Remove-Item -Path $_.FullName -Force -Recurse -ErrorAction SilentlyContinue
                }

                Write-Host "    󱆳 Finalizing directory removal..." -ForegroundColor Blue
                cmd /c "rd /s /q `"$fullPath`"" 2>$null
            } else {
                Write-Host "    󰆴 Deleting: $fullPath" -ForegroundColor DarkGray
                Set-ItemProperty -Path $fullPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
                Remove-Item -Path $fullPath -Force
            }

            if (!(Test-Path $fullPath)) {
                Write-Host "`n ✅ ZAP! Successfully obliterated." -ForegroundColor Green
            } else {
                Write-Host "`n ❌ Error: The system is still locking some items." -ForegroundColor Red
            }
        } catch {
            Write-Host "`n ❌ Critical Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Invoke-QuickSearch {
    param([string]$query = "")
    
    Write-Host " 🔍 Searching accurately... (Ctrl+C to abort)" -ForegroundColor DarkGray

    $files = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.FullName -notmatch '\\\.git|\\\.venv|\\node_modules' -and
            ($query -eq "" -or $_.Name -match $query -or $_.Extension -match $query)
        } | ForEach-Object { $_.FullName }

    if (-not $files) {
        Write-Host " ❌ No files matching '$query' found." -ForegroundColor Red
        return
    }

    $selection = $files | fzf --query "$query" `
        --reverse `
        --header "󰩉 EXACT FIND & ACTION" `
        --tiebreak=end,length `
        --extended `
        --preview "bat --color=always --style=numbers {1}"
    
    if ($selection) {
        $selection = $selection.Trim()
        Write-Host "`n 📄 Selected: " -NoNewline -ForegroundColor Cyan
        Write-Host (Split-Path $selection -Leaf) -ForegroundColor White
        
        $action = Read-Host "    (o)pen in Code | (c)opy path | (g)o to folder? [o/c/g]"
        switch ($action) {
            "o" { code $selection }
            "c" { $selection | clip; Write-Host "  ✅ Path copied to clipboard!" -ForegroundColor Green }
            "g" { Set-Location (Split-Path $selection) }
            default { Write-Host "  󰅚 Operation cancelled." -ForegroundColor Gray }
        }
    }
}

function Invoke-KillProcess {
    $proc = Get-Process | 
        Select-Object ProcessName, Id, @{Name="Mem(MB)"; Expression={[math]::Round($_.WorkingSet / 1MB, 2)}} | 
        Sort-Object Mem -Descending | 
        ForEach-Object { "$($_.ProcessName.PadRight(20)) | ID: $($_.Id.ToString().PadRight(8)) | Mem: $($_.Mem) MB" } |
        fzf --reverse --header "󰆴 SELECT PROCESS TO KILL (Sniper Mode)" --height 50%

    if ($proc) {
        $pid = ($proc -split "ID: ")[1].Split("|")[0].Trim()
        Stop-Process -Id $pid -Force
        Write-Host "  ✅ Process $pid terminated." -ForegroundColor Green
    }
}

function Get-GitStatusSummary {
    Write-Host "`n  󰊢  GIT REPOSITORY SCANNER" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    
    Get-ChildItem -Directory | ForEach-Object {
        $dotGit = Join-Path $_.FullName ".git"
        if (Test-Path $dotGit) {
            Push-Location $_.FullName
            $status = git status --porcelain
            $branch = git rev-parse --abbrev-ref HEAD
            $color = if ($status) { "Yellow" } else { "Green" }
            $icon = if ($status) { "󱓻" } else { "󰄬" }

            Write-Host "  $icon  " -NoNewline -ForegroundColor $color
            Write-Host "$($_.Name.PadRight(20))" -NoNewline -ForegroundColor White
            Write-Host " [$branch]" -ForegroundColor Gray
            Pop-Location
        }
    }
    Write-Host ""
}

function New-Project {
    param([string]$Path = "")

    $config = Get-ProfileConfig
    $basePath = if ($Path) { $Path } else { $config.projectRoot }

    if (-not (Test-Path $basePath)) {
        Write-Host " ❌ Base path not found: $basePath" -ForegroundColor Red; return
    }

    Write-Host "`n  󰚝  PROJECT ARCHITECT v2" -ForegroundColor Magenta
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    
    $languages = @(
        "Flutter", "Python", "Vite (React/Vue/Svelte)", "Rust", 
        "C++ (CMake)", "Node.js", "C# / .NET", "Web (HTML/CSS/JS)"
    )
    $lang = $languages | fzf --reverse --height 45% --header "SELECT STACK" --border

    if (-not $lang) { return }

    $name = Read-Host "  󰋚 Enter Project Name"
    if (-not $name) { Write-Host "  󰅚 Cancelled." -ForegroundColor Gray; return }

    $fullPath = Join-Path $basePath $name

    if (Test-Path $fullPath) { 
        Write-Host " ⚠️ Folder already exists!" -ForegroundColor Yellow; return 
    }

    Write-Host "`n  🏗️  Building $lang project..." -ForegroundColor Cyan

    switch ($lang) {
        "Vite (React/Vue/Svelte)" {
            Set-Location $basePath
            npm create vite@latest $name
        }
        "Rust" {
            Set-Location $basePath
            cargo new $name
        }
        "C++ (CMake)" {
            New-Item -Path $fullPath -ItemType Directory | Out-Null
            Set-Location $fullPath

            cmake -B . -S . --init 2>$null 

            if (-not (Test-Path "CMakeLists.txt")) {
                Write-Host "  📦 Generating Modern C++ Template..." -ForegroundColor DarkGray
                New-Item -Path "src", "include" -ItemType Directory | Out-Null

                $cmakeTemplate = @"
cmake_minimum_required(VERSION 3.20)
project($name VERSION 1.0.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
file(GLOB_RECURSE SOURCES "src/*.cpp")
add_executable(\${PROJECT_NAME} \${SOURCES})
target_include_directories(\${PROJECT_NAME} PUBLIC include)
"@
                $cmakeTemplate | Out-File "CMakeLists.txt" -Encoding utf8
                "#include <iostream>`n`nint main() {`n    std::cout << ""Hello $name!"" << std::endl;`n    return 0;`n}" | Out-File "src/main.cpp"
            }
        }
        "Flutter" {
            Set-Location $basePath
            flutter create $name
        }
        "Python" {
            New-Item -Path $fullPath -ItemType Directory | Out-Null
            Set-Location $fullPath
            New-Item -Path "src", "tests" -ItemType Directory | Out-Null
            New-Item -Path "src\main.py" -ItemType File | Out-Null
            Write-Host "  📦 Creating virtual environment..." -ForegroundColor DarkGray
            python -m venv .venv
            ".venv/`n__pycache__/`n.env" | Out-File .gitignore
            Write-Host "  ✅ Python project ready." -ForegroundColor Green
        }
        "Node.js" {
            New-Item -Path $fullPath -ItemType Directory | Out-Null
            Set-Location $fullPath
            npm init -y | Out-Null
            "node_modules/`n.env" | Out-File .gitignore
            Write-Host "  ✅ Node.js initialized." -ForegroundColor Green
        }
        "C# / .NET" {
            New-Item -Path $fullPath -ItemType Directory | Out-Null
            Set-Location $fullPath
            dotnet new console
        }
        "Web (HTML/CSS/JS)" {
            New-Item -Path $fullPath -ItemType Directory | Out-Null
            Set-Location $fullPath
            New-Item -Path "index.html", "style.css", "main.js" -ItemType File | Out-Null
            Write-Host "  ✅ Web boilerplate ready." -ForegroundColor Green
        }
    }

    Set-Location $fullPath
    Write-Host "`n  🚀 Project '$name' is ready at $fullPath" -ForegroundColor Magenta
    $open = Read-Host "  Open in VS Code? (y/N)"
    if ($open -eq "y") { code . }
}

function help-system {
    Clear-Host
    Write-Host "`n  󰞷  TERMINAL COMMAND CENTER - USER GUIDE" -ForegroundColor Magenta
    Write-Host "  ================================================================" -ForegroundColor DarkGray

    function Out-Cmd ($List) {
        foreach ($c in $List) {
            Write-Host "    $($c.Cmd.PadRight(16))" -ForegroundColor Green -NoNewline
            Write-Host " │ " -ForegroundColor DarkGray -NoNewline
            Write-Host $c.Desc -ForegroundColor White
        }
    }

    Write-Host "`n  󰙅  NAVIGATION & FILES" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Out-Cmd @(
        @{ Cmd = "l / ll / la"; Desc = "List files (eza) with icons/details" },
        @{ Cmd = ".. [n]";      Desc = "Go up 'n' levels in directories" },
        @{ Cmd = "mcd <dir>";   Desc = "Create directory and enter it immediately" },
        @{ Cmd = "ff";          Desc = "Fuzzy search files and open in VS Code" },
        @{ Cmd = "extr <file>"; Desc = "Extract compressed files (zip, rar, 7z...)" },
        @{ Cmd = "zap <path>";   Desc = "Atomic Delete: Forcefully remove files/folders with live progress" },
        @{ Cmd = "find";         Desc = "Quick Search: Find file and choose (Open/Copy/Go)" },
        @{ Cmd = "gs";           Desc = "Git Summary: Scan all subfolders for git status" },
        @{ Cmd = "newp [path]";  Desc = "Project Architect: Interactive scaffolding for dev projects" }
    )

    Write-Host "`n  󰘚  SYSTEM & VISUALIZATION" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Out-Cmd @(
        @{ Cmd = "welcome";     Desc = "Show system dashboard / Neofetch style" },
        @{ Cmd = "ps";          Desc = "Top 20 process monitor with CPU/RAM icons" },
        @{ Cmd = "jv <file>";   Desc = "Visualize JSON structure in tree view" },
        @{ Cmd = "lv <file>";   Desc = "Log viewer with smart color-coding" },
        @{ Cmd = "cv <file>";   Desc = "CSV table viewer or GUI explorer" },
        @{ Cmd = "wup";         Desc = "Scan and display Winget updates visually" }
    )

    Write-Host "`n  󰠵  MAINTENANCE & TOOLS" -ForegroundColor Green
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Out-Cmd @(
        @{ Cmd = "reload / ep"; Desc = "Reload / Edit `$PROFILE` in VS Code" },
        @{ Cmd = "us / uw / uc"; Desc = "Update managers: Scoop / Winget / Choco" },
        @{ Cmd = "whereis";     Desc = "Check if app was installed via Package Manager" },
        @{ Cmd = "myip / ports"; Desc = "Network info / Active listening ports" },
        @{ Cmd = "kill";         Desc = "Sniper Mode: Select and force-kill processes via FZF" }
    )

    Write-Host "`n  󰌌  KEYBOARD SHORTCUTS" -ForegroundColor Magenta
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "    [Ctrl + T]  " -ForegroundColor Yellow -NoNewline; Write-Host "│ Fuzzy file search & copy path"
    Write-Host "    [Ctrl + G]  " -ForegroundColor Yellow -NoNewline; Write-Host "│ Interactive folder navigation (zoxide)"
    Write-Host "    [Ctrl + R]  " -ForegroundColor Yellow -NoNewline; Write-Host "│ Smart history search"
    Write-Host "    [Ctrl + L]  " -ForegroundColor Yellow -NoNewline; Write-Host "│ Clear screen (Native)"

    Write-Host "`n  󰚌  EXTRA PROTOCOLS" -ForegroundColor Blue
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "    w           " -ForegroundColor Yellow -NoNewline; Write-Host "│ Full 3-day weather forecast"
    Write-Host "    ed          " -ForegroundColor Yellow -NoNewline; Write-Host "│ Quick-edit file in VS Code using FZF"
    Write-Host "    hix         " -ForegroundColor Yellow -NoNewline; Write-Host "| Search history and EXECUTE immediately"
    Write-Host "    matrix      " -ForegroundColor Yellow -NoNewline; Write-Host "│ Enter digital rain mode (cmatrix)"
    
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
            $weatherRaw = curl.exe -s "wttr.in/$($weatherCity)?format=%t" --connect-timeout 2
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
    Write-Host "`n  Type 'help' or 'h' anytime to see help menu.`n" -ForegroundColor DarkGray
    Write-Host ""

}

function Check-WingetVisual {
    Write-Host "`n 󰚰  Scanning for Winget updates..." -ForegroundColor Magenta

    $raw = winget upgrade | Where-Object { $_ -match '\S' }

    $headerLine = ""
    $dividerLine = ""
    for ($i = 0; $i -lt $raw.Count; $i++) {
        if ($raw[$i] -match '^-+$') { 
            $headerLine = $raw[$i-1]
            $dividerLine = $raw[$i]
            $dataStart = $i + 1
            break 
        }
    }

    if (-not $dividerLine) {
        Write-Host " ✅ All systems operational. No updates found." -ForegroundColor Green
        return
    }

    $posId        = $headerLine.IndexOf("Id")
    if ($posId -lt 0) { $posId = $headerLine.IndexOf("ID") }
    
    $posVersion   = $headerLine.IndexOf("Versi")
    if ($posVersion -lt 0) { $posVersion = $headerLine.IndexOf("Version") }
    
    $posAvailable = $headerLine.IndexOf("Dispon")
    if ($posAvailable -lt 0) { $posAvailable = $headerLine.IndexOf("Available") }

    Write-Host "   UPDATES AVAILABLE:" -ForegroundColor Cyan
    $separator = "─" * 165
    Write-Host " $separator" -ForegroundColor DarkGray
    Write-Host "  $( "APPLICATION".PadRight(35) ) $( "CURRENT".PadRight(25) ) $( "LATEST".PadRight(25) ) $( "QUICK UPDATE COMMAND" )" -ForegroundColor White
    Write-Host " $separator" -ForegroundColor DarkGray

    $raw | Select-Object -Skip $dataStart | ForEach-Object {
        $line = $_
        if ($line -match "actualizaciones disponibles" -or $line -match "updates available") { return }

        try {
            $name    = $line.Substring(0, $posId).Trim()
            $id      = $line.Substring($posId, ($posVersion - $posId)).Trim()
            $current = $line.Substring($posVersion, ($posAvailable - $posVersion)).Trim()
            $latest  = $line.Substring($posAvailable).Trim().Split(' ')[0]

            $dispName = if ($name.Length -gt 33) { $name.Substring(0, 30) + "..." } else { $name }
            $commandId = if ($id -match '…') { $id -replace '…', '*' } else { $id }

            Write-Host "  󰏗  " -NoNewline -ForegroundColor Yellow
            Write-Host "$( $dispName.PadRight(31) )" -NoNewline -ForegroundColor White
            Write-Host "$( $current.PadRight(25) )" -NoNewline -ForegroundColor Gray
            Write-Host " ➜  " -NoNewline -ForegroundColor Magenta
            Write-Host "$( $latest.PadRight(24) )" -NoNewline -ForegroundColor Green
            
            Write-Host "   " -NoNewline -ForegroundColor DarkGray
            Write-Host "winget update --id " -NoNewline -ForegroundColor DarkCyan
            Write-Host $commandId -ForegroundColor Cyan
        } catch { }
    }

    Write-Host " $separator" -ForegroundColor DarkGray
    Write-Host " 💡 Total items found: $(($raw.Count - $dataStart - 1))" -ForegroundColor Gray
    Write-Host ""
}

function ConvertFrom-SourceTable {
    param([Parameter(ValueFromPipeline=$true)] [string[]]$InputObject)
    begin { $lines = @() }
    process { $lines += $InputObject }
    end {
        if ($lines.Count -lt 2) { return }
        $headerLine = $lines | Where-Object { $_ -match '^[a-zA-Z].*\s{2,}' } | Select-Object -First 1
        if (-not $headerLine) { return }
        
        $headers = [regex]::Matches($headerLine, '(?<name>\S+(?:\s\S+)*)\s*')
        foreach ($line in ($lines | Where-Object { $_ -match '^[a-zA-Z0-9].*\s{2,}' } | Select-Object -Skip 1)) {
            $obj = New-Object PSObject
            foreach ($h in $headers) {
                $val = if ($h.Index + $h.Length -le $line.Length) {
                    $line.Substring($h.Index, $h.Length).Trim()
                } else {
                    $line.Substring($h.Index).Trim()
                }
                $obj | Add-Member -MemberType NoteProperty -Name $h.Groups['name'].Value -Value $val
            }
            $obj
        }
    }
}

function Show-JsonVisual {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )

    try {
        $fullPath = Resolve-Path $Path
        $data = Get-Content $fullPath -Raw | ConvertFrom-Json
    } catch {
        Write-Host " ❌ Error: The file is not a valid JSON or does not exist." -ForegroundColor Red
        return
    }

    Write-Host "`n 󰘦  Visualizing: $(Split-Path $fullPath -Leaf)" -ForegroundColor Magenta
    Write-Host " ──────────────────────────────────────────────────" -ForegroundColor DarkGray

    function Invoke-DrawNode {
        param($Object, $Indent = "")

        if ($Object -is [PSCustomObject] -or $Object -is [System.Collections.IDictionary]) {
            $properties = $Object | Get-Member -MemberType NoteProperty, Property
            $count = $properties.Count
            $i = 0

            foreach ($p in $properties) {
                $i++
                $isLast = ($i -eq $count)

                $connector = if ($isLast) { " └── " } else { " ├── " }
                $space = if ($isLast) { "     " } else { " │   " }
                $nextIndent = $Indent + $space

                Write-Host "$Indent$connector" -NoNewline -ForegroundColor DarkGray
                Write-Host "$($p.Name): " -NoNewline -ForegroundColor Cyan
                
                $val = $Object.$($p.Name)
                if ($val -is [PSCustomObject] -or $val -is [Array]) {
                    Write-Host "󰅂" -ForegroundColor DarkGray
                    Invoke-DrawNode -Object $val -Indent $nextIndent
                } else {
                    Write-Host $val -ForegroundColor White
                }
            }
        }
        elseif ($Object -is [Array]) {
            $count = $Object.Count
            for ($j=0; $j -lt $count; $j++) {
                $isLast = ($j -eq $count -1)
                
                $connector = if ($isLast) { " └── " } else { " ├── " }
                $space = if ($isLast) { "     " } else { " │   " }
                $nextIndent = $Indent + $space

                Write-Host "$Indent$connector" -NoNewline -ForegroundColor DarkGray
                Write-Host "[$j] " -NoNewline -ForegroundColor Yellow
                
                $item = $Object[$j]
                if ($item -is [PSCustomObject] -or $item -is [Array]) {
                    Write-Host "󰅂" -ForegroundColor DarkGray
                    Invoke-DrawNode -Object $item -Indent $nextIndent
                } else {
                    Write-Host $item -ForegroundColor White
                }
            }
        }
    }

    Invoke-DrawNode -Object $data
    Write-Host " ──────────────────────────────────────────────────`n" -ForegroundColor DarkGray
}

function Show-LogVisual {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (!(Test-Path $Path)) { Write-Host " ❌ File not found." -ForegroundColor Red; return }

    Write-Host "`n   Reading Log: $(Split-Path $Path -Leaf)" -ForegroundColor Magenta
    Write-Host " ──────────────────────────────────────────────────" -ForegroundColor DarkGray

    Get-Content $Path | ForEach-Object {
        $line = $_
        if ($line -match "ERROR|Critical|Failed") { Write-Host $line -ForegroundColor Red }
        elseif ($line -match "WARN|Warning") { Write-Host $line -ForegroundColor Yellow }
        elseif ($line -match "INFO|Success") { Write-Host $line -ForegroundColor Cyan }
        else { Write-Host $line -ForegroundColor Gray }
    }
    Write-Host " ──────────────────────────────────────────────────`n" -ForegroundColor DarkGray
}

function Show-CsvVisual {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        $fullPath = Resolve-Path $Path
        $data = Import-Csv $fullPath
        $count = ($data | Measure-Object).Count

        Write-Host "`n   CSV Data: $(Split-Path $fullPath -Leaf) ($count registros)" -ForegroundColor Cyan
        
        if ($count -gt 50) {
            Write-Host " 󰆼  Launching standalone browser..." -ForegroundColor DarkGray
            Start-Process powershell -ArgumentList "-NoProfile -Command `"Import-Csv '$fullPath' | Out-GridView -Title 'CSV Explorer: $(Split-Path $fullPath -Leaf)'`"" -WindowStyle Hidden
            
            Write-Host " ✅ Open browser. Free terminal." -ForegroundColor Green
        } else {
            $data | Format-Table -AutoSize
        }
    } catch {
        Write-Host " ❌ Error reading CSV. Check the delimiter." -ForegroundColor Red
    }
}

function Show-ProcessVisual {
    Write-Host "`n   Active Process Monitor" -ForegroundColor Magenta
    Write-Host " ──────────────────────────────────────────────────" -ForegroundColor DarkGray

    Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 | ForEach-Object {
        $mem = [Math]::Round($_.WorkingSet / 1MB, 2)
        $cpu = [Math]::Round($_.CPU, 1)

        $color = "White"
        if ($mem -gt 500) { $color = "Yellow" }
        if ($mem -gt 1000) { $color = "Red" }

        Write-Host "  " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($_.Name.PadRight(25))" -NoNewline -ForegroundColor Cyan
        Write-Host "   $($cpu.ToString().PadLeft(6)) s" -NoNewline -ForegroundColor Gray
        Write-Host " 󰍛  $($mem.ToString().PadLeft(8)) MB" -ForegroundColor $color
    }
    Write-Host " ──────────────────────────────────────────────────`n" -ForegroundColor DarkGray
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
Set-Alias whereis Get-InstallMethod
Set-Alias wup Check-WingetVisual
Set-Alias jv Show-JsonVisual
Set-Alias cv Show-CsvVisual
Set-Alias lv Show-LogVisual
Set-Alias pv Show-ProcessVisual
Set-Alias zap Invoke-Zap
Set-Alias find Invoke-QuickSearch
Set-Alias kill Invoke-KillProcess
Set-Alias gs Get-GitStatusSummary
Set-Alias newp New-Project

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
