#!/usr/bin/env bash
# One-time install: register chromepilot to auto-start at login.
# Dispatches to launchd (macOS) or systemd (Linux). Idempotent.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
  Darwin)
    PLIST="$HOME/Library/LaunchAgents/com.wainut.chromepilot.plist"
    mkdir -p "$HOME/Library/LaunchAgents"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.wainut.chromepilot</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>${HERE}/start-chromepilot.sh</string>
  </array>
  <key>WorkingDirectory</key><string>${HERE}</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key>
  <dict>
    <key>Crashed</key><true/>
  </dict>
  <key>StandardOutPath</key><string>${HERE}/server.log</string>
  <key>StandardErrorPath</key><string>${HERE}/server.log.err</string>
</dict>
</plist>
EOF
    launchctl unload "$PLIST" 2>/dev/null || true
    launchctl load   "$PLIST"
    echo "Installed: $PLIST"
    echo
    echo "launchd will start chromepilot now and on every login, and relaunch it"
    echo "if the server crashes. Chrome CDP (9222) and HTTP server (9223) will"
    echo "be live whenever you are logged in."
    echo
    echo "To uninstall:"
    echo "  launchctl unload \"$PLIST\" && rm \"$PLIST\""
    ;;

  Linux)
    UNIT_DIR="$HOME/.config/systemd/user"
    UNIT="${UNIT_DIR}/chromepilot.service"
    mkdir -p "$UNIT_DIR"
    cat > "$UNIT" <<EOF
[Unit]
Description=chromepilot CDP + HTTP server
After=graphical-session.target

[Service]
Type=simple
WorkingDirectory=${HERE}
ExecStart=/usr/bin/env bash ${HERE}/start-chromepilot.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now chromepilot.service
    echo "Installed: $UNIT"
    echo
    echo "systemd will start chromepilot now and on every login, and restart it"
    echo "on failure. Chrome CDP (9222) and HTTP server (9223) will be live"
    echo "whenever you are logged in."
    echo
    echo "Status: systemctl --user status chromepilot"
    echo "Logs  : journalctl --user -u chromepilot -f"
    echo "To uninstall:"
    echo "  systemctl --user disable --now chromepilot && rm \"$UNIT\""
    ;;

  *)
    echo "Unsupported OS: $(uname -s)"
    echo "This installer supports macOS (launchd) and Linux (systemd user)."
    exit 1
    ;;
esac
