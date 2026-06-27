import SwiftUI

@main
struct WalletDemoApp: App {
    init() {
        #if DEBUG
        JourneyPhaseSelfCheck.run()   // crashes loudly on a broken phase rule
        #endif
    }

    var body: some Scene {
        WindowGroup {
            // Demo mode (launch args set -DemoNow) renders the Live Activity surfaces for a
            // mocked phase; otherwise the normal app.
            if DemoConfig.isActive {
                DemoHarnessView()
            } else {
                ContentView()
            }
        }
    }
}
