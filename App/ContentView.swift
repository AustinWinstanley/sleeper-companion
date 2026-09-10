import SwiftUI
import WidgetKit

/// Routes between first-run setup and the home screen based on whether a user_id is stored.
struct ContentView: View {
    @State private var userID = UserStore.userID
    @State private var displayName = UserStore.displayName

    var body: some View {
        NavigationStack {
            if let userID {
                HomeView(userID: userID, displayName: displayName ?? "", onReset: reset)
            } else {
                SetupView(onPicked: pick)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)) { _ in
            UserStore.pullFromCloud()
            reload()
        }
        .onOpenURL { url in
            SleeperHandoff.handle(url)
        }
    }

    private func pick(_ user: SleeperUser) {
        UserStore.save(userID: user.userID, displayName: user.displayName ?? user.username ?? user.userID)
        WidgetCenter.shared.reloadAllTimelines()
        reload()
    }

    private func reset() {
        UserStore.clear()
        WidgetCenter.shared.reloadAllTimelines()
        reload()
    }

    private func reload() {
        userID = UserStore.userID
        displayName = UserStore.displayName
    }
}

/// First run: type a Sleeper username, confirm the account it resolves to, done. Sleeper's
/// public user endpoint accepts usernames (and user IDs), so no login is involved.
struct SetupView: View {
    let onPicked: (SleeperUser) -> Void

    @State private var username = ""
    @State private var candidate: SleeperUser?
    @State private var error: String?
    @State private var isLookingUp = false

    var body: some View {
        Form {
            Section {
                TextField("Sleeper username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit(lookUp)
                Button(isLookingUp ? "Looking up…" : "Find my account", action: lookUp)
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
            } header: {
                Text("Who are you on Sleeper?")
            } footer: {
                Text("The username you log in to Sleeper with. Nothing is sent anywhere except Sleeper's public API, and no password is needed.")
            }

            if let candidate {
                Section {
                    UserRow(user: candidate)
                    Button("That's me") {
                        onPicked(candidate)
                    }
                }
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Sleeper Companion")
    }

    private func lookUp() {
        let name = username.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            return
        }
        isLookingUp = true
        error = nil
        candidate = nil
        Task {
            do {
                candidate = try await SleeperAPI.user(named: name)
            } catch {
                self.error = error.localizedDescription
            }
            isLookingUp = false
        }
    }
}

struct UserRow: View {
    let user: SleeperUser

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: user.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "football.fill")
                    .foregroundStyle(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            VStack(alignment: .leading) {
                Text(user.displayName ?? user.username ?? "Unknown")
                    .font(.headline)
                if let username = user.username {
                    Text("@\(username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// After setup: a live preview of the medium widget, league list, and the way back to the picker.
struct HomeView: View {
    let userID: String
    let displayName: String
    let onReset: () -> Void

    @State private var leagues: [CachedLeague] = []
    /// Empty until the league list has loaded; stays empty if the user has no leagues.
    @State private var leagueID = ""
    @State private var result: MatchupResult?
    @State private var playersUpdated = PlayerDirectory.lastUpdated

    var body: some View {
        List {
            Section {
                preview(height: 158) { loaded in
                    MatchupMediumView(loaded: loaded)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("This week")
            }

            Section {
                preview(height: 354) { loaded in
                    MatchupLargeView(loaded: loaded)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } header: {
                Text("Large widget")
            }

            if leagues.count > 1 {
                Section {
                    Picker("League", selection: $leagueID) {
                        ForEach(leagues) { league in
                            Text(league.name).tag(league.id)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("League")
                } footer: {
                    Text("Widgets show this league unless you pick a different one by long-pressing the widget.")
                }
            }

            Section {
                Text("Long-press the Home Screen, tap +, and search for Sleeper Companion. Lock Screen: customize the Lock Screen and add it there. Scores update every 15–30 minutes as iOS allows.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Refresh widgets now") {
                    WidgetCenter.shared.reloadAllTimelines()
                }
            } header: {
                Text("Widget")
            } footer: {
                if let playersUpdated {
                    Text("Player names updated \(playersUpdated.formatted(date: .abbreviated, time: .shortened)).")
                } else {
                    Text("Player names not downloaded yet; lineups show slots only until they are.")
                }
            }

            Section {
                Button("Not \(displayName)? Pick again", role: .destructive, action: onReset)
            }
        }
        .navigationTitle("Sleeper Companion")
        .refreshable {
            await loadMatchup()
        }
        .task {
            // Names first so the preview (and the widgets, via reload) get lineups with names.
            if await PlayerDirectory.refreshIfNeeded() {
                playersUpdated = PlayerDirectory.lastUpdated
                WidgetCenter.shared.reloadAllTimelines()
            }
            leagues = await LeagueDirectory.leagues(userID: userID)
            leagueID = await LeagueDirectory.defaultLeagueID(userID: userID) ?? ""
            await loadMatchup()
        }
        .onChange(of: leagueID) {
            // The app's choice becomes the default for widgets that haven't picked a league.
            if !leagueID.isEmpty, leagueID != UserStore.preferredLeagueID {
                UserStore.preferredLeagueID = leagueID
                WidgetCenter.shared.reloadAllTimelines()
            }
            Task {
                await loadMatchup()
            }
        }
    }

    /// A widget-shaped card. Padding stands in for the system content margins a real widget gets.
    private func preview<Content: View>(height: CGFloat, @ViewBuilder content: @escaping (LoadedMatchup) -> Content) -> some View {
        Group {
            switch result {
            case nil:
                ProgressView()
                    .tint(.white)
            case .needsSetup:
                MessageView(message: "Open Sleeper Companion to set up")
            case .failed(let error):
                MessageView(message: error)
            case .loaded(let loaded):
                content(loaded)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(MatchupBackground())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func loadMatchup() async {
        guard !leagueID.isEmpty else {
            result = .failed("No Sleeper leagues found for this season")
            return
        }
        result = await MatchupFetcher.fetch(leagueID: leagueID, userID: userID)
    }
}

#Preview {
    ContentView()
}
