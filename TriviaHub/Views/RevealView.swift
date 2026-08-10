import SwiftUI

/// Screen 6 — the SongPop-style reveal: progress dots + disco ball up top, a row of
/// player avatars with crown/score/name and speed pills, then the 2×2 answer grid where
/// the correct answer pops in solid white and the rest ghost out (GDD §8.6).
struct RevealView: View {
    @EnvironmentObject private var game: GameController

    private var localID: String { game.myPlayerID }

    /// The id of the current leader (highest total), for the crown.
    private var leaderID: String? {
        game.players.filter { !$0.hasLeft }.max {
            $0.score != $1.score ? $0.score < $1.score : $0.name > $1.name
        }?.id
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DiscoBall(size: 150)
                .offset(x: 55, y: -55)
                .opacity(0.9)

            VStack(spacing: 22) {
                ProgressDots(total: game.totalQuestions, current: game.questionIndex)
                    .padding(.top, 12)

                avatarRow

                Spacer(minLength: 4)

                answerGrid

                Text("Next question coming up…")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, 2)
            }
            .padding(20)
        }
    }

    // MARK: - Avatars

    private var avatarRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 18) {
                ForEach(game.players.filter { !$0.hasLeft }) { player in
                    playerCell(player)
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
    }

    private func playerCell(_ player: Player) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                PlayerAvatar(
                    player: player,
                    size: 58,
                    showCrown: player.id == leaderID,
                    ringFraction: ringFraction(for: player.id),
                    highlighted: player.id == localID
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(player.score)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(player.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .frame(maxWidth: 84, alignment: .leading)
                }
            }
            TimePill(ms: game.lastRoundTimesMs[player.id])
        }
    }

    /// Faster answers draw a fuller ring; non-answerers get an empty arc.
    private func ringFraction(for id: String) -> Double? {
        guard let taken = game.lastRoundTimesMs[id] else { return nil }
        let remaining = Double(GameConfig.answerWindowMs - taken)
        return max(0.05, remaining / Double(GameConfig.answerWindowMs))
    }

    // MARK: - Answer grid

    private var answerGrid: some View {
        Group {
            if let payload = game.currentPayload, let correct = game.revealCorrectIndex {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible(), spacing: 14)],
                          spacing: 14) {
                    ForEach(Array(payload.options.enumerated()), id: \.offset) { index, option in
                        AnswerCell(text: option, state: state(index: index, correct: correct))
                            .frame(height: 92)
                    }
                }
            }
        }
    }

    private func state(index: Int, correct: Int) -> AnswerCell.State {
        if index == correct { return .correct }
        if index == game.localAnswerIndex { return .wrongPick }
        return .ghost
    }
}
