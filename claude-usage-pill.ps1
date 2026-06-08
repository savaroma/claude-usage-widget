# Claude Usage Pill Widget (Windows 11)
# A small borderless always-on-top "pill" that sits on the left of the taskbar,
# styled like the Windows weather widget. Shows the rolling 5-hour subscription
# limit %, color-coded. Hover for details, right-click for menu, drag to reposition.
#
# Run:  powershell -sta -NoProfile -ExecutionPolicy Bypass -File claude-usage-pill.ps1
# (or use start-widget.vbs for a silent background launch)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi {
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
}
"@

# ---- config -------------------------------------------------------------------
$CredPath    = Join-Path $env:USERPROFILE ".claude\.credentials.json"
$ApiUrl      = "https://api.anthropic.com/api/oauth/usage"
$PollSeconds = 45
$PosFile     = Join-Path $PSScriptRoot "widget-pos.txt"
$W = 92; $H = 34          # pill size

function Get-StatusColor([int]$pct) {
    if     ($pct -ge 90) { [System.Drawing.Color]::FromArgb(235, 70, 70)  }
    elseif ($pct -ge 70) { [System.Drawing.Color]::FromArgb(245, 150, 30) }
    elseif ($pct -ge 40) { [System.Drawing.Color]::FromArgb(235, 205, 40) }
    else                 { [System.Drawing.Color]::FromArgb(70, 205, 100) }
}

# ---- data ---------------------------------------------------------------------
function Get-Usage {
    try {
        $cred  = Get-Content $CredPath -Raw -ErrorAction Stop | ConvertFrom-Json
        $token = $cred.claudeAiOauth.accessToken
        if (-not $token) { return $null }
        $headers = @{ "Authorization"="Bearer $token"; "anthropic-beta"="oauth-2025-04-20"; "Content-Type"="application/json" }
        return Invoke-RestMethod -Uri $ApiUrl -Headers $headers -Method Get -TimeoutSec 15
    } catch { return $null }
}
function Util([object]$s)  { if ($s -and $s.utilization -ne $null) { [int][math]::Round([double]$s.utilization) } else { -1 } }
function Reset([object]$s) { if ($s -and $s.resets_at) { try { ([datetimeoffset]::Parse($s.resets_at)).LocalDateTime.ToString("ddd HH:mm") } catch { "--" } } else { "--" } }

# ---- shared state -------------------------------------------------------------
$script:H5 = -1; $script:Col = (Get-StatusColor 0); $script:Ok = $false

# ---- form ---------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar   = $false
$form.TopMost         = $true
$form.StartPosition   = 'Manual'
$form.Size            = New-Object System.Drawing.Size($W, $H)
$form.BackColor       = [System.Drawing.Color]::FromArgb(32, 32, 32)
$form.Opacity         = 0.94

# rounded "pill" shape
$radius = [int]($H / 2)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$d = $radius * 2
$path.AddArc(0, 0, $d, $d, 180, 90)
$path.AddArc($W - $d, 0, $d, $d, 270, 90)
$path.AddArc($W - $d, $H - $d, $d, $d, 0, 90)
$path.AddArc(0, $H - $d, $d, $d, 90, 90)
$path.CloseFigure()
$form.Region = New-Object System.Drawing.Region $path

# keep a position inside a visible work area (above the taskbar, on a connected
# monitor) so a stale saved spot can never hide the pill behind the taskbar
function Clamp-Pos([int]$x, [int]$y) {
    $r  = New-Object System.Drawing.Rectangle $x, $y, $W, $H
    $wa = [System.Windows.Forms.Screen]::FromRectangle($r).WorkingArea
    $nx = [int][Math]::Max($wa.Left + 2, [Math]::Min($x, $wa.Right  - $W - 2))
    $ny = [int][Math]::Max($wa.Top + 2,  [Math]::Min($y, $wa.Bottom - $H - 2))
    New-Object System.Drawing.Point($nx, $ny)
}

# position: saved (clamped), else bottom-left just above the taskbar
$scr = [System.Windows.Forms.Screen]::PrimaryScreen
$defX = $scr.Bounds.Left + 12
$defY = $scr.WorkingArea.Bottom - $H - 6
if (Test-Path $PosFile) {
    try { $p = (Get-Content $PosFile -Raw).Split(','); $defX = [int]$p[0]; $defY = [int]$p[1] } catch {}
}
$form.Location = Clamp-Pos $defX $defY

# painting: status dot + percent text
$fontPct = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$fontLbl = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$form.add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    # status dot
    $dot = New-Object System.Drawing.SolidBrush $script:Col
    $g.FillEllipse($dot, 11, ([int](($H-10)/2)), 10, 10); $dot.Dispose()
    # texts
    $white = [System.Drawing.Brushes]::White
    $grey  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(170,170,170))
    $g.DrawString("5h", $fontLbl, $grey, 27, 9)
    $pct = if ($script:Ok) { "$($script:H5)%" } else { "-" }
    $g.DrawString($pct, $fontPct, $white, 44, 7)
    $grey.Dispose()
})

