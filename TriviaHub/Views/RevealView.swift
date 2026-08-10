import SwiftUI

/// Screen 6: correct answer highlighted, points earned this round, brief live
/// leaderboard snippet (GDD §8.6).
struct RevealView: View {
    @EnvironmentObject private var game: GameController

    private var localID: String {
        // The local player's row is highlighted in the snippet.
        game.players.first { $0.name == game.deviceName }?.id ?? ""
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Answer")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.top, 12)

            options
            roundResult
            leaderboardSnippet
            Spacer()

            Text("Next question coming up…")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(24)
    }

    @ViewBuilder
    private var options: some View {
        if let payload = game.currentPayload, let correct = game.revealCorrectIndex {
            VStack(spacing: 12) {
                ForEach(Array(payload.options.enumerated()), id: \.offset) { index, option in
                    HStack {
                        Image(systemName: index == correct ? "checkmark.circle.fill"
                              : (index == game.localAnswerIndex ? "xmark.circle.fill" : "circle"))
                            .foregroundStyle(index == correct ? TriviaTheme.correct
                                             : (index == game.localAnswerIndex ? TriviaTheme.incorrect : .white.opacity(0.3)))
                        Text(option).foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(14)
                    .background(rowColor(index: index, correct: correct))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func rowColor(index: Int, correct: Int) -> Color {
        if index == correct { return TriviaTheme.correct.opacity(0.22) }
        if index == game.localAnswerIndex { return TriviaTheme.incorrect.opacity(0.20) }
        return TriviaTheme.card
    }

    @ViewBuilder
    private var roundResult: some View {
        let earned = game.lastRoundScores[localID] ?? 0
        Card {
            HStack {
                Text(earned > 0 ? "Nice! +\(earned) points" : "No points this round")
                    .font(.headline)
                    .foregroundStyle(earned > 0 ? TriviaTheme.correct : .white.opacity(0.7))
                Spacer()
            }
        }
    }

    private var leaderboardSnippet: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Leaderboard")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                ForEach(Array(game.liveRanked.prefix(4).enumerated()), id: \.element.id) { rank, player in
                    HStack {
                        Text("\(rank + 1).").foregroundStyle(.white.opacity(0.6))
                        Text(player.name)
                            .foregroundStyle(player.id == localID ? TriviaTheme.accent : .white)
                        Spacer()
                        Text("\(player.score)").foregroundStyle(.white)
                    }
                    .font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
