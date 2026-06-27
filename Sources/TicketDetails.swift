import SwiftUI
import UIKit

// MARK: - Haptics
//
// Retained generators so prepare() actually warms the Taptic Engine for the upcoming
// impact, rather than warming a throwaway that deallocates before it can help.
// Silent no-ops on the Simulator (no Taptic Engine); fire only on a physical device.
// UIFeedbackGenerator must be used on the main thread — enforced via @MainActor.

@MainActor
final class HapticsController {
    private let reveal = UIImpactFeedbackGenerator(style: .rigid)

    /// Warm the Taptic Engine on appear so the first flip tap lands crisp and low-latency.
    func prewarm() {
        reveal.prepare()
    }

    /// Card flip: a crisp, pre-warmed rigid impact, then re-arm for the flip back.
    func revealImpact() {
        reveal.impactOccurred()
        reveal.prepare()
    }
}

// MARK: - Siri-style rotating rainbow glow (signifies "Siri-powered")

struct SiriGlowBorder: ViewModifier {
    var cornerRadius: CGFloat = 26
    var lineWidth: CGFloat = 3

    @State private var rotation: Double = 0

    private let colors: [Color] = [.pink, .purple, .indigo, .blue, .cyan, .green, .yellow, .orange, .red, .pink]

    func body(content: Content) -> some View {
        content
            .overlay(border.blur(radius: 9).opacity(0.9)) // soft outer glow
            .overlay(border)                              // crisp edge on top
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                AngularGradient(colors: colors, center: .center,
                                startAngle: .degrees(rotation), endAngle: .degrees(rotation + 360)),
                lineWidth: lineWidth
            )
    }
}

extension View {
    func siriGlow(cornerRadius: CGFloat = 26, lineWidth: CGFloat = 3) -> some View {
        modifier(SiriGlowBorder(cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}

// MARK: - Liquid Glass white panel (iOS 26), low transparency

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            // iOS 26 Liquid Glass with a light white tint — translucent, so the
            // backdrop shows through (some transparency) while still reading white.
            .glassEffect(.regular.tint(.white.opacity(0.45)), in: shape)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

// MARK: - The "Ticket Details" island (carried on the back of the flipped card)

struct TicketDetailsIsland: View {
    let fields: [PassDocument.Field]
    var siriPrompt: String? = nil
    var onClose: () -> Void

    @State private var contentHeight: CGFloat = 0
    private let maxScrollHeight: CGFloat = 460

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                Group {
                    if let siriPrompt {
                        siriPromptRow(siriPrompt)   // Siri took over the island: offer, no fields
                    } else {
                        fieldsColumn
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    contentHeight = height
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            // Hug the content, but cap so a tall ticket / large Dynamic Type scrolls
            // instead of overflowing the screen. The header (with Close) stays pinned above.
            .frame(height: min(max(contentHeight, 1), maxScrollHeight))
        }
        .padding(20)
        .frame(maxWidth: 360)
        .glassPanel(cornerRadius: 28)
        .siriGlow(cornerRadius: 28)
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
        .padding(.horizontal, 28)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
            Text("Ticket Details").font(.headline)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Close")
        }
        .padding(.bottom, 14)
    }

    private var fieldsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(fields) { field in
                row(field)
                if field.id != fields.last?.id {
                    Divider().opacity(0.4)
                }
            }
        }
    }

    private func row(_ field: PassDocument.Field) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let label = field.label {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(field.displayValue)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
    }

    // Siri's offer, shown in place of the field rows in the resell flow. A plain tappable
    // row (no background box) — just the prompt text and a chevron, matching the field rows.
    private func siriPromptRow(_ text: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            SiriVoice.shared.speak(text)
        } label: {
            HStack(spacing: 10) {
                Text(text)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.forward").font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
    }
}
