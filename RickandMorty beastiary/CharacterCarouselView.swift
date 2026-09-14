import SwiftUI

@MainActor
struct CharacterCarouselView: View {
    let characters: [RickMortyCharacter]
    var allowsAutomaticScrolling = true

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Environment(\.accessibilityVoiceOverEnabled)
    private var voiceOverEnabled

    @Environment(\.scenePhase)
    private var scenePhase

    @ScaledMetric(relativeTo: .body)
    private var cardWidth: CGFloat = 148

    @State private var position = ScrollPosition(
        idType: Int.self,
        x: 0
    )

    @State private var offset: CGFloat = 0
    @State private var maximumOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var userHasTakenControl = false

    private let spacing: CGFloat = 12
    private let pointsPerSecond: CGFloat = 20
    private let frameInterval: Double = 1.0 / 30.0

    private var cycleWidth: CGFloat {
        CGFloat(characters.count) * (cardWidth + spacing)
    }

    private var shouldScroll: Bool {
        allowsAutomaticScrolling
            && isVisible
            && scenePhase == .active
            && !reduceMotion
            && !voiceOverEnabled
            && !userHasTakenControl
            && characters.count > 1
            && maximumOffset > 0
            && (
                maximumOffset >= cycleWidth
                    || offset < maximumOffset
            )
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: spacing) {
                // The second copy makes the automatic loop seamless.
                ForEach(0..<2, id: \.self) { copy in
                    ForEach(characters) { character in
                        NavigationLink {
                            CharacterDetailView(character: character)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                AsyncImage(url: character.image) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } else if phase.error != nil {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.secondary)
                                            .frame(
                                                maxWidth: .infinity,
                                                maxHeight: .infinity
                                            )
                                    } else {
                                        ProgressView()
                                            .frame(
                                                maxWidth: .infinity,
                                                maxHeight: .infinity
                                            )
                                    }
                                }
                                .frame(
                                    width: cardWidth,
                                    height: cardWidth * 0.85
                                )
                                .background(
                                    Color.secondary.opacity(0.1)
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 14)
                                )
                                .accessibilityHidden(true)

                                Text(character.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(
                                        horizontal: false,
                                        vertical: true
                                    )
                            }
                            .frame(
                                width: cardWidth,
                                alignment: .leading
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(character.name), \(character.species)"
                        )
                        .accessibilityHint("Opens cast details.")
                        .accessibilityHidden(copy > 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            max(
                0,
                geometry.contentSize.width
                    - geometry.containerSize.width
            )
        } action: { _, value in
            maximumOffset = value
        }
        .onScrollPhaseChange { _, phase in
            if phase == .tracking
                || phase == .interacting
                || phase == .decelerating {
                userHasTakenControl = true
            }
        }
        .onScrollVisibilityChange(threshold: 0.5) { visible in
            isVisible = visible
        }
        .onDisappear {
            isVisible = false
        }
        .task(id: shouldScroll) {
            while shouldScroll && !Task.isCancelled {
                do {
                    try await Task.sleep(
                        for: .seconds(frameInterval)
                    )
                } catch {
                    return
                }

                guard shouldScroll && !Task.isCancelled else {
                    return
                }

                let next = offset
                    + pointsPerSecond * CGFloat(frameInterval)

                if cycleWidth > 0
                    && maximumOffset >= cycleWidth
                    && next >= cycleWidth {
                    offset = next - cycleWidth
                } else {
                    offset = min(next, maximumOffset)
                }

                position.scrollTo(x: offset)
            }
        }
    }
}
