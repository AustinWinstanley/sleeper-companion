import UIKit

/// Widget tap → sleepercompanion://sleeper?league=… → this app → the Sleeper app. Sleeper's universal
/// links only cover its chat pages, so the custom scheme is the only way into the app; the
/// web matchup page is the fallback when Sleeper isn't installed.
enum SleeperHandoff {
    static func handle(_ url: URL) {
        guard url.scheme == "sleepercompanion", url.host == "sleeper" else {
            return
        }
        let leagueID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "league" }?.value

        guard let sleeperURL = URL(string: "sleeper://") else {
            return
        }
        UIApplication.shared.open(sleeperURL) { opened in
            if opened {
                return
            }
            if let leagueID, let webURL = URL(string: "https://sleeper.com/leagues/\(leagueID)/matchup") {
                UIApplication.shared.open(webURL)
            }
        }
    }
}
