import SwiftUI
import Accessibility

@MainActor
struct ContentView: View {
@StateObject private var model = CharacterSearchModel()
@StateObject private var speech = CastSpeech()

@State private var searchText = ""
@State private var searchRetry = 0
@State private var galleryRetry = 0
@State private var showAccessibility = false
@State private var isHomeVisible = false

@FocusState private var searchFocused: Bool

@Environment(\.scenePhase)
private var scenePhase

@Environment(\.accessibilityVoiceOverEnabled)
private var voiceOverEnabled

private struct SearchRequest: Equatable {
    let query: String
    let retry: Int
}

private struct PageIdentity: Hashable {
    let query: String
    let page: Int
}

private var query: String {
    searchText.trimmingCharacters(
        in: .whitespacesAndNewlines
    )
}

var body: some View {
    NavigationStack {
        List {
            Section {
                if !model.gallery.isEmpty {
                    CharacterCarouselView(
                        characters: model.gallery,
                        allowsAutomaticScrolling:
                            isHomeVisible
                            && !searchFocused
                            && !showAccessibility
                            && !speech.isEnabled
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                } else if let message = model.galleryError {
                    CastErrorView(
                        title: "Couldn’t load cast",
                        message: message,
                        retryAt: model.galleryRetryAt
                    ) {
                        galleryRetry += 1
                    }
                } else {
                    ProgressView("Loading cast…")
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 180
                        )
                }
            }

            Section {
                searchField
            }

            if !query.isEmpty {
                Section {
                    searchResults
                }
            }
        }
        .listStyle(.plain)
        .contentMargins(.bottom, 88, for: .scrollContent)
        .navigationTitle("Cast")
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            isHomeVisible = true
        }
        .onDisappear {
            isHomeVisible = false
        }
        .task(id: galleryRetry) {
            await model.loadGallery(
                retry: galleryRetry > 0
            )
        }
        .task(
            id: SearchRequest(
                query: query,
                retry: searchRetry
            )
        ) {
            await model.search(for: query)
        }
        .onReceive(model.$state) { state in
            guard voiceOverEnabled, isHomeVisible else {
                return
            }

            switch state {
            case .results(let cast):
                let message = cast.isEmpty
                    ? "No matches."
                    : "\(cast.count) matching cast members loaded."

                AccessibilityNotification
                    .Announcement(message)
                    .post()

            case .failed(let message):
                AccessibilityNotification
                    .Announcement(message)
                    .post()

            case .idle, .loading:
                break
            }
        }
    }
    .environmentObject(speech)
    .overlay(alignment: .bottomTrailing) {
        Button {
            searchFocused = false
            showAccessibility = true
        } label: {
            Image(systemName: "accessibility")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Color.accentColor,
                    in: Circle()
                )
                .shadow(
                    color: .black.opacity(0.18),
                    radius: 6,
                    y: 3
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Accessibility")
        .accessibilityValue(
            speech.isEnabled
                ? "Read aloud on"
                : "Read aloud off"
        )
        .padding(20)
    }
    .sheet(isPresented: $showAccessibility) {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Read aloud",
                        isOn: $speech.isEnabled
                    )
                } footer: {
                    Text(
                        """
                        Adds a read button to search results \
                        and reads details when opened.
                        """
                    )
                }

                if speech.speakingCharacterID != nil {
                    Button("Stop reading") {
                        speech.stop()
                    }
                }
            }
            .navigationTitle("Accessibility")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showAccessibility = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    .onChange(of: query) { _, _ in
        speech.stop()
    }
    .onChange(of: scenePhase) { _, phase in
        if phase != .active {
            speech.stop()
        }
    }
    .onChange(of: voiceOverEnabled) { _, enabled in
        if enabled {
            speech.stop()
        }
    }
}

