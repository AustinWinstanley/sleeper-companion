import AppIntents
import WidgetKit

/// Widget configuration: which of the user's leagues to show. The options list comes from
/// /user/{user_id}/leagues/nfl/{season}; with one league the default is applied silently, so
/// friends never have to open the picker.
struct SelectLeagueIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose League"
    static let description = IntentDescription("Pick which of your Sleeper leagues the widget shows.")

    @Parameter(title: "League")
    var league: LeagueEntity?
}

struct LeagueEntity: AppEntity {
    let id: String
    let name: String
    let season: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "League"
    static let defaultQuery = LeagueQuery()

    var displayRepresentation: DisplayRepresentation {
        return DisplayRepresentation(title: "\(name)", subtitle: "\(season)")
    }

    init(_ league: CachedLeague) {
        id = league.id
        name = league.name
        season = league.season
    }
}

struct LeagueQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [LeagueEntity] {
        return await allLeagues().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LeagueEntity] {
        return await allLeagues()
    }

    func defaultResult() async -> LeagueEntity? {
        guard let userID = UserStore.userID else {
            return nil
        }
        let defaultID = await LeagueDirectory.defaultLeagueID(userID: userID)
        return await allLeagues().first { $0.id == defaultID }
    }

    private func allLeagues() async -> [LeagueEntity] {
        guard let userID = UserStore.userID else {
            return []
        }
        return await LeagueDirectory.leagues(userID: userID).map { LeagueEntity($0) }
    }
}
