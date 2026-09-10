//
//  CharacterModels.swift
//  RickandMorty beastiary
//
//  Created by Wyatt, Leteef NZ/IBC-ZGD on 9/10/26.
//

import Foundation

struct CharacterResponse: Decodable{ let results: [RickMortyCharacter]
}

struct RickMortyCharacter : Decodable, Identifiable {
    
    let id: Int
    let name : String
    let species: String
    let status: String
    let type: String
    let origin: CharacterOrigin
    let image: URL
    let created: Date
}

struct CharacterOrigin: Decodable {
    let name: String
}
