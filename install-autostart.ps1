# One-time install: register chromepilot to auto-start at Windows login.
# Idempotent - overwriting the same shortcut is safe.

$ErrorActionPreference = "Stop"

$startup = [Environment]::GetFolderPath('Startup')
$lnk     = Join-Path $startup 'chromepilot.lnk'
$vbs     = Join-Path $PSScriptRoot 'start-chromepilot-hidden.vbs'

if (-not (Test-Path $vbs)) {
    Write-Host "Cannot find $vbs - run this from the Chromepilot repo root."
    exit 1
}

$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnk)
$sc.TargetPath       = 'wscript.exe'
$sc.Arguments        = "`"$vbs`""
$sc.WorkingDirectory = $PSScriptRoot
$sc.Description      = 'Auto-start chromepilot CDP + HTTP server on login'
$sc.Save()

Write-Host "Installed: $lnk"
Write-Host ""
Write-Host "On your next Windows login, Chrome CDP (9222) and the HTTP server (9223)"
Write-Host "will come up automatically in the background."
Write-Host ""
Write-Host "To uninstall: Remove-Item '$lnk'"
