import UIKit

/// A snapshot plus everything the views need that can't be loaded lazily inside a widget
/// (no AsyncImage there), so avatars are fetched up front.
struct LoadedMatchup {
    let snapshot: MatchupSnapshot
    let stale: Bool
    let myAvatar: UIImage?
    let theirAvatar: UIImage?

    static func load(_ snapshot: MatchupSnapshot, stale: Bool) async -> LoadedMatchup {
        async let mine = AvatarLoader.load(snapshot.mine.avatarURL)
        async let theirs = AvatarLoader.load(snapshot.theirs?.avatarURL)
        return await LoadedMatchup(snapshot: snapshot, stale: stale, myAvatar: mine, theirAvatar: theirs)
    }
}

enum MatchupResult {
    case needsSetup
    case loaded(LoadedMatchup)
    case failed(String)
}

/// Shared by the widget's timeline provider and the app's preview: fetch, cache, fall back.
enum MatchupFetcher {
    static func fetch(leagueID: String, userID: String) async -> MatchupResult {
        do {
            let snapshot = try await MatchupLoader.load(leagueID: leagueID, userID: userID)
            MatchupCache.save(snapshot, leagueID: leagueID, userID: userID)
            return .loaded(await LoadedMatchup.load(snapshot, stale: false))
        } catch {
            // Network or lookup failure: stale scores beat an error when we have them.
            if let cached = MatchupCache.load(leagueID: leagueID, userID: userID) {
                return .loaded(await LoadedMatchup.load(cached, stale: true))
            }
            return .failed(error.localizedDescription)
        }
    }
}

enum AvatarLoader {
    static func load(_ url: URL?) async -> UIImage? {
        guard let url else {
            return nil
        }
        if let result = try? await SleeperAPI.session.data(from: url), let image = UIImage(data: result.0) {
            MatchupCache.saveAvatar(result.0, for: url)
            return image
        }
        if let data = MatchupCache.loadAvatar(for: url) {
            return UIImage(data: data)
        }
        return nil
    }
}
