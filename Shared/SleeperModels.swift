import Foundation

// Only the fields the widget uses are decoded; Sleeper's payloads carry far more.

struct NFLState: Decodable {
    let week: Int?
    let displayWeek: Int?
    let season: String
    let leagueSeason: String?

    enum CodingKeys: String, CodingKey {
        case week
        case displayWeek = "display_week"
        case season
        case leagueSeason = "league_season"
    }

    /// display_week is what the Sleeper app shows; week can lag it. Never below 1.
    var currentWeek: Int {
        return max(displayWeek ?? week ?? 1, 1)
    }

    var currentSeason: String {
        return leagueSeason ?? season
    }
}

struct League: Decodable, Identifiable, Hashable {
    struct Settings: Decodable, Hashable {
        let playoffWeekStart: Int?

        enum CodingKeys: String, CodingKey {
            case playoffWeekStart = "playoff_week_start"
        }
    }

    let leagueID: String
    let name: String
    let season: String
    let status: String?
    let settings: Settings?
    let rosterPositions: [String]?
    let scoringSettings: [String: Double]?

    enum CodingKeys: String, CodingKey {
        case leagueID = "league_id"
        case name
        case season
        case status
        case settings
        case rosterPositions = "roster_positions"
        case scoringSettings = "scoring_settings"
    }

    /// Points per reception: 1 is PPR, 0.5 half, 0 standard. Picks which projection to show.
    var receptionPoints: Double {
        return scoringSettings?["rec"] ?? 0
    }

    var id: String {
        return leagueID
    }

    /// Starting slots in lineup order; matchup `starters` arrays line up with these.
    var starterSlots: [String] {
        return (rosterPositions ?? []).filter { !["BN", "IR", "TAXI"].contains($0) }
    }
}

struct SleeperUser: Decodable, Identifiable, Hashable {
    struct Metadata: Decodable, Hashable {
        let teamName: String?
        let avatar: String?

        enum CodingKeys: String, CodingKey {
            case teamName = "team_name"
            case avatar
        }
    }

    let userID: String
    let username: String?
    let displayName: String?
    let avatar: String?
    let metadata: Metadata?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case displayName = "display_name"
        case avatar
        case metadata
    }

    var id: String {
        return userID
    }

    /// Custom team name, falling back to the display name. Empty strings count as unset.
    var teamName: String? {
        return nonEmpty(metadata?.teamName) ?? nonEmpty(displayName)
    }

    /// Team avatar (metadata.avatar) is already a full URL; user avatar is an ID on the CDN.
    var avatarURL: URL? {
        if let teamAvatar = nonEmpty(metadata?.avatar), let url = URL(string: teamAvatar) {
            return url
        }
        if let avatar = nonEmpty(avatar) {
            return SleeperAPI.avatarCDN.appending(path: avatar)
        }
        return nil
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return value
    }
}

struct Roster: Decodable, Identifiable {
    struct Settings: Decodable {
        let wins: Int?
        let losses: Int?
        let ties: Int?
        let fpts: Int?
        let fptsDecimal: Int?

        enum CodingKeys: String, CodingKey {
            case wins
            case losses
            case ties
            case fpts
            case fptsDecimal = "fpts_decimal"
        }
    }

    let rosterID: Int
    let ownerID: String?
    let coOwners: [String]?
    let settings: Settings?

    enum CodingKeys: String, CodingKey {
        case rosterID = "roster_id"
        case ownerID = "owner_id"
        case coOwners = "co_owners"
        case settings
    }

    var id: Int {
        return rosterID
    }

    func isOwned(by userID: String) -> Bool {
        return ownerID == userID || (coOwners ?? []).contains(userID)
    }

    /// Season points for, split by Sleeper into whole and hundredths.
    var pointsFor: Double {
        return Double(settings?.fpts ?? 0) + Double(settings?.fptsDecimal ?? 0) / 100
    }

