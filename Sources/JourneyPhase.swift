import Foundation

// MARK: - Journey phase engine
//
// Where the ticket-holder is in their journey to the match. This single pure function is
// the brain of the Live Activity: it decides which fact gets surfaced. No side effects,
// no UIKit — just (time + venue proximity) -> phase, so it's trivially testable and shared
// by the app and (later) the widget extension.

enum JourneyPhase: String, CaseIterable {
    case preEvent       // days/hours out, away from venue
    case approaching    // within the travel window, en route
    case atVenue        // at the stadium, before kickoff
    case inProgress     // kickoff -> final whistle
    case postEvent      // after the match
    case unknown        // can't confidently place the user -> neutral fallback
}

extension JourneyPhase {
    /// How long before doors we start treating the user as "approaching" (the travel window).
    static let travelLead: TimeInterval = 2 * 3600
    // ponytail: assume a ~2.5h match for the final-whistle boundary; decode
    // semantics.eventEndDate if a real end time ever matters.
    static let assumedMatchDuration: TimeInterval = 2.5 * 3600

    /// The one rule that orders the phases. `now == nil` (no usable clock) -> unknown, so the
    /// UI degrades to a neutral card rather than guessing.
    static func resolve(now: Date?, atVenue: Bool, doors: Date?, kickoff: Date?) -> JourneyPhase {
        guard let now, let doors, let kickoff else { return .unknown }
        let end = kickoff.addingTimeInterval(assumedMatchDuration)
        if now >= end { return .postEvent }
        if now >= kickoff { return .inProgress }
        if atVenue { return .atVenue }                                // proximity wins before kickoff
        if now >= doors.addingTimeInterval(-travelLead) { return .approaching }
        return .preEvent
    }
}

#if DEBUG
// Runnable check: executed at app launch (WalletDemoApp.init). A broken rule crashes on
// launch, so the screenshot loop fails loudly instead of producing a wrong card.
enum JourneyPhaseSelfCheck {
    static func run() {
        let doors = iso("2026-07-14T16:00:00-04:00")!
        let kickoff = iso("2026-07-14T19:00:00-04:00")!
        func p(_ s: String, atVenue: Bool = false) -> JourneyPhase {
            JourneyPhase.resolve(now: iso(s), atVenue: atVenue, doors: doors, kickoff: kickoff)
        }
        assert(p("2026-07-12T10:00:00-04:00") == .preEvent)                 // 2 days out
        assert(p("2026-07-14T13:00:00-04:00") == .preEvent)                 // before doors-2h (14:00)
        assert(p("2026-07-14T14:30:00-04:00") == .approaching)             // inside the travel window
        assert(p("2026-07-14T16:30:00-04:00", atVenue: false) == .approaching)
        assert(p("2026-07-14T16:30:00-04:00", atVenue: true) == .atVenue)  // proximity overrides
        assert(p("2026-07-14T20:00:00-04:00") == .inProgress)              // after kickoff (19:00)
        assert(p("2026-07-14T22:00:00-04:00") == .postEvent)               // after ~21:30 whistle
        assert(JourneyPhase.resolve(now: nil, atVenue: false, doors: doors, kickoff: kickoff) == .unknown)
    }

    private static func iso(_ s: String) -> Date? {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
#endif
