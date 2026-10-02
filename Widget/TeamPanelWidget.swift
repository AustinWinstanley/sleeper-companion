import AppIntents
import SwiftUI
import WidgetKit

enum TeamSide: String, AppEnum {
    case mine
    case opponent

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Team"
    static let caseDisplayRepresentations: [TeamSide: DisplayRepresentation] = [
        .mine: "My team",
        .opponent: "Opponent",
    ]
}

struct TeamPanelIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Team Panel"
    static let description = IntentDescription("One team's score, top scorers and record. Add two, yours and your opponent's, to fill the row.")

    @Parameter(title: "Team", default: .mine)
    var side: TeamSide

    @Parameter(title: "League")
    var league: LeagueEntity?
}

struct TeamPanelEntry: TimelineEntry {
    let date: Date
    let result: MatchupResult
    let side: TeamSide
}

struct TeamPanelProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TeamPanelEntry {
        return TeamPanelEntry(date: .now, result: .loaded(.sample), side: .mine)
    }

    func snapshot(for configuration: TeamPanelIntent, in context: Context) async -> TeamPanelEntry {
        if context.isPreview {
            return TeamPanelEntry(date: .now, result: .loaded(.sample), side: configuration.side)
        }
        return await load(configuration)
    }

    func timeline(for configuration: TeamPanelIntent, in context: Context) async -> Timeline<TeamPanelEntry> {
        let entry = await load(configuration)
        return Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(entry.result.refreshInterval)))
    }

    private func load(_ configuration: TeamPanelIntent) async -> TeamPanelEntry {
        let result = await MatchupEntryLoader.result(for: configuration.league)
        return TeamPanelEntry(date: .now, result: result, side: configuration.side)
    }
}

struct TeamPanelEntryView: View {
    let entry: TeamPanelEntry

    var body: some View {
        Group {
            switch entry.result {
            case .needsSetup:
                Text("Open Sleeper Companion to set up")
                    .font(.caption2)
            case .failed(let error):
                Text(error)
                    .font(.caption2)
            case .loaded(let loaded):
                TeamPanelView(loaded: loaded, isMine: entry.side == .mine)
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(handoffURL)
    }

    private var handoffURL: URL? {
        if case .loaded(let loaded) = entry.result {
            return loaded.snapshot.sleeperHandoffURL
        }
        return nil
    }
}

struct TeamPanelWidget: Widget {
    let kind = "TeamPanel"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TeamPanelIntent.self, provider: TeamPanelProvider()) { entry in
            TeamPanelEntryView(entry: entry)
        }
        .configurationDisplayName("Team Panel")
        .description("One team's score, top scorers and record. Add two to fill the row.")
        .supportedFamilies([.accessoryRectangular])
    }
}

#Preview("Team Panel", as: .accessoryRectangular) {
    TeamPanelWidget()
} timeline: {
    TeamPanelEntry(date: .now, result: .loaded(.sample), side: .mine)
    TeamPanelEntry(date: .now, result: .loaded(.sample), side: .opponent)
    TeamPanelEntry(date: .now, result: .loaded(.sampleBye), side: .opponent)
}
