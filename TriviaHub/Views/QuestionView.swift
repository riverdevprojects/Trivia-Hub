import SwiftUI

/// Screen 5: prompt (text or image) + 4 answer buttons + countdown bar + live
/// "X/Y answered" indicator (GDD §8.5).
///
/// The countdown bar is a *local* UI animation started from `questionStartDate`; the
/// authoritative end of the round is a host message, so a laggy bar can never strand a
/// player on this screen (GDD §3.3).
struct QuestionView: View {
    @EnvironmentObject private var game: GameController

    var body: some View {
        VStack(spacing: 20) {
            topBar
            countdownBar
            prompt
            Spacer(minLength: 8)
            answerButtons
            answeredIndicator
        }
        .padding(24)
    }

    private var topBar: some View {
        HStack {
            Text("Question \(game.questionIndex + 1) of \(game.totalQuestions)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            if let genre = game.selectedGenreName {
                Text(genre)
                    .font(.caption)
                    .foregroundStyle(TriviaTheme.accent)
            }
        }
    }

    private var countdownBar: some View {
        TimelineView(.animation) { timeline in
            let fraction = remainingFraction(at: timeline.date)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(fraction > 0.3 ? TriviaTheme.accent : TriviaTheme.incorrect)
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 10)
        }
    }

    @ViewBuilder
    private var prompt: some View {
        if let payload = game.currentPayload {
            VStack(spacing: 16) {
                if let imageName = payload.promptImageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(TriviaTheme.cardStroke, lineWidth: 1)
                        )
                }
                Text(payload.promptText)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var answerButtons: some View {
        VStack(spacing: 12) {
            if let payload = game.currentPayload {
                ForEach(Array(payload.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        game.submitAnswer(index)
                    } label: {
                        HStack {
                            Text(option)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(background(for: index))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(game.localAnswerIndex == index ? TriviaTheme.accent : TriviaTheme.cardStroke,
                                        lineWidth: game.localAnswerIndex == index ? 2 : 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(game.localAnswerIndex != nil)
                }
            }
        }
    }

    private func background(for index: Int) -> Color {
        game.localAnswerIndex == index ? TriviaTheme.accent.opacity(0.25) : TriviaTheme.card
    }

    private var answeredIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(.white.opacity(0.6))
            Text("\(game.answeredCount)/\(game.players.filter { !$0.hasLeft }.count) answered")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            if game.localAnswerIndex != nil {
                Text("• Waiting for others…")
                    .font(.caption)
                    .foregroundStyle(TriviaTheme.accent)
            }
        }
    }

    private func remainingFraction(at date: Date) -> Double {
        guard let start = game.questionStartDate else { return 1 }
        let elapsed = date.timeIntervalSince(start) * 1000
        let remaining = Double(GameConfig.answerWindowMs) - elapsed
        return max(0, min(1, remaining / Double(GameConfig.answerWindowMs)))
    }
}
