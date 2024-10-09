$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

#MODULES
Import-Module Terminal-Icons
Import-Module size
Import-Module -Name FindSearch
Import-Module -Name Microsoft.WinGet.CommandNotFound
Import-Module $env:USERPROFILE\Documents\PowerShell\Scripts\PSScriptAnalyzer\out\PSScriptAnalyzer\1.22.0\PSScriptAnalyzer.psd1


#PROMPT
oh-my-posh init pwsh --config C:\Users\Nooch\Documents\PowerShell\craver.omp.json | Invoke-Expression

#FZF
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+r' -PSReadlineChordReverseHistory 'Ctrl+h'
Set-PsFzfOption -ForegroundColor Green
Set-PsFzfOption -TabExpansion

#READLINE
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionViewStyle ListView
Get-PSReadLineOption -ShowToolTips TRUE
Set-PSReadlineOption -Color @{
    "Command" = [ConsoleColor]::Blue
    "Parameter" = [ConsoleColor]::DarkBlue
    "Operator" = [ConsoleColor]::Magenta
    "Variable" = [ConsoleColor]::White
    "String" = [ConsoleColor]::Yellow
    "Number" = [ConsoleColor]::brightBlue
    "Type" = [ConsoleColor]::Cyan
    "Comment" = [ConsoleColor]::DarkCyan
}

$(Clear-History)
$(Clear-Host)

#UTILITIES
function ll ($command) {
	lsd.exe -l
}
function lr ($command) {
	lsd.exe -Rl
}
function la ($command) {
	lsd.exe -la
}
function sql {
    param(
        [string]$db
    )
    Write-Host "Ejecutando el script de python para mostrar la base de datos: $db" -ForegroundColor Green
    python $env:USERPROFILE\Documents\PowerShell\Scripts\.\sql.py $db
}
function lra ($command) {
	lsd.exe -RlA
}
function psc ($command) {
	cd $env:USERPROFILE\Documents\PowerShell
}
function pscs ($command) {
	cd $env:USERPROFILE\Documents\PowerShell\Scripts
}
function off ($command) {
	shutdown /s /t 0
}
function reboot ($command) {
	shutdown /r /t 0
}
function kali ($command) {
	wsl -d kali-linux
}
function reload ($command) {
	$(& $PROFILE)
}
function updateposh ($command) {
	winget upgrade JanDeDobbeleer.OhMyPosh -s winget
}
function ctt ($command) {
	iwr -useb https://christitus.com/win | iex
}

function Convert-MarkdownToText{
    param(
        [string]$markdownText
    )
    
    # Reemplazar encabezados Markdown por texto plano
    $text = $markdownText -replace "###? ", ""           # Remover encabezados con #
    $text = $text -replace "\*\*(.+?)\*\*", '$1'          # Quitar negritas **texto**
    $text = $text -replace "- ", "* "                     # Cambiar guiones por viñetas *
    $text = $text -replace "<.*?>", ""                    # Eliminar etiquetas HTML como <details>
    
    return $text
}

