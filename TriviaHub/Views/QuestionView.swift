import SwiftUI

/// Screen 5 — the question screen in party style: progress dots, a shrinking timer bar,
/// the prompt (text or image), and a chunky 2×2 answer grid, plus a live "X/Y answered"
/// row of avatars (GDD §8.5).
///
/// The timer bar is a *local* UI animation from `questionStartDate`; the authoritative end
/// of the round is a host message, so a laggy bar can never strand a player (GDD §3.3).
struct QuestionView: View {
    @EnvironmentObject private var game: GameController

    private var activePlayers: [Player] { game.players.filter { !$0.hasLeft } }

    var body: some View {
        VStack(spacing: 18) {
            ProgressDots(total: game.totalQuestions, current: game.questionIndex)
                .padding(.top, 12)

            timerBar
            prompt

            Spacer(minLength: 4)

            answerGrid
            answeredRow
        }
        .padding(20)
    }

    // MARK: - Timer

    private var timerBar: some View {
        TimelineView(.animation) { timeline in
            let fraction = remainingFraction(at: timeline.date)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.18))
                    Capsule()
                        .fill(fraction > 0.3 ? TriviaTheme.gold : TriviaTheme.incorrect)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 12)
        }
    }

    // MARK: - Prompt

    @ViewBuilder
    private var prompt: some View {
        if let payload = game.currentPayload {
            VStack(spacing: 14) {
                if let imageName = payload.promptImageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
                }
                Text(payload.promptText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Answers

    private var answerGrid: some View {
        Group {
            if let payload = game.currentPayload {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14),
                                    GridItem(.flexible(), spacing: 14)],
                          spacing: 14) {
                    ForEach(Array(payload.options.enumerated()), id: \.offset) { index, option in
                        AnswerCell(
                            text: option,
                            state: game.localAnswerIndex == index ? .selected : .idle,
                            action: { game.submitAnswer(index) },
                            disabled: game.localAnswerIndex != nil
                        )
                        .frame(height: 96)
                    }
                }
            }
        }
    }

    // MARK: - Answered indicator

    private var answeredRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: -10) {
                ForEach(activePlayers.prefix(8)) { player in
                    PlayerAvatar(player: player, size: 28,
                                 highlighted: player.id == game.myPlayerID)
                }
            }
            Text("\(game.answeredCount)/\(activePlayers.count) answered")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            if game.localAnswerIndex != nil {
                Text("• Locked in!")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TriviaTheme.gold)
            }
        }
        .padding(.top, 2)
    }

    private func remainingFraction(at date: Date) -> Double {
        guard let start = game.questionStartDate else { return 1 }
        let elapsed = date.timeIntervalSince(start) * 1000
        let remaining = Double(GameConfig.answerWindowMs) - elapsed
        return max(0, min(1, remaining / Double(GameConfig.answerWindowMs)))
    }
}
