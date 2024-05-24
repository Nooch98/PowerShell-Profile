$canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1

#MODULES
Import-Module Terminal-Icons
Import-Module size
Import-Module -Name FindSearch


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
	cd $emv:USERPROFILE\Documents\PowerShell
}
function pscs ($command) {
	cd $emv:USERPROFILE\Documents\PowerShell\Scripts
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

function update-powershell {
	if (-not $global:canConnectToGitHub) {
		Write-Host "Skipping PowerShell update check due to Github.com not responding within 1 second" -ForegroundColor Yellow
		return
	}

	try {
		Write-Host "Cheking for PowerShell updates..."
		$updateNeeded = $false
		$currentversion = $PSVersionTable.PSVersion.ToString()
		$gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
		$latestReleaseinfo = Invoke-RestMethod -Uri $gitHubApiUrl
		$latestversion = $latestReleaseinfo.tag_name.Trim('v')
		if ($currentversion -lt $latestversion) {
			$updateNeeded = $true
		}

		if ($updateNeeded) {
			Write-Host "Updating PowerShell..." -ForegroundColor Yellow
			winget "Microsoft.PowerShell" --acept-source-agreements --acept-package-agreements
			Write-Host "PowerShell has ben updated. please restart your shell to reflect changes" -ForegroundColor Magenta
		} else {
			Write-Host "Your PowerShell is up to date." -ForegroundColor Green
		}
	} catch {
		Write-Error "Failed to update PowerShell. Error: $_"
	}
}
update-powershell

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
Set-Alias iscript I$emv:USERPROFILEnvoke-ScriptAnalyzer

#AI
Import-Module -Name PSReadLine
Set-PSReadLineKeyHandler -Key 'Ctrl+*' -ScriptBlock {
	$prompt = Read-Host "Enter the prompt"
	& $env:USERPROFILE\Documents\PowerShell\Scripts\Ai.ps1 $prompt
}
Set-Alias ollamauninstall $env:USERPROFILE\Documents\PowerShell\Scripts\.\uninstall_ai.ps1

Invoke-Expression (& { (zoxide init powershell | Out-String) })
