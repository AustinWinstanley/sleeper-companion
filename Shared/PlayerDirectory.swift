import Foundation

/// Player ID → short display name ("P. Mahomes", "49ers") and NFL team. The full /players/nfl
/// payload is ~15 MB, far too big for a widget's memory budget, so only the app downloads it
/// (at most once a day) and writes a small map into the App Group for both targets to read.
enum PlayerDirectory {
    static let maxAge: TimeInterval = 24 * 60 * 60

    struct Entry: Codable {
        let name: String
        let team: String?

        // Single-letter keys: this file holds ~9,000 entries.
        enum CodingKeys: String, CodingKey {
            case name = "n"
            case team = "t"
        }
    }

    private static var container: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: UserStore.appGroupID)
    }

    private static var fileURL: URL? {
        return container?.appending(path: "players.json")
    }

    /// Names and teams as two lookups. Empty until the app has downloaded the directory once.
    static func load() -> (names: [String: String], teams: [String: String]) {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return ([:], [:])
        }
        var names: [String: String] = [:]
        var teams: [String: String] = [:]
        for (playerID, entry) in entries {
            names[playerID] = entry.name
            if let team = entry.team {
                teams[playerID] = team
            }
        }
        return (names, teams)
    }

    static var lastUpdated: Date? {
        guard let fileURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    /// Returns true if a download happened, so the caller can reload widget timelines.
    @discardableResult
    static func refreshIfNeeded() async -> Bool {
        if let lastUpdated, Date.now.timeIntervalSince(lastUpdated) < maxAge {
            return false
        }
        do {
            try await refresh()
            return true
        } catch {
            return false
        }
    }

    static func refresh() async throws {
        guard let fileURL else {
            return
        }
        // URLSession.shared rather than SleeperAPI.session: this download outlives a 30 s budget on cellular.
        let url = SleeperAPI.baseURL.appending(path: "players/nfl")
        let (data, _) = try await URLSession.shared.data(from: url)
        let raw = try JSONDecoder().decode([String: RawPlayer].self, from: data)

        var entries: [String: Entry] = [:]
        for (playerID, player) in raw {
            // Inactive players can't be started, and dropping them keeps the map small.
            if player.active != true && player.position != "DEF" {
                continue
            }
            entries[playerID] = Entry(name: shortName(player), team: player.team)
        }
        let encoded = try JSONEncoder().encode(entries)
        try encoded.write(to: fileURL, options: .atomic)

        // The names-only file from earlier builds is superseded.
        if let legacy = container?.appending(path: "player-names.json") {
            try? FileManager.default.removeItem(at: legacy)
        }
    }

    /// "P. Mahomes" for players; team defenses are keyed by abbreviation and read best as "49ers".
    private static func shortName(_ player: RawPlayer) -> String {
        let last = player.lastName ?? ""
        if player.position == "DEF" {
            return last
        }
        if let initial = player.firstName?.first {
            return "\(initial). \(last)"
        }
        return last
    }

    private struct RawPlayer: Decodable {
        let firstName: String?
        let lastName: String?
        let position: String?
        let team: String?
        let active: Bool?

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case position
            case team
            case active
        }
    }
}
