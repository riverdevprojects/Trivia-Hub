import SwiftUI

/// Shared visual language, tuned to feel like a bright party-trivia game (SongPop-style):
/// a vivid violet gradient, gold highlights, chunky rounded elements, and a solid-white
/// "correct" pop against translucent ghost options.
enum TriviaTheme {

    // MARK: - Core palette
    static let bgTop = Color(red: 0.49, green: 0.33, blue: 0.90)   // #7D54E6
    static let bgBottom = Color(red: 0.64, green: 0.39, blue: 0.90) // #A263E6
    static let background = LinearGradient(
        colors: [bgTop, bgBottom],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// Deep purple used for text on white surfaces (the correct-answer button).
    static let purpleInk = Color(red: 0.38, green: 0.24, blue: 0.75) // #6140BF

    static let gold = Color(red: 0.98, green: 0.79, blue: 0.20)      // crown + current dot
    static let accent = Color(red: 0.55, green: 0.85, blue: 1.0)     // cyan accent

    static let correct = Color(red: 0.34, green: 0.82, blue: 0.51)
    static let incorrect = Color(red: 0.95, green: 0.42, blue: 0.47)

    // MARK: - Surfaces
    static let card = Color.white.opacity(0.14)
    static let cardStroke = Color.white.opacity(0.22)

    /// Translucent lavender used by the speed pills.
    static let pill = Color.white.opacity(0.22)

    /// Ghosted answer option (the ones that aren't correct on the reveal).
    static let ghost = Color.white.opacity(0.12)
    static let ghostText = Color.white.opacity(0.45)

    // MARK: - Avatars
    /// Vivid, evenly-spaced avatar colors. Chosen deterministically per player id so a
    /// given player keeps the same color for the whole match.
    private static let avatarPalette: [Color] = [
        Color(red: 0.98, green: 0.55, blue: 0.30), // orange
        Color(red: 0.36, green: 0.78, blue: 0.74), // teal
        Color(red: 0.98, green: 0.45, blue: 0.62), // pink
        Color(red: 0.42, green: 0.66, blue: 0.98), // blue
        Color(red: 0.68, green: 0.55, blue: 0.95), // violet
        Color(red: 0.98, green: 0.75, blue: 0.30), // amber
        Color(red: 0.45, green: 0.82, blue: 0.55), // green
        Color(red: 0.95, green: 0.52, blue: 0.42), // coral
    ]

    static func avatarColor(for id: String) -> Color {
        let hash = id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return avatarPalette[hash % avatarPalette.count]
    }
}

// MARK: - Button styles

/// Primary filled (white) button used on home / lobby / final screens.
struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(enabled ? Color.white : Color.white.opacity(0.3))
            .foregroundColor(enabled ? TriviaTheme.purpleInk : .white.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(enabled ? 0.15 : 0), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Secondary translucent button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(TriviaTheme.card)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(TriviaTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(TriviaTheme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
