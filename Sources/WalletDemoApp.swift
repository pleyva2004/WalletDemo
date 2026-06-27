import SwiftUI

@main
struct WalletDemoApp: App {
    enum Screen { case messages, pass }

    // `-FlowStep pass` jumps straight to the auto-flipped pass + Siri resell prompt (for
    // screenshots); default is the Messages thread.
    @State private var screen: Screen =
        UserDefaults.standard.string(forKey: "FlowStep") == "pass" ? .pass : .messages

    var body: some Scene {
        WindowGroup {
            Group {
                switch screen {
                case .messages:
                    MessagesThreadView {
                        withAnimation(.easeInOut(duration: 0.35)) { screen = .pass }
                    }
                case .pass:
                    ContentView(initiallyFlipped: true,
                                siriPrompt: "Would you like me to check resell tickets?",
                                onBack: { withAnimation(.easeInOut(duration: 0.35)) { screen = .messages } })
                }
            }
            .transition(.opacity)
        }
    }
}
