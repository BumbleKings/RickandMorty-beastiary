//
//  CharacterDetailView.swift
//  RickandMorty beastiary
//
//  Created by Wyatt, Leteef NZ/IBC-ZGD on 9/10/26.
//

import SwiftUI

struct CharacterDetailView: View {
    let character: RickMortyCharacter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(character.name)
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal)

                AsyncImage(url: character.image) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .accessibilityLabel(
                                "Portrait of \(character.name)"
                            )
                    } else if phase.error != nil {
                        Text("Image unavailable")
                            .foregroundStyle(.secondary)
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
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    LabeledContent(
                        "Species",
                        value: character.species
                    )

                    LabeledContent(
                        "Status",
                        value: character.status
                    )

                    LabeledContent(
                        "Origin",
                        value: character.origin.name
                    )

                    if !character.type
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty {
                        LabeledContent(
                            "Type",
                            value: character.type
                        )
                    }

                    LabeledContent(
                        "Created",
                        value: character.created.formatted(
                            date: .long,
                            time: .shortened
                        )
                    )
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
