import SwiftUI

// MARK: - Shared Live Activity surfaces
//
// The SwiftUI a Live Activity widget extension would render on the Lock Screen and in the
// Dynamic Island. Kept in the app target so the demo harness can screenshot every phase
// headlessly (a real Live Activity lives on the Lock Screen / DI, which simctl can't reach
// headlessly — these are the identical views the extension would use). The QR reuses
// `QRCode` from PassCardView; colors reuse `Color(passRGB:)` from PassModel.

// MARK: Palette + time/relative helpers

struct PassPalette {
    let bg: Color, fg: Color, label: Color
    init(_ doc: PassDocument) {
        bg = Color(passRGB: doc.backgroundColor, fallback: Color(red: 11/255, green: 38/255, blue: 80/255))
        fg = Color(passRGB: doc.foregroundColor, fallback: .white)
        label = Color(passRGB: doc.labelColor, fallback: Color(red: 214/255, green: 178/255, blue: 92/255))
    }
    static let shared = PassPalette(PassStore.document)
}

enum VenueTime {
    // ponytail: venue tz hardcoded to ET (this is a MetLife/Eastern ticket); derive from
    // semantics if the app ever shows multi-venue passes.
    static let zone = TimeZone(identifier: "America/New_York") ?? .current
    static func clock(_ d: Date?) -> String { fmt(d, "h:mm a") }
    static func dayClock(_ d: Date?) -> String { fmt(d, "EEE h:mm a") }
    private static func fmt(_ d: Date?, _ format: String) -> String {
        guard let d else { return "—" }
        let f = DateFormatter(); f.timeZone = zone; f.dateFormat = format
        return f.string(from: d)
    }
}

/// Human "time until" string from the (mocked) now to a target. The real on-device activity
/// would use `Text(date, style: .timer)`; the demo computes statically so a mocked clock
/// shows the correct delta in a screenshot.
func phaseRelative(_ now: Date, _ target: Date) -> String {
    let secs = target.timeIntervalSince(now)
    if secs <= 0 { return "now" }
    let days = Int(secs) / 86_400
    if days >= 1 { return days == 1 ? "1 day" : "\(days) days" }
    let h = Int(secs) / 3600, m = (Int(secs) % 3600) / 60
    return h >= 1 ? "\(h)h \(m)m" : "\(m)m"
}

// MARK: Per-phase presentation (the content-importance matrix, in code)

struct PhasePresentation {
    let phase: JourneyPhase
    let ticket: TicketSnapshot

    var label: String {
        switch phase {
        case .preEvent: return "PRE-EVENT"
        case .approaching: return "APPROACHING"
        case .atVenue: return "AT VENUE"
        case .inProgress: return "IN PROGRESS"
        case .postEvent: return "POST-EVENT"
        case .unknown: return "DEFAULT"
        }
    }

    var question: String {
        switch phase {
        case .preEvent: return "When is this, and do I need to do anything yet?"
        case .approaching: return "Should I be leaving, and where am I going?"
        case .atVenue: return "How do I get in — fast?"
        case .inProgress: return "Where's my seat?"
        case .postEvent: return "Is this over? Anything I still need?"
        case .unknown: return "Show me the basics."
        }
    }

    var showsQR: Bool { phase == .atVenue }

    /// Dynamic Island compact: (sf-symbol, leading text) + trailing text.
    func compact(now: Date) -> (symbol: String, leading: String, trailing: String) {
        switch phase {
        case .preEvent:
            let togo = ticket.kickoff.map { phaseRelative(now, $0) } ?? "Soon"
            return ("calendar", togo, "kickoff")
        case .approaching:
            let togo = ticket.doors.map { phaseRelative(now, $0) } ?? "Soon"
            return ("figure.walk", "Doors \(togo)", "Gate \(ticket.gate)")
        case .atVenue:
            return ("qrcode", "Gate \(ticket.gate)", "Sec \(ticket.section)")
        case .inProgress:
            return ("sportscourt", "Sec \(ticket.section)", "Seat \(ticket.seat)")
        case .postEvent:
            return ("checkmark.seal", "Full time", "")
        case .unknown:
            return ("ticket", ticket.matchup, VenueTime.clock(ticket.kickoff))
        }
    }

