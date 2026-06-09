#!/usr/bin/env python3
# Claude Usage — macOS menu-bar widget (SwiftBar / xbar plugin)
#
# Shows the rolling 5-hour subscription limit %, a live-ish countdown to its
# reset, and the 7-day limit %. Mirrors the Windows pill (claude-usage-pill.ps1):
# same color thresholds, same resilient backoff so we never hammer the
# rate-limited usage endpoint.
#
# Install: drop this file in your SwiftBar plugin folder (filename must keep the
#   ".60s.py" suffix so SwiftBar refreshes every 60s) and `chmod +x` it.
#   Works with xbar too. See macos/README.md.
#
# It runs fresh on every refresh, so last-good values and the backoff schedule
# are persisted in a small cache file between runs.
#
# <xbar.title>Claude Usage</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>savaroma</xbar.author>
# <xbar.desc>Claude subscription limit usage (5h / 7d) in the menu bar.</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

API_URL = "https://api.anthropic.com/api/oauth/usage"
BETA = "oauth-2025-04-20"
POLL = 60                       # normal cadence (matches the .60s. filename)
TIMEOUT = 15
KEYCHAIN_SERVICE = "Claude Code-credentials"
CRED_FILE = os.path.expanduser("~/.claude/.credentials.json")
CACHE = os.path.expanduser("~/Library/Caches/claude-usage-widget/state.json")
REPO = "https://github.com/savaroma/claude-usage-widget"

# colored dots instead of menu-bar text color: they render in color in both
# light and dark menu bars, and let each segment carry its own status.
DOT = {"green": "\U0001F7E2", "yellow": "\U0001F7E1",
       "orange": "\U0001F7E0", "red": "\U0001F534", "gray": "⚪"}


def dot_for(pct):
    if pct is None or pct < 0:
        return DOT["gray"]
    if pct >= 90:
        return DOT["red"]
    if pct >= 70:
        return DOT["orange"]
    if pct >= 40:
        return DOT["yellow"]
    return DOT["green"]


# ---- token ---------------------------------------------------------------
def read_token():
    """Return (access_token, meta) from Keychain, falling back to the file.
    meta carries expiresAt/subscriptionType when available. ('', {}) if none."""
    # 1) Keychain (the usual place on macOS)
    try:
        out = subprocess.run(
            ["security", "find-generic-password",
             "-s", KEYCHAIN_SERVICE, "-a", os.environ.get("USER", ""), "-w"],
            capture_output=True, text=True, timeout=10)
        if out.returncode == 0 and out.stdout.strip():
            oa = json.loads(out.stdout).get("claudeAiOauth", {})
            if oa.get("accessToken"):
                return oa["accessToken"], oa
    except Exception:
        pass
    # 2) Fallback file
    try:
        with open(CRED_FILE) as f:
            oa = json.load(f).get("claudeAiOauth", {})
            if oa.get("accessToken"):
                return oa["accessToken"], oa
    except Exception:
        pass
    return "", {}


# ---- network -------------------------------------------------------------
def fetch(token):
    """Return (data_dict_or_None, http_status_or_0)."""
    req = urllib.request.Request(API_URL, headers={
        "Authorization": "Bearer " + token,
        "anthropic-beta": BETA,
    })
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return json.loads(r.read().decode("utf-8")), r.status
    except urllib.error.HTTPError as e:
        return None, e.code
    except Exception:
        return None, 0


# ---- parsing / formatting ------------------------------------------------
def util(section):
    if isinstance(section, dict) and section.get("utilization") is not None:
        return int(round(float(section["utilization"])))
    return None


def parse_dt(s):
    if not s:
        return None
    try:
        # normalize Z and trim fractional seconds to 6 digits for 3.9's fromisoformat
        s = s.replace("Z", "+00:00")
        s = re.sub(r"\.(\d{6})\d+", r".\1", s)
        return datetime.fromisoformat(s)
    except Exception:
        return None


