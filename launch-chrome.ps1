# PowerShell script to launch Chrome with remote debugging enabled
# Uses a dedicated profile so it runs alongside your normal Chrome without conflict

$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$debugProfile = "$PSScriptRoot\chrome-debug-profile"

# If CDP is already up, reuse it instead of launching a second debug Chrome
try {
    Invoke-WebRequest -Uri "http://127.0.0.1:9222/json/version" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop | Out-Null
    Write-Host "CDP already live on 9222 - reusing existing debug Chrome."
    exit 0
} catch {
    # Not running yet - launch below
}

Write-Host "Launching Chrome with remote debugging on port 9222 (separate profile, your normal Chrome is untouched)..."
Start-Process $chromePath -ArgumentList "--remote-debugging-port=9222", "--user-data-dir=$debugProfile", "--no-first-run", "--no-default-browser-check"
Start-Sleep -Seconds 3

try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:9222/json/version" -UseBasicParsing -ErrorAction Stop
    Write-Host "Connected! CDP is live."
    Write-Host $response.Content
} catch {
    Write-Host "Warning: Could not verify CDP connection yet. Give it a few more seconds."
}