    /// "W-L", with "-T" appended only when there are ties.
    var record: String {
        let wins = settings?.wins ?? 0
        let losses = settings?.losses ?? 0
        let ties = settings?.ties ?? 0
        if ties > 0 {
            return "\(wins)-\(losses)-\(ties)"
        }
        return "\(wins)-\(losses)"
    }
}

/// One roster's entry in a week's matchups. Two entries sharing matchup_id are opponents;
/// a nil matchup_id is a bye week.
struct MatchupRow: Decodable {
    let rosterID: Int
    let matchupID: Int?
    let points: Double?
    let customPoints: Double?
    /// Player IDs in slot order ("0" for an empty slot) and their points, index-aligned.
    let starters: [String]?
    let startersPoints: [Double]?

    enum CodingKeys: String, CodingKey {
        case rosterID = "roster_id"
        case matchupID = "matchup_id"
        case points
        case customPoints = "custom_points"
        case starters
        case startersPoints = "starters_points"
    }

    /// Commissioner overrides win over computed points.
    var score: Double {
        return customPoints ?? points ?? 0
    }
}

/// Where a player's NFL game stands this week. `unknown` means no schedule was available.
enum GameStatus: String, Codable {
    case upcoming
    case live
    case final
    case bye
    case unknown
}

/// One game from the undocumented schedule endpoint.
struct ScheduledGame: Decodable {
    let week: Int
    let home: String
    let away: String
    /// "2026-10-04". The endpoint has no kickoff time.
    let date: String
    let status: String

    /// Only pre_game and complete are certain; anything else that isn't a cancellation is
    /// treated as in progress, since the live value has never been observed off-season.
    var gameStatus: GameStatus {
        switch status {
        case "pre_game":
            return .upcoming
        case "complete":
            return .final
        case "canceled", "postponed":
            return .unknown
        default:
            return .live
        }
    }
}

/// One player's entry from the undocumented weekly projections endpoint. Entries exist for
/// unprojected players too, which is useful: they still carry team and injury status.
struct RawProjection: Decodable {
    struct Stats: Decodable {
        let ppr: Double?
        let half: Double?
        let std: Double?

        enum CodingKeys: String, CodingKey {
            case ppr = "pts_ppr"
            case half = "pts_half_ppr"
            case std = "pts_std"
        }
    }

    struct Player: Decodable {
        let injuryStatus: String?

        enum CodingKeys: String, CodingKey {
            case injuryStatus = "injury_status"
        }
    }

    let playerID: String
    let team: String?
    let stats: Stats?
    let player: Player?

    enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case team
        case stats
        case player
    }
}

/// The slim form of a projection that gets cached and passed around.
struct PlayerProjection: Codable, Hashable {
    let ppr: Double?
    let half: Double?
    let std: Double?
    let team: String?
    let injury: String?

    /// The preset closest to the league's reception scoring. An approximation: leagues with
    /// unusual scoring will differ from Sleeper's own in-app projection.
    func points(receptionPoints: Double) -> Double? {
        if receptionPoints >= 0.75 {
            return ppr ?? half ?? std
        }
        if receptionPoints >= 0.25 {
            return half ?? ppr ?? std
        }
        return std ?? half ?? ppr
    }
}

struct LeagueTransaction: Decodable {
    let type: String
    let status: String
    /// player_id → roster_id
    let adds: [String: Int]?
    let drops: [String: Int]?
    let rosterIDs: [Int]?
    let statusUpdated: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case status
        case adds
        case drops
        case rosterIDs = "roster_ids"
        case statusUpdated = "status_updated"
    }
}

/// One game in the playoff bracket. `r` is the round (1 = first playoff week), `t1`/`t2` are
/// roster ids once known, `w`/`l` are set when it is decided, `p` marks a placement game
/// (1 = championship, 3 = third place).
struct BracketMatch: Decodable {
    let round: Int
    let teamOne: Int?
    let teamTwo: Int?
    let winner: Int?
    let loser: Int?
    let place: Int?

    enum CodingKeys: String, CodingKey {
        case round = "r"
        case teamOne = "t1"
        case teamTwo = "t2"
        case winner = "w"
        case loser = "l"
        case place = "p"
    }
}
