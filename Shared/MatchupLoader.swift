import Foundation

enum MatchupError: LocalizedError {
    case noRoster(leagueName: String)

    var errorDescription: String? {
        switch self {
        case .noRoster(let leagueName):
            return "You don't have a team in \(leagueName)"
        }
    }
}

/// Everything beyond the four core league payloads. All of it is optional: each piece that
/// fails to load simply leaves its part of the widget out.
struct WeekContext {
    var playerNames: [String: String] = [:]
    var playerTeams: [String: String] = [:]
    var projections: [String: PlayerProjection] = [:]
    var games: [ScheduledGame] = []
    var transactions: [LeagueTransaction] = []
    var bracket: [BracketMatch] = []
}

/// Builds the matchup snapshot for one user in one league.
/// `load` does the fetching; `build` is pure so it can be tested with canned payloads.
enum MatchupLoader {
    static func load(leagueID: String, userID: String) async throws -> MatchupSnapshot {
        // Week comes from NFL state so nobody has to touch anything each Tuesday.
        let state = try await SleeperAPI.nflState()
        let week = state.currentWeek
        let season = state.currentSeason

        async let leagueTask = SleeperAPI.league(leagueID)
        async let usersTask = SleeperAPI.users(inLeague: leagueID)
        async let rostersTask = SleeperAPI.rosters(inLeague: leagueID)
        async let rowsTask = SleeperAPI.matchups(inLeague: leagueID, week: week)
        // Extras ride along in parallel and are allowed to fail.
        async let gamesTask = try? SleeperAPI.schedule(season: season)
        async let transactionsTask = try? SleeperAPI.transactions(inLeague: leagueID, week: week)
        let (league, users, rosters, rows) = try await (leagueTask, usersTask, rostersTask, rowsTask)

        var context = WeekContext()
        let directory = PlayerDirectory.load()
        context.playerNames = directory.names
        context.playerTeams = directory.teams
        context.projections = await ProjectionDirectory.load(season: season, week: week)
        context.games = await gamesTask ?? []
        context.transactions = await transactionsTask ?? []
        // The bracket only means something once playoffs have started.
        if let playoffWeekStart = league.settings?.playoffWeekStart, week >= playoffWeekStart {
            context.bracket = (try? await SleeperAPI.winnersBracket(inLeague: leagueID)) ?? []
        }

        return try build(league: league, users: users, rosters: rosters, rows: rows,
                         week: week, userID: userID, context: context)
    }

    static func build(league: League, users: [SleeperUser], rosters: [Roster], rows: [MatchupRow],
                      week: Int, userID: String, context: WeekContext, now: Date = .now) throws -> MatchupSnapshot {
        guard let myRoster = rosters.first(where: { $0.isOwned(by: userID) }) else {
            throw MatchupError.noRoster(leagueName: league.name)
        }

        // Standings the way Sleeper orders them: wins, then season points for.
        let standings = rosters.sorted { left, right in
            let leftWins = left.settings?.wins ?? 0
            let rightWins = right.settings?.wins ?? 0
            if leftWins != rightWins {
                return leftWins > rightWins
            }
            return left.pointsFor > right.pointsFor
        }

        // NFL team → where its game stands this week. A team missing from a non-empty map is on bye.
        var teamStatus: [String: GameStatus] = [:]
        for game in context.games where game.week == week {
            teamStatus[game.home] = game.gameStatus
            teamStatus[game.away] = game.gameStatus
        }

        let describer = Describer(users: users, rows: rows, standings: standings, slots: league.starterSlots,
                                  receptionPoints: league.receptionPoints, teamStatus: teamStatus, context: context)
        let mine = describer.describe(myRoster)

        // Opponent is the other roster sharing my matchup_id; no matchup_id means bye week.
        var theirs: TeamSummary? = nil
        var opponentRosterID: Int? = nil
        if let matchupID = mine.matchupID {
            let opponentRow = rows.first { $0.matchupID == matchupID && $0.rosterID != myRoster.rosterID }
            if let opponentRow, let opponentRoster = rosters.first(where: { $0.rosterID == opponentRow.rosterID }) {
                theirs = describer.describe(opponentRoster)
                opponentRosterID = opponentRoster.rosterID
            }
        }

        var teamNames: [Int: String] = [:]
        var standingLines: [StandingLine] = []
        for (index, roster) in standings.enumerated() {
            let name = describer.teamName(roster)
            teamNames[roster.rosterID] = name
            standingLines.append(StandingLine(rank: index + 1, teamName: name, record: roster.record,
                                              pointsFor: roster.pointsFor,
                                              isMine: roster.rosterID == myRoster.rosterID,
                                              isOpponent: roster.rosterID == opponentRosterID))
        }

        let bracket = BracketDescriber.describe(bracket: context.bracket, rosterID: myRoster.rosterID, week: week,
                                                playoffWeekStart: league.settings?.playoffWeekStart, teamNames: teamNames)

        return MatchupSnapshot(
            leagueID: league.leagueID, leagueName: league.name, week: week,
            playoffWeekStart: league.settings?.playoffWeekStart,
            mine: mine, theirs: theirs, fetchedAt: now,
            standings: standingLines,
            transactionLine: TransactionDescriber.line(transactions: context.transactions, teamNames: teamNames,
                                                       playerNames: context.playerNames),
            playoffRound: bracket.round,
            bracketPath: bracket.path,
            refreshInterval: RefreshPolicy.interval(games: context.games, week: week, now: now)
        )
    }

