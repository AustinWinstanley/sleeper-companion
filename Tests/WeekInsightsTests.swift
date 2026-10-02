import Foundation
import Testing
@testable import SleeperCompanion

/// Game status, projections, injuries, refresh pacing, bracket and transactions: everything
/// that comes from the optional data around the core matchup.
struct WeekInsightsTests {
    // MARK: Game status and projections

    @Test func starterStatusComesFromTheTeamsGameThisWeek() throws {
        let snapshot = try Fixtures.build(userID: "U1", context: Fixtures.fullContext)
        #expect(snapshot.mine.starters.map { $0.status } == [.final, .live, .unknown, .upcoming])
        // P6's team has no game this week; P8's team isn't an NFL team on the slate either.
        #expect(snapshot.theirs?.starters.map { $0.status } == [.upcoming, .bye, .upcoming, .bye])
    }

    @Test func withoutAScheduleEveryStatusIsUnknown() throws {
        var context = Fixtures.fullContext
        context.games = []
        let snapshot = try Fixtures.build(userID: "U1", context: context)
        #expect(snapshot.mine.starters.allSatisfy { $0.status == .unknown })
        #expect(snapshot.mine.hasGameInfo == false)
        #expect(snapshot.refreshInterval == RefreshPolicy.defaultInterval)
    }

    @Test func remainingCountsLiveAndUpcomingStarters() throws {
        let snapshot = try Fixtures.build(userID: "U1", context: Fixtures.fullContext)
        #expect(snapshot.mine.remaining == 2)
        #expect(snapshot.theirs?.remaining == 2)
    }

    @Test func projectedTotalMixesActualAndProjection() throws {
        let snapshot = try Fixtures.build(userID: "U1", context: Fixtures.fullContext)
        // P1 final: actual 20. P2 live: max(15.5, 18). Empty slot: 0. P4 upcoming: projection 17.5.
        #expect(snapshot.mine.projectedTotal == 20 + 18 + 0 + 17.5)
        #expect(snapshot.mine.statusLine == "2 left · proj 55.5")
    }

    @Test func noProjectionsMeansNoProjectedTotal() throws {
        let snapshot = try Fixtures.build(userID: "U1")
        #expect(snapshot.mine.projectedTotal == nil)
        #expect(snapshot.mine.statusLine == nil)
    }

    @Test func projectionFollowsLeagueReceptionScoring() {
        let projection = PlayerProjection(ppr: 18, half: 16, std: 14, team: nil, injury: nil)
        #expect(projection.points(receptionPoints: 1) == 18)
        #expect(projection.points(receptionPoints: 0.5) == 16)
        #expect(projection.points(receptionPoints: 0) == 14)
    }

    @Test func upcomingRowsShowTheProjectionAndPlayedRowsShowPoints() throws {
        let starters = try Fixtures.build(userID: "U1", context: Fixtures.fullContext).mine.starters
        #expect(starters[0].showsProjection == false)
        #expect(starters[0].displayPoints == 20)
        #expect(starters[3].showsProjection)
        #expect(starters[3].displayPoints == 17.5)
    }

    // MARK: Injuries and availability

    @Test func tagsAndUnavailableStarters() throws {
        let snapshot = try Fixtures.build(userID: "U1", context: Fixtures.fullContext)
        #expect(snapshot.mine.starters.map { $0.tag } == [nil, nil, nil, "Q"])
        #expect(snapshot.theirs?.starters.map { $0.tag } == [nil, "BYE", "O", "BYE"])
        // Mine: only the empty slot. Questionable still plays.
        #expect(snapshot.mine.unavailableStarters == 1)
        #expect(snapshot.starterWarning == "1 starter out")
        #expect(snapshot.theirs?.unavailableStarters == 3)
    }

    @Test func injuryStopsMatteringOnceTheGameStarts() {
        let live = StarterLine(slot: "RB", name: "A. Back", points: 3, projected: 10, injury: "Out", status: .live)
        #expect(live.tag == nil)
        #expect(live.isUnavailable == false)
    }

