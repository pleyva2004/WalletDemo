import SwiftUI

// MARK: - Launch-argument-driven demo harness
//
// Renders the Live Activity surfaces for one JourneyPhase using a mocked clock, so every
// use case in usecase.md can be screenshotted headlessly (see demo-shots.sh). Launch args
// (parsed by iOS into UserDefaults' argument domain):
//   -DemoNow <ISO8601>     the mocked "now"  ("none" -> nil clock -> unknown phase)
//   -DemoAtVenue <YES|NO>  whether the user is at the venue
// Absent -DemoNow, the app shows the normal ContentView, unchanged.

enum DemoConfig {
    static var isActive: Bool { UserDefaults.standard.string(forKey: "DemoNow") != nil }
    static var now: Date? {
        guard let s = UserDefaults.standard.string(forKey: "DemoNow"), s != "none" else { return nil }
        return TicketSnapshot.iso(s)
    }
    static var atVenue: Bool { UserDefaults.standard.bool(forKey: "DemoAtVenue") }
}

struct DemoHarnessView: View {
    private let ticket = TicketSnapshot(PassStore.document)
    private let summarizer: Summarizer = TemplateSummarizer()

    private var now: Date { DemoConfig.now ?? Date() }
    private var phase: JourneyPhase {
        JourneyPhase.resolve(now: DemoConfig.now, atVenue: DemoConfig.atVenue,
                             doors: ticket.doors, kickoff: ticket.kickoff)
    }

    var body: some View {
        let p = PhasePresentation(phase: phase, ticket: ticket)
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.16), .black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text(p.label).font(.title3.weight(.heavy)).foregroundStyle(.white)
                    Text("“\(p.question)”").font(.subheadline).italic().foregroundStyle(.white.opacity(0.7))
                }
                DynamicIslandPill(phase: phase, ticket: ticket, now: now)
                LockScreenCard(phase: phase, ticket: ticket, now: now,
                               summary: summarizer.line(for: phase, ticket: ticket, now: now))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 50)
        }
    }
}
