# Trivia Hub

A free iOS multiplayer party trivia game played entirely offline over a local
peer-to-peer connection — no internet, no backend, no accounts. One player hosts
a lobby, others join over Wi-Fi or Bluetooth (Apple's MultipeerConnectivity picks
automatically), a genre is chosen, and everyone answers a series of timed
multiple-choice questions on their own device. Points are awarded for correctness
and speed.

Built from the [Game Design Document](TRIVIA_HUB_GDD.md).

## Requirements

- **iOS 16.7+** (deployment target)
- Xcode 16 or later (the project uses a filesystem-synchronized group,
  `objectVersion = 77`)
- Two or more physical devices on the same Wi-Fi network, or with Bluetooth
  enabled, to actually play. MultipeerConnectivity discovery does **not** work
  between two Simulators; use real devices (or one device + one Simulator on the
  same Mac's network) for multiplayer testing.

## Running

1. Open `TriviaHub.xcodeproj` in Xcode.
2. Select the `TriviaHub` scheme and a device.
3. Build & run. On first launch each device asks for **Local Network**
   permission — this is required for peer discovery.

## How a match flows

1. **Home** — enter a name, tap **Host Game** or **Join Game**.
2. **Lobby** — the host advertises; joiners see nearby lobbies and tap to join.
   The host's **Start Game** button enables once ≥2 players are connected.
3. **Genre select** — the host picks a genre; everyone else sees a waiting state.
4. **Questions** — 10 questions (default), 10-second timer each. If everyone
   answers early, the round reveals immediately.
5. **Reveal** — correct answer + points this round + a live leaderboard.
6. **Final leaderboard** — ranked scores, with **Play Again** (host) that returns
   the lobby to genre selection.

## Architecture

Host-authoritative (GDD §3.2): the host is the single source of truth for the
question index, timer, and all scores. Clients only render what the host
broadcasts and send their answer taps back; they never advance their own screen
state or compute their own scores. This eliminates desync between devices.

| Layer | Files |
|-------|-------|
| Models | `Models/TriviaModels.swift`, `Models/GameModels.swift`, `Models/TriviaMessage.swift` |
| Networking | `Networking/MultipeerSession.swift` (raw MC plumbing), `Networking/GameController.swift` (game brain / state machine) |
| Data | `Data/GenreRegistry.swift`, `Data/MovieQuotes.json`, `Data/Screensavers.json` |
| Views | `Views/` — one SwiftUI view per screen, driven by `RootView`'s phase switch |

### Message protocol

All peer traffic is a single `Codable` enum, `TriviaMessage`, JSON-encoded over
the `MCSession`. The answer key (`correctIndex`) is stripped into `QuestionPayload`
before sending, so a modified client can't peek at answers; only the host knows the
correct index until it broadcasts the reveal.

### Timing

The 10-second countdown is authoritative on the host's clock. Each client runs a
**local** countdown for its progress bar only (started when the `questionStart`
message arrives, so cross-device clock drift can't desync anything); the real
"time's up" is always a host message.

## Content

The two starter genres ship with small **placeholder** banks for testing:

- `Data/MovieQuotes.json` — ~12 sample text questions (quote → movie or speaker).
- `Data/Screensavers.json` — 6 sample image questions referencing three
  placeholder gradient images in `Assets.xcassets`.

Both are data-driven: to add or replace content, edit the JSON (and drop in image
assets for image genres) — no gameplay code changes needed. Adding a whole new
genre later is a JSON file plus one line in `GenreRegistry`.

> The real Movie-Quote bank and real (public-domain / CC-licensed) Screensaver
> photos are supplied separately by the content owner; the placeholders exist only
> so the loading and rendering paths can be exercised.

## Out of scope for v1

Internet/backend play, accounts, persistent stats, more than the two starter
genres, reconnect-after-disconnect, and spectator mode (GDD §10).
