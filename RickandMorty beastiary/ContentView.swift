import SwiftUI

@MainActor
struct ContentView: View {
    @State private var searchText = ""
    @StateObject private var searchModel = CharacterSearchModel()

    var body: some View {
        NavigationStack {
            List {
                switch searchModel.state {
                case .idle:
                    Text("Enter a character name to start searching.")
                        .foregroundStyle(.secondary)

                case .loading:
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Searching…")
                    }

                case .results(let characters):
                    if characters.isEmpty {
                        Text("No characters found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(characters) { character in
                            NavigationLink {
                                CharacterDetailView(character: character)
                            }
                            label: {
                                CharacterRow(character: character)
                            }
                        }
                    }

                case .failed(let message):
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn’t load characters")
                            .font(.headline)

                        Text(message)
                            .foregroundStyle(.secondary)

                        Text("Change your search to try again.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Characters")
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search characters"
            )
            .task(id: searchText) {
                await searchModel.search(for: searchText)
            }
        }
    }
}

private struct CharacterRow: View {
    let character: RickMortyCharacter

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: character.image) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(width: 64, height: 64)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.headline)

                Text(character.species)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