function update-powershell {
    if (-not $global:canConnectToGitHub) {
        Write-Host "Skipping PowerShell update check due to Github.com not responding within 1 second" -ForegroundColor Yellow
        return
    }

    try {
        Write-Host "Checking for PowerShell updates..."
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases"
        $latestReleasesInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        
        # Filtrando para incluir pre-releases y releases normales
        $latestRelease = $latestReleasesInfo | Where-Object { $_.prerelease -eq $true } | Select-Object -First 1
        
        # Si no se encuentran pre-releases, seleccionar el release normal
        if (-not $latestRelease) {
            $latestRelease = $latestReleasesInfo | Where-Object { $_.prerelease -eq $false } | Select-Object -First 1
        }

        $latestVersion = $latestRelease.tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            # Mostrar las notas de actualización
            $releaseNotes = Convert-MarkdownToText -markdownText $latestRelease.body
            Write-Host "New PowerShell version $latestVersion is available. Release notes:" -ForegroundColor Yellow
            Write-Host $releaseNotes -ForegroundColor Cyan

            # Pedir confirmación antes de instalar
            $confirmUpdate = Read-Host "Do you want to update to version $latestVersion? (y/n)"
            if ($confirmUpdate -eq 'y') {
                Write-Host "Updating PowerShell to version $latestVersion..." -ForegroundColor Yellow
                winget install "Microsoft.PowerShell.preview" --accept-source-agreements --accept-package-agreements
                Write-Host "PowerShell has been updated to version $latestVersion. Please restart your shell to reflect changes" -ForegroundColor Magenta
            } else {
                Write-Host "Update cancelled by user." -ForegroundColor Red
            }
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}

function Invoke-Fzf {
    $selectitem = & 'fzf' --reverse --preview-window=up:50% --preview='bat --color=always --style=numbers {1}'
    if ($selectitem) {
        Set-Clipboard -Value $selectitem
    }
}
Set-PSReadLineKeyHandler -Key 'Ctrl+t' -ScriptBlock { Invoke-Fzf }

function mkcd {
    param($dir)
    mkdir $dir
    cd $dir
}

function info {
	& $env:USERPROFILE\Documents\PowerShell\Scripts\.\SysInfo.ps1
}

function uptime {
    $bootuptime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    $CurrentDate = Get-Date
    $uptime = $CurrentDate - $bootuptime
    #Windows Powershell only
        net statistics workstation | Select-String "since" | foreach-object {$_.ToString().Replace('Statistics since ', 'Last Reboot: ')}
    Write-Output "Uptime: Days: $($uptime.days), Hours: $($uptime.Hours), Minutes:$($uptime.Minutes), Seconds:$($uptime.Seconds)"
    Remove-Variable bootuptime
    Remove-Variable CurrentDate
    Remove-Variable uptime
}

function ep {code $PROFILE}

function comparar ($command) {
	& $env:USERPROFILE\Documents\PowerShell\Scripts\.\compare_files.ps1
}

Set-PSReadLineKeyHandler -Key 'alt+Ctrl+Shift+a' -ScriptBlock { & .\app\Scripts\activate; Write-Host "Activado el entorno virtual presiona ctrl + l para actualizar la shell" -ForegroundColor Green}
Set-PSReadLineKeyHandler -Key 'alt+Ctrl+Shift+d' -ScriptBlock { & cd .\app\Scripts\ & deactivate; Write-Host "Desactivado el entorno virtual presiona ctrl + l para actualizar la shell" -ForegroundColor Green}
Set-PSReadLineKeyHandler -Key 'alt+ctrl+shift+c' -ScriptBlock { & python -m venv app;  & .\app\Scripts\activate; Write-Host "Entorno virtual creado y activado presiona ctrl + l para actualizar la shell" -ForegroundColor Green}

#ALIAS
Set-Alias ls lsd
Set-Alias cat bat
Set-Alias net netsh
Set-Alias nets netstat
Set-Alias mcat mdcat
Set-Alias touch New-Item
Set-Alias g git
Set-Alias grep findstr
Set-Alias wr Invoke-WebRequest
Set-Alias installm Install-Module
Set-Alias importm Import-Module
Set-Alias py python
Set-Alias iscript Invoke-ScriptAnalyzer


#AI
Import-Module -Name PSReadLine
Set-PSReadLineKeyHandler -Key 'Ctrl+*' -ScriptBlock {
	$prompt = Read-Host "Enter the prompt"
	& $env:USERPROFILE\Documents\PowerShell\Scripts\Ai.ps1 $prompt
}
Set-Alias ollamauninstall $env:USERPROFILE\Documents\PowerShell\Scripts\.\uninstall_ai.ps1

Invoke-Expression (& { (zoxide init powershell | Out-String) })
