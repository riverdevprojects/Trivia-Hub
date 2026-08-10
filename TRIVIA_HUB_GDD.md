# Trivia Hub — Game Design Document

## 1. Overview

Trivia Hub is a free iOS multiplayer party trivia game, played entirely offline over a local peer-to-peer connection (no internet, no backend server, no accounts). One player hosts a lobby, others join it, a genre is selected, and everyone answers a series of timed multiple-choice questions on their own device. Points are awarded for correctness and speed. This mirrors the fast, snappy pace of games like SongPop Party.

This is a **brand-new Xcode project / repo**. It does not share code with any prior project. All networking, lobby, and game-loop code described below must be built from scratch as part of this GDD — do not assume any existing multiplayer session code exists in this repo.

**Platform:** iOS (Swift, SwiftUI)
**Networking:** Apple's MultipeerConnectivity framework (peer-to-peer, no internet required — works over Wi-Fi or Bluetooth depending on what's available, MultipeerConnectivity picks automatically)
**Players per lobby:** 2–8 (soft cap, tune later)
**Cost:** Free, no accounts, no backend

---

## 2. Core Game Loop (per match)

1. **Lobby** — host creates a session, players join via device discovery
2. **Genre Selection** — host picks a genre directly, game starts
3. **Question Rounds** — a fixed number of questions (default 10) are played in sequence:
   - Prompt + 4 answer options shown to all players simultaneously
   - 10-second countdown timer
   - Players tap an answer; answer + response time recorded
   - If **all** connected players have answered before the timer expires, skip immediately to reveal (don't wait out the clock)
   - Reveal screen: correct answer highlighted, per-player points awarded shown
   - Short pause, then next question
4. **Final Leaderboard** — total scores shown, ranked, with a "Play Again" option that returns to lobby (same genre or re-pick)

---

## 3. Multiplayer Architecture (MultipeerConnectivity)

This section fully specifies the networking layer since this is a new repo.

### 3.1 Framework & Core Classes

Use Apple's `MultipeerConnectivity` framework. Three key classes:

- `MCPeerID` — represents a device/player identity within a session
- `MCSession` — the actual peer-to-peer connection; handles sending/receiving data
- `MCNearbyServiceAdvertiser` — used by the **host** to advertise the lobby so others can find it
- `MCNearbyServiceBrowser` — used by **joining players** to discover nearby advertised lobbies
- `MCSessionDelegate` — callbacks for connection state changes and incoming data
- `MCNearbyServiceAdvertiserDelegate` — callback for handling incoming invitations (host side)
- `MCNearbyServiceBrowserDelegate` — callback for discovered peers (joiner side)

Service type string (used for discovery — must be a unique, lowercase, hyphenated string ≤15 chars): `"trivia-hub-mp"`

### 3.2 Host-Authoritative Model

The host device is the single source of truth for all game state. This avoids sync conflicts entirely:

- Host owns: current question index, timer state, genre selection results, all players' scores
- Host broadcasts state changes to all peers as serialized messages
- Clients (non-host players) only ever: (a) render what the host tells them to render, and (b) send their local actions (answer taps) back to the host
- Clients never calculate their own score or advance their own screen state independently — they wait for a host broadcast to transition screens. This prevents desync if one device's clock/timer drifts slightly from another's.

### 3.3 Message Protocol

Define a single `Codable` enum wrapping all message types, sent as JSON-encoded `Data` over the `MCSession`. Example shape (adjust as needed during implementation):

```swift
enum TriviaMessage: Codable {
    case playerJoined(name: String, peerID: String)
    case genreSelected(genre: String)
    case questionStart(question: QuestionPayload, questionIndex: Int, totalQuestions: Int)
    case answerSubmitted(peerID: String, answerIndex: Int, timeRemainingMs: Int)
    case allAnswered // host broadcasts this to trigger early reveal
    case revealAnswer(correctIndex: Int, scoresThisRound: [String: Int], totalScores: [String: Int])
    case matchEnded(finalScores: [String: Int])
    case playAgainRequested(peerID: String)
}
```

- `QuestionPayload` = the question data model described in Section 5, sent fresh per question (don't pre-send the whole question bank — keeps payloads small and avoids clients peeking ahead at answers by inspecting local data).
- All timing (the 10s countdown) is driven by the **host's clock**. Host sends `questionStart` with a server-side start timestamp; each client runs its own local countdown UI but the authoritative "time's up" event is a message from the host (`revealAnswer` sent automatically by host's own timer, independent of client timers). This avoids any single client's countdown UI lagging and causing a stuck screen.

### 3.4 Lobby Flow

1. Host taps "Host Game" → app creates `MCPeerID` with device name (editable), starts `MCNearbyServiceAdvertiser`, shows a lobby screen with a live list of connected players.
2. Other players tap "Join Game" → app starts `MCNearbyServiceBrowser`, shows list of discovered nearby lobbies (advertised host device names), tap to send invitation.
3. Host auto-accepts invitations (or shows an accept prompt — pick whichever is simpler to implement first; auto-accept is fine for v1 given this is a casual party game).
4. As each player connects, host broadcasts an updated player roster to everyone so all lobby screens stay in sync.
5. Host has a "Start Game" button, enabled once ≥2 players are connected. Tapping it kicks off genre selection (Section 4).

### 3.5 Disconnection Handling (v1 scope)

Keep this simple for v1: if a player disconnects mid-match, the host removes them from the active player list and continues the match with remaining players (their score is dropped from the live leaderboard but shown as "left the game" on the final results screen). Do not attempt reconnection/resume logic in v1 — flag it as a future improvement.

---

## 4. Genre Selection

Host-only selection. Host is shown a grid of the available genres (see Section 6), taps one, and the game starts immediately with that genre. All other players see a brief "Host is choosing a genre..." waiting screen until `genreSelected` arrives. (No in-app voting — if a group wants to vote, they can just do it out loud before the host taps.)

For v1, only these **two genres** are wired up and playable:
1. **Movie Quote Trivia**
2. **Screensaver Trivia**

Build the genre-selection UI to support an arbitrary list (not hardcoded to 2), since 8 more genres will be added later — this just means the question-bank loading system (Section 6) needs to be data-driven from the start.

---

## 5. Scoring System

- Correct answer: **base 50 points**
- Speed bonus: additional points scaled by how much time was left when the player answered, out of the 10-second window. Suggested formula:

```
bonus = round(50 * (timeRemainingMs / 10000))
totalPointsThisQuestion = correct ? (50 + bonus) : 0
```

This means an instant correct answer nets ~100 points, an answer right at the buzzer nets ~50, and any wrong answer nets 0 (no penalty for guessing).

- Host is the only device that calculates final scores (from the `answerSubmitted` messages it receives, which include each player's submission time). This keeps scoring authoritative and prevents a modified client from reporting fake scores.
- Running total score is broadcast to all players after every question's reveal so the in-game leaderboard stays live.

---

## 6. Question Data Model

All genres share one common data shape so the question-loading and gameplay-rendering code stays generic and new genres can be dropped in later without code changes.

```swift
struct TriviaQuestion: Codable {
    let id: String
    let promptText: String        // for text-based genres (e.g. the movie quote itself)
    let promptImageName: String?  // for image-based genres (e.g. screensaver photo), nil if not used
    let options: [String]         // exactly 4 options
    let correctIndex: Int         // 0-3
}

struct TriviaGenre: Codable {
    let id: String                // e.g. "movie_quotes"
    let displayName: String       // e.g. "Movie Quote Trivia"
    let questions: [TriviaQuestion]
}
```

Each genre's questions live in a bundled JSON file (e.g. `MovieQuotes.json`, `Screensavers.json`) inside the app bundle, decoded into `TriviaGenre` at launch or on first selection. Adding a new genre later = adding a new JSON file + registering it in a `GenreRegistry` — no gameplay code changes needed.

The host device is responsible for randomly selecting/shuffling the question order and the total question count for a match (default: 10 questions), then sending each `QuestionPayload` to clients one at a time as described in Section 3.3.

---

## 7. Genre Specs (v1 — the two starter genres)

### 7.1 Movie Quote Trivia

**Format:** Text-only, no images.

- `promptText` = a memorable movie quote, shown large at the top of the screen
- `promptImageName` = nil
- The 4 `options` are randomized between two possible answer types per question (mirrors SongPop's song-name-vs-artist pattern):
  - **Character/speaker name** — "Who says this line?" with 4 character or actor names as options
  - **Movie title** — "What movie is this from?" with 4 movie titles as options
- Which type a given question uses should be baked into that question's data (not decided at runtime) — simplest is to just write both question types into the same JSON bank and shuffle them together, since the UI treats them identically (a prompt + 4 text options either way).
- No licensing/rights concern here since quotes are just text (short quotation, transformative/factual-trivia use) — no bundled movie stills or studio images needed for this genre.

**You (River) will supply the actual quote bank** (JSON list of quotes/characters/movies/wrong-answer options) — Claude Code should build the loading/rendering system generically and can stub in a small placeholder set of ~10 sample questions for testing until you drop in the real bank.

### 7.2 Screensaver Trivia

**Format:** Image-based.

- `promptImageName` = references a bundled image asset (a landscape/nature photo in the style of a classic OS screensaver)
- `promptText` = a short instruction like "Where is this?"
- 4 `options` = plausible location names (e.g. "Yellowstone", "Yosemite", "Banff", "Glacier National Park")
- **Image sourcing:** use open-source/public-domain or Creative-Commons-licensed nature photography (e.g. Unsplash license, Wikimedia Commons, USGS/NPS public domain photos) rather than actual proprietary OS screensaver image packs, to avoid licensing issues. You've already flagged you'll source these yourself — Claude Code doesn't need to source real images, just build the system to load bundled image assets by filename per question and can use a couple of placeholder/sample images for testing.

---

## 8. Screens (SwiftUI Views)

1. **Home Screen** — "Host Game" / "Join Game" buttons
2. **Lobby Screen (Host)** — device name field, live connected-player list, "Start Game" button
3. **Lobby Screen (Joiner)** — list of discoverable nearby games, tap to join, waiting state once joined
4. **Genre Select Screen** — host sees a grid of genre cards, single tap to start; non-host players see a "Host is choosing a genre..." waiting state
5. **Question Screen** — prompt (text or image) + 4 tappable answer buttons + countdown timer bar + live "X/Y players answered" indicator
6. **Reveal Screen** — correct answer highlighted, points earned this round, brief live leaderboard snippet
7. **Final Leaderboard Screen** — ranked final scores, "Play Again" / "Return to Home" buttons

---

## 9. Suggested Build Order (for Claude Code)

1. Project scaffold + SwiftUI navigation shell between the 7 screens (static/mock data, no networking yet)
2. MultipeerConnectivity layer: session setup, advertiser/browser, lobby join/host flow, player roster sync
3. Message protocol (`TriviaMessage` enum + send/receive plumbing over `MCSession`)
4. Genre data model + JSON loading + `GenreRegistry`, with placeholder question banks for both genres
5. Genre selection flow (host-picks, broadcast to others)
6. Question round loop: host-driven timer, question broadcast, answer collection, early-skip-to-reveal logic, scoring calculation
7. Reveal + running leaderboard broadcast/UI
8. Final leaderboard + play-again flow
9. Disconnection handling (basic drop-player case from Section 3.5)
10. Polish pass: timer bar animation, reveal transitions, sound effects (optional v1.1)

---

## 10. Explicitly Out of Scope for v1

- Internet/backend play (local peer-to-peer only)
- Accounts, persistent stats across matches, global leaderboards
- More than 2 genres (architecture supports it, content doesn't exist yet)
- Reconnect-after-disconnect mid-match
- Spectator mode
