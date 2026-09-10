# Kimi Usage Tracker

A lightweight macOS menu bar app that shows your [Kimi Code](https://www.kimi.com/code/) quota at a glance — the Kimi counterpart to menu bar trackers like Claude Usage Tracker.

The menu bar shows a small capsule with the remaining percentage of your 5-hour window. Click it for per-window details: used / limit, remaining percent, and reset times.

## How it works

- Reads the access token from the Kimi Code CLI's own sign-in state (`$KIMI_CODE_HOME/credentials` or `~/.kimi-code/credentials`).
- Calls `GET https://api.kimi.ai/coding/v1/usages` every 60 seconds and renders whatever windows (`limits[]`) the response contains — typically the 5-hour window, and the weekly window when present.
- Only the **access token** and its expiry are read. The refresh token is never touched, the credentials file is never written, and the token is never stored or logged by this app. Credentials are re-read on every cycle because the CLI rotates short-lived tokens.
- When the token lapses (the CLI renews it the next time you use it), the last good values stay on screen **dimmed** until a fresh read succeeds. On any failure — expired sign-in, network error, unrecognized response format — the app degrades to stale data instead of inventing numbers.

## Privacy boundary

- Reads local sign-in state only to request quota.
- Sends the access token only to Kimi's quota endpoint.
- Persists only the last good quota snapshot (numbers and timestamps) under `~/Library/Application Support/usage-tracker-kimi/` so stale display survives restarts.
- No telemetry, analytics, crash reporting, or third-party tracking.

## Requirements

- macOS 13 or later
- A signed-in [Kimi Code](https://www.kimi.com/code/) CLI on the same Mac
- Swift toolchain (Xcode or Command Line Tools) to build

## Build & run

```sh
scripts/make_app.sh
open build/KimiUsageTracker.app
```

`make_app.sh` compiles a release binary, bundles it as `KimiUsageTracker.app` (with `LSUIElement` so it stays out of the Dock), and ad-hoc signs it. To stop the app, use the Quit button in its panel, or `pkill -f KimiUsageTracker`.

## Roadmap

- Signed and notarized releases via GitHub Actions
- Launch at login
- Richer weekly-window presentation

## Acknowledgments

The quota protocol (endpoint, credentials location, expired-token behavior) was informed by [CC Quota](https://github.com/Robin0725/cc-quota) (MIT).

## License

MIT. Not affiliated with or endorsed by Moonshot AI. Kimi is a trademark of its respective owner.
