# Sleeper Companion — project context

iOS app + WidgetKit extension showing the user's current Sleeper fantasy football matchup.
Personal, open-source, distributed to friends via TestFlight; never the App Store.
See README.md for the feature list, layout, and fork instructions.

## Fixed facts
- Data source: Sleeper public REST API, `https://api.sleeper.app/v1`, read-only, no auth, all GET/JSON.
  Endpoints used: `/state/nfl`, `/user/{username_or_id}`, `/league/{id}`, `/league/{id}/users`,
  `/league/{id}/rosters`, `/league/{id}/matchups/{week}`, `/user/{user_id}/leagues/nfl/{season}`,
  `/players/nfl` (app only, ~15 MB, slimmed into the App Group; never fetch it from the widget).
- Avatars: user avatar is an ID → `https://sleepercdn.com/avatars/thumbs/{avatar}`;
  team avatar (`user.metadata.avatar`) is already a full URL. Team name is `user.metadata.team_name`,
  fallback `display_name`.
- Matchup pairing: two roster entries share `matchup_id`; `matchup_id == null` means bye week.
  Score is `custom_points ?? points`. Record is in `roster.settings.{wins,losses,ties}`; season points
  are `fpts` + `fpts_decimal/100`. Rosters can have `co_owners`. `starters`/`starters_points` align with
  the league's non-bench `roster_positions`.
- The documented API has no projections, schedule or game status. Undocumented endpoints on
  `https://api.sleeper.app` (no `/v1`) do: `/schedule/nfl/regular/{season}` (status `pre_game`/`complete`,
  dates but no kickoff times; the live status value has not been observed, so anything else is treated
  as live) and `/projections/nfl/{season}/{week}?season_type=regular&position[]=QB` (stats `pts_ppr`,
  `pts_half_ppr`, `pts_std`; `team`; `player.injury_status`). ~2 MB across positions, so fetch one
  position at a time and cache (`ProjectionDirectory`, 3 h). All of it is best effort: failures must
  leave the core matchup working. No win probability and no game clock anywhere.
- Also used: `/league/{id}/transactions/{week}` and `/league/{id}/winners_bracket` (documented).
- iOS widget refresh is OS-budgeted (~15–30 min); scores will lag live games regardless of approach.
- Sleeper's universal links only cover chat pages; `sleeper://` (bare scheme) opens the app.
- Lock Screen has no full-row widget size; the Team Panel kind exists so two copies fill the row.

## Build / identifiers
- XcodeGen: `project.yml` → `xcodegen generate`; the .xcodeproj is gitignored.
- `APP_BUNDLE_ID` and `DEVELOPMENT_TEAM` in project.yml are the only per-fork values. App Group,
  iCloud KVS id, widget bundle id and the `sleepercompanion://` scheme derive from them; Swift derives
  the App Group from the bundle identifier at runtime (see `UserStore`).
- Minimum iOS 17 (AppIntentConfiguration). Widget kinds: `MatchupWidget`, `TeamPanel`.
- `systemExtraLargePortrait` (iOS 27 full-page size) is gated with `#if compiler(>=6.3)` plus
  `#available`, because CI's older Xcode has no such case. Not yet verified on an iOS 27 device.
- Anything shown in Xcode's General tab (display name, app category, version, build) must be set in
  project.yml. Edits made in Xcode are lost on the next `xcodegen generate`.
- Set `TARGETED_DEVICE_FAMILY` per target in project.yml; XcodeGen's target presets override a
  project-level value, and a universal build fails App Store validation on orientations.
- Storage: `user_id` in App Group defaults (source of truth), mirrored to iCloud key-value store.

## Tests / CI
- `Tests/` is a Swift Testing bundle hosted by the app; fixtures are canned API JSON decoded through the
  real models. `MatchupLoader.build` is the pure entry point to test; `load` only fetches. Optional data
  goes in through `WeekContext`. Run `xcodegen generate` after adding a test file.
- `.github/workflows/ci.yml` generates the project and runs `xcodebuild test` on a macOS runner.

## Not done
- Interactive league-flip button; Live Activity (needs a push server); win probability; see README "Ideas".

## Code style
- Always use braces for loops/conditionals, even single-statement bodies.
- No shorthand or abbreviations except very common ones (`i`, `k`/`v`).
- Standard map/filter are fine; avoid passing custom functions as parameters where a plain loop reads better.
- Reasonably terse but readable; not every step needs a named variable.
- Comments that capture the reasoning/pseudocode worked out while solving.
