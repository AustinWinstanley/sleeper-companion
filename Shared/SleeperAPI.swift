import Foundation

/// Thin client for the Sleeper public REST API. Read-only, no auth, every call is GET + JSON.
enum SleeperAPI {
    static let baseURL = URL(string: "https://api.sleeper.app/v1")!
    static let avatarCDN = URL(string: "https://sleepercdn.com/avatars/thumbs")!
    /// Host root for the endpoints Sleeper's own apps use but the API docs don't list
    /// (schedule, projections). They can change without notice, so every caller treats
    /// them as best effort and falls back to showing less.
    static let rootURL = URL(string: "https://api.sleeper.app")!

    // Widgets get a tight time budget, so fail fast rather than hang on a bad connection.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static func get<Value: Decodable>(_ path: String) async throws -> Value {
        return try await fetch(baseURL.appending(path: path), label: path)
    }

    static func getUndocumented<Value: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Value {
        var components = URLComponents(url: rootURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query
        }
        guard let url = components?.url else {
            throw SleeperAPIError.badStatus(0, path)
        }
        return try await fetch(url, label: path)
    }

    private static func fetch<Value: Decodable>(_ url: URL, label: String) async throws -> Value {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SleeperAPIError.badStatus(http.statusCode, label)
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    static func nflState() async throws -> NFLState {
        return try await get("state/nfl")
    }

    /// Accepts a username or a user_id. Sleeper answers `null` for unknown names, which is a
    /// friendlier error than a decoding failure.
    static func user(named username: String) async throws -> SleeperUser {
        let url = baseURL.appending(path: "user/\(username)")
        let (data, _) = try await session.data(from: url)
        if String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) == "null" {
            throw SleeperAPIError.unknownUser(username)
        }
        return try JSONDecoder().decode(SleeperUser.self, from: data)
    }

    static func league(_ leagueID: String) async throws -> League {
        return try await get("league/\(leagueID)")
    }

    static func users(inLeague leagueID: String) async throws -> [SleeperUser] {
        return try await get("league/\(leagueID)/users")
    }

    static func rosters(inLeague leagueID: String) async throws -> [Roster] {
        return try await get("league/\(leagueID)/rosters")
    }

    static func matchups(inLeague leagueID: String, week: Int) async throws -> [MatchupRow] {
        return try await get("league/\(leagueID)/matchups/\(week)")
    }

    static func leagues(forUser userID: String, season: String) async throws -> [League] {
        return try await get("user/\(userID)/leagues/nfl/\(season)")
    }

    static func transactions(inLeague leagueID: String, week: Int) async throws -> [LeagueTransaction] {
        return try await get("league/\(leagueID)/transactions/\(week)")
    }

    static func winnersBracket(inLeague leagueID: String) async throws -> [BracketMatch] {
        return try await get("league/\(leagueID)/winners_bracket")
    }

    /// Undocumented. Every regular-season game with its status; no kickoff times, only dates.
    static func schedule(season: String) async throws -> [ScheduledGame] {
        return try await getUndocumented("schedule/nfl/regular/\(season)")
    }

    /// Undocumented. One position per call keeps each payload small enough to decode inside a widget.
    static func projections(season: String, week: Int, position: String) async throws -> [RawProjection] {
        let query = [URLQueryItem(name: "season_type", value: "regular"), URLQueryItem(name: "position[]", value: position)]
        return try await getUndocumented("projections/nfl/\(season)/\(week)", query: query)
    }
}

enum SleeperAPIError: LocalizedError {
    case badStatus(Int, String)
    case unknownUser(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code, let path):
            return "Sleeper returned \(code) for \(path)"
        case .unknownUser(let username):
            return "No Sleeper user named \"\(username)\""
        }
    }
}
