#!/usr/bin/env node
// Cross-platform dispatcher for the combined launcher.
// Picks start-browsejs.ps1 on Windows and start-browsejs.sh elsewhere.
const { spawnSync } = require("child_process");
const { join } = require("path");

const isWin = process.platform === "win32";
const here  = __dirname;

const result = isWin
  ? spawnSync("powershell.exe",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", join(here, "start-browsejs.ps1")],
      { stdio: "inherit" })
  : spawnSync("bash",
      [join(here, "start-browsejs.sh")],
      { stdio: "inherit" });

process.exit(result.status ?? 1);
