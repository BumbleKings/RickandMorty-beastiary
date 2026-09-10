//
//  CharacterFetcherTests.swift
//  RickandMorty beastiary
//
//  Created by Wyatt, Leteef NZ/IBC-ZGD on 9/10/26.
//

import Foundation
import XCTest
@testable import RickandMorty_beastiary

final class CharacterFetcherTests: XCTestCase {
    @MainActor
    func testDecodesCharacterAndCreationDate() async throws {
        let json = """
        {
            "results": [
                {
                    "id": 1,
                    "name": "Rick Sanchez",
                    "species": "Human",
                    "status": "Alive",
                    "type": "",
                    "origin": {
                        "name": "Earth (C-137)"
                    },
                    "image": "https://rickandmortyapi.com/api/character/avatar/1.jpeg",
                    "created": "2017-11-04T18:48:46.250Z"
                }
            ]
        }
        """

        let data = Data(json.utf8)

        let characters = try CharacterFetcher.decodeCharacters(
            from: data
        )

        XCTAssertEqual(characters.count, 1)

        let character = try XCTUnwrap(characters.first)

        XCTAssertEqual(character.id, 1)
        XCTAssertEqual(character.name, "Rick Sanchez")
        XCTAssertEqual(character.species, "Human")
        XCTAssertEqual(character.status, "Alive")
        XCTAssertEqual(character.type, "")
        XCTAssertEqual(character.origin.name, "Earth (C-137)")
        XCTAssertEqual(
            character.image.absoluteString,
            "https://rickandmortyapi.com/api/character/avatar/1.jpeg"
        )

        // Expected UTC timestamp, expressed as seconds since 1970.
        XCTAssertEqual(
            character.created.timeIntervalSince1970,
            1_509_821_326.250,
            accuracy: 0.001
        )
    }
}
