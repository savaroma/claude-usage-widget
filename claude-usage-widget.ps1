# Claude Usage Tray Widget
# Shows Claude subscription limit utilization (% of the rolling 5h window and the
# weekly limit) as a system-tray icon in the bottom-right of the Windows taskbar.
#
# Run:  powershell -sta -NoProfile -ExecutionPolicy Bypass -File claude-usage-widget.ps1
# (or double-click start-widget.vbs for a silent background launch)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Net.ServicePointManager]::SecurityProtocol = `
    [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Win32 DestroyIcon so the GDI handle from Bitmap.GetHicon() doesn't leak each refresh
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeIcon {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);
}
"@

# ---- config -------------------------------------------------------------------
$CredPath     = Join-Path $env:USERPROFILE ".claude\.credentials.json"
$ApiUrl       = "https://api.anthropic.com/api/oauth/usage"
$PollSeconds  = 45
# tray icon color thresholds (based on 5h utilization %)
function Get-StatusColor([int]$pct) {
    if     ($pct -ge 90) { [System.Drawing.Color]::FromArgb(230, 60, 60)  }  # red
    elseif ($pct -ge 70) { [System.Drawing.Color]::FromArgb(240, 140, 0)  }  # orange
    elseif ($pct -ge 40) { [System.Drawing.Color]::FromArgb(225, 200, 0)  }  # yellow
    else                 { [System.Drawing.Color]::FromArgb(60, 200, 90)  }  # green
}

# ---- data ---------------------------------------------------------------------
function Get-Usage {
    try {
        $cred  = Get-Content $CredPath -Raw -ErrorAction Stop | ConvertFrom-Json
        $token = $cred.claudeAiOauth.accessToken
        if (-not $token) { return $null }
        $headers = @{
            "Authorization"  = "Bearer $token"
            "anthropic-beta" = "oauth-2025-04-20"
            "Content-Type"   = "application/json"
        }
        return Invoke-RestMethod -Uri $ApiUrl -Headers $headers -Method Get -TimeoutSec 15
    } catch {
        return $null
    }
}

function Util([object]$section) {
    if ($section -and $section.utilization -ne $null) {
        return [int][math]::Round([double]$section.utilization)
    }
    return -1   # not applicable
}
function ResetLocal([object]$section) {
    if ($section -and $section.resets_at) {
        try { return ([datetimeoffset]::Parse($section.resets_at)).LocalDateTime.ToString("ddd HH:mm") } catch {}
    }
    return "--"
}

# ---- icon rendering -----------------------------------------------------------
$script:PrevHandle = [IntPtr]::Zero
function New-PercentIcon([int]$pct, [System.Drawing.Color]$color) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $text = if ($pct -lt 0) { "?" } elseif ($pct -ge 100) { "99" } else { "$pct" }
    $size = if ($text.Length -ge 2) { 19 } else { 22 }
    $font = New-Object System.Drawing.Font("Segoe UI", $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $sf   = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $brush = New-Object System.Drawing.SolidBrush $color
    $rect  = New-Object System.Drawing.RectangleF 0, 0, 32, 32
    $g.DrawString($text, $font, $brush, $rect, $sf)
    $g.Dispose(); $brush.Dispose(); $font.Dispose()

    $hicon = $bmp.GetHicon()
    $icon  = [System.Drawing.Icon]::FromHandle($hicon)
    $bmp.Dispose()
    return @{ Icon = $icon; Handle = $hicon }
}

# ---- tray UI ------------------------------------------------------------------
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Visible = $true
$notify.Text = "Claude usage - loading..."

$menu      = New-Object System.Windows.Forms.ContextMenuStrip
$mi5h      = $menu.Items.Add("5h:  --")     ; $mi5h.Enabled = $false
$mi7d      = $menu.Items.Add("7d:  --")     ; $mi7d.Enabled = $false
$miSonnet  = $menu.Items.Add("7d Sonnet: --"); $miSonnet.Enabled = $false
$miUpdated = $menu.Items.Add("updated: --") ; $miUpdated.Enabled = $false
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$miRefresh = $menu.Items.Add("Refresh now")
$miExit    = $menu.Items.Add("Exit")
$notify.ContextMenuStrip = $menu

function Set-TrayIcon([int]$pct, [System.Drawing.Color]$color) {
    $made = New-PercentIcon $pct $color
    $old  = $notify.Icon
    $notify.Icon = $made.Icon
    if ($script:PrevHandle -ne [IntPtr]::Zero) { [NativeIcon]::DestroyIcon($script:PrevHandle) | Out-Null }
    $script:PrevHandle = $made.Handle
    if ($old) { $old.Dispose() }
}

function Update-Usage {
    $u = Get-Usage
    if ($null -eq $u) {
        Set-TrayIcon -pct -1 -color ([System.Drawing.Color]::Gray)
        $notify.Text   = "Claude usage - no data (logged in?)"
        $mi5h.Text     = "No data - is Claude Code logged in?"
        $mi7d.Text     = "(check ~/.claude/.credentials.json)"
        $miSonnet.Text = "7d Sonnet: --"
        $miUpdated.Text = "updated: " + (Get-Date).ToString("HH:mm:ss")
        return
    }
    $h5  = Util $u.five_hour
    $d7  = Util $u.seven_day
    $d7s = Util $u.seven_day_sonnet

    Set-TrayIcon -pct $h5 -color (Get-StatusColor $h5)
    $notify.Text   = "5h: $h5%   7d: $d7%"
    $mi5h.Text     = "5h:  $h5%   (resets " + (ResetLocal $u.five_hour) + ")"
    $mi7d.Text     = "7d:  $d7%   (resets " + (ResetLocal $u.seven_day) + ")"
    $miSonnet.Text = if ($d7s -ge 0) { "7d Sonnet: $d7s%" } else { "7d Sonnet: n/a" }
    $miUpdated.Text = "updated: " + (Get-Date).ToString("HH:mm:ss")
}

$miRefresh.add_Click({ Update-Usage })
$miExit.add_Click({
    $notify.Visible = $false
    if ($script:PrevHandle -ne [IntPtr]::Zero) { [NativeIcon]::DestroyIcon($script:PrevHandle) | Out-Null }
    $notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
# double-click the tray icon = force refresh
$notify.add_DoubleClick({ Update-Usage })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $PollSeconds * 1000
$timer.add_Tick({ Update-Usage })
$timer.Start()

Update-Usage   # initial fetch
[System.Windows.Forms.Application]::Run()
