# Claude Usage Widget — Windows

A "pill" that shows your Claude subscription limit usage **inside the Windows
taskbar** (like the weather widget): the rolling **5-hour** and **weekly** limits as
live, color-coded percentages, plus a countdown to the 5-hour reset.

```
●5h 24% 2h05m   ●7d 10%
```

(`2h05m` = time left until the 5-hour window resets.)

## Form factors

| Script | Where it shows |
| --- | --- |
| `claude-usage-pill.ps1` *(default)* | A pill **embedded inside the taskbar** (or floating just above it) |
| `claude-usage-widget.ps1` | A system-tray icon (bottom-right notification area) |

Each dot is colored by that limit's utilization: green < 40, yellow 40–69,
orange 70–89, red ≥ 90. The countdown sits next to the 5h %. Hover for exact %,
reset times, and the 7-day Sonnet limit.

Zero install — runs on the built-in Windows PowerShell.

## Quick start

From this `windows/` folder, double-click **`start-widget.vbs`** (silent), or for
one run / debugging:

```powershell
powershell -sta -NoProfile -ExecutionPolicy Bypass -File .\claude-usage-pill.ps1
```

Right-click the pill for the menu (**Refresh now**, **Start at login**, **Exit**).

## Run it reliably (recommended)

Use the **watchdog**, which relaunches the widget if it dies — important in embed
mode, because the embedded window is destroyed whenever `explorer.exe` restarts.
Right-click the pill → **Start at login** installs a Startup shortcut to
`start-watchdog.vbs`. To start it now without rebooting:

```powershell
wscript .\start-watchdog.vbs
```

## Configuration

Variables at the top of `claude-usage-pill.ps1`:

| Variable | Meaning | Default |
| --- | --- | --- |
| `$EmbedInTaskbar` | `$true` = inside the taskbar; `$false` = float just above it | `$true` |
| `$TaskbarSide` | `'left'` (by Widgets/weather) or `'right'` (before the clock) | `'left'` |
| `$TaskbarLeftOffset` | px from the left edge when side = `'left'` | `175` |
| `$TaskbarRightGap` | px gap before the tray when side = `'right'` | `10` |
| `$W`, `$H` | pill size | `195 x 34` |
| `$PollSeconds` | refresh interval (the countdown also updates at this cadence) | `60` |
| `$DebugLogging` | write `debug.err.log` for troubleshooting | `$false` |

(Position isn't draggable in embed mode — set it with `$TaskbarSide` / `$TaskbarLeftOffset`.)

## How it works

Reads the OAuth token from `~/.claude/.credentials.json` and calls
`GET https://api.anthropic.com/api/oauth/usage` (header `anthropic-beta: oauth-2025-04-20`),
parsing `five_hour` / `seven_day` → `utilization` and `resets_at`. The 5h countdown is
computed locally from `resets_at` (no extra requests), so polling stays at once a
minute. Full endpoint reference: [../docs/usage-endpoint.md](../docs/usage-endpoint.md).

Embedding uses the `SetParent(Shell_TrayWnd)` technique (the same approach
TrafficMonitor uses) to make the window a child of the taskbar.

## Troubleshooting

- **Pill is gray / shows `-`:** the usage fetch failed. Hover for the reason:
  - *rate-limited* — the endpoint returned **HTTP 429**; the widget backs off (up to
    10 min) and recovers automatically. Don't restart it in a loop (that makes it
    worse). Polling once per minute is well within limits.
  - *offline / not logged in* — open Claude Code and run `/login`.
- **Pill vanished after an explorer restart / Windows update:** expected for an
  embedded window; the **watchdog** brings it back within ~5s.
- **Sits on the wrong spot / overlaps icons:** adjust `$TaskbarLeftOffset` (or
  switch `$TaskbarSide`).

## Notes

- Embedding into the taskbar is a **hack** (`SetParent`), not a supported API — it
  can break with Windows feature updates (the watchdog re-embeds after restarts).
- Token auto-refresh is intentionally **not** implemented (it could rotate the
  refresh token and break Claude Code's login); relies on Claude Code keeping the
  credentials file fresh.

See the [top-level README](../README.md) for the project overview and disclaimer.
