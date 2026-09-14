import Foundation
import XCTest
@testable import RickandMorty_beastiary

final class CharacterFetcherTests: XCTestCase {
    private func fixture(
        created: String = "2017-11-04T18:48:46.250Z"
    ) -> Data {
        Data("""
        {
          "results": [{
            "id": 1,
            "name": "Rick Sanchez",
            "species": "Human",
            "status": "Alive",
            "type": "",
            "origin": {
              "name": "Earth (C-137)"
            },
            "image": "https://rickandmortyapi.com/api/character/avatar/1.jpeg",
            "created": "\(created)"
          }]
        }
        """.utf8)
    }

    func testDecodesCharacterAndCreationDate() throws {
        let cast = try CharacterFetcher.decodeCharacters(
            from: fixture()
        )

        let character = try XCTUnwrap(cast.first)

        XCTAssertEqual(cast.count, 1)
        XCTAssertEqual(character.id, 1)
        XCTAssertEqual(character.name, "Rick Sanchez")
        XCTAssertEqual(character.species, "Human")
        XCTAssertEqual(character.status, "Alive")
        XCTAssertEqual(
            character.origin.name,
            "Earth (C-137)"
        )
        XCTAssertEqual(
            character.image.absoluteString,
            "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
        )
        XCTAssertNil(character.availableType)
        XCTAssertEqual(
            character.created.timeIntervalSince1970,
            1_509_821_326.250,
            accuracy: 0.001
        )
    }

    func testAcceptsDateWithoutFractionalSeconds() throws {
        let cast = try CharacterFetcher.decodeCharacters(
            from: fixture(
                created: "2017-11-04T18:48:46Z"
            )
        )

        let character = try XCTUnwrap(cast.first)

        XCTAssertEqual(
            character.created.timeIntervalSince1970,
            1_509_821_326,
            accuracy: 0.001
        )
    }

    func testRejectsInvalidDateAndMalformedJSON() {
        XCTAssertThrowsError(
            try CharacterFetcher.decodeCharacters(
                from: fixture(created: "invalid")
            )
        )

        XCTAssertThrowsError(
            try CharacterFetcher.decodeCharacters(
                from: Data("invalid".utf8)
            )
        )
    }

    func testRateLimitPreservesServerCooldown() throws {
        let now = Date(
            timeIntervalSince1970: 1_500_000_000
        )

        let url = try XCTUnwrap(
            URL(
                string: "https://rickandmortyapi.com/api/character/"
            )
        )

        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "30"]
            )
        )

        XCTAssertThrowsError(
            try CharacterFetcher.validate(
                response,
                now: now
            )
        ) { error in
            XCTAssertEqual(
                CharacterFetcherError.deadline(for: error),
                now.addingTimeInterval(30)
            )
        }
    }

    func testRetryAfterSupportsHTTPDateAndMissingHeader() {
        let now = Date(
            timeIntervalSince1970: 1_500_000_000
        )

        XCTAssertEqual(
            CharacterFetcher.retryDate(
                "Fri, 14 Jul 2017 02:40:30 GMT",
                now: now
            ),
            now.addingTimeInterval(30)
        )

        XCTAssertEqual(
            CharacterFetcher.retryDate(nil, now: now),
            now.addingTimeInterval(5)
        )

        XCTAssertEqual(
            CharacterFetcher.retryDate("-10", now: now),
            now.addingTimeInterval(5)
        )
    }

    func testServerFailureIsNotTreatedAsNoMatches() throws {
        let url = try XCTUnwrap(
            URL(
                string: "https://rickandmortyapi.com/api/character/"
            )
        )

        let response = try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: 503,
                httpVersion: nil,
                headerFields: nil
            )
        )

        XCTAssertThrowsError(
            try CharacterFetcher.validate(response)
        ) { error in
            guard let error = error as? CharacterFetcherError,
                  case .httpStatus(503) = error else {
                return XCTFail("Expected a server error.")
            }
        }
    }
}
