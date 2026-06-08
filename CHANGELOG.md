# Changelog

All notable changes to this project are documented here.
Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]
### Fixed
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
