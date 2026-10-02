import SwiftUI
import WidgetKit

// Home Screen layouts: avatar + score (bold when leading),
// record, team name per side; week / league / last-updated in the middle of the medium layout.
// No outer padding here: the widget gets system content margins, the app adds its own.
//
// Accented rendering (Tinted / Clear icon styles): iOS strips the background and paints
// everything in one tint. Views marked widgetAccentable() get the accent shade, so scores and
// the week header are marked; avatars opt back into full color. Nothing here can force an
// opaque background in that mode; that is the user's Home Screen setting.

extension Color {
    static let matchupTop = Color(red: 0x0f / 255.0, green: 0x2a / 255.0, blue: 0x1a / 255.0)
    static let matchupBottom = Color(red: 0x0b / 255.0, green: 0x0f / 255.0, blue: 0x14 / 255.0)
}

struct MatchupBackground: View {
    var body: some View {
        LinearGradient(colors: [.matchupTop, .matchupBottom], startPoint: .top, endPoint: .bottom)
    }
}

extension Double {
    func points(decimals: Int = 2) -> String {
        return formatted(.number.precision(.fractionLength(decimals)))
    }
}

struct AvatarView: View {
    let image: UIImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                fullColor(Image(uiImage: image).resizable())
                    .scaledToFill()
            } else {
                Image(systemName: "football.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.2)
                    .foregroundStyle(.gray)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    // Photos in accented mode would otherwise be flattened to a single tint.
    @ViewBuilder
    private func fullColor(_ image: Image) -> some View {
        if #available(iOS 18.0, *) {
            image.widgetAccentedRenderingMode(.fullColor)
        } else {
            image
        }
    }
}

struct TeamColumn: View {
    let team: TeamSummary
    let avatar: UIImage?
    let leading: Bool
    var alignRight = false
    /// The small widget has room for one detail line, so it shows game progress when there
    /// is any and the record otherwise. Larger layouts show both.
    var compact = false

    var body: some View {
        VStack(alignment: alignRight ? .trailing : .leading, spacing: 2) {
            HStack(spacing: 6) {
                if alignRight {
                    score
                    AvatarView(image: avatar, size: 32)
                } else {
                    AvatarView(image: avatar, size: 32)
                    score
                }
            }
            if compact {
                detail(team.statusLine ?? team.recordWithRank)
            } else {
                detail(team.recordWithRank)
                if let statusLine = team.statusLine {
                    detail(statusLine)
                }
            }
            Text(team.teamName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.gray)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var score: some View {
        Text(team.points.points())
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(leading ? Color.white : Color(white: 0.75))
            .widgetAccentable(leading)
    }
}

/// "2 starters out" in orange, shown wherever the lineup has a slot that will score nothing.
struct StarterWarning: View {
    let text: String
    var size: CGFloat = 9

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(.orange)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
    }
}

/// Week, league, playoff round or countdown, lineup warning, last updated.
struct CenterColumn: View {
    let loaded: LoadedMatchup

    var body: some View {
        VStack(spacing: 2) {
            Text("Week \(loaded.snapshot.week)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .widgetAccentable()
            Text(loaded.snapshot.leagueName)
                .font(.system(size: 10))
                .foregroundStyle(.gray)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
            if let playoffLabel = loaded.snapshot.playoffLabel {
                Text(playoffLabel)
                    .font(.system(size: 9))
                    .foregroundStyle(.gray)
            }
            if let warning = loaded.snapshot.starterWarning {
                StarterWarning(text: warning)
            }
            Spacer().frame(height: 4)
            Text(UpdatedLabel.text(for: loaded))
                .font(.system(size: 9))
                .foregroundStyle(loaded.stale ? Color.orange : Color.gray)
        }
    }
}

struct MatchupMediumView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        HStack(alignment: .center) {
            TeamColumn(team: snapshot.mine, avatar: loaded.myAvatar, leading: snapshot.iAmLeading)
            Spacer()
            if let theirs = snapshot.theirs {
                CenterColumn(loaded: loaded)
                Spacer()
                TeamColumn(team: theirs, avatar: loaded.theirAvatar, leading: !snapshot.iAmLeading, alignRight: true)
            } else {
                Text("Bye week")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
            }
        }
    }
}

