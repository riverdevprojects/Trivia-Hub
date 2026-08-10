import SwiftUI
import MultipeerConnectivity

/// Screen 3: Joiner lobby — discoverable games, tap to join, waiting state (GDD §8.3).
struct JoinLobbyView: View {
    @EnvironmentObject private var game: GameController

    /// Once we appear in a roster from the host we treat ourselves as "joined".
    private var hasJoined: Bool {
        game.players.contains { $0.name == game.deviceName } || !game.players.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            header

            if hasJoined {
                joinedState
            } else {
                discoveryState
            }

            Spacer()
        }
        .padding(24)
    }

    private var header: some View {
        HStack {
            Button {
                game.leaveToHome()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Text("Join a Game")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 60, height: 1)
        }
    }

    private var discoveryState: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ProgressView().tint(TriviaTheme.accent)
                Text("Looking for nearby games…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.top, 8)

            if game.discoveredHosts.isEmpty {
                Card {
                    Text("Make sure the host has tapped “Host Game” and you're on the same Wi-Fi or have Bluetooth on.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Card {
                    VStack(spacing: 10) {
                        ForEach(game.discoveredHosts, id: \.self) { host in
                            Button {
                                game.invite(host)
                            } label: {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                        .foregroundStyle(TriviaTheme.accent)
                                    Text(host.displayName)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                .padding(.vertical, 6)
                            }
                            if host != game.discoveredHosts.last {
                                Divider().overlay(Color.white.opacity(0.1))
                            }
                        }
                    }
                }
            }
        }
    }

    private var joinedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(TriviaTheme.correct)
            Text("You're in!")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("Waiting for the host to start…")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Text("In the lobby")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    ForEach(game.players) { player in
                        HStack {
                            Image(systemName: "person.fill").foregroundStyle(TriviaTheme.accent)
                            Text(player.name).foregroundStyle(.white)
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
