# The Claude subscription usage endpoint

This widget gets its numbers from the same place Claude Code's limit indicator
does: an **undocumented** OAuth endpoint. Documented here so the project can be
maintained if Anthropic changes it.

## Request

```
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <accessToken>
anthropic-beta: oauth-2025-04-20
Content-Type: application/json
```

The `accessToken` lives in `~/.claude/.credentials.json`:

```jsonc
{
  "claudeAiOauth": {
    "accessToken":  "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt":    1780872739253,        // ms epoch
    "scopes":       ["user:inference", "user:sessions:claude_code", ...],
    "subscriptionType": "max",
    "rateLimitTier":    "default_claude_max_5x"
  },
  "organizationUuid": "..."
}
```

Claude Code refreshes this file while it runs, so the widget just re-reads it
each poll. **Never commit this file or its tokens.**

## Response

Each section may be `null`. `utilization` is a percent (0–100); `resets_at` is an
ISO-8601 timestamp with offset.

```jsonc
{
  "five_hour":        { "utilization": 8.0, "resets_at": "2026-06-08T01:30:00+00:00" },
  "seven_day":        { "utilization": 4.0, "resets_at": "2026-06-14T10:00:00+00:00" },
  "seven_day_sonnet": { "utilization": 0.0, "resets_at": "..." },
  "seven_day_opus":   null,
  "extra_usage":      { "is_enabled": false, "monthly_limit": null,
                        "used_credits": null, "utilization": null }
}
```

The endpoint is **read-only** and does not consume the usage limit — safe to poll.

## How it was found

Grep the Claude Code VS Code extension bundle
(`~/.vscode/extensions/anthropic.claude-code-*/extension.js`). The parser there
maps `five_hour` / `seven_day` / `seven_day_sonnet` / `extra_usage` to
`{ utilization, resetsAt }`. The same bundle contains the OAuth token endpoint
(`/v1/oauth/token`), the public client id, and the `oauth-2025-04-20` beta tag.

## Token refresh (not implemented, on purpose)

The refresh flow is `POST .../v1/oauth/token` with
`{ grant_type: "refresh_token", refresh_token, client_id }`. We deliberately do
**not** call it: OAuth refresh tokens are typically rotated on use, so refreshing
from the widget could invalidate the token Claude Code holds and force a
re-login. Instead we depend on Claude Code to keep the credentials file fresh.
