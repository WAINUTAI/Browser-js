' Hidden launcher wrapper. Runs start-browsejs.ps1 without showing a console window.
' Used for auto-start on Windows login.
Set sh = CreateObject("WScript.Shell")
scriptDir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
ps1 = scriptDir & "\start-browsejs.ps1"
' 0 = hidden window, False = don't wait
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & ps1 & """", 0, False
