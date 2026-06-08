# Watchdog for the Claude usage widget.
# Keeps the widget alive: if it dies (e.g. explorer.exe restarts and the embedded
# taskbar child window is destroyed with it), this relaunches it within ~5s.
# Launch silently via start-watchdog.vbs (or add that to your Startup folder).

$ErrorActionPreference = 'SilentlyContinue'
$me  = $PID
$ps1 = Join-Path $PSScriptRoot 'claude-usage-pill.ps1'

while ($true) {
    $running = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $me -and $_.CommandLine -like '*-File*claude-usage-pill.ps1*' }
    if (-not $running) {
        Start-Process powershell -ArgumentList '-sta','-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',$ps1 -WindowStyle Hidden
    }
    Start-Sleep -Seconds 5
}
