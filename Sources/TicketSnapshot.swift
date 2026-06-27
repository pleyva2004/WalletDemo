import Foundation

// MARK: - Typed, presentation-ready view of the ticket
//
// Derived once from the decoded PassDocument so the Live Activity surfaces don't re-parse
// pass.json fields by key. pass.json stays the single source of truth — this just types it.

struct TicketSnapshot {
    let homeTeam: String      // "USA"
    let awayTeam: String      // "ARG"
    let matchName: String     // "Semi-final"
    let venue: String         // full venue string
    let venueShort: String    // "MetLife Stadium"
    let gate: String          // "C"
    let entrance: String      // "Gate C - West Plaza"
    let section: String
    let row: String
    let seat: String
    let doors: Date?
    let kickoff: Date?
    let qrMessage: String?
    let qrAltText: String?
    let support: String?

    var seatLine: String { "Section \(section) · Row \(row) · Seat \(seat)" }
    var matchup: String { "\(homeTeam) vs \(awayTeam)" }
}

extension TicketSnapshot {
    init(_ doc: PassDocument) {
        let et = doc.eventTicket
        func aux(_ key: String) -> String { et.auxiliaryFields?.first { $0.key == key }?.value ?? "" }
        func back(_ key: String) -> String? { et.backFields?.first { $0.key == key }?.value }

        let primaries = et.primaryFields ?? []
        homeTeam = primaries.first?.value ?? "USA"
        awayTeam = primaries.dropFirst().first?.value ?? "ARG"
        matchName = et.secondaryFields?.first { $0.key == "round" }?.value ?? "Match"
        let fullVenue = back("venue") ?? "MetLife Stadium"
        venue = fullVenue
        venueShort = fullVenue.split(separator: ",").first.map(String.init) ?? fullVenue
        gate = et.headerFields?.first { $0.key == "gate" }?.value ?? "C"
        entrance = back("entrance") ?? "Gate \(et.headerFields?.first { $0.key == "gate" }?.value ?? "C")"
        section = aux("section"); row = aux("row"); seat = aux("seat")
        doors = back("doors").flatMap(TicketSnapshot.iso)
        kickoff = doc.relevantDate.flatMap(TicketSnapshot.iso)
        qrMessage = doc.barcodes?.first?.message
        qrAltText = doc.barcodes?.first?.altText
        support = back("support")
    }

    static func iso(_ s: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
