# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]
### Added
- **Embed inside the taskbar** (`$EmbedInTaskbar`, default on) via
  `SetParent(Shell_TrayWnd)` — the pill lives in the taskbar like the weather
  widget. Configurable side/offset (`$TaskbarSide`, `$TaskbarLeftOffset`,
  `$TaskbarRightGap`); re-embeds itself if the taskbar is recreated.
- **Watchdog** (`watchdog.ps1` + `start-watchdog.vbs`): relaunches the widget if
  it dies (e.g. the embedded window is destroyed when explorer.exe restarts).
  "Start at login" now installs the watchdog.
- Pill now shows **both 5h and 7d** utilization, each with its own colored dot.

### Changed
- Poll interval 45s → 60s.
- "Lock position" menu item is hidden in embed mode (dragging doesn't apply).
- Debug logging is now off by default (`$DebugLogging`).

### Fixed
- **Rate-limit handling:** the usage endpoint returns HTTP 429 if polled too
  often. Replaced the fixed 5s retry (which hammered the endpoint and kept the
  pill gray) with exponential backoff (90s start on 429, capped at 10 min) that
  pauses normal polling and keeps showing the last good value.
- Pill could be hidden behind the taskbar after a reboot when a stale
  `widget-pos.txt` pointed onto the taskbar band or a disconnected monitor.
  Saved/dragged positions are now clamped to a visible work area (above the
  taskbar, on a connected screen) on load and on drag-release.

## [0.1.0] - 2026-06-08
### Added
- **Pill widget** (`claude-usage-pill.ps1`): a borderless, always-on-top "pill"
  docked at the bottom-left, just above the taskbar, styled like the Windows
  weather widget. Shows the rolling **5-hour** subscription-limit utilization %,
  color-coded (green / yellow / orange / red).
- Hover tooltip with 5h, 7d and 7d-Sonnet utilization and reset times.
- Context menu: **Refresh now**, **Lock position**, **Start at login**, **Exit**.
- Draggable; position is persisted to `widget-pos.txt`.
- **Tray-icon variant** (`claude-usage-widget.ps1`) as a fallback form factor.
- Silent background launcher (`start-widget.vbs`).
- Reads usage from the (undocumented) `GET /api/oauth/usage` endpoint using the
  OAuth token Claude Code stores in `~/.claude/.credentials.json`.

### Reliability
- Z-order guard: re-asserts top-most every second so the taskbar can't bury it;
  positioned just above the taskbar to avoid the overlap entirely.
- Resilient polling: on a transient fetch failure (e.g. Claude Code rewriting the
  credentials file during a session change) the widget keeps the last good value
  and retries every 5s instead of blanking to gray.
