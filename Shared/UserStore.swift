import Foundation

/// Where the chosen Sleeper user lives. App Group defaults are the source of truth shared by the
/// app and the widget; iCloud key-value store mirrors it so a new phone skips the setup picker.
enum UserStore {
    /// group.<app bundle id>, matching project.yml. The widget's bundle ID is the app's plus
    /// ".widget", so both targets land on the same group without a hardcoded string.
    static let appGroupID: String = {
        var identifier = Bundle.main.bundleIdentifier ?? "sleepercompanion"
        if identifier.hasSuffix(".widget") {
            identifier.removeLast(".widget".count)
        }
        return "group.\(identifier)"
    }()

    private static let userIDKey = "sleeperUserID"
    private static let displayNameKey = "sleeperDisplayName"
    private static let leaguesKey = "cachedLeagues"
    private static let preferredLeagueKey = "preferredLeagueID"

    static var defaults: UserDefaults {
        return UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static var cloud: NSUbiquitousKeyValueStore {
        return .default
    }

    /// App Group first; iCloud covers a widget added on a new phone before the app was opened.
    static var userID: String? {
        return defaults.string(forKey: userIDKey) ?? cloud.string(forKey: userIDKey)
    }

    static var displayName: String? {
        return defaults.string(forKey: displayNameKey) ?? cloud.string(forKey: displayNameKey)
    }

    static func save(userID: String, displayName: String) {
        defaults.set(userID, forKey: userIDKey)
        defaults.set(displayName, forKey: displayNameKey)
        defaults.removeObject(forKey: leaguesKey)
        cloud.set(userID, forKey: userIDKey)
        cloud.set(displayName, forKey: displayNameKey)
        cloud.synchronize()
    }

    /// League picked in the app; widgets without an explicit choice follow it.
    static var preferredLeagueID: String? {
        get {
            return defaults.string(forKey: preferredLeagueKey)
        }
        set {
            defaults.set(newValue, forKey: preferredLeagueKey)
        }
    }

    static func clear() {
        for key in [userIDKey, displayNameKey, leaguesKey, preferredLeagueKey] {
            defaults.removeObject(forKey: key)
            cloud.removeObject(forKey: key)
        }
        cloud.synchronize()
    }

    /// Called on app launch and when iCloud reports a change: copy iCloud's value into the
    /// App Group if this device has none yet. Local wins otherwise, so a reset here sticks.
    static func pullFromCloud() {
        cloud.synchronize()
        if defaults.string(forKey: userIDKey) == nil, let cloudID = cloud.string(forKey: userIDKey) {
            defaults.set(cloudID, forKey: userIDKey)
            defaults.set(cloud.string(forKey: displayNameKey), forKey: displayNameKey)
        }
    }

    // Cached league list, so the widget's league picker resolves names offline.

    static var cachedLeagues: [CachedLeague] {
        get {
            guard let data = defaults.data(forKey: leaguesKey) else {
                return []
            }
            return (try? JSONDecoder().decode([CachedLeague].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: leaguesKey)
            }
        }
    }
}

struct CachedLeague: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let season: String
}

/// The user's leagues for the current season. Network first, App Group cache when offline.
enum LeagueDirectory {
    static func refresh(userID: String) async throws -> [CachedLeague] {
        let state = try await SleeperAPI.nflState()
        let leagues = try await SleeperAPI.leagues(forUser: userID, season: state.currentSeason)
        let cached = leagues.map { CachedLeague(id: $0.leagueID, name: $0.name, season: $0.season) }
        UserStore.cachedLeagues = cached
        return cached
    }

    static func leagues(userID: String) async -> [CachedLeague] {
        if let fresh = try? await refresh(userID: userID) {
            return fresh
        }
        return UserStore.cachedLeagues
    }

    /// The league chosen in the app if it is still one of the user's leagues, else the first
    /// listed (with one league that means no picker is ever needed). nil with no leagues.
    static func defaultLeagueID(userID: String) async -> String? {
        let leagues = await leagues(userID: userID)
        if let preferred = UserStore.preferredLeagueID, leagues.contains(where: { $0.id == preferred }) {
            return preferred
        }
        return leagues.first?.id
    }
}
