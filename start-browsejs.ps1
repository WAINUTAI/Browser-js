# Idempotent launcher for the full browser-js stack:
#   - Chrome with CDP on port 9222 (separate profile, does not touch your normal Chrome)
#   - HTTP server on port 9223 (node server.js)
# Safe to run multiple times. Safe to run at Windows login.

$ErrorActionPreference = "SilentlyContinue"

$root         = $PSScriptRoot
$chromePath   = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$debugProfile = Join-Path $root "chrome-debug-profile"
$serverJs     = Join-Path $root "server.js"
$logFile      = Join-Path $root "server.log"

function Test-Port($port) {
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port/json/version" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        return $true
    } catch {
        # 9223 does not serve /json/version — probe /health instead
        try {
            Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }
}

# ── 1. Chrome on 9222 ───────────────────────────────────────────────────────
if (Test-Port 9222) {
    Write-Host "[chrome]  9222 already live - skipping launch"
} else {
    Write-Host "[chrome]  launching debug Chrome (separate profile)"
    Start-Process $chromePath -ArgumentList `
        "--remote-debugging-port=9222", `
        "--user-data-dir=$debugProfile", `
        "--no-first-run", `
        "--no-default-browser-check" `
        -WindowStyle Minimized
    Start-Sleep -Seconds 3
}

# ── 2. HTTP server on 9223 ──────────────────────────────────────────────────
if (Test-Port 9223) {
    Write-Host "[server]  9223 already live - skipping launch"
} else {
    Write-Host "[server]  launching node server.js (log: $logFile)"
    # Start detached so this script can exit while the server keeps running.
    # Output goes to server.log for debugging.
    Start-Process -FilePath "node" `
        -ArgumentList "`"$serverJs`"" `
        -WorkingDirectory $root `
        -WindowStyle Hidden `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError  "$logFile.err"
    Start-Sleep -Seconds 2
}

# ── 3. Verify ───────────────────────────────────────────────────────────────
$chromeOk = Test-Port 9222
$serverOk = Test-Port 9223
Write-Host ""
Write-Host "Chrome (9222): $(if ($chromeOk) {'OK'} else {'DOWN'})"
Write-Host "Server (9223): $(if ($serverOk) {'OK'} else {'DOWN'})"
if ($chromeOk -and $serverOk) { exit 0 } else { exit 1 }
