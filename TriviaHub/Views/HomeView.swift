import SwiftUI

/// Screen 1: Host / Join entry point (GDD §8.1).
struct HomeView: View {
    @EnvironmentObject private var game: GameController

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text("Trivia Hub")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(TriviaTheme.accent)
                Text("Local multiplayer party trivia")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                Text("Your name")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                TextField("Name", text: $game.deviceName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(14)
                    .background(TriviaTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 14) {
                Button("Host Game") { game.hostGame() }
                    .buttonStyle(PrimaryButtonStyle())

                Button("Join Game") { game.joinGame() }
                    .buttonStyle(PrimaryButtonStyle())
            }

            Spacer()

            Text("No internet needed — plays over Wi-Fi or Bluetooth")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
