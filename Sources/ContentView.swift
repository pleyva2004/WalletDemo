import SwiftUI
import PassKit

struct ContentView: View {
    private let doc = PassStore.document

    @State private var passToAdd: IdentifiablePass?
    @State private var statusTitle = ""
    @State private var statusMessage = ""
    @State private var showStatus = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PassCardView(doc: doc)
                    addToWalletSection
                    PassDetailsView(doc: doc)
                    mockupNote
                }
                .padding()
            }
            .navigationTitle("Wallet")
        }
        .sheet(item: $passToAdd) { wrapped in
            AddPassesSheet(pass: wrapped.pass) { passToAdd = nil }
        }
        .alert(statusTitle, isPresented: $showStatus) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage)
        }
    }

    @ViewBuilder private var addToWalletSection: some View {
        if PKAddPassesViewController.canAddPasses() {
            AddToWalletButton(style: .black) { attemptAdd() }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
        }
    }

    private var mockupNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Mockup", systemImage: "info.circle")
                .font(.footnote.weight(.semibold))
            Text("The card above is rendered in-app from the same pass.json that builds the real .pkpass. The bundled pass is unsigned — adding it to Apple Wallet needs a Pass Type ID certificate (paid Apple Developer Program).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func attemptAdd() {
        switch WalletPassLoader.loadBundledPass() {
        case .ready(let pass):
            passToAdd = IdentifiablePass(pass: pass)
        case .unsigned(let error):
            statusTitle = "Pass isn't signed yet"
            statusMessage = "Apple Wallet rejected the unsigned demo pass (\(error.domain) \(error.code)). Sign it with a Pass Type ID certificate to enable Add to Wallet. The card above is the in-app mockup."
            showStatus = true
        case .missing:
            statusTitle = "Pass not found"
            statusMessage = "WorldCupPass.pkpass isn't bundled. Run Pass/build-pass.sh, then rebuild."
            showStatus = true
        }
    }
}

// MARK: - Back-of-pass details (what Wallet shows on the flip side)

struct PassDetailsView: View {
    let doc: PassDocument

    var body: some View {
        if let backFields = doc.eventTicket.backFields, !backFields.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Ticket details")
                    .font(.headline)
                    .padding(.bottom, 8)
                ForEach(backFields) { field in
                    VStack(alignment: .leading, spacing: 2) {
                        if let label = field.label {
                            Text(label.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Text(field.displayValue)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    if field.id != backFields.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
