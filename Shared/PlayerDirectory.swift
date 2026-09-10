import Foundation

/// Player ID → short display name ("P. Mahomes", "49ers"). The full /players/nfl payload is
/// ~15 MB, far too big for a widget's memory budget, so only the app downloads it (at most
/// once a day) and writes a ~250 KB map into the App Group for both targets to read.
enum PlayerDirectory {
    static let maxAge: TimeInterval = 24 * 60 * 60

    private static var fileURL: URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: UserStore.appGroupID) else {
            return nil
        }
        return container.appending(path: "player-names.json")
    }

    static func names() -> [String: String] {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
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

        var names: [String: String] = [:]
        for (playerID, player) in raw {
            // Inactive players can't be started, and dropping them keeps the map small.
            if player.active != true && player.position != "DEF" {
                continue
            }
            names[playerID] = shortName(player)
        }
        let encoded = try JSONEncoder().encode(names)
        try encoded.write(to: fileURL, options: .atomic)
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
        let active: Bool?

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case position
            case active
        }
    }
}
