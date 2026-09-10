import Foundation

// Stand-in data for widget placeholders, the gallery preview, and SwiftUI previews.
extension MatchupSnapshot {
    private static let sampleSlots = ["QB", "RB", "RB", "WR", "WR", "TE", "FLEX", "FLEX", "DEF"]
    private static let myStarters = ["P. Mahomes", "B. Robinson", "J. Gibbs", "J. Chase", "A. St. Brown", "T. Kelce", "D. London", "J. Jacobs", "49ers"]
    private static let theirStarters = ["J. Allen", "S. Barkley", "D. Henry", "J. Jefferson", "C. Lamb", "B. Bowers", "P. Nacua", "J. Cook", "Ravens"]

    private static func lineup(_ names: [String], _ points: [Double]) -> [StarterLine] {
        var lines: [StarterLine] = []
        for (index, name) in names.enumerated() {
            lines.append(StarterLine(slot: sampleSlots[index], name: name, points: points[index]))
        }
        return lines
    }

    static let sample = MatchupSnapshot(
        leagueID: "sample",
        leagueName: "The League",
        week: 3,
        playoffWeekStart: 15,
        mine: TeamSummary(teamName: "Gridiron Goblins", ownerName: "austin", avatarURL: nil,
                          points: 112.46, record: "2-0", rank: 1, matchupID: 1,
                          starters: lineup(myStarters, [24.3, 18.1, 15.7, 22.4, 9.8, 6.2, 8.1, 3.9, 3.96])),
        theirs: TeamSummary(teamName: "Waiver Wire Warriors", ownerName: "friend", avatarURL: nil,
                            points: 98.12, record: "1-1", rank: 5, matchupID: 1,
                            starters: lineup(theirStarters, [19.9, 14.2, 21.0, 12.5, 8.4, 4.1, 6.3, 4.72, 7.0])),
        fetchedAt: .now
    )

    static let sampleBye = MatchupSnapshot(
        leagueID: "sample",
        leagueName: "The League",
        week: 14,
        playoffWeekStart: 15,
        mine: TeamSummary(teamName: "Gridiron Goblins", ownerName: "austin", avatarURL: nil,
                          points: 0, record: "9-4", rank: 2, matchupID: nil,
                          starters: lineup(myStarters, Array(repeating: 0, count: 9))),
        theirs: nil,
        fetchedAt: .now
    )
}

extension LoadedMatchup {
    static let sample = LoadedMatchup(snapshot: .sample, stale: false, myAvatar: nil, theirAvatar: nil)
    static let sampleStale = LoadedMatchup(snapshot: .sample, stale: true, myAvatar: nil, theirAvatar: nil)
    static let sampleBye = LoadedMatchup(snapshot: .sampleBye, stale: false, myAvatar: nil, theirAvatar: nil)
}
