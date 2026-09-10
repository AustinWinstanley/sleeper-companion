import Foundation

/// Last good payload per league+user, plus avatar bytes, in the App Group container so a failed
/// fetch shows stale scores marked "Cached" instead of an error.
enum MatchupCache {
    private static var directory: URL? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: UserStore.appGroupID) else {
            return nil
        }
        let directory = container.appending(path: "MatchupCache", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func save(_ snapshot: MatchupSnapshot, leagueID: String, userID: String) {
        guard let url = snapshotURL(leagueID: leagueID, userID: userID),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    static func load(leagueID: String, userID: String) -> MatchupSnapshot? {
        guard let url = snapshotURL(leagueID: leagueID, userID: userID),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(MatchupSnapshot.self, from: data)
    }

    static func saveAvatar(_ data: Data, for url: URL) {
        guard let fileURL = avatarURL(for: url) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func loadAvatar(for url: URL) -> Data? {
        guard let fileURL = avatarURL(for: url) else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    private static func snapshotURL(leagueID: String, userID: String) -> URL? {
        return directory?.appending(path: "\(leagueID)-\(userID).json")
    }

    // Both avatar URL shapes end in a unique id or filename, so the last component is enough of a key.
    private static func avatarURL(for url: URL) -> URL? {
        return directory?.appending(path: "avatar-\(url.lastPathComponent)")
    }
}