struct MatchupSmallView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        VStack(alignment: .leading, spacing: 6) {
            TeamColumn(team: snapshot.mine, avatar: loaded.myAvatar, leading: snapshot.iAmLeading, compact: true)
            if let theirs = snapshot.theirs {
                // The warning replaces the "vs" line: a dead lineup slot matters more than the week number.
                if let warning = snapshot.starterWarning {
                    StarterWarning(text: warning, size: 10)
                } else {
                    Text("vs · Week \(snapshot.week)")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
                TeamColumn(team: theirs, avatar: loaded.theirAvatar, leading: !snapshot.iAmLeading, compact: true)
            } else {
                Text("Bye week · Week \(snapshot.week)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray)
            }
            if loaded.stale {
                Text(UpdatedLabel.text(for: loaded))
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The two starting lineups slot by slot. Per row the higher number is brighter, same rule as
/// the headline scores. Before kickoff a row shows the projection in italics; once a game is
/// final the name dims; a live game gets a green dot. Injury and bye flags sit after the name.
struct LineupTable: View {
    let mine: TeamSummary
    let theirs: TeamSummary?

    var body: some View {
        let rowCount = max(mine.starters.count, theirs?.starters.count ?? 0)
        VStack(spacing: 6) {
            ForEach(0..<rowCount, id: \.self) { index in
                let left = index < mine.starters.count ? mine.starters[index] : nil
                let right = (theirs?.starters ?? []).count > index ? theirs?.starters[index] : nil
                let leftLeads = (left?.displayPoints ?? 0) >= (right?.displayPoints ?? 0)
                HStack(spacing: 6) {
                    starter(left, leads: leftLeads, alignRight: false)
                    Text(left?.shortSlot ?? right?.shortSlot ?? "")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.gray)
                        .frame(width: 34)
                    if theirs != nil {
                        starter(right, leads: !leftLeads, alignRight: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func starter(_ line: StarterLine?, leads: Bool, alignRight: Bool) -> some View {
        let isFinal = line?.status == .final
        let name = Text(line?.name ?? "")
            .font(.system(size: 11))
            .foregroundStyle(isFinal ? Color(white: 0.5) : Color(white: 0.92))
            .lineLimit(1)
            .truncationMode(.tail)
        let points = Text((line?.displayPoints ?? 0).points(decimals: 1))
            .font(.system(size: 11, weight: leads ? .semibold : .regular))
            .italic(line?.showsProjection == true)
            .monospacedDigit()
            .foregroundStyle(pointsColor(line, leads: leads))
        HStack(spacing: 4) {
            if alignRight {
                points
                Spacer(minLength: 0)
                flags(line)
                name
            } else {
                name
                flags(line)
                Spacer(minLength: 0)
                points
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func pointsColor(_ line: StarterLine?, leads: Bool) -> Color {
        if line?.showsProjection == true {
            return Color(white: 0.55)
        }
        return leads ? Color.white : Color(white: 0.7)
    }

    @ViewBuilder
    private func flags(_ line: StarterLine?) -> some View {
        if line?.status == .live {
            Circle()
                .fill(Color.green)
                .frame(width: 5, height: 5)
        }
        if let tag = line?.tag {
            Text(tag)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(line?.isUnavailable == true ? Color.orange : Color.yellow)
        }
    }
}

/// Medium header on top, then the lineups, then one line of league context: the playoff
/// path during playoffs, the latest roster move otherwise.
struct MatchupLargeView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        VStack(spacing: 8) {
            MatchupMediumView(loaded: loaded)
            Divider()
                .overlay(Color.white.opacity(0.15))
            LineupTable(mine: snapshot.mine, theirs: snapshot.theirs)
            Spacer(minLength: 0)
            if let footer = snapshot.bracketPath.last ?? snapshot.transactionLine {
                Text(footer)
                    .font(.system(size: 9))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
    }
}

/// The iOS 27 full-page size: everything in the large layout plus league standings, the full
/// playoff path and the latest roster move.
struct MatchupExtraLargeView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        VStack(spacing: 8) {
            MatchupMediumView(loaded: loaded)
            Divider()
                .overlay(Color.white.opacity(0.15))
            LineupTable(mine: snapshot.mine, theirs: snapshot.theirs)
            Divider()
                .overlay(Color.white.opacity(0.15))
            standings(snapshot.standings)
            Spacer(minLength: 0)
            VStack(spacing: 2) {
                ForEach(snapshot.bracketPath, id: \.self) { line in
                    footnote(line)
                }
                if let transactionLine = snapshot.transactionLine {
                    footnote(transactionLine)
                }
            }
        }
    }

    private func standings(_ lines: [StandingLine]) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("Standings")
                Spacer()
                Text("PF")
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.gray)
            ForEach(lines, id: \.rank) { line in
                HStack(spacing: 6) {
                    Text("\(line.rank)")
                        .frame(width: 16, alignment: .trailing)
                        .foregroundStyle(.gray)
                    Text(line.teamName)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(line.record)
                        .monospacedDigit()
                    Text(line.pointsFor.points(decimals: 1))
                        .monospacedDigit()
                        .frame(width: 52, alignment: .trailing)
                }
                .font(.system(size: 11, weight: line.isMine ? .semibold : .regular))
                .foregroundStyle(line.isMine || line.isOpponent ? Color.white : Color(white: 0.65))
                .widgetAccentable(line.isMine)
            }
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9))
            .foregroundStyle(.gray)
            .lineLimit(1)
    }
}

enum UpdatedLabel {
    static func text(for loaded: LoadedMatchup) -> String {
        let time = loaded.snapshot.fetchedAt.formatted(date: .omitted, time: .shortened)
        return loaded.stale ? "Cached \(time)" : time
    }
}

/// Plain text for setup prompts and errors, styled for the dark gradient background.
struct MessageView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
