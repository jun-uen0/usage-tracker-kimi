# Kimi Usage Tracker

A lightweight macOS menu bar app that shows your [Kimi Code](https://www.kimi.com/code/) quota at a glance — the Kimi counterpart to menu bar trackers like Claude Usage Tracker.

The menu bar shows how much of your 5-hour window you have used — matching the percentage on the official quota page — in one of two styles: percent capsule or battery-style bar, switchable from the app's panel. Click it for per-window details: per-window gauge bars, used / limit, reset times, plus a shortcut that opens the official quota page.

## Menu bar styles

Pick the style from the segmented control at the top of the panel; the choice is remembered across launches.

- **Percent** (default): a capsule with the used percentage, e.g. `61%`.
- **Bar**: a battery-style capsule that fills up as the window is used.

The percentage and the gauge fill both follow the official page and show **usage** (how much is consumed), not remaining. If the API ever reports a weekly (or other long) window without a 5-hour one, the longest window is shown with a small `W` marker, in every style. When the app can't refresh, the last good value stays on screen dimmed.

## Why there is no monthly total

The official subscription page shows an additional **monthly total usage** figure next to the 5-hour window. That number comes from a web-only API (`GetSubscriptionStats` on `www.kimi.ai`) that requires the browser session's ES256 token — the CLI's access token is rejected (`signing method ES256 is invalid`), and no monthly figure exists on the CLI-accessible `coding/v1/usages` endpoint (its `totalQuota` is empty and `limits[]` only carries rate windows). The 5-hour percentage from `/usages` matches the site's integer part (the site computes decimals from internal units the API does not expose). For the monthly total, use the panel's "Open official quota page" button. This limitation is shared by other trackers, e.g. [onWatch](https://github.com/onllm-dev/onWatch/blob/main/docs/KIMI_SETUP.md).

## How it works

- Reads the access token from the Kimi Code CLI's own sign-in state (`$KIMI_CODE_HOME/credentials` or `~/.kimi-code/credentials`).
- Calls `GET https://api.kimi.ai/coding/v1/usages` every 60 seconds and renders whatever windows (`limits[]`) the response contains — typically the 5-hour window, and the weekly window when present.
- Only the **access token** and its expiry are read. The refresh token is never touched, the credentials file is never written, and the token is never stored or logged by this app. Credentials are re-read on every cycle because the CLI rotates short-lived tokens.
- When the token lapses (the CLI renews it the next time you use it), the last good values stay on screen **dimmed** until a fresh read succeeds. On any failure — expired sign-in, network error, unrecognized response format — the app degrades to stale data instead of inventing numbers.
- The bar gauge is pre-rendered into a template `NSImage` with `ImageRenderer` because `MenuBarExtra` labels ignore fixed frames on arbitrary SwiftUI content (text sizes naturally, shapes collapse). Template rendering keeps it readable in both light and dark menu bars.

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
- Weekly-window presentation: the panel already renders any window the API returns, but the current account's `/usages` response only ever carries the 5-hour window. Surfacing a weekly limit needs either Kimi to expose it on this endpoint or a separate data source; tracked as an open question.

## Acknowledgments

The quota protocol (endpoint, credentials location, expired-token behavior) was informed by [CC Quota](https://github.com/Robin0725/cc-quota) (MIT).

## License

MIT. Not affiliated with or endorsed by Moonshot AI. Kimi is a trademark of its respective owner.
