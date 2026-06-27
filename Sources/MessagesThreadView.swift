import SwiftUI

// MARK: - Mock iMessage thread for the World Cup ticket
//
// A scripted conversation in which the user shares the match ticket. Styled like iMessage
// (gray received bubbles, blue sent bubbles, tails, header, input bar). The ticket-card
// bubble is rendered from the bundled pass.json so it stays in parity with the real ticket.

struct MessagesThreadView: View {
    private let doc = PassStore.document
    private let onOpenPass: () -> Void

    init(onOpenPass: @escaping () -> Void = {}) {
        self.onOpenPass = onOpenPass
    }

    var body: some View {
        VStack(spacing: 0) {
            ContactHeader(name: "Sam Rivera", initials: "SR")
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    Text("iMessage • Yesterday 8:42 PM")
                        .font(.caption2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)

                    ForEach(script) { msg in
                        switch msg.kind {
                        case .received:
                            if msg.siri {
                                SiriActionBubble(text: msg.text, tail: msg.tail, onOpenPass: onOpenPass)
                            } else {
                                BubbleRow(isSent: false, tail: msg.tail) { TextBubble(text: msg.text, isSent: false) }
                            }
                        case .sent:
                            BubbleRow(isSent: true, tail: msg.tail) { TextBubble(text: msg.text, isSent: true) }
                        case .ticket:
                            BubbleRow(isSent: true, tail: false) { TicketMessageCard(doc: doc) }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            InputBar()
        }
    }

    // The scripted thread. `tail` marks the last bubble of each consecutive run.
    private var script: [Message] {
        [
            .init(.received, "Hey… I'm so sorry but I can't make the match tomorrow 😞", tail: true),
            .init(.sent, "wait, are you sure?", tail: true),
            .init(.received, "Unfortunately yes — you should try reselling it.", tail: true, siri: true),
        ]
    }
}

// MARK: - Message model

private struct Message: Identifiable {
    enum Kind { case received, sent, ticket }
    let id = UUID()
    let kind: Kind
    let text: String
    let tail: Bool
    let siri: Bool   // Siri-surfaced: glow the bubble + show the "Open Pass in Wallet" action
    init(_ kind: Kind, _ text: String = "", tail: Bool = false, siri: Bool = false) {
        self.kind = kind; self.text = text; self.tail = tail; self.siri = siri
    }
}

// MARK: - Bubble layout

private struct BubbleRow<Content: View>: View {
    let isSent: Bool
    let tail: Bool
    @ViewBuilder var content: Content

    var body: some View {
        HStack {
            if isSent { Spacer(minLength: 60) }
            content
            if !isSent { Spacer(minLength: 60) }
        }
        .padding(isSent ? .trailing : .leading, tail ? 8 : 16)
        .padding(isSent ? .leading : .trailing, 16)
        .padding(.vertical, 1)
    }
}

private struct TextBubble: View {
    let text: String
    let isSent: Bool

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isSent ? .white : Color(.label))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSent ? Color(red: 0.04, green: 0.52, blue: 1.0) : Color(.systemGray5))
            )
    }
}

// A Siri-surfaced received bubble: rainbow glow + a contextual "Open Pass in Wallet" action,
// and Siri speaks the actionable phrase aloud when it appears.
private struct SiriActionBubble: View {
    let text: String
    let tail: Bool
    let onOpenPass: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            BubbleRow(isSent: false, tail: tail) {
                TextBubble(text: text, isSent: false)
            }
            Button(action: onOpenPass) {
                HStack(spacing: 10) {
                    Text("Open Pass in Wallet")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    AppleWalletLogo(size: 15)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.systemGray3)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color(.systemGray), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 6])))
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
        }
        .onAppear { SiriVoice.shared.speak("try reselling it") }
    }
}

// Stylized rendition of the Apple Wallet app icon: colored cards fanning out of a pocket.
// ponytail: drawn, not a bundled asset — Apple's exact logo is proprietary; this reads as Wallet.
private struct AppleWalletLogo: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack(alignment: .bottom) {
            card(Color(red: 0.99, green: 0.62, blue: 0.09), width: 0.72, peek: 0.26) // orange (back)
            card(Color(red: 0.96, green: 0.26, blue: 0.45), width: 0.82, peek: 0.18) // pink
            card(Color(red: 0.21, green: 0.74, blue: 0.97), width: 0.91, peek: 0.10) // blue
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)          // front pocket
                .fill(Color(red: 0.13, green: 0.14, blue: 0.18))
                .frame(width: size, height: size * 0.56)
        }
        .frame(width: size, height: size)
    }

    private func card(_ c: Color, width: CGFloat, peek: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
            .fill(c)
            .frame(width: size * width, height: size * 0.5)
            .offset(y: -size * peek)
    }
}

// MARK: - Ticket card bubble (rendered from pass.json)

private struct TicketMessageCard: View {
    let doc: PassDocument

    private var bg: Color { Color(passRGB: doc.backgroundColor, fallback: Color(red: 11/255, green: 38/255, blue: 80/255)) }
    private var fg: Color { Color(passRGB: doc.foregroundColor, fallback: .white) }
    private var label: Color { Color(passRGB: doc.labelColor, fallback: Color(red: 214/255, green: 178/255, blue: 92/255)) }

    private func aux(_ key: String) -> String { doc.eventTicket.auxiliaryFields?.first { $0.key == key }?.value ?? "" }
    private func back(_ key: String) -> String? { doc.eventTicket.backFields?.first { $0.key == key }?.value }
    private var kickoff: String {
        doc.eventTicket.secondaryFields?.first { $0.key == "datetime" }?.displayValue ?? ""
    }
    private var venueShort: String {
        (back("venue")?.split(separator: ",").first).map(String.init) ?? "MetLife Stadium"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wallet.pass.fill").font(.caption)
                Text("FIFA WORLD CUP 26").font(.caption2.weight(.bold))
            }
            .foregroundStyle(label)

            Text("🇺🇸 USA  vs  ARG 🇦🇷")
                .font(.title3.weight(.bold)).foregroundStyle(fg)
            Text(doc.eventTicket.secondaryFields?.first { $0.key == "round" }?.value ?? "Semi-final")
                .font(.subheadline.weight(.semibold)).foregroundStyle(fg.opacity(0.9))

            Divider().overlay(fg.opacity(0.2))

            row("KICKOFF", kickoff)
            row("VENUE", venueShort)
            row("SEAT", "Section \(aux("section")) · Row \(aux("row")) · Seat \(aux("seat"))")

            Text("Tap to view in Wallet")
                .font(.caption2).foregroundStyle(fg.opacity(0.6))
                .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 250, alignment: .leading)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(fg.opacity(0.12)))
    }

    private func row(_ l: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(l).font(.caption2.weight(.semibold)).foregroundStyle(label)
            Text(v).font(.subheadline).foregroundStyle(fg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Chrome: contact header + input bar

private struct ContactHeader: View {
    let name: String
    let initials: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.backward").font(.title3.weight(.semibold)).foregroundStyle(.blue)
            Spacer()
            VStack(spacing: 4) {
                Circle().fill(Color(.systemGray3))
                    .frame(width: 38, height: 38)
                    .overlay(Text(initials).font(.caption.weight(.semibold)).foregroundStyle(.white))
                HStack(spacing: 3) {
                    Text(name).font(.caption.weight(.medium))
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "video").font(.title3).foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

private struct InputBar: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Color(.systemGray2))
            HStack {
                Text("iMessage").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(Color(.systemGray2))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .overlay(Capsule().stroke(Color(.systemGray3)))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }
}
