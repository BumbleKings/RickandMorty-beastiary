import Foundation

nonisolated protocol CharacterFetching: Sendable {
    func searchPage(
        name: String,
        page: Int
    ) async throws -> CharacterResponse

    func randomCast() async throws -> [RickMortyCharacter]
}

actor CharacterFetcher: CharacterFetching {
    private let session: URLSession
    private var retryAfter: Date?
    private var cache: [URL: CachedResponse] = [:]

    private struct CachedResponse: Sendable {
        let page: CharacterResponse
        let expires: Date
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(name: String) async throws -> [RickMortyCharacter] {
        try await searchPage(name: name, page: 1).results
    }

    func searchPage(
        name: String,
        page: Int
    ) async throws -> CharacterResponse {
        let query = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !query.isEmpty else {
            return .empty
        }

        guard page > 0 else {
            throw CharacterFetcherError.invalidURL
        }

        do {
            return try await request([
                URLQueryItem(name: "name", value: query),
                URLQueryItem(name: "page", value: String(page))
            ])
        } catch CharacterFetcherError.notFound {
            return .empty
        }
    }

    func randomCast() async throws -> [RickMortyCharacter] {
        let firstPage = try await request([])

        guard let pages = firstPage.info?.pages, pages > 0 else {
            throw CharacterFetcherError.invalidResponse
        }

        let pageNumber = Int.random(in: 1...pages)
        let page: CharacterResponse

        if pageNumber == 1 {
            page = firstPage
        } else {
            page = try await request([
                URLQueryItem(
                    name: "page",
                    value: String(pageNumber)
                )
            ])
        }

        guard !page.results.isEmpty else {
            throw CharacterFetcherError.invalidResponse
        }

        return Array(page.results.shuffled().prefix(12))
    }

    private func request(
        _ queryItems: [URLQueryItem]
    ) async throws -> CharacterResponse {
        try Task.checkCancellation()

        var components = URLComponents()
        components.scheme = "https"
        components.host = "rickandmortyapi.com"
        components.path = "/api/character/"
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw CharacterFetcherError.invalidURL
        }

        if let cached = cache[url], cached.expires > Date() {
            return cached.page
        }

        if let retryAfter, retryAfter > Date() {
            throw CharacterFetcherError.rateLimited(
                until: retryAfter
            )
        }

        let request = URLRequest(
            url: url,
            timeoutInterval: 15
        )

        let (data, response) = try await session.data(for: request)

        try Task.checkCancellation()

        do {
            try Self.validate(response)
        } catch CharacterFetcherError.rateLimited(let date) {
            retryAfter = max(retryAfter ?? date, date)

            throw CharacterFetcherError.rateLimited(
                until: retryAfter ?? date
            )
        }

        let page = try Self.decodePage(from: data)

        guard let info = page.info, info.pages >= 0 else {
            throw CharacterFetcherError.invalidResponse
        }

        cache = cache.filter { $0.value.expires > Date() }

        if cache.count >= 20 {
            cache.removeAll(keepingCapacity: true)
        }

        cache[url] = CachedResponse(
            page: page,
            expires: Date().addingTimeInterval(60)
        )

        return page
    }

    nonisolated static func validate(
        _ response: URLResponse,
        now: Date = Date()
    ) throws {
        guard let response = response as? HTTPURLResponse else {
            throw CharacterFetcherError.invalidResponse
        }

        switch response.statusCode {
        case 200...299:
            return

        case 404:
            throw CharacterFetcherError.notFound

        case 429:
            let date = retryDate(
                response.value(forHTTPHeaderField: "Retry-After"),
                now: now
            )

            throw CharacterFetcherError.rateLimited(until: date)

        default:
            throw CharacterFetcherError.httpStatus(
                response.statusCode
            )
        }
    }

    nonisolated static func retryDate(
        _ header: String?,
        now: Date
    ) -> Date {
        if let header {
            let value = header.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            if let seconds = TimeInterval(value),
               seconds.isFinite,
               seconds >= 0 {
                return now.addingTimeInterval(
                    min(
                        seconds,
                        Date.distantFuture.timeIntervalSince(now)
                    )
                )
            }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
            formatter.isLenient = false

            if let date = formatter.date(from: value) {
                return max(now, date)
            }
        }

        return now.addingTimeInterval(5)
    }

    nonisolated static func decodeCharacters(
        from data: Data
    ) throws -> [RickMortyCharacter] {
        try decodePage(from: data).results
    }

    nonisolated private static func decodePage(
        from data: Data
    ) throws -> CharacterResponse {
        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = formatter.date(from: value) {
                return date
            }

            formatter.formatOptions = [.withInternetDateTime]

            if let date = formatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid creation date."
            )
        }

        return try decoder.decode(
            CharacterResponse.self,
            from: data
        )
    }
}

nonisolated enum CharacterFetcherError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case notFound
    case httpStatus(Int)
    case rateLimited(until: Date)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request could not be created."

        case .invalidResponse, .notFound:
            return "The cast could not be loaded. Please try again."

        case .rateLimited:
            return """
            The service is receiving too many requests. \
            Please wait before retrying.
            """

        case .httpStatus(let code):
            return (500...599).contains(code)
                ? "The cast service is temporarily unavailable."
                : "The service could not complete the request (HTTP \(code))."
        }
    }

    static func message(for error: Error) -> String {
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return """
                Your connection is unavailable. \
                Reconnect and try again.
                """

            case .timedOut:
                return "The request took too long. Please try again."

            default:
                return """
                Could not connect to the cast service. \
                Please try again.
                """
            }
        }

        if error is DecodingError {
            return """
            The service returned data the app could not read. \
            Please try again.
            """
        }

        if let error = error as? CharacterFetcherError {
            return error.localizedDescription
        }

        return """
        Something went wrong while loading the cast. \
        Please try again.
        """
    }

    static func deadline(for error: Error) -> Date? {
        if let error = error as? CharacterFetcherError,
           case .rateLimited(let date) = error {
            return date
        }

        return nil
    }
}