def countdown(resets_at, now_ts):
    """Compact time-until-reset, e.g. '2h13m', '47m', '<1m', 'resetting...'."""
    dt = parse_dt(resets_at)
    if not dt:
        return None
    secs = dt.timestamp() - now_ts
    if secs <= 0:
        return "resetting…"
    if secs < 60:
        return "<1m"
    mins = int(secs // 60)
    if mins < 60:
        return "%dm" % mins
    return "%dh%02dm" % (mins // 60, mins % 60)


def reset_abs(resets_at):
    """Absolute reset time in local zone, e.g. 'today 14:30' / 'Sun 10:00'."""
    dt = parse_dt(resets_at)
    if not dt:
        return None
    loc = dt.astimezone()
    today = datetime.now().astimezone().date()
    day = "today" if loc.date() == today else loc.strftime("%a %d %b")
    return "%s %s" % (day, loc.strftime("%H:%M"))


# ---- cache ---------------------------------------------------------------
def load_state():
    try:
        with open(CACHE) as f:
            return json.load(f)
    except Exception:
        return {"good": None, "fails": 0, "next_allowed": 0, "why": ""}


def save_state(st):
    try:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE, "w") as f:
            json.dump(st, f)
    except Exception:
        pass


# ---- main ----------------------------------------------------------------
def main():
    now = time.time()
    st = load_state()
    should_fetch = now >= st.get("next_allowed", 0)
    data, http = None, None

    if should_fetch:
        token, meta = read_token()
        if not token:
            http = -1  # no token at all
        else:
            data, http = fetch(token)
            if http == 401:
                # token went stale: re-read once (Claude Code may have just
                # refreshed it) and retry — do NOT enter the long 429 backoff.
                token, meta = read_token()
                if token:
                    data, http = fetch(token)

    if data is not None:
        st["good"] = {
            "h5": util(data.get("five_hour")),
            "d7": util(data.get("seven_day")),
            "d7s": util(data.get("seven_day_sonnet")),
            "r5": (data.get("five_hour") or {}).get("resets_at"),
            "r7": (data.get("seven_day") or {}).get("resets_at"),
            "r7s": (data.get("seven_day_sonnet") or {}).get("resets_at"),
            "at": now,
        }
        st["fails"] = 0
        st["why"] = ""
        st["next_allowed"] = now + POLL
        stale = False
    elif should_fetch:
        # we tried and failed -> back off (don't hammer the rate-limited API)
        st["fails"] = st.get("fails", 0) + 1
        base = 90 if http == 429 else 20
        wait = int(min(base * (2 ** min(st["fails"] - 1, 3)), 600))
        st["next_allowed"] = now + wait
        st["why"] = ("rate-limited (429)" if http == 429
                     else "no token / Claude Code not logged in" if http == -1
                     else "offline" if http == 0
                     else "stale token (401)" if http == 401
                     else "HTTP %s" % http) + (", retry in %ds" % wait)
        stale = True
    else:
        # inside the normal poll window: show last good untouched. Only flag it
        # stale if it's genuinely old (e.g. SwiftBar was paused / machine slept).
        g = st.get("good")
        age = now - g.get("at", 0) if g else 1e9
        stale = age > POLL * 2.5

    render(st, stale, now)
    save_state(st)


def render(st, stale, now):
    g = st.get("good")
    out = []
    if g:
        h5, d7 = g.get("h5"), g.get("d7")
        cd = countdown(g.get("r5"), now)
        seg5 = "%s 5h %s" % (dot_for(h5), ("%d%%" % h5) if h5 is not None else "—")
        if cd and h5 is not None:
            seg5 += " · " + cd
        seg7 = "%s 7d %s" % (dot_for(d7), ("%d%%" % d7) if d7 is not None else "—")
        line = seg5 + "  " + seg7 + ("  ⚠︎" if stale else "")
        out.append(line + " | font=Menlo size=13")
        out.append("---")
        # dropdown details: default text color (adapts to light/dark menu) with a
        # colored status dot up front, so it stays readable on a white background.
        out.append("%s 5h limit: %s%s" % (
            dot_for(h5),
            ("%d%%" % h5) if h5 is not None else "—",
            ("   resets in %s (%s)" % (countdown(g.get("r5"), now), reset_abs(g.get("r5"))))
            if g.get("r5") else ""))
        out.append("%s 7d limit: %s%s" % (
            dot_for(d7),
            ("%d%%" % d7) if d7 is not None else "—",
            ("   resets %s" % reset_abs(g.get("r7"))) if g.get("r7") else ""))
        d7s = g.get("d7s")
        out.append("%s 7d Sonnet: %s%s" % (
            dot_for(d7s),
            ("%d%%" % d7s) if d7s is not None else "n/a",
            ("   resets %s" % reset_abs(g.get("r7s"))) if g.get("r7s") else ""))
        out.append("---")
        ago = int(now - g.get("at", now))
        if stale:
            out.append("⚠︎ stale: %s | color=#e0a030" % (
                st.get("why") or "no fresh data (%ds old)" % ago))
        out.append("updated %ds ago | color=#999999" % ago)
    else:
        out.append("%s 5h — | font=Menlo size=13" % DOT["gray"])
        out.append("---")
        out.append("No data yet | color=#999999")
        if st.get("why"):
            out.append("%s | color=#e0a030" % st["why"])
    out.append("Refresh now | refresh=true")
    out.append("Open project page | href=%s" % REPO)
    print("\n".join(out))


if __name__ == "__main__":
    main()
