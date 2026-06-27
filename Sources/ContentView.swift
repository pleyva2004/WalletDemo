import SwiftUI

struct ContentView: View {
    private let doc = PassStore.document

    /// When true, the card arrives already flipping to the Ticket Details island (used by
    /// the Messages resell flow). `siriPrompt`, when set, replaces the island's field rows.
    let initiallyFlipped: Bool
    let siriPrompt: String?

    init(initiallyFlipped: Bool = false, siriPrompt: String? = nil) {
        self.initiallyFlipped = initiallyFlipped
        self.siriPrompt = siriPrompt
    }

    /// 0 = front (pass) facing the viewer, 180 = back (Ticket Details) facing the viewer.
    @State private var flipAngle: Double = 0
    @State private var cardSize: CGSize = .zero
    @State private var haptics = HapticsController()

    private var showingBack: Bool { flipAngle >= 90 }
    private var backFields: [PassDocument.Field] { doc.eventTicket.backFields ?? [] }
    private var passBackground: Color {
        Color(passRGB: doc.backgroundColor, fallback: Color(red: 11/255, green: 38/255, blue: 80/255))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    flippableCard
                    hint
                }
                .padding()
            }
            .navigationTitle("Wallet")
        }
        .onAppear {
            haptics.prewarm()
            if initiallyFlipped && !showingBack {
                toggleFlip()                            // reuse the spring + haptic to reveal
                SiriVoice.shared.speak(siriPrompt)      // speak as the island lands
            }
        }
    }

    // MARK: - The card that flips between the pass front and the Ticket Details back

    private var flippableCard: some View {
        ZStack {
            PassCardView(doc: doc)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
                .modifier(FlipFace(angle: flipAngle, isBack: false))

            cardBack
                .modifier(FlipFace(angle: flipAngle, isBack: true))
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { toggleFlip() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(showingBack ? "Shows the ticket front" : "Shows ticket details")
        .accessibilityAction { toggleFlip() }
    }

    /// The reverse face: the same card footprint carrying the unchanged Ticket Details island.
    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(passBackground)
            .overlay {
                TicketDetailsIsland(fields: backFields, siriPrompt: siriPrompt) { toggleFlip() }
            }
            .frame(width: cardSize.width == 0 ? nil : cardSize.width,
                   height: cardSize.height == 0 ? nil : cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12)))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }

    private var hint: some View {
        Label(showingBack ? "Tap the ticket to flip back" : "Tap the ticket for details",
              systemImage: "hand.tap")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func toggleFlip() {
        haptics.revealImpact()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            flipAngle = showingBack ? 0 : 180
        }
    }
}

// MARK: - Card-flip face
//
// Both faces share one animated `angle` so they rotate together as a single card.
// The back is pre-offset by 180° so it starts facing away and reads un-mirrored once the
// flip completes. Opacity snaps at the 90° edge-on point — where the card has no apparent
// width — so the swap between faces is invisible and the reverse face never shows through.

struct FlipFace: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        let faceAngle = isBack ? angle + 180 : angle
        let isVisible = isBack ? angle >= 90 : angle < 90
        content
            .opacity(isVisible ? 1 : 0)
            .rotation3DEffect(.degrees(faceAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}
