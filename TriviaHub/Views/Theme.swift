import SwiftUI

/// Small shared visual language so the seven screens feel like one app.
enum TriviaTheme {
    static let background = LinearGradient(
        colors: [Color(red: 0.09, green: 0.10, blue: 0.20),
                 Color(red: 0.16, green: 0.09, blue: 0.28)],
        startPoint: .top, endPoint: .bottom
    )
    static let accent = Color(red: 0.45, green: 0.80, blue: 1.0)
    static let correct = Color(red: 0.30, green: 0.80, blue: 0.45)
    static let incorrect = Color(red: 0.90, green: 0.35, blue: 0.40)
    static let card = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.15)
}

/// Primary filled button used on the home / lobby screens.
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(enabled ? TriviaTheme.accent : Color.gray.opacity(0.4))
            .foregroundColor(enabled ? .black : .white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A translucent card container.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .background(TriviaTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(TriviaTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
