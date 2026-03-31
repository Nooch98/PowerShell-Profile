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
    param(
        [Parameter(Mandatory=$false)]
        [int]$levels = 1
    )

    $currentPath = $pwd.Path
    $targetPath = $currentPath

    try {
        for ($i = 0; $i -lt $levels; $i++) {
            $parent = Split-Path $targetPath -Parent

            if (-not $parent -or $targetPath -eq $parent) {
                if ($targetPath -ne $currentPath) {
                    Write-Host "  󱞊  Reached root directory: " -NoNewline -ForegroundColor DarkYellow
                    Write-Host $targetPath -ForegroundColor White
                } else {
                    Write-Host "  󰀦  Already at root." -ForegroundColor DarkGray
                }
                break
            }
            $targetPath = $parent
        }

        if ($targetPath -ne $currentPath) {
            Set-Location $targetPath

            $relative = $targetPath.Split('\')[-1]
            if (-not $relative) { $relative = $targetPath }
            
            Write-Host "  󰁝  Up $levels level(s) │ " -NoNewline -ForegroundColor Gray
            Write-Host "Now in: $relative" -ForegroundColor Cyan
        }

    } catch {
        Write-Host "  ❌ Error navigating upwards." -ForegroundColor Red
    }
}

function mcd {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
        Write-Host "  📁 Directory created: " -NoNewline -ForegroundColor Gray
        Write-Host $Path -ForegroundColor Cyan
    } else {
        Write-Host "  📂 Directory already exists, switching..." -ForegroundColor DarkGray
    }

    Set-Location -Path $Path
}

function uptime {
    $os = Get-CimInstance Win32_OperatingSystem
    $bootTime = $os.LastBootUpTime
    $uptime = (Get-Date) - $bootTime

    $parts = @()
    if ($uptime.Days -gt 0)    { $parts += "$($uptime.Days)d" }
    if ($uptime.Hours -gt 0)   { $parts += "$($uptime.Hours)h" }
    if ($uptime.Minutes -gt 0) { $parts += "$($uptime.Minutes)m" }
    if ($parts.Count -eq 0)    { $parts += "$($uptime.Seconds)s" }
    
    $uptimeString = $parts -join " "

    $color = "Green"
    if ($uptime.Days -gt 7)  { $color = "Yellow" }
    if ($uptime.Days -gt 30) { $color = "Red" }

    Write-Host "`n  󱑍  SYSTEM UPTIME" -ForegroundColor Magenta
    Write-Host "  " + ("─" * 40) -ForegroundColor DarkGray
    
    Write-Host "  Last Reboot : " -NoNewline -ForegroundColor Gray
    Write-Host "$($bootTime.ToString('f'))" -ForegroundColor Cyan
    
    Write-Host "  Active for  : " -NoNewline -ForegroundColor Gray
    Write-Host $uptimeString -ForegroundColor $color
    
    Write-Host ""
}

function diskinfo {
    Write-Host "`n  󰋊  STORAGE OVERVIEW" -ForegroundColor Magenta
    Write-Host "  ================================================================" -ForegroundColor DarkGray

    $disks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.Size -gt 0 } | ForEach-Object {
        $sizeGB = [Math]::Round($_.Size / 1GB, 2)
        $freeGB = [Math]::Round($_.FreeSpace / 1GB, 2)
        $usedGB = [Math]::Round($sizeGB - $freeGB, 2) # Forzamos redondeo aquí
        $percentUsed = [Math]::Round(($usedGB / $sizeGB) * 100, 1)

        $color = "Green"
        if ($percentUsed -gt 75) { $color = "Yellow" }
        if ($percentUsed -gt 90) { $color = "Red" }

        $barLength = 10
        $filled = [int][Math]::Floor($percentUsed / 10)
        $bar = ("#" * $filled) + ("." * ($barLength - $filled))

        [PSCustomObject]@{
            Drive    = $_.DeviceID
            Label    = if ($_.VolumeName) { $_.VolumeName } else { "Local Disk" }
            Total    = $sizeGB
            Used     = $usedGB
            Free     = $freeGB
            Usage    = "$percentUsed%"
            Status   = "[$bar]"
            _Color   = $color
        }
    }

    $hdr = "  {0,-6} {1,-15} {2,10} {3,10} {4,10}   {5,-12}" -f "DRIVE", "LABEL", "TOTAL", "USED", "FREE", "HEALTH"
    Write-Host $hdr -ForegroundColor Cyan
    Write-Host "  $("-" * 72)" -ForegroundColor DarkGray

    foreach ($d in $disks) {
        $t = "{0:N2}" -f $d.Total
        $u = "{0:N2}" -f $d.Used
        $f = "{0:N2}" -f $d.Free
        
        $line = "  {0,-6} {1,-15} {2,10} {3,10} {4,10}   " -f $d.Drive, $d.Label, $t, $u, $f
        Write-Host $line -NoNewline
        Write-Host "$($d.Status) $($d.Usage)" -ForegroundColor $d._Color
    }
    Write-Host ""
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
        Write-Host "`n  󰚰  Checking for PowerShell Preview updates..." -ForegroundColor Gray

        $currentVersion = $PSVersionTable.PSVersion
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases"

        $headers = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" }
        $allReleases = Invoke-RestMethod -Uri $gitHubApiUrl -Headers $headers -ErrorAction SilentlyContinue
        
        if ($null -eq $allReleases) {
            Write-Host "  󰅚  GitHub API unreachable or Rate Limited." -ForegroundColor DarkYellow
            return
        }

        $latestPreview = $allReleases | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        $tag = $latestPreview.tag_name
        $regex = '\d+(\.\d+)+'
        $cleanLatest = ([regex]::Match($tag, $regex)).Value
        $cleanCurrent = ([regex]::Match($currentVersion.ToString(), $regex)).Value

        if ($tag -match "-preview\.(\d+)") { $cleanLatest += ".$($Matches[1])" }
        if ($currentVersion.ToString() -match "-preview\.(\d+)") { $cleanCurrent += ".$($Matches[1])" }

        if ([version]$cleanLatest -gt [version]$cleanCurrent) {
            Write-Host "  󱧘  New Preview available: " -NoNewline -ForegroundColor Magenta
            Write-Host $tag -ForegroundColor White
            
            Write-Host "  󰇚  Updating via WinGet..." -ForegroundColor Cyan

            $updateResult = winget update --id Microsoft.PowerShell.Preview --silent --accept-source-agreements --accept-package-agreements 2>&1
            
            if ($lastExitCode -eq 0) {
                Write-Host "  󰄬  Update complete! Please restart your terminal." -ForegroundColor Green
            } else {
                Write-Host "  󰅚  WinGet couldn't complete the update automatically." -ForegroundColor Red
            }
        } else {
            Write-Host "  󰄬  PowerShell Preview is up to date (" -NoNewline -ForegroundColor DarkGray
            Write-Host $tag -NoNewline -ForegroundColor Gray
            Write-Host ")" -ForegroundColor DarkGray
        }

    } catch {
        Write-Host "  󰅚  Error during update check: $($_.Exception.Message)" -ForegroundColor DarkRed
    }
}

function Invoke-Fzf {
    $selectitem = & 'fzf' --reverse --preview-window=up:50% --preview='bat --color=always --style=numbers {1}'
    if ($selectitem) { Set-Clipboard -Value $selectitem }
}

function activate {
    param([string]$Name = "")

    $found = $null

    $venvNames = if ($Name) { @($Name) } else { @("venv", ".venv", "env", ".env", "app") }
    $subPaths  = @("Scripts\activate.ps1", "bin\activate.ps1")

    Write-Host "`n  🐍 Searching for Python Virtual Environment..." -ForegroundColor Gray

    foreach ($vName in $venvNames) {
        foreach ($sPath in $subPaths) {
            $testPath = Join-Path (Get-Location) "$vName\$sPath"
            if (Test-Path $testPath) {
                $found = Get-Item $testPath
                break
            }
        }
        if ($found) { break }
    }

    if ($found) {
        $envName = $found.Directory.Parent.Name
        Write-Host "  󱔎  Activating: " -NoNewline -ForegroundColor Blue
        Write-Host "$envName" -ForegroundColor White

        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

        & $found.FullName

        Write-Host "  󰄬  Environment ready." -ForegroundColor Green
        Write-Host "  󰌑  Tip: Use 'deactivate' to exit or 'Ctrl+L' to clear." -ForegroundColor DarkGray
    } else {
        Write-Host "  ❌ No virtual environment found " -NoNewline -ForegroundColor Red
        if ($Name) { Write-Host "with name '$Name'" -ForegroundColor Yellow } 
        else { Write-Host "(tried venv, .venv, env, .env)" -ForegroundColor DarkGray }
    }
    Write-Host ""
}

function Select-Fzf { $input | fzf --reverse --height 50% --border --prompt='Select > ' | Out-String}

