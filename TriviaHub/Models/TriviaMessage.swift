import Foundation

/// Every message exchanged over the `MCSession`, wrapped in a single `Codable` enum
/// and sent as JSON-encoded `Data` (GDD §3.3).
///
/// Direction conventions:
/// - `roster`, `genreSelected`, `questionStart`, `allAnswered`, `revealAnswer`,
///   `matchEnded` are broadcast **host → clients**.
/// - `playerJoined`, `answerSubmitted`, `playAgainRequested` flow **client → host**.
enum TriviaMessage: Codable {
    /// Client announces its chosen display name right after connecting.
    case playerJoined(id: String, name: String)

    /// Host → all: the authoritative player roster (keeps every lobby/leaderboard in sync).
    case roster(players: [Player])

    /// Host → all: the genre the host picked; clients leave the waiting screen.
    case genreSelected(genreID: String, displayName: String)

    /// Host → all: begin a question. `startTimestampMs` is the host's clock at start;
    /// clients run a *local* countdown for UI only — the authoritative "time's up" is
    /// the host's `revealAnswer` message (GDD §3.3).
    case questionStart(question: QuestionPayload,
                       questionIndex: Int,
                       totalQuestions: Int,
                       startTimestampMs: Int)

    /// Client → host: the local player's answer. `timeRemainingMs` is the client's own
    /// measurement, included for completeness; the host recomputes authoritatively from
    /// its own clock when scoring (GDD §5).
    case answerSubmitted(playerID: String, answerIndex: Int, timeRemainingMs: Int)

    /// Host → all: live "X of Y answered" progress for the question screen indicator.
    case answerProgress(answered: Int, total: Int)

    /// Host → all: every connected player has answered; clients may show an early
    /// "revealing…" state (the reveal itself still arrives via `revealAnswer`).
    case allAnswered

    /// Host → all: reveal the correct answer plus this round's and running totals.
    case revealAnswer(correctIndex: Int,
                      scoresThisRound: [String: Int],
                      totalScores: [String: Int])

    /// Host → all: the match is over; final ranked scores.
    case matchEnded(finalScores: [String: Int])

    /// Client → host: this player tapped "Play Again" on the final screen.
    case playAgainRequested(playerID: String)

    /// Host → all: reset scores and return to genre selection (clients show the
    /// "Host is choosing a genre…" waiting state) for another match with the same lobby.
    case restart
}

extension TriviaMessage {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    /// Encode for transmission over the session.
    func encoded() throws -> Data {
        try Self.encoder.encode(self)
    }

    /// Decode a received payload, returning nil for anything unrecognized rather than
    /// throwing into the delegate callback.
    static func decode(from data: Data) -> TriviaMessage? {
        try? decoder.decode(TriviaMessage.self, from: data)
    }
}
