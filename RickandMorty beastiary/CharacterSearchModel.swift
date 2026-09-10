//
//  CharacterSearchModel.swift
//  RickandMorty beastiary
//
//  Created by Wyatt, Leteef NZ/IBC-ZGD on 9/10/26.
//

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

    private let fetcher = CharacterFetcher()

    func search(for name: String) async {
        guard !Task.isCancelled else {
            return
        }

        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            state = .idle
            return
        }

        state = .loading

        do {
            try await Task.sleep(nanoseconds: 350_000_000)
            
            let characters = try await fetcher.search(name: query)

            try Task.checkCancellation()

            state = .results(characters)
        } catch {
            guard !Task.isCancelled else {
                return
            }

            state = .failed(error.localizedDescription)
        }
    }
}
