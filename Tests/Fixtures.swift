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

    static func build(userID: String, playerNames: [String: String] = Fixtures.playerNames) throws -> MatchupSnapshot {
        return try MatchupLoader.build(league: league, users: users, rosters: rosters, rows: rows,
                                       week: 3, userID: userID, playerNames: playerNames)
    }
}
