import SwiftUI

@MainActor
struct CharacterDetailView: View {
    let character: RickMortyCharacter

    @EnvironmentObject private var speech: CastSpeech

    @Environment(\.scenePhase)
    private var scenePhase

    @State private var imageRetry = 0
    @State private var isVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AsyncImage(url: character.image) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .accessibilityLabel(
                                "Portrait of \(character.name)"
                            )
                    } else if phase.error != nil {
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.largeTitle)

                            Text("Image unavailable")

                            Button("Retry image") {
                                imageRetry += 1
                            }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 220
                        )
                    } else {
                        ProgressView("Loading image…")
                            .frame(
                                maxWidth: .infinity,
                                minHeight: 220
                            )
                    }
                }
                .id(imageRetry)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 16) {
                    if speech.isEnabled {
                        Button {
                            speech.toggle(
                                character,
                                details: true
                            )
                        } label: {
                            Label(
                                speech.speakingCharacterID == character.id
                                    ? "Stop reading"
                                    : "Read aloud",
                                systemImage:
                                    speech.speakingCharacterID == character.id
                                    ? "stop.fill"
                                    : "speaker.wave.2.fill"
                            )
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }

                    CastDetailField(
                        title: "Species",
                        value: character.species
                    )

                    CastDetailField(
                        title: "Status",
                        value: character.status
                    )

                    CastDetailField(
                        title: "Origin",
                        value: character.origin.name
                    )

                    if let type = character.availableType {
                        CastDetailField(
                            title: "Type",
                            value: type
                        )
                    }

                    CastDetailField(
                        title: "Created",
                        value: character.formattedCreationDate
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .contentMargins(.bottom, 88, for: .scrollContent)
        .navigationTitle(character.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isVisible = true
            speech.readAutomatically(character)
        }
        .onDisappear {
            isVisible = false
            speech.stop()
        }
        .onChange(of: speech.isEnabled) { _, enabled in
            if enabled && isVisible && scenePhase == .active {
                speech.readAutomatically(character)
            }
        }
    }
}

private struct CastDetailField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)

            Text(value)
                .font(.body)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .fixedSize(
            horizontal: false,
            vertical: true
        )
        .accessibilityElement(children: .combine)
    }
}
