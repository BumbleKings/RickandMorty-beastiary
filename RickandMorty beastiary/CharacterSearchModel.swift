import Foundation
import Combine

enum CharacterSearchState {
    case idle
    case loading
    case results([RickMortyCharacter])
    case failed(String)
}

@MainActor
final class CharacterSearchModel: ObservableObject {
    @Published private(set) var state: CharacterSearchState = .idle
    @Published private(set) var searchRetryAt: Date?

    @Published private(set) var nextPage: Int?
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var pageError: String?
    @Published private(set) var pageRetryAt: Date?

    @Published private(set) var gallery: [RickMortyCharacter] = []
    @Published private(set) var galleryError: String?
    @Published private(set) var galleryRetryAt: Date?

    private let fetcher: any CharacterFetching
    private let debounce: Duration

    private var activeQuery = ""
    private var searchID = UUID()
    private var galleryID = UUID()
    private var hasAttemptedGallery = false
    private var pageTask: Task<Void, Never>?

    init(
        fetcher: any CharacterFetching = CharacterFetcher(),
        debounce: Duration = .milliseconds(350)
    ) {
        self.fetcher = fetcher
        self.debounce = debounce
    }

    func loadGallery(retry: Bool = false) async {
        guard !Task.isCancelled,
              gallery.isEmpty,
              !hasAttemptedGallery || retry else {
            return
        }

        let requestID = UUID()
        galleryID = requestID

        galleryError = nil
        galleryRetryAt = nil

        do {
            let cast = try await fetcher.randomCast()

            try Task.checkCancellation()

            guard requestID == galleryID else {
                return
            }

            gallery = cast
            hasAttemptedGallery = true
        } catch {
            guard requestID == galleryID,
                  !Task.isCancelled,
                  !(error is CancellationError) else {
                return
            }

            hasAttemptedGallery = true
            galleryError = CharacterFetcherError.message(for: error)
            galleryRetryAt = CharacterFetcherError.deadline(for: error)
        }
    }

    func search(for name: String) async {
        guard !Task.isCancelled else {
            return
        }

        pageTask?.cancel()
        pageTask = nil

        searchID = UUID()
        let requestID = searchID

        activeQuery = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        nextPage = nil
        isLoadingNextPage = false
        pageError = nil
        pageRetryAt = nil
        searchRetryAt = nil

        guard !activeQuery.isEmpty else {
            state = .idle
            return
        }

        state = .loading

        do {
            if debounce > .zero {
                try await Task.sleep(for: debounce)
            }

            try Task.checkCancellation()

            guard requestID == searchID else {
                return
            }

            let response = try await fetcher.searchPage(
                name: activeQuery,
                page: 1
            )

            try Task.checkCancellation()

            guard requestID == searchID else {
                return
            }

            accept(response, page: 1, existing: [])
        } catch {
            guard requestID == searchID,
                  !Task.isCancelled,
                  !(error is CancellationError) else {
                return
            }

            searchRetryAt = CharacterFetcherError.deadline(for: error)
            state = .failed(
                CharacterFetcherError.message(for: error)
            )
        }
    }

    func loadNextPage(
        _ page: Int,
        for name: String,
        retry: Bool = false
    ) async {
        let requestID = searchID

        // Avoid requesting the same page twice.
        if let running = pageTask {
            await running.value
        }

        guard !Task.isCancelled,
              requestID == searchID,
              name == activeQuery,
              nextPage == page,
              pageError == nil || retry,
              case .results = state else {
            return
        }

        isLoadingNextPage = true
        pageError = nil
        pageRetryAt = nil

        let fetcher = fetcher
        let query = activeQuery

        let task = Task { @MainActor [weak self] in
            defer {
                if let self, self.searchID == requestID {
                    self.isLoadingNextPage = false
                    self.pageTask = nil
                }
            }

            do {
                let response = try await fetcher.searchPage(
                    name: query,
                    page: page
                )

                try Task.checkCancellation()

                guard let self,
                      self.searchID == requestID,
                      case .results(let existing) = self.state else {
                    return
                }

                self.accept(
                    response,
                    page: page,
                    existing: existing
                )
            } catch {
                guard let self,
                      self.searchID == requestID,
                      !Task.isCancelled,
                      !(error is CancellationError) else {
                    return
                }

                self.pageError = CharacterFetcherError.message(
                    for: error
                )
                self.pageRetryAt = CharacterFetcherError.deadline(
                    for: error
                )
            }
        }

        pageTask = task

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func accept(
        _ response: CharacterResponse,
        page: Int,
        existing: [RickMortyCharacter]
    ) {
        var seen = Set(existing.map(\.id))

        let newCast = response.results.filter {
            seen.insert($0.id).inserted
        }

        nextPage = !response.results.isEmpty
            && page < (response.info?.pages ?? 0)
            ? page + 1
            : nil

        state = .results(existing + newCast)
    }
}
