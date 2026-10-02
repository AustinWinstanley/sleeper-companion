import Foundation

// The flattened, cacheable result of a fetch: everything the views draw, nothing they compute.

/// One starting slot: the slot label from the league's roster positions, the player's short
/// name (empty until the app has downloaded the player directory), this week's points, and
/// when available the projection, injury status and where the player's game stands.
struct StarterLine: Codable, Hashable {
    let slot: String
    let name: String
    let points: Double
    var projected: Double? = nil
    var injury: String? = nil
    var status: GameStatus = .unknown

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

    /// Short flag next to the name. Injury flags stop mattering once the game has kicked off.
    var tag: String? {
        if name == "Empty" {
            return nil
        }
        if status == .bye {
            return "BYE"
        }
        if status == .live || status == .final {
            return nil
        }
        switch injury {
        case "Out":
            return "O"
        case "Doubtful":
            return "D"
        case "Questionable":
            return "Q"
        case "IR":
            return "IR"
        case "PUP":
            return "PUP"
        case "Sus":
            return "SUS"
        default:
            return nil
        }
    }

    /// A slot that will score nothing unless the lineup changes: empty, on bye, or ruled out.
    var isUnavailable: Bool {
        if status == .live || status == .final {
            return false
        }
        if name == "Empty" || status == .bye {
            return true
        }
        return ["Out", "IR", "PUP", "Sus"].contains(injury ?? "")
    }

    /// Before kickoff the row shows the projection; from kickoff on, real points.
    var showsProjection: Bool {
        return status == .upcoming && projected != nil
    }

    var displayPoints: Double {
        if showsProjection, let projected {
            return projected
        }
        return points
    }

    /// This slot's contribution to the projected total. Without a game clock a live player is
    /// taken as the better of actual and projection, which undercounts a hot start slightly.
    var expectedPoints: Double {
        switch status {
        case .final, .bye:
            return points
        case .upcoming:
            return projected ?? points
        case .live, .unknown:
            return max(points, projected ?? points)
        }
    }
}

/// One side of a matchup.
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
    /// nil when no projections were available.
    var projectedTotal: Double? = nil

    /// "2-0 · 3rd"
    var recordWithRank: String {
        guard let rank else {
            return record
        }
        return "\(record) · \(rank.ordinal)"
    }

    /// Starters whose game hasn't finished.
    var remaining: Int {
        return starters.filter { $0.status == .upcoming || $0.status == .live }.count
    }

    var hasGameInfo: Bool {
        return starters.contains { $0.status != .unknown }
    }

    var unavailableStarters: Int {
        return starters.filter { $0.isUnavailable }.count
    }

    /// "5 left · proj 118.4", "Final", or nil when neither schedule nor projections loaded.
    var statusLine: String? {
        var parts: [String] = []
        if hasGameInfo {
            parts.append(remaining == 0 ? "Final" : "\(remaining) left")
        }
        if let projectedTotal, remaining > 0 || !hasGameInfo {
            parts.append("proj \(projectedTotal.formatted(.number.precision(.fractionLength(1))))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct StandingLine: Codable, Hashable {
    let rank: Int
    let teamName: String
    let record: String
    let pointsFor: Double
    let isMine: Bool
    let isOpponent: Bool
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
    var standings: [StandingLine] = []
    /// "7 moves · Bravo added J. Smith"
    var transactionLine: String? = nil
    /// "Semifinal", "Championship", "Consolation"; nil in the regular season.
    var playoffRound: String? = nil
    /// One line per playoff game so far, oldest first: "Quarterfinal: beat Bravo".
    var bracketPath: [String] = []
    /// How soon the widget should ask for its next refresh, from the NFL schedule.
    var refreshInterval: TimeInterval = RefreshPolicy.defaultInterval

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

    /// The playoff round once playoffs start, a countdown before that.
    var playoffLabel: String? {
        if let playoffRound {
            return playoffRound
        }
        guard let playoffWeekStart else {
            return nil
        }
        let weeks = playoffWeekStart - week
        if weeks <= 0 {
            return "Playoffs"
        }
        return "Playoffs in \(weeks) wk\(weeks == 1 ? "" : "s")"
    }

    /// "2 starters out" when my lineup has slots that will score nothing.
    var starterWarning: String? {
        let count = mine.unavailableStarters
        if count == 0 {
            return nil
        }
        return "\(count) starter\(count == 1 ? "" : "s") out"
    }

    /// Deep link the widget hands to the app, which forwards to Sleeper.
    var sleeperHandoffURL: URL? {
        return URL(string: "sleepercompanion://sleeper?league=\(leagueID)")
    }
}

extension Int {
    var ordinal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