    /// Turns one roster into a TeamSummary. A struct rather than a long parameter list.
    private struct Describer {
        let users: [SleeperUser]
        let rows: [MatchupRow]
        let standings: [Roster]
        let slots: [String]
        let receptionPoints: Double
        let teamStatus: [String: GameStatus]
        let context: WeekContext

        func teamName(_ roster: Roster) -> String {
            let owner = users.first { $0.userID == roster.ownerID }
            return owner?.teamName ?? "Team \(roster.rosterID)"
        }

        func describe(_ roster: Roster) -> TeamSummary {
            let owner = users.first { $0.userID == roster.ownerID }
            let row = rows.first { $0.rosterID == roster.rosterID }
            let rank = standings.firstIndex { $0.rosterID == roster.rosterID }.map { $0 + 1 }

            // starters, starters_points and the league's starting slots are index-aligned.
            var starters: [StarterLine] = []
            let ids = row?.starters ?? []
            let points = row?.startersPoints ?? []
            for (index, playerID) in ids.enumerated() {
                let slot = index < slots.count ? slots[index] : "FLEX"
                let scored = index < points.count ? points[index] : 0
                if playerID == "0" {
                    starters.append(StarterLine(slot: slot, name: "Empty", points: scored))
                    continue
                }
                let projection = context.projections[playerID]
                starters.append(StarterLine(
                    slot: slot,
                    name: context.playerNames[playerID] ?? "",
                    points: scored,
                    projected: projection?.points(receptionPoints: receptionPoints),
                    injury: projection?.injury,
                    status: gameStatus(playerID: playerID, projection: projection)
                ))
            }

            // Only claim a projection when projections actually loaded.
            var projectedTotal: Double? = nil
            if !context.projections.isEmpty && !starters.isEmpty {
                projectedTotal = starters.reduce(0) { $0 + $1.expectedPoints }
            }

            return TeamSummary(
                teamName: teamName(roster),
                ownerName: owner?.displayName ?? "",
                avatarURL: owner?.avatarURL,
                points: row?.score ?? 0,
                record: roster.record,
                rank: rank,
                matchupID: row?.matchupID,
                starters: starters,
                projectedTotal: projectedTotal
            )
        }

        private func gameStatus(playerID: String, projection: PlayerProjection?) -> GameStatus {
            if teamStatus.isEmpty {
                return .unknown
            }
            // Projections carry the current team; the daily player directory is the fallback.
            guard let team = projection?.team ?? context.playerTeams[playerID] else {
                return .unknown
            }
            return teamStatus[team] ?? .bye
        }
    }
}
