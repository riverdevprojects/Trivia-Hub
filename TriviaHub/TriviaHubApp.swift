import SwiftUI

@main
struct TriviaHubApp: App {
    // One registry and one controller shared across the whole app.
    @StateObject private var registry: GenreRegistry
    @StateObject private var game: GameController

    init() {
        let registry = GenreRegistry()
        _registry = StateObject(wrappedValue: registry)
        _game = StateObject(wrappedValue: GameController(genreRegistry: registry))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(registry)
                .environmentObject(game)
        }
    }
}
