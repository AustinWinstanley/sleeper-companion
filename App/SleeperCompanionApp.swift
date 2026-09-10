import SwiftUI

@main
struct SleeperCompanionApp: App {
    init() {
        // A new phone signed into the same iCloud account skips setup.
        UserStore.pullFromCloud()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
