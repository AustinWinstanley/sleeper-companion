import Foundation

// Small pure helpers that turn the week's extra data (schedule, bracket, transactions)
// into the lines and numbers the snapshot carries. Pure so they can be tested directly.

/// iOS grants a widget a limited number of refreshes per day. Spend them when scores can
/// change: every 15 minutes while games are live, a little slower on a game day before
/// kickoff (the schedule has dates but no kickoff times), and rarely otherwise.
enum RefreshPolicy {
    static let defaultInterval: TimeInterval = 15 * 60
    static let liveInterval: TimeInterval = 15 * 60
    static let gameDayInterval: TimeInterval = 20 * 60
    static let idleInterval: TimeInterval = 2 * 60 * 60

    static func interval(games: [ScheduledGame], week: Int, now: Date = .now) -> TimeInterval {
        let thisWeek = games.filter { $0.week == week }
        if thisWeek.isEmpty {
            // No schedule: behave as before it existed.
            return defaultInterval
        }
        if thisWeek.contains(where: { $0.gameStatus == .live }) {
            return liveInterval
        }
        let today = easternDateString(now)
        if thisWeek.contains(where: { $0.gameStatus == .upcoming && $0.date == today }) {
            return gameDayInterval
        }
        return idleInterval
    }

    /// Schedule dates are US Eastern calendar days.
    static func easternDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum BracketDescriber {
    struct Description: Equatable {
        var round: String?
        var path: [String] = []
    }

    /// Where a roster stands in the winners bracket for the given week. Round 1 is played in
    /// the league's first playoff week. Returns nothing before playoffs or without a bracket.
    static func describe(bracket: [BracketMatch], rosterID: Int, week: Int, playoffWeekStart: Int?,
                         teamNames: [Int: String]) -> Description {
        guard let playoffWeekStart, week >= playoffWeekStart, !bracket.isEmpty else {
            return Description()
        }
        let currentRound = week - playoffWeekStart + 1
        let lastRound = bracket.map { $0.round }.max() ?? currentRound
        let mine = bracket
            .filter { $0.teamOne == rosterID || $0.teamTwo == rosterID }
            .sorted { $0.round < $1.round }

        var description = Description()
        for match in mine where match.round <= currentRound {
            let opponentID = match.teamOne == rosterID ? match.teamTwo : match.teamOne
            let opponent = opponentID.flatMap { teamNames[$0] } ?? "TBD"
            let name = roundName(match, lastRound: lastRound)
            if match.winner == rosterID {
                description.path.append("\(name): beat \(opponent)")
            } else if match.winner != nil {
                description.path.append("\(name): lost to \(opponent)")
            } else {
                description.path.append("\(name): vs \(opponent)")
            }
            if match.round == currentRound {
                description.round = name
            }
        }

        if description.round == nil {
            // Not playing in the bracket this week: either seeded past this round or out of it.
            let playsLater = mine.contains { $0.round > currentRound }
            description.round = playsLater ? "Playoff bye" : "Consolation"
        }
        return description
    }

    private static func roundName(_ match: BracketMatch, lastRound: Int) -> String {
        if let place = match.place {
            return place == 1 ? "Championship" : "\(place.ordinal) place game"
        }
        switch lastRound - match.round {
        case 1:
            return "Semifinal"
        case 2:
            return "Quarterfinal"
        default:
            return "Round \(match.round)"
        }
    }
}

enum TransactionDescriber {
    /// "7 moves · Bravo added J. Smith". Counts only completed transactions; failed waiver
    /// claims are noise. nil when nothing has happened this week.
    static func line(transactions: [LeagueTransaction], teamNames: [Int: String], playerNames: [String: String]) -> String? {
        let completed = transactions.filter { $0.status == "complete" }
        guard let latest = completed.max(by: { ($0.statusUpdated ?? 0) < ($1.statusUpdated ?? 0) }) else {
            return nil
        }
        let count = "\(completed.count) move\(completed.count == 1 ? "" : "s")"
        return "\(count) · \(describe(latest, teamNames: teamNames, playerNames: playerNames))"
    }

    private static func describe(_ transaction: LeagueTransaction, teamNames: [Int: String], playerNames: [String: String]) -> String {
        let teams = (transaction.rosterIDs ?? []).map { teamNames[$0] ?? "Team \($0)" }
        if transaction.type == "trade" {
            return "Trade: \(teams.joined(separator: " ↔ "))"
        }
        let team = teams.first ?? "Someone"
        if let added = transaction.adds?.keys.sorted().first {
            return "\(team) added \(playerNames[added] ?? "a player")"
        }
        if let dropped = transaction.drops?.keys.sorted().first {
            return "\(team) dropped \(playerNames[dropped] ?? "a player")"
        }
        return "\(team) made a move"
    }
}