    // MARK: Refresh pacing

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)!
    }

    @Test func refreshIsFastWhileAGameIsLive() {
        let interval = RefreshPolicy.interval(games: Fixtures.games, week: 3, now: date("2026-09-25T12:00:00Z"))
        #expect(interval == RefreshPolicy.liveInterval)
    }

    @Test func refreshIsModerateOnAGameDayBeforeKickoff() {
        let pregame = Fixtures.games.filter { $0.status != "in_progress" }
        // 18:00 UTC on the 27th is 2 pm Eastern on the 27th, a day with an upcoming game.
        let interval = RefreshPolicy.interval(games: pregame, week: 3, now: date("2026-09-27T18:00:00Z"))
        #expect(interval == RefreshPolicy.gameDayInterval)
    }

    @Test func refreshIsSlowBetweenGameDays() {
        let pregame = Fixtures.games.filter { $0.status != "in_progress" }
        let interval = RefreshPolicy.interval(games: pregame, week: 3, now: date("2026-09-25T18:00:00Z"))
        #expect(interval == RefreshPolicy.idleInterval)
    }

    @Test func gameDayUsesTheEasternCalendarDate() {
        // 03:00 UTC on the 28th is still 11 pm Eastern on the 27th.
        #expect(RefreshPolicy.easternDateString(date("2026-09-28T03:00:00Z")) == "2026-09-27")
    }

    // MARK: Standings, transactions, bracket

    @Test func standingsListEveryTeamAndMarkTheMatchup() throws {
        let standings = try Fixtures.build(userID: "U1").standings
        #expect(standings.map { $0.teamName } == ["Charlie", "Bravo", "Alpha Team", "Team 4"])
        #expect(standings.map { $0.isMine } == [false, false, true, false])
        #expect(standings.map { $0.isOpponent } == [false, true, false, false])
        #expect(standings[2].pointsFor == 300.5)
    }

    @Test func transactionLineCountsCompletedAndDescribesTheLatest() throws {
        let snapshot = try Fixtures.build(userID: "U1", context: Fixtures.fullContext)
        // The failed waiver is newest but ignored; the trade is the latest completed move.
        #expect(snapshot.transactionLine == "2 moves · Trade: Alpha Team ↔ Charlie")
    }

    @Test func addIsDescribedWithTeamAndPlayer() {
        let adds = Fixtures.transactions.filter { $0.type == "free_agent" }
        let line = TransactionDescriber.line(transactions: adds, teamNames: [2: "Bravo"], playerNames: Fixtures.playerNames)
        #expect(line == "1 move · Bravo added J. Chase")
    }

    @Test func noBracketInfoBeforePlayoffs() throws {
        let snapshot = try Fixtures.build(userID: "U2", week: 14, context: Fixtures.fullContext)
        #expect(snapshot.playoffRound == nil)
        #expect(snapshot.bracketPath.isEmpty)
        #expect(snapshot.playoffLabel == "Playoffs in 1 wk")
    }

    @Test func bracketNamesTheRoundAndTracksThePath() throws {
        // Roster 2 (U2) won round one and plays the top seed in the semifinal in week 16.
        let roundOne = try Fixtures.build(userID: "U2", week: 15, context: Fixtures.fullContext)
        #expect(roundOne.playoffRound == "Quarterfinal")
        #expect(roundOne.bracketPath == ["Quarterfinal: beat Team 4"])

        let semifinal = try Fixtures.build(userID: "U2", week: 16, context: Fixtures.fullContext)
        #expect(semifinal.playoffRound == "Semifinal")
        #expect(semifinal.bracketPath == ["Quarterfinal: beat Team 4", "Semifinal: vs Charlie"])
        #expect(semifinal.playoffLabel == "Semifinal")
    }

    @Test func seededTeamsHaveAByeAndEliminatedTeamsAreInConsolation() throws {
        #expect(try Fixtures.build(userID: "U1", week: 15, context: Fixtures.fullContext).playoffRound == "Playoff bye")
        // Roster 4 (co-owner U5) lost round one.
        let eliminated = try Fixtures.build(userID: "U5", week: 16, context: Fixtures.fullContext)
        #expect(eliminated.playoffRound == "Consolation")
        #expect(eliminated.bracketPath == ["Quarterfinal: lost to Bravo"])
    }

    @Test func placementGamesAreNamed() {
        let final = BracketMatch(round: 3, teamOne: 1, teamTwo: 2, winner: nil, loser: nil, place: 1)
        let third = BracketMatch(round: 3, teamOne: 3, teamTwo: 4, winner: nil, loser: nil, place: 3)
        let names = [1: "A", 2: "B", 3: "C", 4: "D"]
        #expect(BracketDescriber.describe(bracket: [final, third], rosterID: 1, week: 17, playoffWeekStart: 15, teamNames: names).round == "Championship")
        #expect(BracketDescriber.describe(bracket: [final, third], rosterID: 3, week: 17, playoffWeekStart: 15, teamNames: names).round == "3rd place game")
    }
}
