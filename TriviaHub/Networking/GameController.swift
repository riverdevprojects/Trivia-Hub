import Foundation
import MultipeerConnectivity
import SwiftUI
import UIKit

/// The game brain. One instance drives the whole app. It owns a ``MultipeerSession``
/// and implements the host-authoritative state machine (GDD §3.2): the host advances
/// phases and computes scores; clients only render what the host tells them and send
/// their local answer taps back.
///
/// A single class handles both roles; `role` selects which branches run.
@MainActor
final class GameController: ObservableObject {

    // MARK: - Shared published state (drives the UI on every device)

    @Published var phase: GamePhase = .home
    @Published var role: GameRole = .none

    /// Editable device/player name shown in the lobby.
    @Published var deviceName: String

    /// The authoritative roster (host-maintained, broadcast to clients).
    @Published var players: [Player] = []

    /// Hosts discovered while browsing (joiner side).
    @Published var discoveredHosts: [MCPeerID] = []

    @Published var selectedGenreName: String?

    // Question round (client-render) state
    @Published var currentPayload: QuestionPayload?
    @Published var questionIndex: Int = 0
    @Published var totalQuestions: Int = GameConfig.defaultQuestionCount
    /// When the *local* countdown UI started. Set to `Date()` on receipt so drift
    /// between device clocks can't desync the bar; the authoritative "time's up" is a
    /// host message (GDD §3.3).
    @Published var questionStartDate: Date?
    @Published var localAnswerIndex: Int?
    @Published var answeredCount: Int = 0

    // Reveal state
    @Published var revealCorrectIndex: Int?
    @Published var lastRoundScores: [String: Int] = [:]
    /// Each player's response time this round in ms (time taken to answer); absent if
    /// they didn't answer. Drives the speed pills on the reveal screen.
    @Published var lastRoundTimesMs: [String: Int] = [:]

    // Final
    @Published var finalRankedScores: [Player] = []

    // MARK: - Networking

    private var multipeer: MultipeerSession?

    // MARK: - Host-only match state

    private var matchQuestions: [TriviaQuestion] = []
    private var currentQuestion: TriviaQuestion?
    private var hostQuestionStartMs: Int = 0
    private var answersThisRound: [String: (answerIndex: Int, timeRemainingMs: Int)] = [:]
    private var revealWorkItem: DispatchWorkItem?
    private var deadlineWorkItem: DispatchWorkItem?
    private var pendingGenre: TriviaGenre?

    private let genreRegistry: GenreRegistry

    init(deviceName: String = UIDevice.current.name, genreRegistry: GenreRegistry) {
        self.deviceName = MultipeerSession.sanitize(deviceName)
        self.genreRegistry = genreRegistry
    }

    /// The local player's stable id (its peer display name).
    private var localID: String { multipeer?.myPeerID.displayName ?? deviceName }

    /// Public accessor so views can highlight the local player's row/avatar.
    var myPlayerID: String { localID }

    var isHost: Bool { role == .host }

    // MARK: - Lobby entry points

    func hostGame() {
        let mp = MultipeerSession(displayName: deviceName)
        mp.delegate = self
        multipeer = mp
        role = .host
        // Seed roster with the host itself.
        players = [Player(id: mp.myPeerID.displayName, name: deviceName)]
        mp.startHosting()
        phase = .hostLobby
    }

    func joinGame() {
        let mp = MultipeerSession(displayName: deviceName)
        mp.delegate = self
        multipeer = mp
        role = .client
        players = []
        discoveredHosts = []
        mp.startBrowsing()
        phase = .joinLobby
    }

    func invite(_ host: MCPeerID) {
        multipeer?.invite(host)
    }

    /// Leave whatever we're doing and return home, tearing down the session.
    func leaveToHome() {
        cancelHostTimers()
        multipeer?.teardown()
        multipeer = nil
        role = .none
        players = []
        discoveredHosts = []
        selectedGenreName = nil
        currentPayload = nil
        currentQuestion = nil
        matchQuestions = []
        answersThisRound = [:]
        localAnswerIndex = nil
        revealCorrectIndex = nil
        finalRankedScores = []
        phase = .home
    }

