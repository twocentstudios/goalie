import SwiftUI

@main
struct goalieApp: App {
    @StateObject var rootStore: RootStore = .init()

    var body: some Scene {
        Window("Goalie", id: "root") {
            RootView(store: rootStore)
                .frame(minWidth: 190, maxWidth: 350, minHeight: nil, maxHeight: nil)
        }
        .windowResizability(.contentSize)
    }
}
