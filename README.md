# Claude Usage Widget

A tiny widget that shows, at a glance, how much of your Claude **subscription**
limit you've burned — the rolling **5-hour** window and the **weekly** limit — as
live, color-coded percentages, with a countdown to the 5-hour reset. So you find out
*before* you get cut off.

The numbers match what Claude Code shows, and because the limit is account-wide they
reflect usage across **all** your devices.

```
5h 24% · 2h05m    7d 10%
```

## Platforms

| Platform | What you get | Docs |
| --- | --- | --- |
| **Windows** | A pill **inside the taskbar** (like the weather widget), or a tray icon | [windows/README.md](windows/README.md) |
| **macOS** | A **menu-bar** item (SwiftBar / xbar plugin) | [macos/README.md](macos/README.md) |

Pick your platform's folder and follow its README — each is self-contained.

## Repository layout

```
windows/   PowerShell taskbar pill + tray widget, watchdog, launchers
macos/     SwiftBar/xbar menu-bar plugin
docs/      usage-endpoint.md (the data source) · macos-prompt.md (build prompt)
```

## How it works (both platforms)

Each widget reads the OAuth token Claude Code already stores locally and calls the
same **undocumented** endpoint Claude Code's own limit indicator uses:

```
GET https://api.anthropic.com/api/oauth/usage     (header: anthropic-beta: oauth-2025-04-20)
```

It parses `five_hour` / `seven_day` → `utilization` (%) and `resets_at`, computing the
countdown locally. The endpoint is read-only and **does not spend your limit**, but it
**is rate-limited** — both widgets poll once a minute and back off on HTTP 429. Full
reference: [docs/usage-endpoint.md](docs/usage-endpoint.md).

## Disclaimer

Unofficial and **not affiliated with Anthropic**. This tool reads your Claude
*subscription* usage via an **undocumented** endpoint (`/api/oauth/usage`) using the
OAuth token Claude Code already stores locally. It only ever touches **your own** token
on **your own** machine and sends nothing anywhere else. The endpoint is undocumented
and rate-limited — it may change or stop working at any time. The Windows taskbar
embedding relies on an unsupported `SetParent` technique. Use at your own risk.

## License

MIT — see [LICENSE](LICENSE).
