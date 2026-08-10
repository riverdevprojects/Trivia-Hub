import SwiftUI

// MARK: - Player avatar

/// A circular, cartoon-style avatar: a vivid color disc with the player's initials and a
/// contrasting ring — the SongPop-style character token. An optional crown sits above the
/// leader and an optional score-ring arc traces the rim.
struct PlayerAvatar: View {
    let player: Player
    var size: CGFloat = 60
    var showCrown: Bool = false
    /// 0…1 fraction to draw as an arc around the avatar (e.g. answer speed). nil = full ring.
    var ringFraction: Double? = nil
    var highlighted: Bool = false

    private var color: Color { TriviaTheme.avatarColor(for: player.id) }

    private var initials: String {
        let letters = player.name
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(2)
            .compactMap { $0.first }
        let text = String(letters).uppercased()
        return text.isEmpty ? "?" : String(text.prefix(2))
    }

    var body: some View {
        ZStack {
            // Outer ring (full track).
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: size * 0.08)
                .frame(width: size, height: size)

            // Progress arc (speed / correctness), if provided.
            if let fraction = ringFraction {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
            }

            // Avatar disc.
            Circle()
                .fill(
                    LinearGradient(colors: [color.opacity(0.95), color.opacity(0.7)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(highlighted ? 0.9 : 0.35),
                                    lineWidth: highlighted ? 3 : 1.5)
                        .frame(width: size * 0.82, height: size * 0.82)
                )
        }
        .frame(width: size, height: size)
        .overlay(alignment: .top) {
            if showCrown {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.28))
                    .foregroundStyle(TriviaTheme.gold)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .offset(y: -size * 0.34)
            }
        }
    }
}

// MARK: - Progress dots

/// The row of question-progress dots along the top: answered = filled dark, current =
/// gold, upcoming = translucent.
struct ProgressDots: View {
    let total: Int
    let current: Int   // 0-based index of the current question

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Circle()
                    .fill(color(for: index))
                    .frame(width: index == current ? 14 : 11,
                           height: index == current ? 14 : 11)
                    .overlay(
                        Circle().stroke(Color.white.opacity(index == current ? 0.9 : 0),
                                        lineWidth: 2)
                    )
            }
        }
    }

    private func color(for index: Int) -> Color {
        if index == current { return TriviaTheme.gold }
        if index < current { return Color.black.opacity(0.45) }
        return Color.white.opacity(0.25)
    }
}

// MARK: - Speed pill

/// The little rounded "1.7s" response-time pill shown under an avatar on the reveal.
struct TimePill: View {
    /// Response time in ms, or nil if the player didn't answer.
    let ms: Int?

    private var label: String {
        guard let ms else { return "—" }
        return String(format: "%.1fs", Double(ms) / 1000.0)
    }

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(TriviaTheme.pill)
            .clipShape(Capsule())
    }
}

// MARK: - Disco ball decoration

/// A stylized disco ball, tucked into a corner as party decor.
struct DiscoBall: View {
    var size: CGFloat = 120

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.95),
                             TriviaTheme.accent.opacity(0.8),
                             Color(red: 0.4, green: 0.6, blue: 0.9)],
                    center: .topLeading, startRadius: 2, endRadius: size
                )
            )
            .overlay(discoGrid)
            .overlay(
                Circle().stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .frame(width: size, height: size)
    }

    // Faint facet grid to read as a mirror-ball.
    private var discoGrid: some View {
        GeometryReader { geo in
            let step = geo.size.width / 6
            Path { path in
                for i in 1..<6 {
                    let x = step * CGFloat(i)
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    let y = step * CGFloat(i)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geo.size.width, y: y))
                }
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
        .clipShape(Circle())
    }
}

// MARK: - Answer grid button

/// One cell in the 2×2 answer grid. `state` controls its look so the same component
/// serves the question screen (idle/selected) and the reveal (correct/wrong/ghost).
struct AnswerCell: View {
    enum State {
        case idle
        case selected      // this device's current pick (question screen)
        case correct       // the right answer (reveal)
        case wrongPick     // this device picked it and it's wrong (reveal)
        case ghost         // a non-correct option on the reveal
    }

    let text: String
    let state: State
    var action: () -> Void = {}
    var disabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
                .background(fill)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(stroke, lineWidth: strokeWidth)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .disabled(disabled)
    }

    private var textColor: Color {
        switch state {
        case .correct: return TriviaTheme.purpleInk
        case .ghost: return TriviaTheme.ghostText
        case .wrongPick: return .white
        default: return .white
        }
    }

    private var fill: Color {
        switch state {
        case .correct: return .white
        case .selected: return Color.white.opacity(0.28)
        case .wrongPick: return TriviaTheme.incorrect.opacity(0.30)
        case .ghost: return TriviaTheme.ghost
        case .idle: return TriviaTheme.card
        }
    }

    private var stroke: Color {
        switch state {
        case .selected: return .white
        case .wrongPick: return TriviaTheme.incorrect
        case .correct: return .white
        default: return TriviaTheme.cardStroke
        }
    }

    private var strokeWidth: CGFloat {
        (state == .selected || state == .wrongPick) ? 2.5 : 1
    }
}

/// Chunky press feedback used by the answer cells.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
