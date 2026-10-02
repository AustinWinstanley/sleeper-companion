import Foundation
import Testing
@testable import SleeperCompanion

struct MatchupLoaderTests {
    @Test func pairsOpponentByMatchupID() throws {
        let snapshot = try Fixtures.build(userID: "U1")
        #expect(snapshot.mine.teamName == "Alpha Team")
        #expect(snapshot.theirs?.teamName == "Bravo")
        #expect(snapshot.isBye == false)
    }

    @Test func nilMatchupIDIsABye() throws {
        let snapshot = try Fixtures.build(userID: "U3")
        #expect(snapshot.theirs == nil)
        #expect(snapshot.isBye)
        #expect(snapshot.iAmLeading)
    }

    @Test func coOwnerFindsTheRoster() throws {
        let snapshot = try Fixtures.build(userID: "U5")
        #expect(snapshot.mine.points == 55.0)
        // Roster 4 has no owner in the users list, so the name falls back to the roster id.
        #expect(snapshot.mine.teamName == "Team 4")
    }

    @Test func missingRosterThrows() {
        #expect(throws: MatchupError.self) {
            try Fixtures.build(userID: "nobody")
        }
    }

    @Test func customPointsOverridePoints() throws {
        let snapshot = try Fixtures.build(userID: "U1")
        #expect(snapshot.theirs?.points == 120.25)
        #expect(snapshot.mine.points == 101.5)
        #expect(snapshot.iAmLeading == false)
    }

    @Test func standingsOrderByWinsThenPointsFor() throws {
        // U3 has the most wins; U2 and U1 are tied on wins and U2 has more points for.
        #expect(try Fixtures.build(userID: "U3").mine.rank == 1)
        #expect(try Fixtures.build(userID: "U2").mine.rank == 2)
        #expect(try Fixtures.build(userID: "U1").mine.rank == 3)
        #expect(try Fixtures.build(userID: "U5").mine.rank == 4)
    }

    @Test func recordIncludesTiesOnlyWhenPresent() throws {
        #expect(try Fixtures.build(userID: "U1").mine.record == "2-1")
        #expect(try Fixtures.build(userID: "U5").mine.record == "0-2-1")
        #expect(try Fixtures.build(userID: "U1").mine.recordWithRank == "2-1 · 3rd")
    }

    @Test func lineupAlignsWithStarterSlotsAndSkipsBench() throws {
        let starters = try Fixtures.build(userID: "U1").mine.starters
        #expect(starters.map { $0.slot } == ["QB", "RB", "WR", "FLEX"])
        #expect(starters.map { $0.name } == ["J. Allen", "S. Barkley", "Empty", "J. Chase"])
        #expect(starters.map { $0.points } == [20.0, 15.5, 0, 66.0])
    }

    @Test func unknownPlayerNameIsEmptyUntilDirectoryExists() throws {
        let starters = try Fixtures.build(userID: "U1", context: WeekContext()).mine.starters
        #expect(starters[0].name == "")
        #expect(starters[2].name == "Empty")
    }

    @Test func playoffLabelCountsDownThenFlips() throws {
        let snapshot = try Fixtures.build(userID: "U1")
        #expect(snapshot.playoffLabel == "Playoffs in 12 wks")
        // Past the start with no bracket loaded, the label still flips.
        #expect(try Fixtures.build(userID: "U1", week: 16).playoffLabel == "Playoffs")
    }

    @Test func handoffURLCarriesTheLeague() throws {
        let snapshot = try Fixtures.build(userID: "U1")
        #expect(snapshot.sleeperHandoffURL?.absoluteString == "sleepercompanion://sleeper?league=L1")
    }
}
