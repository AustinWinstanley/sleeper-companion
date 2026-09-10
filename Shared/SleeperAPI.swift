import Foundation

/// Thin client for the Sleeper public REST API. Read-only, no auth, every call is GET + JSON.
enum SleeperAPI {
    static let baseURL = URL(string: "https://api.sleeper.app/v1")!
    static let avatarCDN = URL(string: "https://sleepercdn.com/avatars/thumbs")!

    // Widgets get a tight time budget, so fail fast rather than hang on a bad connection.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()

    static func get<Value: Decodable>(_ path: String) async throws -> Value {
        let url = baseURL.appending(path: path)
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SleeperAPIError.badStatus(http.statusCode, path)
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
