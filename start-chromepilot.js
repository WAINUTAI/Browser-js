#!/usr/bin/env node
// Cross-platform dispatcher for the combined launcher.
// Picks start-chromepilot.ps1 on Windows and start-chromepilot.sh elsewhere.
const { spawnSync } = require("child_process");
const { join } = require("path");

const isWin = process.platform === "win32";
const here  = __dirname;

const result = isWin
  ? spawnSync("powershell.exe",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(here, "start-chromepilot.ps1")],
      { stdio: "inherit" })
  : spawnSync("bash",
      [join(here, "start-chromepilot.sh")],
      { stdio: "inherit" });

process.exit(result.status ?? 1);
