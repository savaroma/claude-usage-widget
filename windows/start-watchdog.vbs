' Silent launcher for the watchdog (which keeps the widget alive and re-embeds
' it after explorer.exe restarts). Put a shortcut to this in shell:startup.
Set sh = CreateObject("WScript.Shell")
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -File """ & scriptDir & "watchdog.ps1""", 0, False