private var searchField: some View {
    HStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

        TextField("Search cast", text: $searchText)
            .focused($searchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .onSubmit {
                searchFocused = false
            }
            .accessibilityLabel("Search cast")

        if !searchText.isEmpty {
            Button {
                searchText = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(
                        minWidth: 44,
                        minHeight: 44
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear search")
        }
    }
    .frame(minHeight: 44)
}

@ViewBuilder
private var searchResults: some View {
    switch model.state {
    case .idle:
        EmptyView()

    case .loading:
        ProgressView("Searching…")

    case .results(let cast):
        if cast.isEmpty {
            Text("No matches")
                .foregroundStyle(.secondary)
        } else {
            ForEach(cast) { character in
                HStack(spacing: 8) {
                    NavigationLink {
                        CharacterDetailView(
                            character: character
                        )
                    } label: {
                        CharacterRow(
                            character: character
                        )
                    }
                    .accessibilityHint(
                        "Opens cast details."
                    )

                    if speech.isEnabled {
                        Button {
                            speech.toggle(character)
                        } label: {
                            Image(
                                systemName:
                                    speech.speakingCharacterID == character.id
                                    ? "stop.fill"
                                    : "speaker.wave.2.fill"
                            )
                            .frame(
                                minWidth: 44,
                                minHeight: 44
                            )
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(
                            speech.speakingCharacterID == character.id
                                ? "Stop reading"
                                : "Read \(character.name)"
                        )
                    }
                }
            }

            paginationFooter(
                loadedCount: cast.count
            )
        }

    case .failed(let message):
        CastErrorView(
            title: "Couldn’t load cast",
            message: message,
            retryAt: model.searchRetryAt
        ) {
            searchRetry += 1
        }
    }
}

@ViewBuilder
private func paginationFooter(
    loadedCount: Int
) -> some View {
    if let page = model.nextPage {
        if let message = model.pageError {
            CastErrorView(
                title: "Couldn’t load more cast",
                message: message,
                retryAt: model.pageRetryAt
            ) {
                let requestedQuery = query

                Task {
                    await model.loadNextPage(
                        page,
                        for: requestedQuery,
                        retry: true
                    )
                }
            }
        } else {
            NextPageTrigger(
                isEnabled:
                    isHomeVisible && scenePhase == .active
            ) {
                await model.loadNextPage(
                    page,
                    for: query
                )
            }
            .id(
                PageIdentity(
                    query: query,
                    page: page
                )
            )
        }
    } else {
        Text("All \(loadedCount) matches loaded")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

}

private struct NextPageTrigger: View {
let isEnabled: Bool
let load: () async -> Void

@State private var isVisible = false

var body: some View {
    ProgressView("Loading more…")
        .frame(
            maxWidth: .infinity,
            minHeight: 44
        )
        .onScrollVisibilityChange(threshold: 0.1) {
            isVisible = $0
        }
        .task(id: isVisible && isEnabled) {
            if isVisible && isEnabled {
                await load()
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
        .clipShape(
            RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
            Text(character.name)
                .font(.headline)

            Text(character.species)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(character.status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .fixedSize(
            horizontal: false,
            vertical: true
        )
    }
    .accessibilityElement(children: .combine)
}

}

private struct CastErrorView: View {
let title: String
let message: String
let retryAt: Date?
let retry: () -> Void

var body: some View {
    VStack(alignment: .leading, spacing: 10) {
        Text(title)
            .font(.headline)

        Text(message)
            .foregroundStyle(.secondary)

        TimelineView(
            .periodic(from: .now, by: 1)
        ) { context in
            let seconds = max(
                0,
                (
                    retryAt?.timeIntervalSince(context.date) ?? 0
                ).rounded(.up)
            )

            Button {
                guard seconds <= 0 else {
                    return
                }

                retry()
            } label: {
                Text(
                    seconds > 0
                        ? "Try again in \(seconds.formatted(.number.precision(.fractionLength(0))))s"
                        : "Try again"
                )
                .frame(minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(seconds > 0)
        }
    }
    .padding(.vertical, 8)
}

}
