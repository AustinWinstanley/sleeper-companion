import Foundation

/// One starting slot: the slot label from the league's roster positions, the player's short
/// name (empty until the app has downloaded the player directory), and this week's points.
struct StarterLine: Codable, Hashable {
    let slot: String
    let name: String
    let points: Double

    /// Sleeper's longer slot names don't fit a 34 pt column.
    var shortSlot: String {
        switch slot {
        case "SUPER_FLEX":
            return "SFLX"
        case "REC_FLEX":
            return "RFLX"
        case "WRRB_FLEX":
            return "W/R"
        case "IDP_FLEX":
            return "IDP"
        default:
            return slot
        }
    }
}

/// One side of a matchup, flattened to what the views need. Codable so it can be cached.
struct TeamSummary: Codable, Hashable {
    let teamName: String
    let ownerName: String
    let avatarURL: URL?
    let points: Double
    let record: String
    /// Standing in the league: wins, then season points for. nil only if the roster is missing.
    let rank: Int?
    let matchupID: Int?
    let starters: [StarterLine]

    /// "2-0 · 3rd"
    var recordWithRank: String {
        guard let rank else {
            return record
        }
        return "\(record) · \(rank.ordinal)"
    }
}

struct MatchupSnapshot: Codable, Hashable {
    let leagueID: String
    let leagueName: String
    let week: Int
    let playoffWeekStart: Int?
    let mine: TeamSummary
    /// nil means bye week.
    let theirs: TeamSummary?
    let fetchedAt: Date

    var isBye: Bool {
        return theirs == nil
    }

    /// Ties count as leading so the bold score never disappears from both sides.
    var iAmLeading: Bool {
        guard let theirs else {
            return true
        }
        return mine.points >= theirs.points
    }

    /// "Playoffs in 3 wks" during the regular season, "Playoffs" once they start.
    var playoffLabel: String? {
        guard let playoffWeekStart else {
            return nil
        }
        let weeks = playoffWeekStart - week
        if weeks <= 0 {
            return "Playoffs"
        }
        return "Playoffs in \(weeks) wk\(weeks == 1 ? "" : "s")"
    }

    /// Deep link the widget hands to the app, which forwards to Sleeper.
    var sleeperHandoffURL: URL? {
        return URL(string: "sleepercompanion://sleeper?league=\(leagueID)")
    }
}

enum MatchupError: LocalizedError {
    case noRoster(leagueName: String)

    var errorDescription: String? {
        switch self {
        case .noRoster(let leagueName):
            return "You don't have a team in \(leagueName)"
        }
    }
}

/// Builds the matchup snapshot for one user in one league, plus standings and starting lineups.
/// `load` does the fetching; `build` is pure so it can be tested with canned payloads.
enum MatchupLoader {
    static func load(leagueID: String, userID: String) async throws -> MatchupSnapshot {
        // Week comes from NFL state so nobody has to touch anything each Tuesday.
        let state = try await SleeperAPI.nflState()
        let week = state.currentWeek

        async let leagueTask = SleeperAPI.league(leagueID)
        async let usersTask = SleeperAPI.users(inLeague: leagueID)
        async let rostersTask = SleeperAPI.rosters(inLeague: leagueID)
        async let rowsTask = SleeperAPI.matchups(inLeague: leagueID, week: week)
        let (league, users, rosters, rows) = try await (leagueTask, usersTask, rostersTask, rowsTask)

        return try build(league: league, users: users, rosters: rosters, rows: rows,
                         week: week, userID: userID, playerNames: PlayerDirectory.names())
    }

    static func build(league: League, users: [SleeperUser], rosters: [Roster], rows: [MatchupRow],
                      week: Int, userID: String, playerNames: [String: String], now: Date = .now) throws -> MatchupSnapshot {
        guard let myRoster = rosters.first(where: { $0.isOwned(by: userID) }) else {
            throw MatchupError.noRoster(leagueName: league.name)
        }

        // Standings the way Sleeper orders them: wins, then season points for.
        let standings = rosters.sorted { left, right in
            let leftWins = left.settings?.wins ?? 0
            let rightWins = right.settings?.wins ?? 0
            if leftWins != rightWins {
                return leftWins > rightWins
            }
            return left.pointsFor > right.pointsFor
        }
        let context = DescribeContext(users: users, rows: rows, standings: standings,
                                      slots: league.starterSlots, playerNames: playerNames)

        let mine = describe(myRoster, context)

        // Opponent is the other roster sharing my matchup_id; no matchup_id means bye week.
        var theirs: TeamSummary? = nil
        if let matchupID = mine.matchupID {
            let opponentRow = rows.first { $0.matchupID == matchupID && $0.rosterID != myRoster.rosterID }
            if let opponentRow, let opponentRoster = rosters.first(where: { $0.rosterID == opponentRow.rosterID }) {
                theirs = describe(opponentRoster, context)
            }
        }

        return MatchupSnapshot(leagueID: league.leagueID, leagueName: league.name, week: week,
                               playoffWeekStart: league.settings?.playoffWeekStart,
                               mine: mine, theirs: theirs, fetchedAt: now)
    }

    private struct DescribeContext {
        let users: [SleeperUser]
        let rows: [MatchupRow]
        let standings: [Roster]
        let slots: [String]
        let playerNames: [String: String]
    }

    private static func describe(_ roster: Roster, _ context: DescribeContext) -> TeamSummary {
        let owner = context.users.first { $0.userID == roster.ownerID }
        let row = context.rows.first { $0.rosterID == roster.rosterID }
        let rank = context.standings.firstIndex { $0.rosterID == roster.rosterID }.map { $0 + 1 }

        // starters, starters_points and the league's starting slots are index-aligned.
        var starters: [StarterLine] = []
        let ids = row?.starters ?? []
        let points = row?.startersPoints ?? []
        for (index, playerID) in ids.enumerated() {
            let slot = index < context.slots.count ? context.slots[index] : "FLEX"
            var name = context.playerNames[playerID] ?? ""
            if playerID == "0" {
                name = "Empty"
            }
            starters.append(StarterLine(slot: slot, name: name, points: index < points.count ? points[index] : 0))
        }

        return TeamSummary(
            teamName: owner?.teamName ?? "Team \(roster.rosterID)",
            ownerName: owner?.displayName ?? "",
            avatarURL: owner?.avatarURL,
            points: row?.score ?? 0,
            record: roster.record,
            rank: rank,
            matchupID: row?.matchupID,
            starters: starters
        )
    }
}

extension Int {
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
