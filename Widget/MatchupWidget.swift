import SwiftUI
import WidgetKit

struct MatchupTimelineEntry: TimelineEntry {
    let date: Date
    let result: MatchupResult
}

struct MatchupProvider: AppIntentTimelineProvider {
    // Refreshes are OS-budgeted (~15–30 min in practice); asking for less than 15 buys nothing.
    private let refreshInterval: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> MatchupTimelineEntry {
        return MatchupTimelineEntry(date: .now, result: .loaded(.sample))
    }

    func snapshot(for configuration: SelectLeagueIntent, in context: Context) async -> MatchupTimelineEntry {
        // The widget gallery wants something instantly; real data is fine everywhere else.
        if context.isPreview {
            return placeholder(in: context)
        }
        return await load(configuration)
    }

    func timeline(for configuration: SelectLeagueIntent, in context: Context) async -> Timeline<MatchupTimelineEntry> {
        let entry = await load(configuration)
        return Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(refreshInterval)))
    }

    private func load(_ configuration: SelectLeagueIntent) async -> MatchupTimelineEntry {
        return MatchupTimelineEntry(date: .now, result: await MatchupEntryLoader.result(for: configuration.league))
    }
}

/// Shared by every widget kind: resolve the user and league, then fetch with cache fallback.
enum MatchupEntryLoader {
    static func result(for league: LeagueEntity?) async -> MatchupResult {
        guard let userID = UserStore.userID else {
            return .needsSetup
        }
        // No league chosen yet (picker never opened, or it was offline): resolve the default now.
        var leagueID = league?.id
        if leagueID == nil {
            leagueID = await LeagueDirectory.defaultLeagueID(userID: userID)
        }
        guard let leagueID else {
            return .failed("No Sleeper leagues found for this season")
        }
        return await MatchupFetcher.fetch(leagueID: leagueID, userID: userID)
    }
}

struct MatchupWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MatchupTimelineEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if isAccessory {
                    Color.clear
                } else {
                    MatchupBackground()
                }
            }
            // A widget can only open its own app; the app forwards this to sleeper://.
            .widgetURL(handoffURL)
    }

    private var handoffURL: URL? {
        if case .loaded(let loaded) = entry.result {
            return loaded.snapshot.sleeperHandoffURL
        }
        return nil
    }

    @ViewBuilder
    private var content: some View {
        switch entry.result {
        case .needsSetup:
            message("Open Sleeper Companion to set up")
        case .failed(let error):
            message(error)
        case .loaded(let loaded):
            switch family {
            case .systemSmall:
                MatchupSmallView(loaded: loaded)
            case .systemLarge:
                MatchupLargeView(loaded: loaded)
            case .accessoryRectangular:
                MatchupRectangularView(loaded: loaded)
            case .accessoryCircular:
                MatchupCircularView(loaded: loaded)
            case .accessoryInline:
                MatchupInlineView(loaded: loaded)
            default:
                MatchupMediumView(loaded: loaded)
            }
        }
    }

    @ViewBuilder
    private func message(_ text: String) -> some View {
        if isAccessory {
            Text(text)
                .font(.caption2)
        } else {
            MessageView(message: text)
        }
    }

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            return true
        default:
            return false
        }
    }
}

struct MatchupWidget: Widget {
    let kind = "MatchupWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectLeagueIntent.self, provider: MatchupProvider()) { entry in
            MatchupWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Matchup")
        .description("Your current Sleeper fantasy matchup.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview("Medium", as: .systemMedium) {
    MatchupWidget()
} timeline: {
    MatchupTimelineEntry(date: .now, result: .loaded(.sample))
    MatchupTimelineEntry(date: .now, result: .loaded(.sampleStale))
    MatchupTimelineEntry(date: .now, result: .loaded(.sampleBye))
    MatchupTimelineEntry(date: .now, result: .needsSetup)
}

#Preview("Large", as: .systemLarge) {
    MatchupWidget()
} timeline: {
    MatchupTimelineEntry(date: .now, result: .loaded(.sample))
    MatchupTimelineEntry(date: .now, result: .loaded(.sampleBye))
}

#Preview("Small", as: .systemSmall) {
    MatchupWidget()
} timeline: {
    MatchupTimelineEntry(date: .now, result: .loaded(.sample))
    MatchupTimelineEntry(date: .now, result: .loaded(.sampleBye))
}

#Preview("Rectangular", as: .accessoryRectangular) {
    MatchupWidget()
} timeline: {
    MatchupTimelineEntry(date: .now, result: .loaded(.sample))
}

#Preview("Circular", as: .accessoryCircular) {
    MatchupWidget()
} timeline: {
    MatchupTimelineEntry(date: .now, result: .loaded(.sample))
}

#Preview("Inline", as: .accessoryInline) {
    MatchupWidget()
} timeline: {
    MatchupTimelineEntry(date: .now, result: .loaded(.sample))
}
