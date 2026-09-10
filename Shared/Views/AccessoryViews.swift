import SwiftUI
import WidgetKit

// Lock Screen layouts. No explicit colors beyond .secondary: the system renders these in
// vibrant monochrome and picks the tint, so hardcoded white would fight it.

/// Rectangular slot (~160×72 pt): one row per team with avatar, name and score (leader bold),
/// then a score-share bar with week and rank. Stale data swaps the week for "Cached".
struct MatchupRectangularView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        VStack(alignment: .leading, spacing: 3) {
            teamRow(snapshot.mine, avatar: loaded.myAvatar, leading: snapshot.iAmLeading)
            if let theirs = snapshot.theirs {
                teamRow(theirs, avatar: loaded.theirAvatar, leading: !snapshot.iAmLeading)
            } else {
                Text("Bye week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ShareBar(mine: snapshot.mine.points, theirs: snapshot.theirs?.points ?? 0)
                Text(footer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// My share of the combined score. Hand-drawn because Gauge's linear styles insist on
    /// rendering their label, which eats a full line in a 72 pt slot.
    private struct ShareBar: View {
        let mine: Double
        let theirs: Double

        var body: some View {
            let fraction = mine / max(mine + theirs, 1)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.4))
                    Capsule()
                        .fill(.primary)
                        .frame(width: max(geometry.size.width * fraction, 4))
                        .widgetAccentable()
                }
            }
            .frame(height: 4)
        }
    }

    private func teamRow(_ team: TeamSummary, avatar: UIImage?, leading: Bool) -> some View {
        HStack(spacing: 5) {
            AvatarView(image: avatar, size: 16)
            Text(team.teamName)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 4)
            Text(team.points.points(decimals: 1))
                .font(.system(size: 13, weight: leading ? .bold : .regular))
                .monospacedDigit()
                .widgetAccentable(leading)
        }
    }

    private var footer: String {
        if loaded.stale {
            return "Cached"
        }
        let snapshot = loaded.snapshot
        if let rank = snapshot.mine.rank {
            return "Wk \(snapshot.week) · \(rank.ordinal)"
        }
        return "Wk \(snapshot.week)"
    }
}

/// A gauge filled by my share of the combined score, my score in the middle, theirs underneath.
struct MatchupCircularView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        let mine = snapshot.mine.points
        let theirs = snapshot.theirs?.points ?? 0
        let total = max(mine + theirs, 1)
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: mine, in: 0...total) {
                Text("Me")
            } currentValueLabel: {
                Text(mine.points(decimals: 0))
                    .font(.system(size: 15, weight: .bold))
            } minimumValueLabel: {
                Text("")
            } maximumValueLabel: {
                Text(snapshot.isBye ? "Bye" : theirs.points(decimals: 0))
                    .font(.system(size: 9))
            }
            .gaugeStyle(.accessoryCircular)
        }
    }
}

struct MatchupInlineView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        if let theirs = snapshot.theirs {
            Label("\(snapshot.mine.points.points(decimals: 1)) – \(theirs.points.points(decimals: 1)) · Wk \(snapshot.week)",
                  systemImage: "football.fill")
        } else {
            Label("Bye week · Wk \(snapshot.week)", systemImage: "football.fill")
        }
    }
}

/// One team in a rectangular slot: score line, the two top scorers this week, then record,
/// rank and week. Place two side by side (yours and the opponent's) to fill the Lock Screen row.
struct TeamPanelView: View {
    let loaded: LoadedMatchup
    let isMine: Bool

    var body: some View {
        let snapshot = loaded.snapshot
        let team = isMine ? snapshot.mine : snapshot.theirs
        let avatar = isMine ? loaded.myAvatar : loaded.theirAvatar
        let leading = isMine ? snapshot.iAmLeading : !snapshot.iAmLeading
        VStack(alignment: .leading, spacing: 2) {
            if let team {
                HStack(spacing: 5) {
                    AvatarView(image: avatar, size: 16)
                    Text(team.teamName)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    Text(team.points.points(decimals: 1))
                        .font(.system(size: 13, weight: leading ? .bold : .regular))
                        .monospacedDigit()
                        .widgetAccentable(leading)
                }
                ForEach(topStarters(team), id: \.self) { starter in
                    HStack {
                        // Slot label stands in until the app has downloaded player names.
                        Text(starter.name.isEmpty ? starter.shortSlot : starter.name)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(starter.points.points(decimals: 1))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
                Text(footer(team))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                // Asked for the opponent on a bye week.
                Text("Bye week")
                    .font(.caption)
                Text("Wk \(snapshot.week) · \(snapshot.leagueName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func topStarters(_ team: TeamSummary) -> [StarterLine] {
        let filled = team.starters.filter { $0.name != "Empty" }
        return Array(filled.sorted { $0.points > $1.points }.prefix(2))
    }

    private func footer(_ team: TeamSummary) -> String {
        if loaded.stale {
            return "Cached · \(team.recordWithRank)"
        }
        return "\(team.recordWithRank) · Wk \(loaded.snapshot.week)"
    }
}
