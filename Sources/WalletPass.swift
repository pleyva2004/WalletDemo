import SwiftUI
import PassKit

// MARK: - "Add to Apple Wallet" button (wraps UIKit's PKAddPassButton)
//
// Adding a pass needs NO entitlement and NO Info.plist key — only `import PassKit`.
// (The com.apple.developer.pass-type-identifiers entitlement is required only to READ /
// manage the pass library, which this demo does not do.)

struct AddToWalletButton: UIViewRepresentable {
    var style: PKAddPassButtonStyle = .black
    var action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {
        uiView.addPassButtonStyle = style
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

// MARK: - Sheet hosting PKAddPassesViewController for a constructed PKPass

struct AddPassesSheet: UIViewControllerRepresentable {
    let pass: PKPass
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> UIViewController {
        // init?(pass:) is failable; guard instead of force-unwrapping so an unexpected nil
        // dismisses gracefully rather than crashing.
        guard let controller = PKAddPassesViewController(pass: pass) else {
            DispatchQueue.main.async { context.coordinator.onFinish() }
            return UIViewController()
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Coordinator: NSObject, PKAddPassesViewControllerDelegate {
        var onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
            controller.dismiss(animated: true) { self.onFinish() }
        }
    }
}

// MARK: - Loading the bundled .pkpass
//
// NOTE: PKPass(data:) throws IMMEDIATELY for an unsigned pass — NSError in
// PKPassKitErrorDomain, code 1 (PKInvalidDataError). That is EXPECTED for this demo bundle
// until it is signed with a real Pass Type ID certificate, so we surface it gracefully.

enum WalletPassLoader {
    enum Outcome {
        case ready(PKPass)
        case unsigned(NSError)
        case missing
    }

    static func loadBundledPass(named name: String = "WorldCupPass") -> Outcome {
        guard let url = Bundle.main.url(forResource: name, withExtension: "pkpass"),
              let data = try? Data(contentsOf: url) else {
            return .missing
        }
        do {
            return .ready(try PKPass(data: data))
        } catch let error as NSError {
            return .unsigned(error)
        }
    }
}

/// PKPass isn't Identifiable; tiny wrapper so it can drive `.sheet(item:)`.
struct IdentifiablePass: Identifiable {
    let pass: PKPass
    var id: String { pass.serialNumber }
}
