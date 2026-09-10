import Foundation
import Testing
@testable import SleeperCompanion

struct SleeperModelsTests {
    @Test func nflStatePrefersDisplayWeekAndLeagueSeason() throws {
        let state: NFLState = try Fixtures.decode("""
        { "week": 4, "display_week": 3, "season": "2026", "league_season": "2025" }
        """)
        #expect(state.currentWeek == 3)
        #expect(state.currentSeason == "2025")

        let offseason: NFLState = try Fixtures.decode("""
        { "week": 0, "display_week": 0, "season": "2026" }
        """)
        #expect(offseason.currentWeek == 1)
        #expect(offseason.currentSeason == "2026")
    }

    @Test func teamNameFallsBackFromEmptyMetadata() {
        let users = Fixtures.users
        #expect(users[0].teamName == "Alpha Team")
        #expect(users[1].teamName == "Bravo")
        #expect(users[2].teamName == "Charlie")
    }

    @Test func avatarURLPrefersTeamAvatarThenCDN() {
        let users = Fixtures.users
        #expect(users[0].avatarURL?.absoluteString == "https://sleepercdn.com/uploads/alpha.jpg")
        #expect(users[1].avatarURL?.absoluteString == "https://sleepercdn.com/avatars/thumbs/bbb")
        #expect(users[2].avatarURL == nil)
    }

    @Test func starterSlotsDropBenchAndInjuredReserve() {
        #expect(Fixtures.league.starterSlots == ["QB", "RB", "WR", "FLEX"])
    }

    @Test func pointsForCombinesWholeAndDecimalParts() {
        #expect(Fixtures.rosters[0].pointsFor == 300.5)
        #expect(Fixtures.rosters[3].pointsFor == 100.99)
    }

    @Test func shortSlotAbbreviatesLongNames() {
        #expect(StarterLine(slot: "SUPER_FLEX", name: "", points: 0).shortSlot == "SFLX")
        #expect(StarterLine(slot: "QB", name: "", points: 0).shortSlot == "QB")
    }

    @Test func ordinalFormatting() {
        #expect(1.ordinal == "1st")
        #expect(2.ordinal == "2nd")
        #expect(3.ordinal == "3rd")
        #expect(11.ordinal == "11th")
    }
}
