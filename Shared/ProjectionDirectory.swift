import Foundation

/// This week's projections, team and injury status per player, cached in the App Group.
/// The source is ~2 MB across positions, so it is fetched one position at a time (small
/// decodes that fit a widget's memory budget), slimmed, and reused for a few hours by
/// every widget and the app.
enum ProjectionDirectory {
    static let maxAge: TimeInterval = 3 * 60 * 60
    private static let positions = ["QB", "RB", "WR", "TE", "K", "DEF"]
    private static let filePrefix = "projections-"

    private static var container: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: UserStore.appGroupID)
    }

    private static func fileURL(season: String, week: Int) -> URL? {
        return container?.appending(path: "\(filePrefix)\(season)-\(week).json")
    }

    /// Fresh cache if there is one, else a fetch, else whatever stale copy exists, else empty.
    /// Never throws: projections are an extra, and the matchup must still load without them.
    static func load(season: String, week: Int, now: Date = .now) async -> [String: PlayerProjection] {
        let cached = readCache(season: season, week: week)
        if let cached, now.timeIntervalSince(cached.savedAt) < maxAge {
            return cached.projections
        }
        if let fresh = try? await fetch(season: season, week: week) {
            writeCache(fresh, season: season, week: week)
            return fresh
        }
        return cached?.projections ?? [:]
    }

    private static func fetch(season: String, week: Int) async throws -> [String: PlayerProjection] {
        var projections: [String: PlayerProjection] = [:]
        // Sequential on purpose: one decode in memory at a time.
        for position in positions {
            let entries = try await SleeperAPI.projections(season: season, week: week, position: position)
            for entry in entries {
                projections[entry.playerID] = PlayerProjection(
                    ppr: entry.stats?.ppr, half: entry.stats?.half, std: entry.stats?.std,
                    team: entry.team, injury: entry.player?.injuryStatus
                )
            }
        }
        return projections
    }

    private static func readCache(season: String, week: Int) -> (projections: [String: PlayerProjection], savedAt: Date)? {
        guard let url = fileURL(season: season, week: week),
              let data = try? Data(contentsOf: url),
              let projections = try? JSONDecoder().decode([String: PlayerProjection].self, from: data),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let savedAt = attributes[.modificationDate] as? Date else {
            return nil
        }
        return (projections, savedAt)
    }

    private static func writeCache(_ projections: [String: PlayerProjection], season: String, week: Int) {
        guard let container, let url = fileURL(season: season, week: week),
              let data = try? JSONEncoder().encode(projections) else {
            return
        }
        // Earlier weeks are never read again.
        let existing = (try? FileManager.default.contentsOfDirectory(atPath: container.path)) ?? []
        for name in existing where name.hasPrefix(filePrefix) {
            try? FileManager.default.removeItem(at: container.appending(path: name))
        }
        try? data.write(to: url, options: .atomic)
    }
}
