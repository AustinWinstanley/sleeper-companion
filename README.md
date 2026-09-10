# Sleeper Companion

iOS Home Screen and Lock Screen widgets for your [Sleeper](https://sleeper.com) fantasy football matchup: live-ish scores, records and rank, starting lineups, and a one-tap jump into the Sleeper app.

An unofficial personal project, built for one league's group of friends. Not affiliated with Sleeper. See the [disclaimer](#disclaimer) below.

<p align="center">
  <img src="docs/screenshots/home-screen.jpg" width="300" alt="Home Screen: small, medium and large matchup widgets showing scores, records, rank, week, playoff countdown and both starting lineups">
  &nbsp;&nbsp;&nbsp;
  <img src="docs/screenshots/lock-screen.jpg" width="300" alt="Lock Screen: two Team Panel widgets side by side, one per team, showing score, top scorers and record">
</p>

## What it does

- **Setup in one step.** Type your Sleeper username, confirm the account, done. No login, no password, no server.
- **Home Screen widgets** in small, medium and large: score vs opponent with the leader in bold, record and league rank, week, playoff countdown, and in the large size both starting lineups with per-player points.
- **Lock Screen widgets**: a matchup summary, a score-share gauge, an inline line above the clock, and a **Team Panel** you place twice (yours and your opponent's) to use the whole row. iOS has no full-width Lock Screen widget, so this is how you get one.
- **Multiple leagues.** Long-press any widget to pick the league. With one league there is nothing to choose.
- **Tap to open Sleeper.** Any widget hands off to the Sleeper app.
- **Degrades gracefully.** The last good scores are cached and shown marked "Cached" when a refresh fails.

## How it's built

SwiftUI + WidgetKit + AppIntents, iOS 17+, no third-party dependencies. About 1,900 lines of Swift.

- `App/` is the app: username setup, a live preview of every widget layout, league selection.
- `Widget/` is the extension: two widget kinds, each configured through an `AppIntent` whose league options come from the Sleeper API and are cached for offline resolution.
- `Shared/` compiles into both targets: a small typed client for Sleeper's public REST API, the matchup logic (pairing rosters by `matchup_id`, standings from wins then points-for, lineups aligned to the league's roster slots), App Group + iCloud key-value storage, the cache, and the SwiftUI layouts.

A few decisions worth calling out:

- **Player names without blowing the widget memory budget.** Sleeper's player list is ~15 MB. Only the app downloads it, at most once a day, and writes a ~200 KB id-to-name map into the App Group. Widgets read that. Until the app has run once, lineups show slot labels instead of names.
- **One fetch path for everything.** All widget kinds and the in-app preview go through the same loader, so a Home Screen widget, two Lock Screen panels and the app share a cached snapshot rather than multiplying API calls.
- **Refresh is honest.** iOS budgets widget refreshes to roughly every 15 to 30 minutes. The widget asks for that and labels stale data rather than pretending to be live. A true live view would be a Live Activity fed by push, which needs a server and is out of scope.
- **Accented rendering.** With Tinted or Clear icon styles iOS strips widget backgrounds and repaints in one tint. Scores and headers are marked accentable and avatars opt back into full color, so the widget reads well in every style.
- **No hardcoded IDs.** The only per-fork values are the bundle ID and team ID in `project.yml`; App Group, iCloud and URL scheme identifiers derive from them at build and run time.

## Build it

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate
open SleeperCompanion.xcodeproj
```

Unit tests cover the matchup logic (opponent pairing, byes, co-owners, standings, lineup alignment) and model decoding against canned API payloads. Run them with ⌘U or:

```bash
xcodebuild test -project SleeperCompanion.xcodeproj -scheme SleeperCompanion -destination 'platform=iOS Simulator,name=iPhone 16'
```

CI runs the same on every push.

To run on your own devices, change `APP_BUNDLE_ID` and `DEVELOPMENT_TEAM` at the top of `project.yml`. Signing is automatic. Distribution to friends is via TestFlight external testing; builds expire after 90 days, so bump `CURRENT_PROJECT_VERSION` and re-upload a couple of times a season.

## Ideas

Things that would be fun to add. Most wait on data the public API doesn't expose, which is part of why they're interesting.

- **Projections and win probability** next to the live score. The public API has neither, so the widget only shows what has actually happened.
- **A Live Activity during game windows**: full width on the Lock Screen and in the Dynamic Island, fed by push so it stays current instead of waiting on the widget refresh budget.
- **Deep link straight to the matchup.** Sleeper's universal links cover chat, so a widget tap currently lands on the app's home screen.
- **Player headshots** in the large lineup view, and a **yet-to-play** count per side, which needs game status.
- **Extra-large widget** (iOS 27) with league standings under the lineups.
- **Flip leagues from the widget** with an interactive button instead of the configuration sheet.

## Disclaimer

This project is not made, endorsed or supported by Sleeper (Blitz Studios, Inc.). "Sleeper" is a trademark of its owner and is used here only to describe what the app connects to; the icon and all artwork in this repository are original. The app uses only Sleeper's public, unauthenticated API, never handles Sleeper credentials, and is distributed privately to a handful of friends. It will not be published to the App Store. If you are the rights holder and want anything changed or removed, open an issue and it will be handled promptly.
