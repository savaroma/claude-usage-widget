' Silent launcher for the Claude usage tray widget.
' Double-click this file (or put a shortcut to it in shell:startup) to run the
' widget in the background with no visible console window.
Set sh = CreateObject("WScript.Shell")
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sh.Run "powershell -sta -NoProfile -ExecutionPolicy Bypass -File """ & scriptDir & "claude-usage-pill.ps1""", 0, False
