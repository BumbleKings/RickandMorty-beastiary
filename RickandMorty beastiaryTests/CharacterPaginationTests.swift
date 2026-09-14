//
//  CharacterPaginationTests.swift
//  RickandMorty beastiary
//
//  Created by Wyatt, Leteef NZ/IBC-ZGD on 9/14/26.
//

import Foundation
import XCTest
@testable import RickandMorty_beastiary

final class CharacterPaginationTests: XCTestCase {
    @MainActor
    func testAppendsUniqueMatchesAndStopsAtLastPage() async throws {
        let fetcher = try makeFetcher()
        let model = CharacterSearchModel(
            fetcher: fetcher,
            debounce: .zero
        )

        await model.search(for: "Ri")
        XCTAssertEqual(model.nextPage, 2)

        await model.loadNextPage(2, for: "Ri")

        XCTAssertEqual(resultIDs(model), [1, 2, 3])
        XCTAssertNil(model.nextPage)

        await model.loadNextPage(3, for: "Ri")

        let requests = await fetcher.requestLog()
        XCTAssertEqual(requests, ["Ri:1", "Ri:2"])
    }

    @MainActor
    func testFailedPageKeepsResultsAndRetriesSamePage() async throws {
        let fetcher = try makeFetcher(
            failSecondPageOnce: true
        )
        let model = CharacterSearchModel(
            fetcher: fetcher,
            debounce: .zero
        )

        await model.search(for: "Ri")
        await model.loadNextPage(2, for: "Ri")

        XCTAssertEqual(resultIDs(model), [1, 2])
        XCTAssertNotNil(model.pageError)
        XCTAssertEqual(model.nextPage, 2)

        // Scrolling must not repeatedly retry a failed page.
        await model.loadNextPage(2, for: "Ri")

        var requests = await fetcher.requestLog()
        XCTAssertEqual(requests, ["Ri:1", "Ri:2"])

        await model.loadNextPage(
            2,
            for: "Ri",
            retry: true
        )

        XCTAssertEqual(resultIDs(model), [1, 2, 3])
        XCTAssertNil(model.pageError)

        requests = await fetcher.requestLog()
        XCTAssertEqual(
            requests,
            ["Ri:1", "Ri:2", "Ri:2"]
        )
    }

    @MainActor
    func testOldPageCannotAppendAfterSearchChanges() async throws {
        let started = expectation(
            description: "Second page started"
        )

        let fetcher = try makeFetcher(
            onSecondPage: {
                started.fulfill()
            }
        )

        let model = CharacterSearchModel(
            fetcher: fetcher,
            debounce: .zero
        )

        await model.search(for: "Ri")

        let oldPage = Task {
            await model.loadNextPage(2, for: "Ri")
        }

        let waitResult = await XCTWaiter.fulfillment(
            of: [started],
            timeout: 2
        )
        XCTAssertEqual(waitResult, .completed)

        await model.search(for: "Morty")
        await fetcher.releaseSecondPage()
        await oldPage.value

        XCTAssertEqual(resultIDs(model), [99])
        XCTAssertNil(model.nextPage)
        XCTAssertNil(model.pageError)
    }

    @MainActor
    func testEmptySearchDoesNotFetch() async throws {
        let fetcher = try makeFetcher()
        let model = CharacterSearchModel(
            fetcher: fetcher,
            debounce: .zero
        )

        await model.search(for: "   ")

        guard case .idle = model.state else {
            return XCTFail("Expected idle.")
        }

        let requests = await fetcher.requestLog()
        XCTAssertTrue(requests.isEmpty)
    }

    @MainActor
    private func resultIDs(
        _ model: CharacterSearchModel
    ) -> [Int] {
        guard case .results(let cast) = model.state else {
            XCTFail("Expected results.")
            return []
        }

        return cast.map(\.id)
    }

    private func makeFetcher(
        failSecondPageOnce: Bool = false,
        onSecondPage: (@Sendable () -> Void)? = nil
    ) throws -> PaginationTestFetcher {
        let image = try XCTUnwrap(
            URL(
                string: "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
            )
        )

        func character(_ id: Int) -> RickMortyCharacter {
            RickMortyCharacter(
                id: id,
                name: "Cast \(id)",
                species: "Human",
                status: "Alive",
                type: "",
                origin: CharacterOrigin(name: "Earth"),
                image: image,
                created: Date(timeIntervalSince1970: 0)
            )
        }

        return PaginationTestFetcher(
            pages: [
                "Ri:1": CharacterResponse(
                    info: CharacterPageInfo(pages: 2),
                    results: [
                        character(1),
                        character(2)
                    ]
                ),
                "Ri:2": CharacterResponse(
                    info: CharacterPageInfo(pages: 2),
                    results: [
                        character(2),
                        character(3)
                    ]
                ),
                "Morty:1": CharacterResponse(
                    info: CharacterPageInfo(pages: 1),
                    results: [
                        character(99)
                    ]
                )
            ],
            failSecondPageOnce: failSecondPageOnce,
            onSecondPage: onSecondPage
        )
    }
}

private actor PaginationTestFetcher: CharacterFetching {
    private let pages: [String: CharacterResponse]
    private var failSecondPageOnce: Bool
    private let onSecondPage: (@Sendable () -> Void)?

    private var continuation: CheckedContinuation<Void, Never>?
    private var requests: [String] = []

    init(
        pages: [String: CharacterResponse],
        failSecondPageOnce: Bool,
        onSecondPage: (@Sendable () -> Void)?
    ) {
        self.pages = pages
        self.failSecondPageOnce = failSecondPageOnce
        self.onSecondPage = onSecondPage
    }

    func searchPage(
        name: String,
        page: Int
    ) async throws -> CharacterResponse {
        let key = "\(name):\(page)"
        requests.append(key)

        if key == "Ri:2" {
            if failSecondPageOnce {
                failSecondPageOnce = false
                throw URLError(.notConnectedToInternet)
            }

            if let onSecondPage {
                await withCheckedContinuation { continuation in
                    self.continuation = continuation
                    onSecondPage()
                }
            }
        }

        // Deliberately return even after cancellation.
        // The model must reject an obsolete response.
        return pages[key] ?? .empty
    }

    func randomCast() async throws -> [RickMortyCharacter] {
        []
    }

    func releaseSecondPage() {
        continuation?.resume()
        continuation = nil
    }

    func requestLog() -> [String] {
        requests
    }
}
