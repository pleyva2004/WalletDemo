import SwiftUI

struct ContentView: View {
    private let doc = PassStore.document

    @State private var showDetails = false
    @State private var isPressing = false
    @State private var haptics = HapticsController()

    private var backFields: [PassDocument.Field] { doc.eventTicket.backFields ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PassCardView(doc: doc)
                        .scaleEffect(isPressing ? 0.97 : 1)
                        .animation(.easeOut(duration: 0.15), value: isPressing)
                        .onLongPressGesture(minimumDuration: 0.35, maximumDistance: 30) {
                            revealDetails()
                        } onPressingChanged: { pressing in
                            isPressing = pressing
                            if pressing { haptics.pressDown() }
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Shows ticket details")
                        .accessibilityAction { revealDetails() }

                    hint
                }
                .padding()
            }
            .navigationTitle("Wallet")
        }
        .overlay { detailsOverlay }
    }

    private var hint: some View {
        Label("Touch and hold the ticket for details", systemImage: "hand.point.up.left")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder private var detailsOverlay: some View {
        if showDetails {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { dismissDetails() }
                    .transition(.opacity)

                TicketDetailsIsland(fields: backFields) { dismissDetails() }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            .zIndex(1)
        }
    }

    private func revealDetails() {
        haptics.revealImpact()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            showDetails = true
        }
    }

    private func dismissDetails() {
        withAnimation(.easeInOut(duration: 0.22)) {
            showDetails = false
        }
    }
}
