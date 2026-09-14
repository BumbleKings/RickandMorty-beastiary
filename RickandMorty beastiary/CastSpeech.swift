//
//  CastSpeech.swift
//  RickandMorty beastiary
//
//  Created by Wyatt, Leteef NZ/IBC-ZGD on 9/14/26.
//

import AVFoundation
import Combine
import UIKit

@MainActor
final class CastSpeech: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                isEnabled,
                forKey: "cast.readAloudEnabled"
            )

            if !isEnabled {
                stop()
            }
        }
    }

    @Published private(set) var speakingCharacterID: Int?

    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceID: ObjectIdentifier?

    override init() {
        isEnabled = UserDefaults.standard.bool(
            forKey: "cast.readAloudEnabled"
        )

        super.init()

        synthesizer.delegate = self
        synthesizer.usesApplicationAudioSession = false
    }

    func readAutomatically(_ character: RickMortyCharacter) {
        // Avoid automatically talking over Apple's screen reader.
        guard !UIAccessibility.isVoiceOverRunning else {
            return
        }

        read(character, details: true)
    }

    func toggle(
        _ character: RickMortyCharacter,
        details: Bool = false
    ) {
        if speakingCharacterID == character.id {
            stop()
        } else {
            read(character, details: details)
        }
    }

    func read(
        _ character: RickMortyCharacter,
        details: Bool
    ) {
        guard isEnabled else {
            return
        }

        stop()

        let text = details
            ? character.spokenDetails
            : character.spokenSummary

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.prefersAssistiveTechnologySettings = true

        utteranceID = ObjectIdentifier(utterance)
        speakingCharacterID = character.id

        synthesizer.speak(utterance)
    }

    func stop() {
        utteranceID = nil
        speakingCharacterID = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        finish(ObjectIdentifier(utterance))
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        finish(ObjectIdentifier(utterance))
    }

    private nonisolated func finish(
        _ finishedID: ObjectIdentifier
    ) {
        Task { @MainActor [weak self] in
            guard let self,
                  self.utteranceID == finishedID else {
                return
            }

            self.utteranceID = nil
            self.speakingCharacterID = nil
        }
    }
}
