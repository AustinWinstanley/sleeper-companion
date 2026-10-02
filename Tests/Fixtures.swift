import Foundation
@testable import SleeperCompanion

/// Canned Sleeper payloads, shaped like the real API responses, decoded through the app's models
/// so the tests cover decoding as well as the logic.
enum Fixtures {
    static func decode<Value: Decodable>(_ json: String) throws -> Value {
        return try JSONDecoder().decode(Value.self, from: Data(json.utf8))
    }

    static let league: League = try! decode("""
    {
      "league_id": "L1",
      "name": "Test League",
      "season": "2026",
      "status": "in_season",
      "settings": { "playoff_week_start": 15 },
      "scoring_settings": { "rec": 1.0, "pass_td": 4 },
      "roster_positions": ["QB", "RB", "WR", "FLEX", "BN", "BN", "IR"]
    }
    """)

    static let users: [SleeperUser] = try! decode("""
    [
      { "user_id": "U1", "username": "alpha", "display_name": "Alpha", "avatar": "aaa",
        "metadata": { "team_name": "Alpha Team", "avatar": "https://sleepercdn.com/uploads/alpha.jpg" } },
      { "user_id": "U2", "username": "bravo", "display_name": "Bravo", "avatar": "bbb",
        "metadata": { "team_name": "" } },
      { "user_id": "U3", "username": "charlie", "display_name": "Charlie", "avatar": null, "metadata": null },
      { "user_id": "U4", "username": "delta", "display_name": "Delta", "avatar": "ddd", "metadata": {} }
    ]
    """)

    /// Four rosters: U1 vs U2 in matchup 1, U3 on a bye, U4 owned by nobody but co-owned by U5.
    static let rosters: [Roster] = try! decode("""
    [
      { "roster_id": 1, "owner_id": "U1", "co_owners": null,
        "settings": { "wins": 2, "losses": 1, "ties": 0, "fpts": 300, "fpts_decimal": 50 } },
      { "roster_id": 2, "owner_id": "U2", "co_owners": null,
        "settings": { "wins": 2, "losses": 1, "ties": 0, "fpts": 310, "fpts_decimal": 5 } },
      { "roster_id": 3, "owner_id": "U3", "co_owners": null,
        "settings": { "wins": 3, "losses": 0, "ties": 0, "fpts": 250, "fpts_decimal": 0 } },
      { "roster_id": 4, "owner_id": null, "co_owners": ["U5"],
        "settings": { "wins": 0, "losses": 2, "ties": 1, "fpts": 100, "fpts_decimal": 99 } }
    ]
    """)

    static let rows: [MatchupRow] = try! decode("""
    [
      { "roster_id": 1, "matchup_id": 1, "points": 101.5, "custom_points": null,
        "starters": ["P1", "P2", "0", "P4"], "starters_points": [20.0, 15.5, 0, 66.0] },
      { "roster_id": 2, "matchup_id": 1, "points": 90.0, "custom_points": 120.25,
        "starters": ["P5", "P6", "P7", "P8"], "starters_points": [30.0, 30.0, 30.0, 30.25] },
      { "roster_id": 3, "matchup_id": null, "points": 0, "custom_points": null,
        "starters": [], "starters_points": [] },
      { "roster_id": 4, "matchup_id": 2, "points": 55.0, "custom_points": null,
        "starters": ["P9"], "starters_points": [55.0] }
    ]
    """)

    static let playerNames = ["P1": "J. Allen", "P2": "S. Barkley", "P4": "J. Chase", "P5": "P. Mahomes"]

    /// Week 3 slate: BUF already played, PHI is live, CIN and KC play later, DAL is on bye
    /// (absent from the week). The week 2 game must be ignored.
    static let games: [ScheduledGame] = try! decode("""
    [
      { "week": 2, "home": "KC", "away": "CIN", "date": "2026-09-20", "status": "complete" },
      { "week": 3, "home": "BUF", "away": "MIA", "date": "2026-09-24", "status": "complete" },
      { "week": 3, "home": "PHI", "away": "NYG", "date": "2026-09-27", "status": "in_progress" },
      { "week": 3, "home": "CIN", "away": "CLE", "date": "2026-09-27", "status": "pre_game" },
      { "week": 3, "home": "KC", "away": "LV", "date": "2026-09-28", "status": "pre_game" }
    ]
    """)

    /// Roster 1 starts P1 (BUF, final), P2 (PHI, live), an empty slot, P4 (CIN, upcoming, questionable).
    /// Roster 2 starts P5 (KC, upcoming), P6 (DAL, bye), P7 (CIN, out), P8 (no team known).
    static let projections: [String: PlayerProjection] = [
        "P1": PlayerProjection(ppr: 22, half: 21, std: 20, team: "BUF", injury: nil),
        "P2": PlayerProjection(ppr: 18, half: 16, std: 14, team: "PHI", injury: nil),
        "P4": PlayerProjection(ppr: 17.5, half: 15, std: 12.5, team: "CIN", injury: "Questionable"),
        "P5": PlayerProjection(ppr: 24, half: 24, std: 24, team: "KC", injury: nil),
        "P6": PlayerProjection(ppr: nil, half: nil, std: nil, team: "DAL", injury: nil),
        "P7": PlayerProjection(ppr: 9, half: 8, std: 7, team: "CIN", injury: "Out"),
    ]

    static let transactions: [LeagueTransaction] = try! decode("""
    [
      { "type": "waiver", "status": "failed", "adds": { "P9": 1 }, "drops": null, "roster_ids": [1], "status_updated": 900 },
      { "type": "free_agent", "status": "complete", "adds": { "P4": 2 }, "drops": { "P8": 2 }, "roster_ids": [2], "status_updated": 100 },
      { "type": "trade", "status": "complete", "adds": { "P1": 3 }, "drops": null, "roster_ids": [1, 3], "status_updated": 500 }
    ]
    """)

    /// Six-team bracket shape from the live API: rosters 3 and 1 have first-round byes.
    static let bracket: [BracketMatch] = try! decode("""
    [
      { "m": 1, "r": 1, "t1": 2, "t2": 4, "w": 2, "l": 4 },
      { "m": 2, "r": 2, "t1": 3, "t2": 2, "w": null, "l": null, "t2_from": { "w": 1 } },
      { "m": 3, "r": 2, "t1": 1, "t2": null, "w": null, "l": null },
      { "m": 4, "r": 3, "t1": null, "t2": null, "w": null, "l": null, "p": 1 },
      { "m": 5, "r": 3, "t1": null, "t2": null, "w": null, "l": null, "p": 3 }
    ]
    """)

    static var fullContext: WeekContext {
        return WeekContext(playerNames: playerNames, playerTeams: ["P8": "FA"], projections: projections,
                           games: games, transactions: transactions, bracket: bracket)
    }

    /// Names only by default, which is what the widget has when every optional fetch fails.
    static func build(userID: String, week: Int = 3,
                      context: WeekContext = WeekContext(playerNames: Fixtures.playerNames)) throws -> MatchupSnapshot {
        return try MatchupLoader.build(league: league, users: users, rosters: rosters, rows: rows,
                                       week: week, userID: userID, context: context)
    }
}
