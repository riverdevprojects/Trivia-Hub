import SwiftUI

/// Screen 4: Host sees a grid of genre cards (single tap starts the match); clients see
/// a "Host is choosing a genre…" waiting state (GDD §4, §8.4).
struct GenreSelectView: View {
    @EnvironmentObject private var game: GameController
    @EnvironmentObject private var registry: GenreRegistry

    private let columns = [GridItem(.flexible(), spacing: 16),
                           GridItem(.flexible(), spacing: 16)]

    var body: some View {
        if game.isHost {
            hostGrid
        } else {
            clientWaiting
        }
    }

    private var hostGrid: some View {
        VStack(spacing: 20) {
            Text("Pick a genre")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.top, 12)
            Text("Tap one to start the round for everyone.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(registry.genres) { genre in
                        Button {
                            game.hostSelectGenre(genre)
                        } label: {
                            genreCard(genre)
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding(24)
    }

    private func genreCard(_ genre: TriviaGenre) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon(for: genre.id))
                .font(.system(size: 34))
                .foregroundStyle(TriviaTheme.accent)
            Text(genre.displayName)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Text("\(genre.questions.count) questions")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding()
        .background(TriviaTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(TriviaTheme.cardStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func icon(for genreID: String) -> String {
        switch genreID {
        case "movie_quotes": return "film.fill"
        case "screensavers": return "photo.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var clientWaiting: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().tint(TriviaTheme.accent).scaleEffect(1.4)
            Text("Host is choosing a genre…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("Hang tight — the round starts in a moment.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
        }
        .padding(24)
    }
}