function Remove-ModuleFzf {
    Write-Host "`n  󰆧  MODULE UNINSTALLER (fzf-powered)" -ForegroundColor Magenta
    Write-Host "  " + ("─" * 45) -ForegroundColor DarkGray
    Write-Host "  (Tab/Ctrl+Space to select multiple, Enter to confirm)`n" -ForegroundColor Gray

    $modules = Get-Module -ListAvailable | 
               Select-Object Name, Version, Author -Unique | 
               ForEach-Object { "$($_.Name) | v$($_.Version) | by $($_.Author)" }

    if (-not $modules) { 
        Write-Host "  ❌ No modules found." -ForegroundColor Red
        return 
    }

    $selection = $modules | fzf --multi `
        --reverse `
        --header='[Tab: Select | Enter: Uninstall | Esc: Cancel]' `
        --prompt='󰄭 Modules to Remove > ' `
        --border='rounded' `
        --color='hl:176,hl+:176,pointer:208,marker:168'

    if ($selection) {
        foreach ($item in $selection) {
            $moduleName = $item.Split('|')[0].Trim()
            
            Write-Host "  󰚃  Uninstalling: " -NoNewline -ForegroundColor Cyan
            Write-Host $moduleName -ForegroundColor White

            try {
                Uninstall-Module -Name $moduleName -Force -ErrorAction Stop
                Write-Host "  󰄬  Done." -ForegroundColor Green
            } catch {
                Write-Host "  󰅚  Failed: " -NoNewline -ForegroundColor Red
                Write-Host $_.Exception.Message -ForegroundColor DarkGray

                if ($_.Exception.Message -match "in use") {
                    Write-Host "      Tip: Try 'Remove-Module $moduleName' first to unload it." -ForegroundColor DarkYellow
                }
            }
        }
        Write-Host "`n  󰠄  Process finished. Restart shell for a clean state.`n" -ForegroundColor DarkGray
    } else {
        Write-Host "  󰜺  Operation canceled." -ForegroundColor DarkYellow
    }
}

function find-command {
    param([string]$query = "")

    Write-Host "`n  🔍  POWERSHELL COMMAND PALETTE" -ForegroundColor Magenta
    Write-Host "  " + ("─" * 45) -ForegroundColor DarkGray
    Write-Host "  (Enter: Execute | Esc: Cancel)`n" -ForegroundColor Gray

    $commands = Get-Command -CommandType Function, Alias | 
                Where-Object { $_.Source -match "Microsoft.PowerShell_profile.ps1" -or $_.Name -match $query } |
                Select-Object @{Name="Type"; Expression={$_.CommandType}}, Name, Definition |
                ForEach-Object { "$($_.Type.ToString().ToUpper().PadRight(8)) │ $($_.Name)" }

    if (-not $commands) {
        Write-Host "  ❌ No custom commands found." -ForegroundColor Red
        return
    }

    $selection = $commands | fzf --reverse `
        --header='[Enter: Run | Ctrl+C: Copy Name | Esc: Exit]' `
        --prompt='󰍉 Search Tool > ' `
        --height=50% `
        --border='sharp' `
        --color='hl:176,hl+:176,pointer:208,marker:168'

    if ($selection) {
        $cmdName = $selection.Split('│')[1].Trim()

        Write-Host "`n  🚀 Executing: " -NoNewline -ForegroundColor Cyan
        Write-Host $cmdName -ForegroundColor White
        Write-Host "  " + ("─" * 20) -ForegroundColor DarkGray -BackgroundColor Black
        Invoke-Expression $cmdName
    } else {
        Write-Host "  󰜺  Selection canceled." -ForegroundColor DarkYellow
    }
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
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "`n  ⚠️  Winget not found. Aborting." -ForegroundColor Yellow
        return
    }

    Write-Host "`n  󰚰  WINGET PRECISE UPDATE" -ForegroundColor Magenta
    Write-Host ("  " + ("─" * 75)) -ForegroundColor DarkGray
    Write-Host "  󱑤  Scanning for pending updates..." -ForegroundColor Gray -NoNewline

    $raw = winget upgrade | Where-Object { $_ -match '\S' -and $_ -notmatch 'Loading|Cargando' }
    $headerLine = ""
    $dataStart = 0
    for ($i = 0; $i -lt $raw.Count; $i++) {
        if ($raw[$i] -match '^-+$') { 
            $headerLine = $raw[$i-1]
            $dataStart = $i + 1
            break 
        }
    }

    if ($dataStart -eq 0) {
        Write-Host "`r  ✅  System up to date! No pending packages.          " -ForegroundColor Green
        return
    }

    $posId = $headerLine.IndexOf("Id")
    if ($posId -lt 0) { $posId = $headerLine.IndexOf("ID") }
    $posVersion = $headerLine.IndexOf("Versi")
    if ($posVersion -lt 0) { $posVersion = $headerLine.IndexOf("Version") }

    $packages = $raw | Select-Object -Skip $dataStart | ForEach-Object {
        $line = $_
        if ($line.Length -gt $posVersion) {
            $id = $line.Substring($posId, ($posVersion - $posId)).Trim()
            if ($id -and $id -notmatch "updates available|actualizaciones") { $id }
        }
    }

    $total = $packages.Count
    if ($total -eq 0) {
        Write-Host "`r  ✅  No action required.                                " -ForegroundColor Green
        return
    }

    Write-Host "`r  🚀  Processing $total updates...                     " -ForegroundColor Cyan

    $current = 1
    foreach ($id in $packages) {
        $percent = [Math]::Round(($current / $total) * 100)
        $barLength = 20
        $done = [Math]::Round(($current / $total) * $barLength)
        $bar = ("█" * $done) + ("░" * ($barLength - $done))
        
        $cleanId = $id -replace '…', '*'
        $displayId = if ($cleanId.Length -gt 25) { $cleanId.Substring(0, 22) + "..." } else { $cleanId }

        $statusMsg = "  [$bar] $($percent)% │ Updating: $($displayId.PadRight(25)) | ($current / $total)"
        Write-Host "`r$statusMsg" -NoNewline -ForegroundColor Yellow

        $process = Start-Process winget -ArgumentList "upgrade", "--id", "`"$cleanId`"", "--silent", "--accept-package-agreements", "--accept-source-agreements" `
            -NoNewWindow -Wait -PassThru -RedirectStandardOutput $env:TEMP\winget-log.txt -RedirectStandardError $env:TEMP\winget-err.txt

        if ($process.ExitCode -eq 0) {
            $successMsg = "  [$bar] $($percent)% │ Finished: $($displayId.PadRight(25)) | ($current / $total)"
            Write-Host "`r$successMsg" -NoNewline -ForegroundColor Green
        } else {
            $errorMsg = "  [$bar] $($percent)% │ Failed:   $($displayId.PadRight(25)) | ($current / $total)"
            Write-Host "`r$errorMsg" -NoNewline -ForegroundColor Red
            Start-Sleep -Milliseconds 500
        }
        
        $current++
    }

    Write-Host "`n  ✨  All updates processed successfully." -ForegroundColor Magenta
    Write-Host ("  " + ("─" * 75)) -ForegroundColor DarkGray
    Write-Host ""
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

    Write-Host "`n  🔍 Searching installation source for: " -NoNewline -ForegroundColor Gray
    Write-Host "'$AppName'..." -ForegroundColor Cyan
    Write-Host "  " + ("─" * 45) -ForegroundColor DarkGray
    
    $found = $false

    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $scoopCheck = scoop list | Where-Object { $_.Name -match $AppName -or $_ -match $AppName }
        if ($scoopCheck) { 
            foreach ($app in $scoopCheck) {
                $name = if ($app.Name) { $app.Name } else { $app.ToString().Split(' ')[0] }
                Write-Host "  📦 [SCOOP]  │ " -NoNewline -ForegroundColor Cyan
                Write-Host "Found: $name" -ForegroundColor White
                Write-Host "             Uninstall: scoop uninstall $name" -ForegroundColor DarkGray
            }
            $found = $true
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $wingetCheck = winget list --name $AppName --accept-source-agreements -e 2>$null | Select-String $AppName
        if ($wingetCheck) {
            Write-Host "  📦 [WINGET] │ " -NoNewline -ForegroundColor Blue
            Write-Host "Found matches in Winget repository." -ForegroundColor White
            Write-Host "             Uninstall: winget uninstall `"$AppName`"" -ForegroundColor DarkGray
            $found = $true
        }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        $chocoCheck = choco list -lo -r | Where-Object { $_ -match $AppName }
        
        if ($chocoCheck) {
            foreach ($line in $chocoCheck) {
                $cName = $line.Split('|')[0]
                Write-Host "  📦 [CHOCO]  │ " -NoNewline -ForegroundColor Green
                Write-Host "Found: $cName" -ForegroundColor White
                Write-Host "             Uninstall: choco uninstall $cName" -ForegroundColor DarkGray
                $found = $true
            }
        }
    }

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $regCheck = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -match $AppName -or $_.PSChildName -match $AppName } | 
                Select-Object DisplayName, DisplayVersion, UninstallString

    if ($regCheck) {
        foreach ($app in $regCheck) {
            $name = if ($app.DisplayName) { $app.DisplayName } else { "Unknown (Registry ID: $($app.PSChildName))" }
            Write-Host "  🖥️  [REGEDIT] │ " -NoNewline -ForegroundColor Yellow
            Write-Host "Found: $name (v$($app.DisplayVersion))" -ForegroundColor White
            
            if ($app.UninstallString) {
                Write-Host "             Silent/Manual Uninstall: $($app.UninstallString)" -ForegroundColor DarkGray
            }
        }
        $found = $true
    }

    if (-not $found) {
        Write-Host "  ❌ No installation found for '$AppName' in any manager." -ForegroundColor Red
    }
    Write-Host ""
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

    $tablaProcesos = @{}
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object { $tablaProcesos[$_.Id] = $_.ProcessName }
    $tablaProcesos[0] = "Idle"
    $tablaProcesos[4] = "System"
    $lineasNetstat = netstat -ano | Select-String "LISTENING"
    $listaResultados = foreach ($linea in $lineasNetstat) {
        $partes = $linea.ToString().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($partes.Count -ge 4) {
            $idEncontrado = [int]$partes[$partes.Count - 1]
            $puertoNum    = [int]($partes[1].Split(':')[-1])
            $nombreProc   = if ($tablaProcesos.ContainsKey($idEncontrado)) { $tablaProcesos[$idEncontrado] } else { "Protected/Unknown" }

            $tipoEtiqueta = switch ($puertoNum) {
                { $_ -in 80, 443, 8080, 3000, 5000, 5173 } { "󰖟 Web" }
                { $_ -in 3306, 5432, 27017, 6379 } { "󰆼 DB" }
                { $_ -in 22, 21, 3389, 135, 445, 139 } { "󰒍 System" }
                Default { "󱄙 Service" }
            }

            [PSCustomObject]@{
                PortNum   = $puertoNum
                TypeStr   = $tipoEtiqueta
                ProcName  = $nombreProc
                ActualPID = $idEncontrado
            }
        }
    }

    $puertosUnicos = $listaResultados | Sort-Object PortNum -Unique
    $col1 = "    PORT".PadRight(10)
    $col2 = "TYPE".PadRight(16)
    $col3 = "PROCESS".PadRight(28)
    Write-Host "$col1$col2│ $col3│ PID" -ForegroundColor Cyan
    Write-Host "    $("-" * 65)" -ForegroundColor DarkGray

    foreach ($p in $puertosUnicos) {
        $colorPuerto = switch ($p.PortNum) {
            { $_ -in 80, 443, 3000, 5000, 5173 } { "Yellow" }
            { $_ -in 3306, 5432 } { "Cyan" }
            { $_ -in 135, 445, 139 } { "DarkYellow" }
            Default { "White" }
        }

        $txtP = "    $($p.PortNum)".PadRight(12)
        $txtT = "$($p.TypeStr)".PadRight(16)
        $txtN = "$($p.ProcName)".PadRight(26)
        $txtI = "$($p.ActualPID)"

        Write-Host $txtP -ForegroundColor $colorPuerto -NoNewline
        Write-Host $txtT -ForegroundColor DarkGray -NoNewline
        Write-Host "│ " -ForegroundColor DarkGray -NoNewline
        Write-Host $txtN -ForegroundColor White -NoNewline
        Write-Host "│ " -ForegroundColor DarkGray -NoNewline
        Write-Host $txtI -ForegroundColor Gray
    }

    Write-Host "`n  󰚰  Total active listeners: $($puertosUnicos.Count)`n" -ForegroundColor DarkGray
}

function Set-ExtractFile {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$File
    )

    if (-not (Test-Path $File)) {
        Write-Host "  ❌ File not found: $File" -ForegroundColor Red
        return
    }

    $item = Get-Item $File
    $ext = $item.Extension.ToLower()
    $dest = Join-Path $pwd.Path $item.BaseName

    Write-Host "`n  󰛫  Extracting: " -NoNewline -ForegroundColor Gray
    Write-Host $item.Name -ForegroundColor Cyan
    Write-Host "  " + ("─" * 45) -ForegroundColor DarkGray

    if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest | Out-Null }

    switch ($ext) {
        ".zip" { 
            Expand-Archive -Path $item.FullName -DestinationPath $dest -Force 
        }
        
        { $_ -in ".tar", ".gz", ".tgz" } { 
            tar -xvf $item.FullName -C $dest 
        }
        
        ".rar" { 
            if (Get-Command unrar -ErrorAction SilentlyContinue) {
                unrar x $item.FullName "$dest\"
            } elseif (Get-Command 7z -ErrorAction SilentlyContinue) {
                7z x $item.FullName "-o$dest"
            } else {
                Write-Host "  󰀦  Error: Install 'unrar' or '7zip' to extract .rar files." -ForegroundColor Yellow
            }
        }
        
        ".7z" { 
            if (Get-Command 7z -ErrorAction SilentlyContinue) {
                7z x $item.FullName "-o$dest"
            } else {
                Write-Host "  󰀦  Error: 7zip not found in PATH." -ForegroundColor Yellow
            }
        }

        default { 
            Write-Host "  󰅚  Unsupported format: $ext" -ForegroundColor Red
            return
        }
    }

    if ($LASTEXITCODE -eq 0 -or $?) {
        Write-Host "  󰄬  Extraction complete!" -ForegroundColor Green
        Write-Host "  📂 Destination: " -NoNewline -ForegroundColor Gray
        Write-Host "./$($item.BaseName)/" -ForegroundColor White
    }
    Write-Host ""
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
        $date = Get-Date -Format "dd/MM"
        "[$date] $task" | Out-File -FilePath $todoFile -Append -Encoding utf8
        Write-Host "  󰄲 Task added: " -NoNewline -ForegroundColor Green
        Write-Host $task -ForegroundColor White
        return
    } 

    if (Test-Path $todoFile) {
        $content = Get-Content $todoFile | Where-Object { $_ -match '\S' }
        if ($null -eq $content) { 
            Remove-Item $todoFile
            Write-Host "  󰚙  No pending tasks." -ForegroundColor DarkGray
            return 
        }

        Write-Host "`n  󰏫  PENDING TASKS" -ForegroundColor Magenta
        Write-Host "  " + ("─" * 20) -ForegroundColor DarkGray
        
        foreach ($line in $content) {
            $color = if ($line -match "!") { "Yellow" } else { "White" }
            Write-Host "  󰄱  " -NoNewline -ForegroundColor $color
            Write-Host $line -ForegroundColor $color
        }

        $header = "TAB: Mark Multiple | ENTER: Finish/Delete | ESC: Exit"
        $toRemove = $content | fzf --multi --reverse --header $header --prompt="Complete > " --height 40% --border

        if ($toRemove) {
            $newContent = $content | Where-Object { $_ -notin $toRemove }
            if ($newContent) {
                $newContent | Out-File -FilePath $todoFile -Encoding utf8
            } else {
                Remove-Item $todoFile
            }

            $count = ($toRemove | Measure-Object).Count
            Write-Host "`n  󰄭  $count tasks completed! Well done." -ForegroundColor Cyan
        } else {
            Clear-Host
            [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
        }
    } else {
        Write-Host "`n  󰚙  No pending tasks. You're free!" -ForegroundColor DarkGray
    }
}

