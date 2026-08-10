import Foundation

/// A single trivia question. This is the on-disk / in-bundle shape shared by every
/// genre so the loading and rendering code stays generic (GDD §6).
///
/// `correctIndex` lives only on the host. It is deliberately *not* part of
/// ``QuestionPayload`` so a modified client can never peek at the answer by
/// inspecting the data it receives (GDD §3.3).
struct TriviaQuestion: Codable, Identifiable, Equatable {
    let id: String
    let promptText: String        // e.g. the movie quote itself, or "Where is this?"
    let promptImageName: String?  // bundled image asset name for image genres, else nil
    let options: [String]         // exactly 4 options
    let correctIndex: Int         // 0-3

    /// Strips the answer key, producing the payload that is safe to send to clients.
    var payload: QuestionPayload {
        QuestionPayload(
            id: id,
            promptText: promptText,
            promptImageName: promptImageName,
            options: options
        )
    }
}

/// A genre: a display name plus its bundled question bank (GDD §6).
struct TriviaGenre: Codable, Identifiable, Equatable {
    let id: String            // e.g. "movie_quotes"
    let displayName: String   // e.g. "Movie Quote Trivia"
    let questions: [TriviaQuestion]
}

/// The answer-key-free view of a question that is broadcast to clients each round.
/// Clients render this; only the host knows `correctIndex` until the reveal.
struct QuestionPayload: Codable, Identifiable, Equatable {
    let id: String
    let promptText: String
    let promptImageName: String?
    let options: [String]
}