    var minimalSymbol: String { compact(now: .distantPast).symbol }
}

// MARK: Dynamic Island (compact + minimal mock)

struct DynamicIslandPill: View {
    let phase: JourneyPhase
    let ticket: TicketSnapshot
    let now: Date

    var body: some View {
        let p = PhasePresentation(phase: phase, ticket: ticket)
        let c = p.compact(now: now)
        VStack(spacing: 10) {
            // Compact: the two slots flanking the camera (the wide pill).
            ZStack {
                Capsule().fill(.black)
                HStack {
                    Label(c.leading, systemImage: c.symbol)
                        .labelStyle(.titleAndIcon)
                        .font(.footnote.weight(.semibold))
                    Spacer(minLength: 70)   // the camera cutout
                    Text(c.trailing).font(.footnote.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
            }
            .frame(width: 360, height: 44)

            Text("Dynamic Island — compact")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: Lock Screen card (the hero surface)

struct LockScreenCard: View {
    let phase: JourneyPhase
    let ticket: TicketSnapshot
    let now: Date
    let summary: String?

    private let pal = PassPalette.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            topRow
            hero
            if let summary {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles").font(.caption)
                    Text(summary).font(.footnote)
                }
                .foregroundStyle(pal.fg.opacity(0.9))
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pal.bg)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(pal.fg.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
    }

    private var topRow: some View {
        HStack {
            Text("FIFA WORLD CUP 26").font(.caption2.weight(.bold)).foregroundStyle(pal.label)
            Spacer()
            Text("\(ticket.matchup) · \(ticket.matchName)")
                .font(.caption.weight(.semibold)).foregroundStyle(pal.fg.opacity(0.85))
        }
    }

    // The phase-led content — this is the answer to the phase's silent question.
    @ViewBuilder private var hero: some View {
        switch phase {
        case .preEvent:
            big(ticket.kickoff.map { phaseRelative(now, $0) } ?? "Soon", caption: "to kickoff")
            line("DOORS", VenueTime.dayClock(ticket.doors))
            line("VENUE", ticket.venueShort)
        case .approaching:
            big("Doors in \(ticket.doors.map { phaseRelative(now, $0) } ?? "soon")", caption: nil)
            line("HEAD FOR", ticket.entrance)
            line("VENUE", ticket.venueShort)
        case .atVenue:
            HStack(alignment: .center, spacing: 16) {
                qr
                VStack(alignment: .leading, spacing: 8) {
                    line("ENTER AT", "Gate \(ticket.gate)")
                    line("SEAT", ticket.seatLine)
                    Text("Doors are open").font(.caption).foregroundStyle(.green)
                }
                Spacer(minLength: 0)
            }
        case .inProgress:
            big(ticket.seatLine, caption: nil, size: 24)
            Text("NO RE-ENTRY")
                .font(.caption.weight(.bold)).foregroundStyle(pal.bg)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(pal.label, in: Capsule())
        case .postEvent:
            big("Full time", caption: ticket.matchup)
            line("SUPPORT", ticket.support ?? "—")
            Text("Resale only via the official FIFA platform.")
                .font(.caption).foregroundStyle(pal.fg.opacity(0.7))
        case .unknown:
            big(VenueTime.clock(ticket.kickoff), caption: "kickoff")
            line("WHEN", VenueTime.dayClock(ticket.kickoff))
            line("VENUE", ticket.venueShort)
        }
    }

    @ViewBuilder private var qr: some View {
        if let msg = ticket.qrMessage, let img = QRCode.image(from: msg) {
            Image(uiImage: img)
                .interpolation(.none).resizable().scaledToFit()
                .frame(width: 104, height: 104)
                .padding(7).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func big(_ text: String, caption: String?, size: CGFloat = 30) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text).font(.system(size: size, weight: .bold, design: .rounded)).foregroundStyle(pal.fg)
            if let caption { Text(caption).font(.subheadline).foregroundStyle(pal.fg.opacity(0.7)) }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(pal.label)
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(pal.fg)
                .fixedSize(horizontal: false, vertical: true)   // wrap rather than truncate
        }
    }
}