# tooltip with full details
$tip = New-Object System.Windows.Forms.ToolTip
$tip.InitialDelay = 200; $tip.ReshowDelay = 100

# context menu
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miRefresh = $menu.Items.Add("Refresh now")
$miLock    = $menu.Items.Add("Lock position")
$miStartup = $menu.Items.Add("Start at login")
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$miExit    = $menu.Items.Add("Exit")
$form.ContextMenuStrip = $menu

# drag to move (unless locked)
$script:Locked = $false; $script:Drag = $false; $script:DX = 0; $script:DY = 0
$form.add_MouseDown({ param($s,$e) if ($e.Button -eq 'Left' -and -not $script:Locked) { $script:Drag=$true; $script:DX=$e.X; $script:DY=$e.Y } })
$form.add_MouseMove({ param($s,$e) if ($script:Drag) { $form.Left=[System.Windows.Forms.Cursor]::Position.X-$script:DX; $form.Top=[System.Windows.Forms.Cursor]::Position.Y-$script:DY } })
$form.add_MouseUp({   param($s,$e) if ($script:Drag) { $script:Drag=$false; $form.Location = (Clamp-Pos $form.Left $form.Top); try { "$($form.Left),$($form.Top)" | Set-Content $PosFile } catch {} } })

# resilient update: on a transient failure (e.g. Claude Code rewriting the
# credentials file on a session change) keep the last good value instead of
# blanking to gray, and retry every 5s until it recovers.
$script:Fails = 0
$retryTimer = New-Object System.Windows.Forms.Timer
$retryTimer.Interval = 5000

function Update-Usage {
    $u = Get-Usage
    if ($null -eq $u) {
        $script:Fails++
        if ((-not $script:Ok) -or ($script:Fails -ge 5)) {
            # never had data, or down for a while -> show the gray "no data" state
            $script:Ok = $false; $script:H5 = -1; $script:Col = [System.Drawing.Color]::Gray
            $tip.SetToolTip($form, "No data - is Claude Code logged in? (run /login)")
        } else {
            # keep showing the last good value, just mark it stale
            $tip.SetToolTip($form, "5h: $($script:H5)%  (reconnecting...)")
        }
        $retryTimer.Start()
        $form.Invalidate(); Force-Top
        return
    }
    $script:Fails = 0; $retryTimer.Stop()
    $h5  = Util $u.five_hour; $d7 = Util $u.seven_day; $d7s = Util $u.seven_day_sonnet
    $script:Ok = $true; $script:H5 = $h5; $script:Col = (Get-StatusColor $h5)
    $sonTxt = if ($d7s -ge 0) { "$d7s%" } else { "n/a" }
    $tip.SetToolTip($form, "5h: $h5%  (resets $(Reset $u.five_hour))`n7d: $d7%  (resets $(Reset $u.seven_day))`n7d Sonnet: $sonTxt`nupdated $((Get-Date).ToString('HH:mm:ss'))")
    $form.Invalidate(); Force-Top
}
$retryTimer.add_Tick({ Update-Usage })

$miRefresh.add_Click({ Update-Usage })
$miLock.add_Click({ $script:Locked = -not $script:Locked; $miLock.Text = if ($script:Locked) { "Unlock position" } else { "Lock position" } })
$miStartup.add_Click({
    try {
        $startup = [Environment]::GetFolderPath('Startup')
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut((Join-Path $startup "Claude Usage Widget.lnk"))
        $lnk.TargetPath = (Join-Path $PSScriptRoot "start-widget.vbs")
        $lnk.WorkingDirectory = $PSScriptRoot
        $lnk.Save()
        [System.Windows.Forms.MessageBox]::Show("Added to startup.","Claude Usage Widget") | Out-Null
    } catch { [System.Windows.Forms.MessageBox]::Show("Failed: $_","Claude Usage Widget") | Out-Null }
})
$miExit.add_Click({ $form.Close() })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $PollSeconds * 1000
$timer.add_Tick({ Update-Usage })
$timer.Start()

# keep the pill above the taskbar: tool-window + no-activate + topmost, re-asserted often
function Force-Top { [WinApi]::SetWindowPos($form.Handle, [IntPtr](-1), 0, 0, 0, 0, 0x13) | Out-Null }
$form.add_Shown({
    $ex = [WinApi]::GetWindowLong($form.Handle, -20)              # GWL_EXSTYLE
    # WS_EX_TOOLWINDOW(0x80) | WS_EX_NOACTIVATE(0x08000000) | WS_EX_TOPMOST(0x8)
    [WinApi]::SetWindowLong($form.Handle, -20, ($ex -bor 0x80 -bor 0x08000000 -bor 0x8)) | Out-Null
    Force-Top
    Update-Usage
})
$form.add_Click({ Force-Top })
$form.add_Deactivate({ Force-Top })

$topTimer = New-Object System.Windows.Forms.Timer   # cheap z-order guard
$topTimer.Interval = 1000
$topTimer.add_Tick({ Force-Top })
$topTimer.Start()

[System.Windows.Forms.Application]::Run($form)
