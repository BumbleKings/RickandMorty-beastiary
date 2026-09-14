import Foundation

nonisolated struct CharacterResponse: Decodable, Sendable {
    let info: CharacterPageInfo?
    let results: [RickMortyCharacter]

    static let empty = CharacterResponse(
        info: CharacterPageInfo(pages: 0),
        results: []
    )
}

nonisolated struct CharacterPageInfo: Decodable, Sendable {
    let pages: Int
}

nonisolated struct RickMortyCharacter: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String
    let species: String
    let status: String
    let type: String
    let origin: CharacterOrigin
    let image: URL
    let created: Date

    var availableType: String? {
        let value = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var formattedCreationDate: String {
        created.formatted(date: .long, time: .shortened)
    }

    var spokenSummary: String {
        "\(name). Species: \(species). Status: \(status)."
    }

    var spokenDetails: String {
        var parts = [
            spokenSummary,
            "Origin: \(origin.name)."
        ]

        if let availableType {
            parts.append("Type: \(availableType).")
        }

        parts.append("Created: \(formattedCreationDate).")
        return parts.joined(separator: " ")
    }
}

nonisolated struct CharacterOrigin: Decodable, Sendable {
    let name: String
}