function myip {
    $public = if ($global:canConnectToGithub) { curl.exe -s https://api.ipify.org } else { "Offline" }
    $localIP = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi", "Ethernet" -ErrorAction SilentlyContinue | 
               Select-Object -First 1

    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 | 
           Where-Object { $_.ServerAddresses -ne $null -and $_.InterfaceAlias -in @("Wi-Fi", "Ethernet") } | 
           Select-Object -ExpandProperty ServerAddresses | 
           Select-Object -First 1

    Write-Host "`n  󰩟 Network Info:" -ForegroundColor Magenta
    Write-Host "  --------------" -ForegroundColor DarkGray   
    Write-Host "  Local IP  : " -NoNewline; Write-Host ($localIP.IPAddress ?? "Not Found") -ForegroundColor Cyan
    Write-Host "  Public IP : " -NoNewline; Write-Host $public -ForegroundColor Cyan
    Write-Host "  DNS       : " -NoNewline; Write-Host ($dns -join ", " ?? "Not Configured") -ForegroundColor Cyan
    Write-Host ""
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
    param(
        [string]$repoName = "",
        [switch]$View
    )

    $token = $env:GITHUB
    if (-not $token) { Write-Host "❌ Error: `$env:GITHUB` not found." -ForegroundColor Red; return }

    $headers = @{ 
        "Authorization" = "token $token"
        "Accept"        = "application/vnd.github.v3+json"
        "User-Agent"    = "PowerShell-CLI"
    }

    if (-not $repoName) {
        try {
            $myRepos = Invoke-RestMethod -Uri "https://api.github.com/user/repos?per_page=100&sort=updated" -Headers $headers
            $repoName = $myRepos | Select-Object -ExpandProperty full_name | fzf --reverse --header "Select a repository"
            if (-not $repoName) { return }
        } catch {
            Write-Host "❌ Could not list repositories." -ForegroundColor Red; return
        }
    }

    $repoName = $repoName.Trim()

    if ($View) {
        $type = @("Issues", "Pull Requests") | fzf --reverse --height 10% --header "What do you want to browse?"
        if (-not $type) { return }

        $queryType = if ($type -eq "Issues") { "is:issue" } else { "is:pr" }
        $searchUri = "https://api.github.com/search/issues?q=repo:$repoName+$queryType+is:open"
        
        try {
            Write-Host "  🔍 Searching $type..." -ForegroundColor DarkGray
            $response = Invoke-RestMethod -Uri $searchUri -Headers $headers -ErrorAction Stop
            $items = $response.items
            
            if ($null -eq $items -or $items.Count -eq 0) { 
                Write-Host "`n  󰅚 No open $type found in $repoName." -ForegroundColor Yellow
                return 
            }

            $selected = $items | ForEach-Object { 
                "$($_.number.ToString().PadRight(5)) | $($_.user.login.PadRight(15)) | $($_.title)" 
            } | fzf --reverse --header "SELECT AN ITEM TO VIEW DETAILS" --preview-window=top:60%

            if ($selected) {
                $number = ($selected -split " \| ")[0].Trim()
                $detail = $items | Where-Object { $_.number -eq $number }
                
                Clear-Host
                Write-Host "`n  #$($detail.number): $($detail.title)" -ForegroundColor Magenta
                Write-Host "  Author: $($detail.user.login) | Created: $([DateTime]$detail.created_at)" -ForegroundColor DarkGray
                Write-Host "  " + ("-" * 60) -ForegroundColor DarkGray
                
                if ($detail.body) {
                    $detail.body | bat --language md --style=plain
                } else {
                    Write-Host "  (No description provided)" -ForegroundColor DarkGray
                }
                
                Write-Host "`n  🔗 URL: $($detail.html_url)" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "`n  󰅚 GitHub API Error: Could not access repository search." -ForegroundColor Red
            Write-Host "  Verify the repo name '$repoName' and ensure your token has proper permissions." -ForegroundColor DarkGray
        }
        return
    }

    Write-Host "📊 Fetching data for $repoName..." -ForegroundColor Yellow
    try {
        $mainInfo     = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName" -Headers $headers
        $trafficClones = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/traffic/clones" -Headers $headers
        $trafficViews  = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/traffic/views" -Headers $headers
        $releases      = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/releases" -Headers $headers
        $pulls         = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoName/pulls?state=open" -Headers $headers
        
        $prCount = $pulls.Count
        $actualIssues = $mainInfo.open_issues_count - $prCount
        $lastPush = if ($mainInfo.pushed_at) { ([DateTime]$mainInfo.pushed_at).ToString("MM/dd/yyyy HH:mm") } else { "N/A" }

        Clear-Host
        Write-Host "`n  🚀 REPOSITORY STATISTICS" -ForegroundColor Magenta
        Write-Host "  " + ("=" * 45) -ForegroundColor DarkGray
        Write-Host "  📦 Repository : " -NoNewline; Write-Host $repoName -ForegroundColor Cyan
        Write-Host "  " + ("-" * 45) -ForegroundColor DarkGray

        $stats = @(
            @{ Icon = "⭐"; Label = "Stars       "; Value = $mainInfo.stargazers_count; Color = "Yellow" }
            @{ Icon = "🍴"; Label = "Forks       "; Value = $mainInfo.forks_count; Color = "Blue" }
            @{ Icon = "🐞"; Label = "Open Issues "; Value = $actualIssues; Color = "Red" }
            @{ Icon = "🔀"; Label = "Open PRs    "; Value = $prCount; Color = "Green" }
            @{ Icon = "👥"; Label = "Clones (14d)"; Value = "$($trafficClones.count) ($($trafficClones.uniques) unique)"; Color = "Magenta"}
            @{ Icon = "👀"; Label = "Views (14d) "; Value = "$($trafficViews.count) ($($trafficViews.uniques) unique)"; Color = "Green" }
            @{ Icon = "📅"; Label = "Last Push   "; Value = $lastPush; Color = "Cyan" }
        )

        foreach ($s in $stats) {
            Write-Host "  $($s.Icon) $($s.Label) : " -NoNewline
            Write-Host $s.Value -ForegroundColor $s.Color
        }
        Write-Host "`n  💡 Tip: Use 'rs -View' to browse Issues/PRs" -ForegroundColor DarkGray
        Write-Host "  " + ("=" * 45) -ForegroundColor DarkGray

    } catch {
        Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Set-TerminalScheme {
    $wtPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

    if (-not (Test-Path $wtPath)) {
        $wtPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    }

    if (-not (Test-Path $wtPath)) {
        Write-Host "  ❌ settings.json not found!" -ForegroundColor Red
        return
    }

    try {
        $rawJson = Get-Content $wtPath -Raw
        $cleanJson = $rawJson -replace '(?m)^\s*//.*|(?m)\s//.*', ''
        $settings = $cleanJson | ConvertFrom-Json
        
        $schemes = $settings.schemes
        if (-not $schemes) { 
            Write-Host "  󰅚 No schemes defined in your settings.json" -ForegroundColor Yellow
            return 
        }

        $selectedName = $schemes | ForEach-Object { "$($_.name.PadRight(20)) │ BG: $($_.background) FG: $($_.foreground)" } | 
            fzf --reverse --height 45% `
                --header "📺 SELECT TERMINAL SCHEME (Enter to Apply)" `
                --border --prompt="🎨 Scheme > " | 
            ForEach-Object { $_.Split('│')[0].Trim() }
        
        if (-not $selectedName) { return }

        $s = $schemes | Where-Object { $_.name -eq $selectedName }

        $osc = [char]27 + "]"
        $bel = [char]7
        
        Write-Host -NoNewline "${osc}10;$($s.foreground)${bel}"
        Write-Host -NoNewline "${osc}11;$($s.background)${bel}"
        Write-Host -NoNewline "${osc}12;$($s.cursorColor)${bel}"

        $ansiColors = @($s.black, $s.red, $s.green, $s.yellow, $s.blue, $s.purple, $s.cyan, $s.white)
        for ($i = 0; $i -lt $ansiColors.Count; $i++) {
            if ($ansiColors[$i]) { Write-Host -NoNewline "${osc}4;$i;$($ansiColors[$i])${bel}" }
        }

        $settings.profiles.defaults.colorScheme = $selectedName

        $psProfile = $settings.profiles.list | Where-Object { $_.name -match "PowerShell" }
        if ($psProfile) {
            foreach ($p in $psProfile) { $p.colorScheme = $selectedName }
        }

        $settings | ConvertTo-Json -Depth 100 | Set-Content $wtPath

        [Environment]::SetEnvironmentVariable("TERM_SCHEME_NAME", $selectedName, "User")
        
        Write-Host "`n  🎨 Scheme '$selectedName' applied!" -ForegroundColor Cyan
        Write-Host "  󰄬  Current session updated via OSC sequences." -ForegroundColor DarkGray
        Write-Host "  󰄬  Settings.json updated for future sessions." -ForegroundColor DarkGray

    } catch {
        Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Tip: Check if your settings.json has trailing commas or syntax errors." -ForegroundColor DarkYellow
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
        if (-not (Test-Path $Target)) {
            Write-Host "  ❌ Target '$Target' not found." -ForegroundColor Red
            return
        }

        $fullPath = (Resolve-Path $Target).Path
        $isDir = Test-Path $fullPath -PathType Container
        $type = if ($isDir) { "DIRECTORY" } else { "FILE" }

        Write-Host "`n  ⚠️  DANGER: PERMANENT OBLITERATION" -ForegroundColor Black -BackgroundColor Yellow
        Write-Host "  Type: " -NoNewline -ForegroundColor Gray
        Write-Host $type -NoNewline -ForegroundColor White
        Write-Host " | Path: " -NoNewline -ForegroundColor Gray
        Write-Host $fullPath -ForegroundColor Cyan
        
        $confirm = Read-Host "     Type 'y' to vaporize this item"
        if ($confirm -ne "y") { Write-Host "  󰜺  Zap aborted." -ForegroundColor Gray; return }

        Write-Host "`n  󰆴  Initiating Atomic Delete..." -ForegroundColor Magenta
        Write-Host "  " + ("─" * 45) -ForegroundColor DarkGray

        try {
            if ($isDir) {
                Write-Host "  󰛓  Stripping attributes..." -ForegroundColor DarkGray
                cmd /c "attrib -r -s -h `"$fullPath`" /s /d" 2>$null
                Write-Host "  󰆴  Executing RD /S /Q..." -ForegroundColor Cyan
                cmd /c "rd /s /q `"$fullPath`"" 2>$null
            } else {
                Write-Host "  󰆴  Deleting file..." -ForegroundColor DarkGray
                Set-ItemProperty -Path $fullPath -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue
                Remove-Item -Path $fullPath -Force -ErrorAction Stop
            }

            if (-not (Test-Path $fullPath)) {
                Write-Host "  ✅ ZAP! Successfully obliterated.`n" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Error: Access Denied or File Locked by another process.`n" -ForegroundColor Red
            }

        } catch {
            Write-Host "  ❌ Critical Failure: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Invoke-QuickSearch {
    param([string]$query = "")
    
    Write-Host "`n  🔍  FAST FINDER" -ForegroundColor Magenta
    Write-Host "  " + ("─" * 45) -ForegroundColor DarkGray
    Write-Host "  (Enter: Open Code | Ctrl+C: Copy Path | Ctrl+G: Go to folder)`n" -ForegroundColor Gray

    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $files = fd --type f --exclude .git --exclude node_modules --exclude .venv $query
    } else {
        $files = where.exe /r . * | Where-Object { $_ -notmatch '\\\.git|\\\.venv|\\node_modules' }
    }

    if (-not $files) {
        Write-Host "  ❌ No files matching '$query' found." -ForegroundColor Red
        return
    }

    $result = $files | fzf --query "$query" `
        --reverse `
        --header="[Enter: VS Code | Ctrl-C: Copy | Ctrl-G: CD | Esc: Exit]" `
        --preview="bat --color=always --style=numbers --line-range :500 {}" `
        --expect="ctrl-c,ctrl-g" `
        --border="rounded" `
        --info="inline"

    if (-not $result) { return }

    $key = $result[0]
    $selection = $result[1].Trim()

    if ($selection) {
        switch ($key) {
            "ctrl-c" { 
                $selection | clip
                Write-Host "  ✅ Path copied: " -NoNewline -ForegroundColor Green
                Write-Host $selection -ForegroundColor White
            }
            "ctrl-g" { 
                $dir = Split-Path $selection
                Set-Location $dir
                Write-Host "  📂 Navigated to: " -NoNewline -ForegroundColor Cyan
                Write-Host $dir -ForegroundColor White
            }
            default { 
                code $selection
                Write-Host "  📄 Opening in VS Code: " -NoNewline -ForegroundColor Blue
                Write-Host (Split-Path $selection -Leaf) -ForegroundColor White
            }
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
    Write-Host "  " + ("─" * 60) -ForegroundColor DarkGray

    Write-Host ("  {0,-25} {1,-15} {2,-10}" -f "REPOSITORY", "BRANCH", "STATUS") -ForegroundColor Gray
    Write-Host "  " + ("-" * 60) -ForegroundColor DarkGray

    Get-ChildItem -Directory | ForEach-Object {
        $repoPath = $_.FullName
        $dotGit = Join-Path $repoPath ".git"
        
        if (Test-Path $dotGit) {
            $branch = git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null
            if (-not $branch) { $branch = "DETACHED" }
            $statusRaw = git -C $repoPath status --porcelain 2>$null
            $counts = git -C $repoPath rev-list --left-right --count HEAD...@{u} 2>$null
            $ahead = 0; $behind = 0
            if ($counts -match "(\d+)\s+(\d+)") {
                $ahead = $Matches[1]
                $behind = $Matches[2]
            }

            $color = "Green"
            $icon = "󰄬"
            $msg = "Clean"

            if ($statusRaw) {
                $color = "Yellow"
                $icon = "󱓻"
                $msg = "Modified"
            }

            if ($ahead -gt 0) { 
                $msg += " (↑$ahead)"
                $color = "Cyan"
            }
            if ($behind -gt 0) { 
                $msg += " (↓$behind)"
                $color = "Red"
                $icon = "󰚰"
            }

            Write-Host "  $icon  " -NoNewline -ForegroundColor $color
            Write-Host "{0,-22}" -f $_.Name -NoNewline -ForegroundColor White
            Write-Host " {0,-15}" -f "[$branch]" -NoNewline -ForegroundColor Gray
            Write-Host " $msg" -ForegroundColor $color
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

function Get-InstallHistory {
    Clear-Host
    Write-Host "`n    EXTENDED INSTALLATION HISTORY (Last 7 Days)" -ForegroundColor Magenta
    Write-Host ("  " + ("─" * 145)) -ForegroundColor DarkGray
    
    $limitDate = (Get-Date).AddDays(-7)
    $foundAny  = $false

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $regApps = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue | 
        Where-Object { $_.InstallDate -ne $null -and $_.DisplayName -ne $null } | 
        ForEach-Object {
            try {
                $name = $_.DisplayName
                if ($name -match "\{\{.+?\}\}") { $name = "NVIDIA Component (Internal Name)" }
                
                $cleanDate = [DateTime]::ParseExact($_.InstallDate, "yyyyMMdd", $null)
                if ($cleanDate -ge $limitDate) {
                    [PSCustomObject]@{
                        DisplayName = $name
                        Version     = $_.DisplayVersion
                        Publisher   = $_.Publisher
                        Date        = $cleanDate
                        Source      = 'Registry'
                        Details     = "Standard Setup"
                    }
                }
            } catch { $null }
        }

    $msiEvents = Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        ID        = 19, 4371 
        StartTime = $limitDate
    } -ErrorAction SilentlyContinue | ForEach-Object {
        $msg = $_.Message
        $name = if ($msg -match "'(.+?)'") { $Matches[1] } else { "System Component" }
        
        $shortDetail = "Event ID: $($_.Id)"
        if ($msg -match "HRESULT:\s*(0x[0-9A-Fa-f]+|.+?)\.") { $shortDetail = "Res: $($Matches[1])" }
        elseif ($msg -match "Estado:\s*(.+?)\.") { $shortDetail = "$($Matches[1])" }
        elseif ($msg -match "temporizador:\s*(.+?)\.") { $shortDetail = "Timer Change" }

        [PSCustomObject]@{
            DisplayName = $name
            Version     = "N/A"
            Publisher   = "Microsoft/Kernel"
            Date        = $_.TimeCreated
            Source      = 'EventLog'
            Details     = $shortDetail
        }
    }

    $allHistory = ($regApps + $msiEvents) | 
        Sort-Object Date -Descending | 
        Group-Object DisplayName | 
        ForEach-Object { $_.Group[0] }

    if ($allHistory) {
        Write-Host ("    {0,-40} │ {1,-12} │ {2,-18} │ {3,-15} │ {4}" -f "APPLICATION", "VERSION", "PUBLISHER", "DATE / TIME", "DETAILS") -ForegroundColor DarkCyan
        Write-Host ("    " + ("─" * 140)) -ForegroundColor DarkGray

        foreach ($app in $allHistory) {
            $foundAny = $true
            $dateStr = if ($app.Source -eq 'EventLog') { $app.Date.ToString("dd/MM HH:mm") } else { $app.Date.ToString("dd/MM/yyyy") }

            $displayNm = if ($app.DisplayName.Length -gt 38) { $app.DisplayName.Substring(0, 35) + "..." } else { $app.DisplayName }
            $version   = if ($app.Version -and $app.Version.Length -gt 10) { $app.Version.Substring(0, 9) + ".." } else { $app.Version }
            $publisher = if ($app.Publisher -and $app.Publisher.Length -gt 16) { $app.Publisher.Substring(0, 14) + ".." } else { $app.Publisher }
            $details   = if ($app.Details.Length -gt 40) { $app.Details.Substring(0, 37) + "..." } else { $app.Details }

            Write-Host "    " -NoNewline
            Write-Host ("{0,-38} " -f $displayNm) -ForegroundColor White -NoNewline
            Write-Host " │ " -ForegroundColor DarkGray -NoNewline
            Write-Host ("{0,-10} " -f ($version ?? "---")) -ForegroundColor Gray -NoNewline
            Write-Host " │ " -ForegroundColor DarkGray -NoNewline
            Write-Host ("{0,-16} " -f ($publisher ?? "Unknown")) -ForegroundColor Blue -NoNewline
            Write-Host " │ " -ForegroundColor DarkGray -NoNewline
            Write-Host ("{0,-13} " -f $dateStr) -ForegroundColor Yellow -NoNewline
            Write-Host " │ " -ForegroundColor DarkGray -NoNewline
            
            if ($app.Source -eq 'Registry') {
                Write-Host ("{0,-38} " -f $details) -ForegroundColor DarkGreen -NoNewline
                Write-Host "󰘙" -ForegroundColor Green
            } else {
                Write-Host ("{0,-38} " -f $details) -ForegroundColor Cyan -NoNewline
                Write-Host "󱑤" -ForegroundColor Cyan
            }
            Write-Host "" # Salto de línea limpio
        }
    }

    if (-not $foundAny) {
        Write-Host "    No installation activity detected in the last 7 days." -ForegroundColor Gray
    }

    Write-Host ("  " + ("─" * 145)) -ForegroundColor DarkGray
    Write-Host ""
}

function help-system {
    Clear-Host
    Write-Host "`n  󰞷  TERMINAL COMMAND CENTER - USER GUIDE" -ForegroundColor Magenta
    Write-Host "  " + ("=" * 85) -ForegroundColor DarkGray

    function Out-Cmd ($List) {
        Write-Host ("    {0,-8} │ {1,-18} │ {2}" -f "ALIAS", "FUNCTION", "DESCRIPTION") -ForegroundColor DarkCyan
        Write-Host ("    " + ("─" * 81)) -ForegroundColor DarkGray

        foreach ($c in $List) {
            Write-Host "    $($c.A.PadRight(8))" -ForegroundColor Yellow -NoNewline
            Write-Host " │ " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($c.C.PadRight(18))" -ForegroundColor Green -NoNewline
            Write-Host " │ " -ForegroundColor DarkGray -NoNewline
            Write-Host $c.D -ForegroundColor White
        }
    }

    Write-Host "`n  󰙅  NAVIGATION & SEARCH" -ForegroundColor Cyan
    Write-Host ""
    Out-Cmd @(
        @{ A="..";    C="up";              D="Go up 'n' levels (smart root detection)" },
        @{ A="find";  C="Invoke-QuickSearch";D="Instant find & Action (Code/CD/Clip)" },
        @{ A="ff";    C="Invoke-FuzzyOpen"; D="Fuzzy find and open file in VS Code" },
        @{ A="fp";    C="find-text";       D="Search text inside files (Ripgrep)" },
        @{ A="zap";   C="Invoke-Zap";      D="Atomic Delete: Nuclear wipe of targets" },
        @{ A="mcd";   C="mcd";             D="Create and enter directory (recursive)" }
    )

    Write-Host "`n  󰊢  DEVELOPMENT ARCHITECT" -ForegroundColor Blue
    Write-Host ""
    Out-Cmd @(
        @{ A="gs";    C="Get-GitStatusSum"; D="Git Dashboard: Status, Branch & Sync" },
        @{ A="va";    C="activate";        D="Python: Auto-activate venv (Scripts/bin)" },
        @{ A="extr";  C="Set-ExtractFile";  D="Smart Extract: Unpack to auto-folder" },
        @{ A="newp";  C="New-Project";     D="Scaffolding: Generate project structures" },
        @{ A="rs";    C="Get-RepoStats";    D="GitHub: Repository issues and PR stats" }
    )

    Write-Host "`n  󰘚  SYSTEM & MONITORING" -ForegroundColor Yellow
    Write-Host ""
    Out-Cmd @(
        @{ A="di";    C="diskinfo";        D="Storage: Visual health bar and usage %" },
        @{ A="pv";    C="Show-ProcessVis";  D="Monitor: Interactive top process viewer" },
        @{ A="ports"; C="Get-NetworkPorts"; D="Network: Show all listening TCP ports" },
        @{ A="st";    C="Set-TerminalSch";  D="Theme: Live preview and set scheme" },
        @{ A="wup";   C="Check-WingetVis";  D="Updates: Visual scanner for pending apps" },
        @{ A="uptime";C="uptime";           D="System: Boot time and active duration" }
    )

    Write-Host "`n  󰠵  MAINTENANCE & TOOLS" -ForegroundColor Green
    Write-Host ""
    Out-Cmd @(
        @{ A="us/uw";   C="Update-Scoop/W";    D="Silent update for Scoop and WinGet" },
        @{ A="hi";      C="Get-InstallHist";   D="Timeline: Software installed in last 7 days" },
        @{ A="psv";     C="Show-ProcessVisual"; D="Real-time CPU/RAM monitor (Live)" },
        @{ A="cv";      C="Show-CsvVisual";    D="CSV: Auto-delim. [ > 50 rows -> GridView ]" },
        @{ A="lv";      C="Show-LogVisual";    D="Log: [-Lines n] [-Wait] for Live Tail" },
        @{ A="jv";      C="Show-JsonVisual";   D="JSON: [-MaxDepth n] Tree structure viewer" },
        @{ A="kill";    C="Invoke-KillProc";   D="Sniper: Select and kill process via FZF" },
        @{ A="rmmodf";  C="Remove-ModuleFzf";  D="FZF Uninstaller: Select & Remove Modules" },
        @{ A="ed";      C="edit-fast";         D="FZF Editor: Quick open files in Code" },
        @{ A="whereis"; C="Get-InstallMeth";   D="Source: Find app installation path" }
    )

    Write-Host "`n  󰌌  GLOBAL HOTKEYS (FZF)" -ForegroundColor Magenta
    Write-Host ""
    Write-Host ("    " + ("─" * 81)) -ForegroundColor DarkGray
    Write-Host "    Ctrl + T │ Quick file search   │ Ctrl + G │ Folder History (Zoxide)" -ForegroundColor White
    Write-Host "    Ctrl + R │ Smart History       │ Ctrl + L │ Clear & Refresh UI" -ForegroundColor White

    Write-Host "`n  Type 'h' or 'help' to show this guide again.`n" -ForegroundColor DarkGray
}

function welcome {
    Clear-Host
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

    $osInfo = Get-CimInstance Win32_OperatingSystem
    $cpuInfo = Get-CimInstance Win32_Processor
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $gpuList = (Get-CimInstance Win32_VideoController).Name | Where-Object { $_ -notmatch "Virtual|Meta" }

    $totalRam = [Math]::Round($osInfo.TotalVisibleMemorySize / 1MB, 0)
    $freeRam = [Math]::Round($osInfo.FreePhysicalMemory / 1MB, 1)
    $usedRam = $totalRam - $freeRam
    $percentRam = [Math]::Round(($usedRam / $totalRam) * 100, 0)

    $diskFree = [Math]::Round($disk.FreeSpace / 1GB, 1)
    $diskTotal = [Math]::Round($disk.Size / 1GB, 0)

    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $totalThemes = 0
    if (Test-Path $settingsPath) {
        $raw = Get-Content $settingsPath -Raw
        $clean = $raw -replace '(?m)^\s*//.*|(?m)\s//.*', '' # Limpieza de comentarios
        $totalThemes = ($clean | ConvertFrom-Json).schemes.Count
    }

    $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Wi-Fi", "Ethernet" | Select-Object -First 1).IPAddress
    $wslStatusRaw = if (Get-Process "wslhost" -ErrorAction SilentlyContinue) { "Running" } else { "Stopped" }
    $uptimeObj = (Get-Date) - $osInfo.LastBootUpTime
    $uptimeStr = "$($uptimeObj.Days)d $($uptimeObj.Hours)h $($uptimeObj.Minutes)m"

    Add-Type -AssemblyName System.Windows.Forms
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $wmiMonitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams
    $displayInfo = @()
    for ($i = 0; $i -lt $screens.Count; $i++) {
        $res = "$($screens[$i].Bounds.Width)x$($screens[$i].Bounds.Height)"
        if ($wmiMonitors[$i].InstanceName -match 'DISPLAY\\(?<model>[^\\]+)\\') { 
            $model = $Matches['model'] 
        } else { 
            $model = "Display" 
        }
        $displayInfo += "$model ($res)"
    }
    $displayStr = $displayInfo -join " | "

    $weatherClean = "N/A"
    if ($global:canConnectToGithub) {
        try {
            $weatherRaw = curl.exe -s "wttr.in?format=%t" --connect-timeout 1
            if ($weatherRaw -and $weatherRaw -notmatch "HTML") { $weatherClean = $weatherRaw.Trim() }
        } catch {}
    }

    $currentScheme = [Environment]::GetEnvironmentVariable("TERM_SCHEME_NAME", "User") ?? "Default"
    
    $bannerStyles = @(
        @'
    .---.  .---. .-.      .---.  .---. .-.  .-. .---. 
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
     |  KERNEL  : $SHELL                          |
    \==========/----------------------------------\==========/
'@
    )

    $replacements = @{
        '$USER'   = $env:USERNAME.ToUpper().PadRight(8).Substring(0,8)
        '$HOST'   = $env:COMPUTERNAME.ToUpper().PadRight(7).Substring(0,7)
        '$IP'     = $ip.PadRight(13).Substring(0,13)
        '$WSL'    = $wslStatusRaw.ToUpper().PadRight(5).Substring(0,5)
        '$UPTIME' = $uptimeStr.PadRight(20)
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

    Write-Host "`n    $($env:USERNAME)@$($env:COMPUTERNAME)" -ForegroundColor Cyan
    Write-Host "    " + ("─" * 45) -ForegroundColor DarkGray

    $barFill = [Math]::Max(0, [Math]::Min(10, [int]($percentRam / 10)))
    $bar = ("█" * $barFill) + ("░" * (10 - $barFill))

    $infoLayout = @(
        @{ Label = "    OS      "; Value = $osInfo.Caption.Replace("Microsoft ", ""); Color = "White" }
        @{ Label = "    CPU     "; Value = $cpuInfo.Name.Trim(); Color = "Cyan" }
        @{ Label = "  󰢮  GPU     "; Value = ($gpuList -join ", "); Color = "Green" }
        @{ Label = "  󰍹  Displays"; Value = $displayStr; Color = "Red" }
        @{ Label = "    RAM     "; Value = "[$bar] $usedRam GB / $totalRam GB ($percentRam%)"; Color = "Yellow" }
        @{ Label = "  󰋊  Disk (C)"; Value = "$diskFree GB Free / $diskTotal GB Total"; Color = "Cyan" }
        @{ Label = "  󰩟  Local IP"; Value = $ip; Color = "Green" }
        @{ Label = "  󱑍  Uptime  "; Value = $uptimeStr; Color = "Magenta" }
        @{ Label = "    Shell   "; Value = "pwsh $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"; Color = "Blue" }
        @{ Label = "    Weather "; Value = $weatherClean; Color = "White" }
        @{ Label = "  󰟈 WSL      "; Value = "󰟈 $wslStatusRaw"; Color = "Cyan" }
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
    Write-Host "`n    Type 'help' or 'h' anytime to see help menu.`n" -ForegroundColor DarkGray
}

function Get-WezKeybinds {
    $sep = "  " + ("─" * 68)
    
    Clear-Host
    Write-Host "`n  󱊖  WEZTERM SHORTCUTS GUIDE" -ForegroundColor Magenta
    Write-Host $sep -ForegroundColor DarkGray

    function Out-Key ($K, $M, $D) {
        Write-Host "    " -NoNewline
        Write-Host "[" -NoNewline -ForegroundColor DarkGray
        Write-Host $M -NoNewline -ForegroundColor Yellow
        Write-Host " + " -NoNewline -ForegroundColor DarkGray
        Write-Host "$K]" -NoNewline -ForegroundColor Cyan

        $currentLength = ($M + $K + 7).Length
        $pad = " " * ([Math]::Max(1, (28 - $currentLength)))
        
        Write-Host $pad -NoNewline
        Write-Host " │ " -NoNewline -ForegroundColor DarkGray
        Write-Host $D -ForegroundColor White
    }

    Write-Host "`n  󰝤  PANELS & SPLITS" -ForegroundColor Cyan
    Write-Host $sep -ForegroundColor DarkGray
    Out-Key "D"          "ALT+SHIFT"  "Split Horizontal"
    Out-Key "S"          "ALT+SHIFT"  "Split Vertical"
    Out-Key "Z"          "CTRL+SHIFT" "Toggle Zoom (Maximize Pane)"
    Out-Key "Q"          "CTRL+SHIFT" "Close Current Pane"
    Out-Key "B"          "CTRL"       "Rotate Panes (CCW)"

    Write-Host "`n  󰜂  NAVIGATION" -ForegroundColor Green
    Write-Host $sep -ForegroundColor DarkGray
    Out-Key "Arrows"     "ALT"        "Activate Pane (Direction)"
    Out-Key "L/R Arrow"  "ALT+SHIFT"  "Switch Tab (Prev/Next)"
    Out-Key "N"          "ALT"        "Show Tab Navigator"
    Out-Key "L"          "ALT"        "Show Launcher (Workspaces)"

    Write-Host "`n  󰩨  PANE RESIZING" -ForegroundColor Blue
    Write-Host $sep -ForegroundColor DarkGray
    Out-Key "Arrows"     "CTRL+ALT"   "Adjust Pane Size (5 units)"

    Write-Host "`n  󰓩  SYSTEM & TABS" -ForegroundColor Yellow
    Write-Host $sep -ForegroundColor DarkGray
    Out-Key "T"          "ALT+SHIFT"  "New Tab (Current Domain)"
    Out-Key "F"          "CTRL+SHIFT" "Toggle FullScreen"

    Write-Host "`n  󰋚  Tip: Use 'ALT+N' for a visual tab overview." -ForegroundColor DarkGray
    Write-Host $sep -ForegroundColor DarkGray
    Write-Host ""
}

function Check-WingetVisual {
    Write-Host "`n 󰚰  Scanning for Winget updates..." -ForegroundColor Magenta

    $raw = winget upgrade | Where-Object { $_ -match '\S' -and $_ -notmatch 'Loading|Cargando|\[.*\]' }

    if (-not $raw) {
        Write-Host " ✅ All systems operational. No updates found." -ForegroundColor Green
        return
    }

    $headerLine = ""
    $dividerLine = ""
    $dataStart = 0

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

    $posSource    = $headerLine.IndexOf("Origen")
    if ($posSource -lt 0) { $posSource = $headerLine.IndexOf("Source") }

    Write-Host "`n   UPDATES AVAILABLE:" -ForegroundColor Cyan
    $separator = "─" * 125 # Ajustado a un ancho de consola estándar
    Write-Host " $separator" -ForegroundColor DarkGray
    Write-Host ("   {0,-30} │ {1,-15} │ {2,-15} │ {3}" -f "APPLICATION", "CURRENT", "LATEST", "UPDATE COMMAND") -ForegroundColor White
    Write-Host " $separator" -ForegroundColor DarkGray

    $count = 0
    $raw | Select-Object -Skip $dataStart | ForEach-Object {
        $line = $_
        if ($line -match "actualizaciones disponibles" -or $line -match "updates available") { return }
        if ($line.Trim().Length -lt 10) { return }

        try {
            $name    = $line.Substring(0, $posId).Trim()
            $id      = $line.Substring($posId, ($posVersion - $posId)).Trim()
            $current = $line.Substring($posVersion, ($posAvailable - $posVersion)).Trim()

            $endOfAvailable = if ($posSource -gt $posAvailable) { ($posSource - $posAvailable) } else { -1 }
            if ($endOfAvailable -gt 0) {
                $latest = $line.Substring($posAvailable, $endOfAvailable).Trim().Split(' ')[0]
            } else {
                $latest = $line.Substring($posAvailable).Trim().Split(' ')[0]
            }

            $commandId = $id -replace '…', '*' -replace '\.\.\.', '*'
            $dispName = if ($name.Length -gt 28) { $name.Substring(0, 27) + "…" } else { $name }

            Write-Host " 󰏗 " -NoNewline -ForegroundColor Yellow
            Write-Host (" {0,-28} " -f $dispName) -NoNewline -ForegroundColor White
            Write-Host "│ " -NoNewline -ForegroundColor DarkGray
            Write-Host (" {0,-14} " -f $current) -NoNewline -ForegroundColor Gray
            Write-Host "➜ " -NoNewline -ForegroundColor Magenta
            Write-Host (" {0,-14} " -f $latest) -NoNewline -ForegroundColor Green
            Write-Host "│ " -NoNewline -ForegroundColor DarkGray
            Write-Host "winget upgrade --id " -NoNewline -ForegroundColor DarkCyan
            Write-Host $commandId -ForegroundColor Cyan
            
            $count++
        } catch { }
    }

    Write-Host " $separator" -ForegroundColor DarkGray
    Write-Host " 💡 Total: $count updates found. Run 'uw' to update all." -ForegroundColor Gray
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
        [string]$Path,
        [Parameter(Mandatory=$false)]
        [int]$MaxDepth = 4
    )

    try {
        $fullPath = Resolve-Path $Path
        $data = Get-Content $fullPath -Raw | ConvertFrom-Json
    } catch {
        Write-Host "  ❌ Error: Invalid JSON or file not found." -ForegroundColor Red
        return
    }

    $fileName = Split-Path $fullPath -Leaf
    Write-Host "`n  󰘦  JSON STRUCTURE: $fileName" -ForegroundColor Magenta
    Write-Host ("  " + ("─" * 60)) -ForegroundColor DarkGray

    function Invoke-DrawNode {
        param($Object, $Indent = "", $CurrentDepth = 0)

        if ($CurrentDepth -gt $MaxDepth) {
            Write-Host " [...] (Max Depth Reached)" -ForegroundColor DarkGray
            return
        }

        if ($Object -is [PSCustomObject] -or $Object -is [System.Collections.IDictionary]) {
            $props = $Object | Get-Member -MemberType NoteProperty, Property
            $count = $props.Count
            $i = 0

            foreach ($p in $props) {
                $i++
                $isLast = ($i -eq $count)
                $connector = if ($isLast) { "└── " } else { "├── " }
                
                Write-Host "$Indent$connector" -NoNewline -ForegroundColor DarkGray
                Write-Host "$($p.Name): " -NoNewline -ForegroundColor Cyan
                
                Render-Value -Value $Object.$($p.Name) -Indent $Indent -IsLast $isLast -CurrentDepth $CurrentDepth
            }
        }
        elseif ($Object -is [Array]) {
            $count = $Object.Count
            $limit = if ($count -gt 10) { 10 } else { $count }
            
            for ($j=0; $j -lt $limit; $j++) {
                $isLast = ($j -eq $count -1 -or $j -eq 9)
                $connector = if ($isLast) { "└── " } else { "├── " }
                
                Write-Host "$Indent$connector" -NoNewline -ForegroundColor DarkGray
                Write-Host "[$j] " -NoNewline -ForegroundColor Yellow
                
                Render-Value -Value $Object[$j] -Indent $Indent -IsLast $isLast -CurrentDepth $CurrentDepth
            }
            if ($count -gt 10) {
                $pad = if ($Indent) { $Indent + "    " } else { "    " }
                Write-Host "$pad... and $($count - 10) more items" -ForegroundColor DarkGray
            }
        }
    }

    function Render-Value {
        param($Value, $Indent, $IsLast, $CurrentDepth)

        $extender = "│   "
        if ($IsLast) { $extender = "    " }
        $nextIndent = $Indent + $extender

        if ($null -eq $Value) {
            Write-Host "null" -ForegroundColor DarkRed
        }
        elseif ($Value -is [PSCustomObject] -or $Value -is [Array]) {
            Write-Host "󰅂" -ForegroundColor DarkGray
            Invoke-DrawNode -Object $Value -Indent $nextIndent -CurrentDepth ($CurrentDepth + 1)
        }
        elseif ($Value -is [bool]) {
            $boolColor = if ($Value) { "Green" } else { "Red" }
            Write-Host $Value.ToString().ToLower() -ForegroundColor $boolColor
        }
        elseif ($Value -as [double] -ne $null) {
            Write-Host $Value -ForegroundColor Magenta
        }
        else {
            Write-Host "`"$Value`"" -ForegroundColor White
        }
    }

    Invoke-DrawNode -Object $data
    Write-Host ("  " + ("─" * 60)) -ForegroundColor DarkGray
    Write-Host ""
}

function Show-LogVisual {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path,
        [Parameter(Mandatory=$false)]
        [int]$Lines = 25,
        [Parameter(Mandatory=$false)]
        [switch]$Wait
    )

    if (-not (Test-Path $Path)) { 
        Write-Host "`n  ❌ File not found: $Path" -ForegroundColor Red
        return 
    }

    $fileName = Split-Path $Path -Leaf
    $sep = "  " + ("─" * 75)

    Write-Host "`n    LOG SENTINEL: $fileName" -ForegroundColor Magenta
    if ($Wait) { Write-Host "  👀 Mode: Live Follow (Press Ctrl+C to stop)" -ForegroundColor Yellow }
    else { Write-Host "  📄 Showing last $Lines lines" -ForegroundColor Gray }
    Write-Host $sep -ForegroundColor DarkGray

    $ProcessLine = {
        param($line)
        if ($line -match "ERROR|Critical|Failed|Exception|Error:") { 
            Write-Host "    $line" -ForegroundColor Red 
        }
        elseif ($line -match "WARN|Warning|Alert") { 
            Write-Host "    $line" -ForegroundColor Yellow 
        }
        elseif ($line -match "INFO|Success|Done|Completed") { 
            Write-Host "    $line" -ForegroundColor Cyan 
        }
        elseif ($line -match "\d{2}:\d{2}:\d{2}") {
            Write-Host "  󱑂  $line" -ForegroundColor Gray
        }
        else { 
            Write-Host "     $line" -ForegroundColor DarkGray 
        }
    }

    try {
        if ($Wait) {
            Get-Content $Path -Tail $Lines -Wait | ForEach-Object { & $ProcessLine $_ }
        } else {
            Get-Content $Path -Tail $Lines | ForEach-Object { & $ProcessLine $_ }
            Write-Host $sep -ForegroundColor DarkGray
            Write-Host "  💡 Tip: Use 'slv path -Wait' to follow the log in real-time." -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "`n  Finished reading log." -ForegroundColor Gray
    }
    Write-Host ""
}

function Show-CsvVisual {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Host "  ❌ File not found: $Path" -ForegroundColor Red
        return
    }

    try {
        $fullPath = Resolve-Path $Path
        $fileName = Split-Path $fullPath -Leaf

        $sample = Get-Content $fullPath -TotalCount 2
        $delimiter = ","
        if ($sample -match ";") { $delimiter = ";" }
        elseif ($sample -match "\t") { $delimiter = "`t" }

        $data = Import-Csv $fullPath -Delimiter $delimiter
        $count = ($data | Measure-Object).Count
        $sep = "  " + ("─" * 70)

        Write-Host "`n    CSV EXPLORER: $fileName" -ForegroundColor Cyan
        Write-Host $sep -ForegroundColor DarkGray
        Write-Host "  📊 Records: $count  |  󰉿 Delim: '$delimiter'" -ForegroundColor Gray
        Write-Host $sep -ForegroundColor DarkGray

        if ($count -eq 0) {
            Write-Host "  ⚠️  Empty file." -ForegroundColor Yellow
        }
        elseif ($count -gt 50) {
            Write-Host "  󰆼  Launching Out-GridView..." -ForegroundColor Magenta
            $cmd = "Import-Csv '$fullPath' -Delimiter '$delimiter' | Out-GridView -Title 'CSV: $fileName'"
            Start-Process powershell -ArgumentList "-NoProfile", "-Command", $cmd -WindowStyle Hidden
        }
        else {
            $data | Select-Object * | Format-Table -AutoSize
        }
    }
    catch {
        Write-Host "  ❌ Critical Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    Write-Host ""
}

function Show-ProcessVisual {
    $lineSep = "  " + ("─" * 70)
    
    try {
        while ($true) {
            [Console]::Clear() 
            
            Write-Host "`n    ACTIVE PROCESS MONITOR (Top 10 by CPU)" -ForegroundColor Magenta
            Write-Host $lineSep -ForegroundColor DarkGray

            $cpuCounter = Get-Counter '\Process(*)\% Processor Time' -ErrorAction SilentlyContinue
            $numCores = $env:NUMBER_OF_PROCESSORS
            
            $topProcesses = Get-Process | ForEach-Object {
                $pName = $_.Name
                $cpuVal = 0
                $match = $cpuCounter.CounterSamples | Where-Object { $_.InstanceName -eq $pName } | Select-Object -First 1
                if ($match) { $cpuVal = [Math]::Round($match.CookedValue / $numCores, 1) }
                
                [PSCustomObject]@{
                    Name = if ($pName.Length -gt 22) { $pName.Substring(0, 19) + "..." } else { $pName }
                    CPU  = $cpuVal
                    Mem  = [Math]::Round($_.WorkingSet / 1MB, 1)
                }
            } | Sort-Object CPU -Descending | Select-Object -First 10

            Write-Host ("    {0,-25} │ {1,-8} │ {2,-12} │ {3}" -f "PROCESS", "CPU %", "MEMORY", "RAM BAR") -ForegroundColor DarkCyan
            Write-Host ("    " + ("─" * 66)) -ForegroundColor DarkGray

            foreach ($p in $topProcesses) {
                $cpuColor = if ($p.CPU -gt 20) { "Red" } elseif ($p.CPU -gt 5) { "Yellow" } else { "Gray" }
                $memColor = if ($p.Mem -gt 1024) { "Magenta" } else { "White" }
                $barPoints = [Math]::Min([Math]::Floor($p.Mem / 512), 10)
                $bar = ("█" * $barPoints) + ("░" * (10 - $barPoints))

                Write-Host "   " -NoNewline -ForegroundColor DarkGray
                Write-Host ("{0,-23} " -f $p.Name) -NoNewline -ForegroundColor Cyan
                Write-Host " │ " -NoNewline -ForegroundColor DarkGray
                Write-Host ("{0,6}% " -f $p.CPU) -NoNewline -ForegroundColor $cpuColor
                Write-Host " │ " -NoNewline -ForegroundColor DarkGray
                Write-Host ("{0,8} MB " -f $p.Mem) -NoNewline -ForegroundColor $memColor
                Write-Host " │ " -NoNewline -ForegroundColor DarkGray
                Write-Host "[$bar]" -ForegroundColor DarkGray
            }

            Write-Host $lineSep -ForegroundColor DarkGray
            Write-Host "  [Ctrl+C] Stop  |  Refreshing every 2s..." -ForegroundColor DarkGray
            
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-Host "`n  Monitor closed." -ForegroundColor Gray
    }
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
Set-Alias keys Get-WezKeybinds
Set-Alias hi Get-InstallHistory

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
