import SwiftUI

/// Navigation shell that swaps the whole screen based on the game phase. Using a single
/// switch (rather than a NavigationStack) keeps the host-driven, phase-based transitions
/// simple and matches the fact that clients change screens only on host command.
struct RootView: View {
    @EnvironmentObject private var game: GameController

    var body: some View {
        ZStack {
            TriviaTheme.background.ignoresSafeArea()

            content
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: game.phase)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var content: some View {
        switch game.phase {
        case .home:
            HomeView()
        case .hostLobby:
            HostLobbyView()
        case .joinLobby:
            JoinLobbyView()
        case .genreSelect:
            GenreSelectView()
        case .question:
            QuestionView()
        case .reveal:
            RevealView()
        case .finalLeaderboard:
            FinalLeaderboardView()
        }
    }
}
