import SwiftUI

/// Screen 7: ranked final scores, Play Again / Return to Home (GDD §8.7).
/// Play Again is host-only; clients see a waiting note until the host restarts.
struct FinalLeaderboardView: View {
    @EnvironmentObject private var game: GameController

    private var localID: String {
        game.players.first { $0.name == game.deviceName }?.id ?? ""
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Final Scores")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(TriviaTheme.accent)
                .padding(.top, 16)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(game.finalRankedScores.enumerated()), id: \.element.id) { rank, player in
                        row(rank: rank, player: player)
                    }
                }
            }

            Spacer(minLength: 0)

            if game.isHost {
                Button("Play Again") { game.hostPlayAgain() }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Text("Waiting for the host to start another round…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button("Return to Home") { game.leaveToHome() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.top, 4)
        }
        .padding(24)
    }

    private func row(rank: Int, player: Player) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(medalColor(rank).opacity(0.25))
                    .frame(width: 40, height: 40)
                Text("\(rank + 1)")
                    .font(.headline)
                    .foregroundStyle(medalColor(rank))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.headline)
                    .foregroundStyle(player.id == localID ? TriviaTheme.accent : .white)
                if player.hasLeft {
                    Text("left the game")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer()
            Text("\(player.score)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(TriviaTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 0: return Color(red: 1.0, green: 0.84, blue: 0.35)   // gold
        case 1: return Color(red: 0.80, green: 0.83, blue: 0.88)  // silver
        case 2: return Color(red: 0.80, green: 0.55, blue: 0.35)  // bronze
        default: return .white.opacity(0.7)
        }
    }
}
