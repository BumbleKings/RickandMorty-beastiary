//
//  AccessibilityButton.swift
//  RickandMorty beastiary
//
//  Created by Wyatt, Leteef NZ/IBC-ZGD on 9/14/26.
//

import SwiftUI

struct AccessibilityButton: View {
    @State private var showOptions = false

    @Environment(\.accessibilityVoiceOverEnabled)
    private var voiceOverEnabled

    var body: some View {
        Button {
            showOptions = true
        } label: {
            Image(systemName: "accessibility")
                .font(.title2)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Accessibility options")
        .sheet(isPresented: $showOptions) {
            NavigationStack {
                Form {
                    Section("VoiceOver status") {
                        LabeledContent(
                            "VoiceOver",
                            value: voiceOverEnabled ? "On" : "Off"
                        )
                    }

                    Section("Turn VoiceOver on or off") {
                        Text(
                            "Open Settings → Accessibility → VoiceOver."
                        )

                        Text(
                            "You can also ask Siri to turn VoiceOver on or off."
                        )
                    }
                }
                .navigationTitle("Accessibility")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showOptions = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
}
