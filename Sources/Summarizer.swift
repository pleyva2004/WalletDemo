import Foundation

// MARK: - Summary line ("the AI garnish")
//
// One natural-language line the Live Activity leads with. Rules-based today; a
// FoundationModels-backed implementation can slot behind this same protocol later (see
// prd.md "AI engine"). Rules always render; if a Summarizer returns nil the surfaces fall
// back to their structured content — the line never blanks the card.

protocol Summarizer {
    func line(for phase: JourneyPhase, ticket: TicketSnapshot, now: Date) -> String?
}

struct TemplateSummarizer: Summarizer {
    func line(for phase: JourneyPhase, ticket: TicketSnapshot, now: Date) -> String? {
        switch phase {
        case .preEvent:
            let togo = ticket.kickoff.map { phaseRelative(now, $0) } ?? "Soon"
            return "\(togo) to kickoff — doors open \(VenueTime.clock(ticket.doors)) at \(ticket.venueShort). Plan to arrive early; this is a \(ticket.matchName)."
        case .approaching:
            return "Doors open at \(VenueTime.clock(ticket.doors)) — head for \(ticket.entrance). Parking fills early for the \(ticket.matchName)."
        case .atVenue:
            return "You're at \(ticket.venueShort). Enter at Gate \(ticket.gate), then \(ticket.seatLine). Have your QR ready."
        case .inProgress:
            return "\(ticket.matchup) is underway. Your seat: \(ticket.seatLine). Note: no re-entry."
        case .postEvent:
            return "Match complete. Keep this as a memento — for any issues contact ticket support; resale only via the official FIFA platform."
        case .unknown:
            return nil   // no confident moment -> structured neutral card, no narrated line
        }
    }
}
