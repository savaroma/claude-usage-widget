# Claude Usage Widget (Windows)

A tiny desktop widget that shows, at a glance, how much of your Claude
**subscription** limit you've burned — the rolling **5-hour** window and the
**weekly** limit — as a live, color-coded percentage.

Built for the case where heavy research/coding on a Windows machine eats the
limit fast, while you'd otherwise only find out when Claude Code suddenly tells
you you're rate-limited. The number matches what Claude Code shows, and because
the limit is account-wide, it reflects usage across **all** your devices.

There are two form factors:

| Script | Form factor | Looks like |
| --- | --- | --- |
| `claude-usage-pill.ps1` *(default)* | Borderless "pill" docked bottom-left, just above the taskbar | The Windows weather widget |
| `claude-usage-widget.ps1` | System-tray icon (bottom-right notification area) | A normal tray icon with a number |

Zero install — both run on the built-in Windows PowerShell, no dependencies.

## Quick start

```powershell
# pill widget (default)
powershell -sta -NoProfile -ExecutionPolicy Bypass -File .\claude-usage-pill.ps1
```

Or just double-click **`start-widget.vbs`** to launch it silently in the
background (no console window).

- **Hover** → tooltip with 5h / 7d / 7d-Sonnet % and reset times.
- **Drag** (left-drag) → reposition; the spot is remembered in `widget-pos.txt`.
- **Right-click** → menu: *Refresh now*, *Lock position*, *Start at login*, *Exit*.

Dot color by 5h utilization: green < 40, yellow 40–69, orange 70–89, red ≥ 90.

## Start automatically at login

Easiest: right-click the widget → **Start at login** (creates a Startup shortcut
to `start-widget.vbs`). To do it manually:

```powershell
$startup = [Environment]::GetFolderPath('Startup')
$ws = New-Object -ComObject WScript.Shell
$lnk = $ws.CreateShortcut("$startup\Claude Usage Widget.lnk")
$lnk.TargetPath = "$PWD\start-widget.vbs"
$lnk.WorkingDirectory = "$PWD"
$lnk.Save()
```

## Configuration

Edit the variables near the top of `claude-usage-pill.ps1`:

| Variable | Meaning | Default |
| --- | --- | --- |
| `$PollSeconds` | How often to refresh | `45` |
| `$W`, `$H` | Pill size in pixels | `92 x 34` |
| `$defX`, `$defY` | Default position (used until you drag it) | bottom-left, above the taskbar |
| `Get-StatusColor` | Color thresholds | 40 / 70 / 90 |

## How it works

See [docs/usage-endpoint.md](docs/usage-endpoint.md) for the full details. In short:

1. Reads the OAuth token from `~/.claude/.credentials.json` (kept fresh by Claude Code).
2. Calls `GET https://api.anthropic.com/api/oauth/usage` with header
   `anthropic-beta: oauth-2025-04-20`.
3. Parses `five_hour` / `seven_day` / `seven_day_sonnet` → `utilization` (a percent)
   and `resets_at`.

The endpoint is **read-only** and does **not** consume your limit, so polling is free.

## Troubleshooting

- **Pill is gray / shows `-`:** no data — Claude Code isn't logged in or the token
  expired. Open Claude Code and run `/login`. (Transient blips during a session
  change self-heal within ~5s; the widget keeps the last value meanwhile.)
- **Pill keeps hiding behind the taskbar:** it's positioned just *above* the
  taskbar specifically to avoid this. If you dragged it onto the taskbar, delete
  `widget-pos.txt` to reset it.
- **Nothing appears:** make sure it launched with `-sta` (the `.vbs` does this).

## Limitations / notes

- The usage endpoint is **undocumented**; Anthropic may change it. The widget
  fails gracefully (gray `?`) if so.
- This reads your *subscription* limit, not API (pay-as-you-go) billing.
- Token auto-refresh on expiry is intentionally **not** implemented: refreshing
  could rotate the refresh token and break Claude Code's own login. The widget
  relies on Claude Code keeping `~/.claude/.credentials.json` current.

## License

MIT — see [LICENSE](LICENSE).
