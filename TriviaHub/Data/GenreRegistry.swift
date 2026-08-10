import Foundation

/// Loads bundled genre JSON files and exposes the list of playable genres. Adding a new
/// genre later is a matter of dropping in a JSON file and adding one line here — no
/// gameplay code changes (GDD §6).
final class GenreRegistry: ObservableObject {

    /// Each entry maps a bundled JSON filename (without extension) to nothing more —
    /// the display name and id come from inside the file. Order here is the order the
    /// host sees in the genre grid.
    private static let bundledFiles = [
        "MovieQuotes",
        "Screensavers",
    ]

    @Published private(set) var genres: [TriviaGenre] = []

    init(bundle: Bundle = .main) {
        self.genres = Self.loadAll(from: bundle)
    }

    func genre(withID id: String) -> TriviaGenre? {
        genres.first { $0.id == id }
    }

    private static func loadAll(from bundle: Bundle) -> [TriviaGenre] {
        bundledFiles.compactMap { load($0, from: bundle) }
    }

    private static func load(_ name: String, from bundle: Bundle) -> TriviaGenre? {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            #if DEBUG
            print("GenreRegistry: missing bundled file \(name).json")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(TriviaGenre.self, from: data)
        } catch {
            #if DEBUG
            print("GenreRegistry: failed to decode \(name).json — \(error)")
            #endif
            return nil
        }
    }
}
