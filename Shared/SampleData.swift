import Foundation

// Stand-in data for widget placeholders, the gallery preview, and SwiftUI previews.
extension MatchupSnapshot {
    private static let sampleSlots = ["QB", "RB", "RB", "WR", "WR", "TE", "FLEX", "FLEX", "DEF"]
    private static let myStarters = ["P. Mahomes", "B. Robinson", "J. Gibbs", "J. Chase", "A. St. Brown", "T. Kelce", "D. London", "J. Jacobs", "49ers"]
    private static let theirStarters = ["J. Allen", "S. Barkley", "D. Henry", "J. Jefferson", "C. Lamb", "B. Bowers", "P. Nacua", "J. Cook", "Ravens"]
    // A mid-Sunday mix: early games final, one live, late games still to come.
    private static let sampleStatuses: [GameStatus] = [.final, .final, .final, .final, .live, .upcoming, .upcoming, .upcoming, .upcoming]

    private static func lineup(_ names: [String], _ points: [Double], projections: [Double], injuries: [Int: String] = [:]) -> [StarterLine] {
        var lines: [StarterLine] = []
        for (index, name) in names.enumerated() {
            lines.append(StarterLine(slot: sampleSlots[index], name: name, points: points[index],
                                     projected: projections[index], injury: injuries[index], status: sampleStatuses[index]))
        }
        return lines
    }

    private static let sampleStandings: [StandingLine] = [
        StandingLine(rank: 1, teamName: "Gridiron Goblins", record: "2-0", pointsFor: 251.3, isMine: true, isOpponent: false),
        StandingLine(rank: 2, teamName: "Hail Marys", record: "2-0", pointsFor: 240.1, isMine: false, isOpponent: false),
        StandingLine(rank: 3, teamName: "Bench Mob", record: "1-1", pointsFor: 233.8, isMine: false, isOpponent: false),
        StandingLine(rank: 4, teamName: "End Zone Dancers", record: "1-1", pointsFor: 221.0, isMine: false, isOpponent: false),
        StandingLine(rank: 5, teamName: "Waiver Wire Warriors", record: "1-1", pointsFor: 214.6, isMine: false, isOpponent: true),
        StandingLine(rank: 6, teamName: "Fourth and Long", record: "1-1", pointsFor: 209.9, isMine: false, isOpponent: false),
        StandingLine(rank: 7, teamName: "Red Zone Regulars", record: "0-2", pointsFor: 198.2, isMine: false, isOpponent: false),
        StandingLine(rank: 8, teamName: "Punt Intended", record: "0-2", pointsFor: 180.4, isMine: false, isOpponent: false),
    ]

    static let sample = MatchupSnapshot(
        leagueID: "sample",
        leagueName: "The League",
        week: 3,
        playoffWeekStart: 15,
        mine: TeamSummary(teamName: "Gridiron Goblins", ownerName: "austin", avatarURL: nil,
                          points: 84.56, record: "2-0", rank: 1, matchupID: 1,
                          starters: lineup(myStarters, [24.3, 18.1, 15.7, 22.4, 4.06, 0, 0, 0, 0],
                                           projections: [21.0, 16.5, 15.0, 18.2, 15.1, 11.4, 12.2, 13.0, 7.5],
                                           injuries: [6: "Questionable"]),
                          projectedTotal: 143.7),
        theirs: TeamSummary(teamName: "Waiver Wire Warriors", ownerName: "friend", avatarURL: nil,
                            points: 76.0, record: "1-1", rank: 5, matchupID: 1,
                            starters: lineup(theirStarters, [19.9, 14.2, 21.0, 12.5, 8.4, 0, 0, 0, 0],
                                             projections: [22.4, 17.0, 15.8, 17.5, 14.9, 10.8, 14.0, 12.1, 8.0],
                                             injuries: [7: "Out"]),
                            projectedTotal: 127.4),
        fetchedAt: .now,
        standings: sampleStandings,
        transactionLine: "4 moves · Bench Mob added T. Tracy"
    )

    static let sampleBye = MatchupSnapshot(
        leagueID: "sample",
        leagueName: "The League",
        week: 14,
        playoffWeekStart: 15,
        mine: TeamSummary(teamName: "Gridiron Goblins", ownerName: "austin", avatarURL: nil,
                          points: 0, record: "9-4", rank: 2, matchupID: nil,
                          starters: lineup(myStarters, Array(repeating: 0, count: 9), projections: Array(repeating: 12, count: 9))),
        theirs: nil,
        fetchedAt: .now,
        standings: sampleStandings
    )
}

extension LoadedMatchup {
    static let sample = LoadedMatchup(snapshot: .sample, stale: false, myAvatar: nil, theirAvatar: nil)
    static let sampleStale = LoadedMatchup(snapshot: .sample, stale: true, myAvatar: nil, theirAvatar: nil)
    static let sampleBye = LoadedMatchup(snapshot: .sampleBye, stale: false, myAvatar: nil, theirAvatar: nil)
}
