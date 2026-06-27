import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - The in-app mock pass card (styled like an Apple Wallet eventTicket)

struct PassCardView: View {
    let doc: PassDocument

    private var background: Color { Color(passRGB: doc.backgroundColor, fallback: Color(red: 11/255, green: 38/255, blue: 80/255)) }
    private var foreground: Color { Color(passRGB: doc.foregroundColor, fallback: .white) }
    private var labelColor: Color { Color(passRGB: doc.labelColor, fallback: Color(red: 214/255, green: 178/255, blue: 92/255)) }

    var body: some View {
        VStack(spacing: 0) {
            hero
            lowerContent
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(foreground.opacity(0.12)))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }

    // Fields + barcode on opaque navy, pulled up a hair to cover the hero's bottom edge
    // so no anti-aliased hairline shows at the seam.
    private var lowerContent: some View {
        VStack(spacing: 0) {
            fieldsSection
            Rectangle().fill(foreground.opacity(0.18)).frame(height: 1).padding(.horizontal)
            barcodeSection
        }
        .frame(maxWidth: .infinity)
        .background(background)
        .padding(.top, -1.5)
    }

    // MARK: Hero — the supplied match-day artwork (tap branding + teams baked in)

    private var hero: some View {
        Group {
            if let art = HeroArt.image {
                Image(uiImage: art)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Color(red: 0.10, green: 0.20, blue: 0.62).frame(height: 150)
            }
        }
        .frame(maxWidth: .infinity)
        // Round only the top corners (to match the card); the cropped bottom edge sits flush
        // against the fields section. Matches the card's 18pt continuous corner.
        .clipShape(.rect(topLeadingRadius: 18, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 18, style: .continuous))
    }

    // MARK: Field rows (GATE + MATCH/KICKOFF, then SECTION/ROW/SEAT)

    private var fieldsSection: some View {
        VStack(spacing: 14) {
            fieldRow(doc.eventTicket.secondaryFields)
            fieldRow((doc.eventTicket.headerFields ?? []) + (doc.eventTicket.auxiliaryFields ?? []))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func fieldRow(_ fields: [PassDocument.Field]?) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(fields ?? []) { fieldColumn($0) }
        }
    }

    private func fieldColumn(_ field: PassDocument.Field) -> some View {
        VStack(alignment: field.hAlign, spacing: 3) {
            if let label = field.label, !label.isEmpty {
                Text(label.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }
            Text(field.displayValue)
                .font(.title3.weight(.semibold))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: field.frameAlign)
    }

    // MARK: Barcode

    private var barcodeSection: some View {
        VStack(spacing: 8) {
            if let code = doc.barcodes?.first {
                if let image = QRCode.image(from: code.message) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if let altText = code.altText {
                    Text(altText)
                        .font(.caption.monospaced())
                        .foregroundStyle(foreground.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

// MARK: - Bundled match-day artwork (the supplied logo/hero image)

enum HeroArt {
    static let image: UIImage? = {
        guard let url = Bundle.main.url(forResource: "match-hero", withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()
}

// MARK: - QR code generation (CoreImage, no external dependency)

enum QRCode {
    private static let context = CIContext() // expensive to build; reuse across calls

    static func image(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
