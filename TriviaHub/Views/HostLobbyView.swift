import SwiftUI

/// Screen 2: Host lobby — editable name, live player list, Start Game (GDD §8.2).
struct HostLobbyView: View {
    @EnvironmentObject private var game: GameController

    var body: some View {
        VStack(spacing: 20) {
            header

            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lobby name")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(game.deviceName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Nearby players can now find this game.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            playerList

            Spacer()

            Button("Start Game") { game.hostBeginGenreSelection() }
                .buttonStyle(PrimaryButtonStyle(enabled: game.canStart))
                .disabled(!game.canStart)

            if !game.canStart {
                Text("Need at least \(GameConfig.minPlayersToStart) players to start")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(24)
    }

    private var header: some View {
        HStack {
            Button {
                game.leaveToHome()
            } label: {
                Label("Leave", systemImage: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Text("Hosting")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            // Balance the leading button.
            Color.clear.frame(width: 60, height: 1)
        }
    }

    private var playerList: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Players (\(game.players.filter { !$0.hasLeft }.count)/\(GameConfig.maxPlayers))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                ForEach(game.players) { player in
                    HStack {
                        Image(systemName: player.id == game.players.first?.id ? "crown.fill" : "person.fill")
                            .foregroundStyle(TriviaTheme.accent)
                        Text(player.name)
                            .foregroundStyle(.white)
                            .strikethrough(player.hasLeft)
                        if player.hasLeft {
                            Text("left")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
