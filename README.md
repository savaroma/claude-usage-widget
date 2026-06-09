# Claude Usage Widget (Windows)

A tiny widget that shows, at a glance, how much of your Claude **subscription**
limit you've burned — the rolling **5-hour** window and the **weekly** limit — as
live, color-coded percentages. Built for heavy research/coding on Windows that
eats the limit fast, so you find out *before* you get cut off.

The number matches what Claude Code shows, and because the limit is account-wide
it reflects usage across **all** your devices.

```
●5h 9%   ●7d 4%
```

## Form factors

| Script | Where it shows |
| --- | --- |
| `claude-usage-pill.ps1` *(default)* | A "pill" **embedded inside the taskbar** (or floating just above it) |
| `claude-usage-widget.ps1` | A system-tray icon (bottom-right notification area) |

Each dot is colored by that limit's utilization: green < 40, yellow 40–69,
orange 70–89, red ≥ 90. Hover for exact %, reset times, and the 7-day Sonnet limit.

Zero install — runs on the built-in Windows PowerShell.

## Quick start

Double-click **`start-widget.vbs`** (silent), or for one run / debugging:

```powershell
powershell -sta -NoProfile -ExecutionPolicy Bypass -File .\claude-usage-pill.ps1
```

Right-click the pill for the menu (**Refresh now**, **Start at login**, **Exit**).

## Run it reliably (recommended)

Use the **watchdog**, which relaunches the widget if it dies — important in
embed mode, because the embedded window is destroyed whenever `explorer.exe`
restarts. Right-click the pill → **Start at login** installs a Startup shortcut
to `start-watchdog.vbs`. To start it now without rebooting:

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
| `$W`, `$H` | pill size | `150 x 34` |
| `$PollSeconds` | refresh interval | `60` |

(Position isn't draggable in embed mode — set it with `$TaskbarSide` / `$TaskbarLeftOffset`.)

## How it works

See [docs/usage-endpoint.md](docs/usage-endpoint.md). In short: it reads the OAuth
token from `~/.claude/.credentials.json` and calls
`GET https://api.anthropic.com/api/oauth/usage` (header `anthropic-beta: oauth-2025-04-20`),
parsing `five_hour` / `seven_day` → `utilization` and `resets_at`.

Embedding uses the `SetParent(Shell_TrayWnd)` technique (the same approach
TrafficMonitor uses) to make the window a child of the taskbar.

## Troubleshooting

- **Pill is gray / shows `-`:** the usage fetch failed. Hover for the reason:
  - *rate-limited* — the endpoint is **HTTP 429**; the widget backs off (up to
    10 min) and recovers automatically. Don't restart it in a loop (that makes it
    worse). Polling once per minute is well within limits.
  - *offline / not logged in* — open Claude Code and run `/login`.
- **Pill vanished after an explorer restart / Windows update:** that's expected
  for an embedded window; the **watchdog** brings it back within ~5s.
- **Sits on the wrong spot / overlaps icons:** adjust `$TaskbarLeftOffset` (or
  switch `$TaskbarSide`).

## Limitations / notes

- The usage endpoint is **undocumented** and **rate-limited**; Anthropic may
  change it. The widget fails gracefully (gray) and backs off.
- Embedding into the taskbar is a **hack** (`SetParent`), not a supported API —
  it can break with Windows feature updates.
- Shows your *subscription* limit, not API (pay-as-you-go) billing.
- Token auto-refresh is intentionally **not** implemented (it could rotate the
  refresh token and break Claude Code's login); the widget relies on Claude Code
  keeping the credentials file fresh.

## macOS port

Want the same thing in the macOS menu bar (top-right)? See
[docs/macos-prompt.md](docs/macos-prompt.md) — a ready-to-paste prompt with all the
endpoint details and the macOS-specific Keychain token location. Tracked on the
`macos` branch.

## Disclaimer

Unofficial and **not affiliated with Anthropic**. This tool reads your Claude
*subscription* usage via an **undocumented** endpoint (`/api/oauth/usage`) using the
OAuth token Claude Code already stores locally. It only ever touches **your own**
token on **your own** machine and sends nothing anywhere else. The endpoint is
undocumented and rate-limited — it may change or stop working at any time. Embedding
into the taskbar relies on an unsupported `SetParent` technique. Use at your own risk.

## License

MIT — see [LICENSE](LICENSE).
