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
            Text(team.recordWithRank)
                .font(.system(size: 11))
                .foregroundStyle(.gray)
            Text(team.teamName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var score: some View {
        Text(team.points.points())
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(leading ? Color.white : Color(white: 0.75))
            .widgetAccentable(leading)
    }
}

/// Week, league, playoff countdown, last updated. Shared by the medium and large layouts.
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
            TeamColumn(team: snapshot.mine, avatar: loaded.myAvatar, leading: snapshot.iAmLeading)
            if let theirs = snapshot.theirs {
                Text("vs · Week \(snapshot.week)")
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
                TeamColumn(team: theirs, avatar: loaded.theirAvatar, leading: !snapshot.iAmLeading)
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

/// Medium header on top, then the two starting lineups slot by slot. Per row the higher score
/// is white and the lower one dimmed, same rule as the headline scores.
struct MatchupLargeView: View {
    let loaded: LoadedMatchup

    var body: some View {
        let snapshot = loaded.snapshot
        VStack(spacing: 8) {
            MatchupMediumView(loaded: loaded)
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
            lineup(mine: snapshot.mine, theirs: snapshot.theirs)
            Spacer(minLength: 0)
        }
    }

    private func lineup(mine: TeamSummary, theirs: TeamSummary?) -> some View {
        let rowCount = max(mine.starters.count, theirs?.starters.count ?? 0)
        return VStack(spacing: 6) {
            ForEach(0..<rowCount, id: \.self) { index in
                let left = index < mine.starters.count ? mine.starters[index] : nil
                let right = (theirs?.starters ?? []).count > index ? theirs?.starters[index] : nil
                let leftLeads = (left?.points ?? 0) >= (right?.points ?? 0)
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
        let name = Text(line?.name ?? "")
            .font(.system(size: 11))
            .lineLimit(1)
            .truncationMode(.tail)
        let points = Text((line?.points ?? 0).points(decimals: 1))
            .font(.system(size: 11, weight: leads ? .semibold : .regular))
            .monospacedDigit()
        HStack(spacing: 4) {
            if alignRight {
                points
                Spacer(minLength: 0)
                name
            } else {
                name
                Spacer(minLength: 0)
                points
            }
        }
        .foregroundStyle(leads ? Color.white : Color(white: 0.7))
        .frame(maxWidth: .infinity)
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