    var canStart: Bool { isHost && players.count >= GameConfig.minPlayersToStart }

    // MARK: - Host: genre selection & match start

    /// Host tapped "Start Game" in the lobby → move to genre selection.
    func hostBeginGenreSelection() {
        guard isHost else { return }
        phase = .genreSelect
    }

    /// Host picked a genre → start the match immediately (GDD §4).
    func hostSelectGenre(_ genre: TriviaGenre) {
        guard isHost else { return }
        pendingGenre = genre
        selectedGenreName = genre.displayName
        multipeer?.broadcast(.genreSelected(genreID: genre.id, displayName: genre.displayName))
        startMatch(with: genre)
    }

    private func startMatch(with genre: TriviaGenre) {
        // Reset scores for everyone at match start.
        for i in players.indices { players[i].score = 0 }
        broadcastRoster()

        let count = min(GameConfig.defaultQuestionCount, genre.questions.count)
        matchQuestions = Array(genre.questions.shuffled().prefix(count))
        totalQuestions = matchQuestions.count
        questionIndex = 0
        startQuestion(at: 0)
    }

    // MARK: - Host: question loop

    private func startQuestion(at index: Int) {
        guard isHost, index < matchQuestions.count else {
            endMatch()
            return
        }
        cancelHostTimers()
        let question = matchQuestions[index]
        currentQuestion = question
        questionIndex = index
        answersThisRound = [:]
        answeredCount = 0
        localAnswerIndex = nil
        revealCorrectIndex = nil
        currentPayload = question.payload
        hostQuestionStartMs = Self.nowMs()
        questionStartDate = Date()
        phase = .question

        multipeer?.broadcast(.questionStart(question: question.payload,
                                            questionIndex: index,
                                            totalQuestions: totalQuestions,
                                            startTimestampMs: hostQuestionStartMs))
        broadcastAnswerProgress()

        // Authoritative deadline: reveal when the window expires, independent of any
        // client timer (GDD §3.3).
        let deadline = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.hostReveal() }
        }
        deadlineWorkItem = deadline
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(GameConfig.answerWindowMs),
            execute: deadline
        )
    }

    /// Record an answer from any player (including the host's own local tap).
    private func recordAnswer(playerID: String, answerIndex: Int) {
        guard isHost, currentQuestion != nil, answersThisRound[playerID] == nil else { return }
        // Ignore answers from players no longer in the active roster.
        guard players.contains(where: { $0.id == playerID && !$0.hasLeft }) else { return }

        // Authoritative time-remaining from the host's own clock.
        let elapsed = Self.nowMs() - hostQuestionStartMs
        let remaining = max(0, GameConfig.answerWindowMs - elapsed)
        answersThisRound[playerID] = (answerIndex, remaining)
        answeredCount = answersThisRound.count
        broadcastAnswerProgress()

        let activePlayers = players.filter { !$0.hasLeft }
        if answersThisRound.count >= activePlayers.count {
            // Everyone answered → skip straight to reveal (GDD §2).
            multipeer?.broadcast(.allAnswered)
            hostReveal()
        }
    }

    private func hostReveal() {
        guard isHost, let question = currentQuestion else { return }
        cancelHostTimers()

        var roundScores: [String: Int] = [:]
        var roundTimes: [String: Int] = [:]
        for player in players where !player.hasLeft {
            let submission = answersThisRound[player.id]
            let correct = submission?.answerIndex == question.correctIndex
            let remaining = submission?.timeRemainingMs ?? 0
            let pts = GameConfig.points(correct: correct, timeRemainingMs: remaining)
            roundScores[player.id] = pts
            // Response time = how much of the window was used before answering.
            if submission != nil {
                roundTimes[player.id] = max(0, GameConfig.answerWindowMs - remaining)
            }
        }
        // Apply to running totals.
        for i in players.indices {
            players[i].score += roundScores[players[i].id] ?? 0
        }

        let totals = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.score) })
        lastRoundScores = roundScores
        lastRoundTimesMs = roundTimes
        revealCorrectIndex = question.correctIndex

        multipeer?.broadcast(.revealAnswer(correctIndex: question.correctIndex,
                                           scoresThisRound: roundScores,
                                           totalScores: totals,
                                           answerTimesMs: roundTimes))
        phase = .reveal

        // Short pause, then next question (or end).
        let next = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.isHost else { return }
                let nextIndex = self.questionIndex + 1
                if nextIndex < self.matchQuestions.count {
                    self.startQuestion(at: nextIndex)
                } else {
                    self.endMatch()
                }
            }
        }
        revealWorkItem = next
        DispatchQueue.main.asyncAfter(deadline: .now() + GameConfig.revealPauseSeconds, execute: next)
    }

    private func endMatch() {
        guard isHost else { return }
        cancelHostTimers()
        let totals = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.score) })
        multipeer?.broadcast(.matchEnded(finalScores: totals))
        finalRankedScores = rankedPlayers(using: totals)
        phase = .finalLeaderboard
    }

    // MARK: - Host: play again

    func hostPlayAgain() {
        guard isHost else { return }
        for i in players.indices { players[i].score = 0 }
        finalRankedScores = []
        selectedGenreName = nil
        multipeer?.broadcast(.restart)
        broadcastRoster()
        phase = .genreSelect
    }

    // MARK: - Local answer (works for both host and client)

    func submitAnswer(_ index: Int) {
        guard phase == .question, localAnswerIndex == nil else { return }
        localAnswerIndex = index
        let remaining = localTimeRemainingMs()
        if isHost {
            recordAnswer(playerID: localID, answerIndex: index)
        } else {
            multipeer?.broadcast(.answerSubmitted(playerID: localID,
                                                  answerIndex: index,
                                                  timeRemainingMs: remaining))
        }
    }

    /// Client-side best-effort remaining time (UI only; host recomputes authoritatively).
    private func localTimeRemainingMs() -> Int {
        guard let start = questionStartDate else { return 0 }
        let elapsed = Int(Date().timeIntervalSince(start) * 1000)
        return max(0, GameConfig.answerWindowMs - elapsed)
    }

    // MARK: - Host helpers

    private func broadcastRoster() {
        multipeer?.broadcast(.roster(players: players))
    }

    private func broadcastAnswerProgress() {
        let active = players.filter { !$0.hasLeft }.count
        multipeer?.broadcast(.answerProgress(answered: answersThisRound.count, total: active))
    }

    private func cancelHostTimers() {
        revealWorkItem?.cancel(); revealWorkItem = nil
        deadlineWorkItem?.cancel(); deadlineWorkItem = nil
    }

    private func rankedPlayers(using totals: [String: Int]) -> [Player] {
        players
            .map { p -> Player in
                var copy = p
                copy.score = totals[p.id] ?? p.score
                return copy
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.name < rhs.name
            }
    }

    // MARK: - Utilities

    static func nowMs() -> Int {
        Int(Date().timeIntervalSince1970 * 1000)
    }

    /// Convenience for views that show ranked live scores.
    var liveRanked: [Player] {
        players.filter { !$0.hasLeft }.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.name < $1.name
        }
    }

    func name(forID id: String) -> String {
        players.first { $0.id == id }?.name ?? id
    }
}

