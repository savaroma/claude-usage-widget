# macOS menu-bar widget

A [SwiftBar](https://github.com/swiftbar/SwiftBar) / [xbar](https://github.com/matryer/xbar)
plugin that shows your Claude subscription limit usage in the menu bar:

```
🟢 5h 33% · 1h55m   🟢 7d 16%
```

- **5h** — rolling 5-hour limit %, with a **countdown to its reset**.
- **7d** — 7-day limit %.
- Colored dot per segment: 🟢 <40 · 🟡 40–69 · 🟠 70–89 · 🔴 ≥90 · ⚪ no data.
- Click for a dropdown with exact reset times, the 7-day Sonnet limit, last-update
  age, and **Refresh now**.

It reads the same undocumented OAuth endpoint Claude Code's own limit indicator
uses (`/api/oauth/usage`) — read-only, does not spend your limit. See
[../docs/usage-endpoint.md](../docs/usage-endpoint.md).

## Install (SwiftBar — recommended)

```sh
brew install --cask swiftbar
```

1. Launch SwiftBar and pick a plugin folder (e.g. `~/SwiftBar`).
2. Copy the plugin in, keeping the `.60s.py` suffix (that's the 60-second refresh):

   ```sh
   cp claude-usage.60s.py ~/SwiftBar/
   chmod +x ~/SwiftBar/claude-usage.60s.py
   ```
3. SwiftBar → **Refresh all**. The widget appears in the menu bar.

For **xbar** it's the same file in `~/Library/Application Support/xbar/plugins/`.

**Autostart:** SwiftBar itself launches at login (Preferences → "Start at login"),
which starts the plugin — no separate LaunchAgent needed.

## How it behaves

- Polls at most once per 60 s. On failure it keeps showing the last good values
  with a `⚠︎` and backs off (HTTP 429 → starts ~90 s, doubling, capped 10 min),
  so it never hammers the rate-limited endpoint.
- A `401` (expired token) is handled separately: it re-reads the token from the
  Keychain once and retries, rather than entering the long backoff. Keep Claude
  Code logged in — it refreshes the token.

## Token

Read from the macOS **Keychain** (`security find-generic-password -s
"Claude Code-credentials" -a "$USER" -w` → `claudeAiOauth.accessToken`), falling
back to `~/.claude/.credentials.json`. The token is never logged or displayed.
The first run may show a Keychain access prompt — allow it once.

## Run standalone (debug)

```sh
./claude-usage.60s.py     # prints the SwiftBar-format output once
```

State (last-good values + backoff schedule) is cached at
`~/Library/Caches/claude-usage-widget/state.json`.
