import SwiftUI

// MARK: - Decoded subset of pass.json
//
// This is the single source of truth shared with the real .pkpass: the app decodes the
// same pass.json that Pass/build-pass.sh packages, so the in-app card always matches the
// ticket that would land in Apple Wallet.

struct PassDocument: Decodable {
    let organizationName: String
    let description: String
    let logoText: String?
    let foregroundColor: String?
    let backgroundColor: String?
    let labelColor: String?
    let relevantDate: String?
    let barcodes: [Barcode]?
    let eventTicket: EventTicket

    struct Barcode: Decodable {
        let format: String
        let message: String
        let altText: String?
    }

    struct EventTicket: Decodable {
        let headerFields: [Field]?
        let primaryFields: [Field]?
        let secondaryFields: [Field]?
        let auxiliaryFields: [Field]?
        let backFields: [Field]?
    }

    struct Field: Decodable, Identifiable {
        let key: String
        let label: String?
        let value: String
        let dateStyle: String?
        let timeStyle: String?
        let textAlignment: String?
        let ignoresTimeZone: Bool?

        var id: String { key }
    }
}

// MARK: - Field presentation helpers

extension PassDocument.Field {
    /// Renders date-styled fields. For a fixed-venue event ticket, `ignoresTimeZone` pins the
    /// displayed time to the offset baked into the value (e.g. Eastern), so the kickoff reads
    /// the same regardless of the device's time zone — matching Apple Wallet's behavior.
    var displayValue: String {
        guard dateStyle != nil || timeStyle != nil else { return value }
        guard let date = Self.parseISO(value) else { return value }
        let formatter = DateFormatter()
        if ignoresTimeZone == true, let zone = Self.timeZone(from: value) {
            formatter.timeZone = zone
        }
        formatter.dateStyle = Self.style(dateStyle)
        formatter.timeStyle = Self.style(timeStyle)
        return formatter.string(from: date)
    }

    var hAlign: HorizontalAlignment {
        switch textAlignment {
        case "PKTextAlignmentRight": return .trailing
        case "PKTextAlignmentCenter": return .center
        default: return .leading
        }
    }

    var frameAlign: Alignment {
        switch textAlignment {
        case "PKTextAlignmentRight": return .trailing
        case "PKTextAlignmentCenter": return .center
        default: return .leading
        }
    }

    private static func style(_ name: String?) -> DateFormatter.Style {
        switch name {
        case "PKDateStyleShort":  return .short
        case "PKDateStyleMedium": return .medium
        case "PKDateStyleLong":   return .long
        case "PKDateStyleFull":   return .full
        default:                  return .none
        }
    }

    /// Parses ISO8601 with or without fractional seconds (neither option set parses both).
    private static func parseISO(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    /// Extracts the time zone from a trailing ISO8601 offset ("Z" or "±HH:MM").
    private static func timeZone(from string: String) -> TimeZone? {
        if string.hasSuffix("Z") { return TimeZone(secondsFromGMT: 0) }
        let suffix = string.suffix(6) // e.g. "-04:00"
        guard suffix.count == 6, let sign = suffix.first, sign == "+" || sign == "-" else { return nil }
        let parts = suffix.dropFirst().split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]) else { return nil }
        let seconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }
}

// MARK: - PassKit rgb(...) color parsing

extension Color {
    /// Parses a PassKit `rgb(r, g, b)` string; uses `fallback` when absent or malformed.
    init(passRGB string: String?, fallback: Color) {
        guard let string,
              let open = string.firstIndex(of: "("),
              let close = string.firstIndex(of: ")"), open < close else {
            self = fallback; return
        }
        let components = string[string.index(after: open)..<close]
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard components.count == 3 else { self = fallback; return }
        self = Color(.sRGB, red: components[0] / 255, green: components[1] / 255, blue: components[2] / 255)
    }
}

// MARK: - Loading the bundled pass.json

enum PassStore {
    /// The pass.json bundled into the app. Falls back to an embedded copy if the resource
    /// is missing so the UI always renders.
    static let document: PassDocument = {
        if let url = Bundle.main.url(forResource: "pass", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let document = try? JSONDecoder().decode(PassDocument.self, from: data) {
            return document
        }
        // In development, a missing/un-decodable bundled pass.json is a packaging error.
        assertionFailure("Bundled pass.json missing or failed to decode; using fallback.")
        return .fallback
    }()
}

extension PassDocument {
    private static func field(_ key: String, _ label: String?, _ value: String,
                              align: String? = nil, dateStyle: String? = nil, timeStyle: String? = nil,
                              ignoresTimeZone: Bool? = nil) -> Field {
        Field(key: key, label: label, value: value, dateStyle: dateStyle, timeStyle: timeStyle,
              textAlignment: align, ignoresTimeZone: ignoresTimeZone)
    }

    /// Kept in parity with Pass/WorldCupPass.pass/pass.json so the fallback shows the same ticket.
    static let fallback = PassDocument(
        organizationName: "WalletDemo FIFA World Cup 26",
        description: "FIFA World Cup 2026 Semi-final - USA vs Argentina",
        logoText: "FIFA World Cup 26",
        foregroundColor: "rgb(255, 255, 255)",
        backgroundColor: "rgb(11, 38, 80)",
        labelColor: "rgb(214, 178, 92)",
        relevantDate: "2026-07-14T19:00:00-04:00",
        barcodes: [Barcode(format: "PKBarcodeFormatQR",
                           message: "WC2026|SF1|MET|SEC112|ROW8|SEAT14|SN:WC2026-SF1-MET-A112-0007",
                           altText: "WC2026-SF1-MET-A112-0007")],
        eventTicket: EventTicket(
            headerFields: [field("gate", "GATE", "C", align: "PKTextAlignmentRight")],
            primaryFields: [field("home", "USA", "USA"),
                            field("away", "ARGENTINA", "ARG", align: "PKTextAlignmentRight")],
            secondaryFields: [field("round", "MATCH", "Semi-final"),
                              field("datetime", "KICKOFF", "2026-07-14T19:00:00-04:00",
                                    align: "PKTextAlignmentRight",
                                    dateStyle: "PKDateStyleMedium", timeStyle: "PKDateStyleShort",
                                    ignoresTimeZone: true)],
            auxiliaryFields: [field("section", "SECTION", "112"),
                              field("row", "ROW", "8"),
                              field("seat", "SEAT", "14", align: "PKTextAlignmentRight")],
            backFields: [field("venue", "VENUE", "MetLife Stadium, East Rutherford, New Jersey, USA"),
                         field("match-id", "MATCH ID", "FWC26-M101 (Semi-final 1)"),
                         field("entrance", "RECOMMENDED ENTRANCE", "Gate C - West Plaza"),
                         field("doors", "DOORS OPEN", "2026-07-14T16:00:00-04:00",
                               dateStyle: "PKDateStyleMedium", timeStyle: "PKDateStyleShort",
                               ignoresTimeZone: true),
                         field("terms", "TERMS & CONDITIONS",
                               "Non-transferable except via the official FIFA resale platform. Subject to FIFA Ticketing Terms. No re-entry. This is a mockup demo pass and is not valid for entry."),
                         field("support", "TICKET SUPPORT", "support@walletdemo.example")]
        )
    )
}
