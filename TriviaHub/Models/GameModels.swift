import Foundation

/// A connected participant in a match. Identified by the string form of its `MCPeerID`
/// so the identity survives JSON round-trips between devices.
struct Player: Identifiable, Codable, Equatable {
    let id: String            // MCPeerID.displayName-derived stable id
    var name: String
    var score: Int = 0
    var hasLeft: Bool = false // set true if the player disconnects mid-match (GDD §3.5)
}

/// The screen the local device is currently showing. The host advances this locally
/// and broadcasts transitions; clients only change phase in response to host messages
/// (host-authoritative model, GDD §3.2).
enum GamePhase: Equatable {
    case home
    case hostLobby
    case joinLobby
    case genreSelect          // host: grid of genres; client: "Host is choosing…"
    case question
    case reveal
    case finalLeaderboard
}

/// Whether this device is running the match or following it.
enum GameRole: Equatable {
    case host
    case client
    case none
}

/// Fixed gameplay tuning values (GDD §2, §5).
enum GameConfig {
    static let serviceType = "trivia-hub-mp"      // ≤15 chars, lowercase, hyphenated
    static let defaultQuestionCount = 10
    static let answerWindowMs = 10_000            // 10-second countdown
    static let minPlayersToStart = 2
    static let maxPlayers = 8
    static let basePoints = 50
    static let maxSpeedBonus = 50
    static let revealPauseSeconds = 3.0           // pause on the reveal screen

    /// Points for a single question given whether it was correct and how much of the
    /// window remained when the answer landed (GDD §5).
    static func points(correct: Bool, timeRemainingMs: Int) -> Int {
        guard correct else { return 0 }
        let clamped = max(0, min(answerWindowMs, timeRemainingMs))
        let bonus = Int((Double(maxSpeedBonus) * Double(clamped) / Double(answerWindowMs)).rounded())
        return basePoints + bonus
    }
}