// MARK: - MultipeerSession.Delegate

extension GameController: MultipeerSession.Delegate {

    nonisolated func multipeer(_ session: MultipeerSession, didUpdateDiscoveredHosts hosts: [MCPeerID]) {
        Task { @MainActor in self.discoveredHosts = hosts }
    }

    nonisolated func multipeer(_ session: MultipeerSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in self.handleStateChange(peerID: peerID, state: state) }
    }

    nonisolated func multipeer(_ session: MultipeerSession, didReceive message: TriviaMessage, from peerID: MCPeerID) {
        Task { @MainActor in self.handle(message, from: peerID) }
    }

    private func handleStateChange(peerID: MCPeerID, state: MCSessionState) {
        let id = peerID.displayName
        switch state {
        case .connected:
            if isHost {
                // Add to roster if new; a joined message will refine the name.
                if !players.contains(where: { $0.id == id }) {
                    players.append(Player(id: id, name: id))
                }
                broadcastRoster()
            } else {
                // We (a client) just connected to the host → announce our name so the
                // host can put a friendly label on our roster entry.
                announceSelfToHost()
            }
        case .notConnected:
            if isHost {
                // Drop from the active match; keep on final screen as "left" (GDD §3.5).
                if let idx = players.firstIndex(where: { $0.id == id }) {
                    players[idx].hasLeft = true
                }
                broadcastRoster()
                // A departure may complete the "everyone answered" condition.
                if phase == .question, currentQuestion != nil {
                    let active = players.filter { !$0.hasLeft }
                    if !active.isEmpty && answersThisRound.count >= active.count {
                        multipeer?.broadcast(.allAnswered)
                        hostReveal()
                    } else {
                        broadcastAnswerProgress()
                    }
                }
            } else {
                // Client lost the host → the match is over for us.
                leaveToHome()
            }
        case .connecting:
            break
        @unknown default:
            break
        }
    }

    private func handle(_ message: TriviaMessage, from peerID: MCPeerID) {
        switch message {
        // ---- Host-handled (client → host) ----
        case let .playerJoined(id, name):
            guard isHost else { return }
            if let idx = players.firstIndex(where: { $0.id == id }) {
                players[idx].name = name
                players[idx].hasLeft = false
            } else {
                players.append(Player(id: id, name: name))
            }
            broadcastRoster()

        case let .answerSubmitted(playerID, answerIndex, _):
            recordAnswer(playerID: playerID, answerIndex: answerIndex)

        case .playAgainRequested:
            // Informational for v1: the host drives the restart.
            break

        // ---- Client-handled (host → clients) ----
        case let .roster(players):
            guard !isHost else { return }
            self.players = players

        case let .genreSelected(_, displayName):
            guard !isHost else { return }
            selectedGenreName = displayName

        case let .questionStart(question, index, total, _):
            guard !isHost else { return }
            currentPayload = question
            questionIndex = index
            totalQuestions = total
            answeredCount = 0
            localAnswerIndex = nil
            revealCorrectIndex = nil
            questionStartDate = Date()   // local clock — see property doc
            phase = .question

        case let .answerProgress(answered, _):
            guard !isHost else { return }
            answeredCount = answered

        case .allAnswered:
            guard !isHost else { return }
            answeredCount = max(answeredCount, players.filter { !$0.hasLeft }.count)

        case let .revealAnswer(correctIndex, roundScores, totalScores, answerTimesMs):
            guard !isHost else { return }
            revealCorrectIndex = correctIndex
            lastRoundScores = roundScores
            lastRoundTimesMs = answerTimesMs
            for i in players.indices {
                if let total = totalScores[players[i].id] { players[i].score = total }
            }
            phase = .reveal

        case let .matchEnded(finalScores):
            guard !isHost else { return }
            finalRankedScores = rankedPlayers(using: finalScores)
            phase = .finalLeaderboard

        case .restart:
            guard !isHost else { return }
            for i in players.indices { players[i].score = 0 }
            finalRankedScores = []
            selectedGenreName = nil
            phase = .genreSelect  // clients render the "Host is choosing…" waiting state
        }
    }
}

// After a client connects it announces its chosen name to the host.
extension GameController {
    /// Called by the join flow once connected so the host learns our display name.
    func announceSelfToHost() {
        guard role == .client else { return }
        multipeer?.broadcast(.playerJoined(id: localID, name: deviceName))
    }
}
