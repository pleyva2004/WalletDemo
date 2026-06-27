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
            header
            strip
            fieldsSection
            Rectangle().fill(foreground.opacity(0.18)).frame(height: 1).padding(.horizontal)
            barcodeSection
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(foreground.opacity(0.12)))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }

    // MARK: Header — logo wordmark + the header field (GATE)

    private var header: some View {
        HStack(alignment: .top) {
            HStack(spacing: 8) {
                Image(systemName: "soccerball")
                    .font(.title3.bold())
                    .foregroundStyle(foreground)
                Text(doc.logoText ?? doc.organizationName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(foreground)
            }
            Spacer(minLength: 12)
            ForEach(doc.eventTicket.headerFields ?? []) { fieldColumn($0, fill: false) }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: Strip — green pitch with the two teams

    private var strip: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 24/255, green: 110/255, blue: 28/255),
                                    Color(red: 34/255, green: 139/255, blue: 34/255)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { geo in
                let radius = geo.size.height * 0.30
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                    path.addEllipse(in: CGRect(x: geo.size.width / 2 - radius, y: geo.size.height / 2 - radius,
                                               width: radius * 2, height: radius * 2))
                }
                .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
            }
            HStack(spacing: 8) {
                team(doc.eventTicket.primaryFields?.first)
                Text("VS").font(.headline.weight(.heavy)).foregroundStyle(.white.opacity(0.9))
                team(doc.eventTicket.primaryFields?.last)
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 118)
    }

    private func team(_ field: PassDocument.Field?) -> some View {
        VStack(spacing: 4) {
            Text(Self.flag(for: field?.value ?? "")).font(.system(size: 36))
            Text(field?.value ?? "—").font(.title.weight(.bold)).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Secondary + auxiliary field rows

    private var fieldsSection: some View {
        VStack(spacing: 14) {
            fieldRow(doc.eventTicket.secondaryFields)
            fieldRow(doc.eventTicket.auxiliaryFields)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func fieldRow(_ fields: [PassDocument.Field]?) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(fields ?? []) { fieldColumn($0) }
        }
    }

    private func fieldColumn(_ field: PassDocument.Field, fill: Bool = true) -> some View {
        VStack(alignment: field.hAlign, spacing: 2) {
            if let label = field.label, !label.isEmpty {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }
            Text(field.displayValue)
                .font(.callout.weight(.medium))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: fill ? .infinity : nil, alignment: field.frameAlign)
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
                        .frame(width: 148, height: 148)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if let altText = code.altText {
                    Text(altText)
                        .font(.caption2.monospaced())
                        .foregroundStyle(foreground.opacity(0.85))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: Flags

    private static func flag(for abbreviation: String) -> String {
        switch abbreviation.uppercased() {
        case "USA": return "🇺🇸"
        case "ARG": return "🇦🇷"
        case "MEX": return "🇲🇽"
        case "CAN": return "🇨🇦"
        case "BRA": return "🇧🇷"
        case "FRA": return "🇫🇷"
        case "ESP": return "🇪🇸"
        case "GER": return "🇩🇪"
        case "POR": return "🇵🇹"
        default: return "⚽️"
        }
    }
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
