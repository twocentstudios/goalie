import SwiftUI

@main
struct goalieApp: App {
    var body: some Scene {
        Window("Goalie", id: "main") {
            // TODO: real store setup
            ContentView(store: .init(topic: .init(id: .init(), sessions: .init(), goals: .init()), save: { _ in }))
        }
    }
}
