import SwiftUI
import CoreImage.CIFilterBuiltins

/// Component #5 — renders a REAL QR code (CoreImage) on an intentionally white card so it stays scannable in any theme.
struct QRCodeView: View {
    @Environment(\.theme) private var theme

    let string: String
    var size: CGFloat = 220

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    private var qrImage: Image? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(decorative: cg, scale: 1, orientation: .up)
    }

    var body: some View {
        ZStack {
            if let qrImage {
                qrImage
                    .interpolation(.none)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "qrcode")
                        .font(.system(size: size * 0.32, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.35))
                    Text("QR недоступен")
                        .font(BrandFont.caption)
                        .foregroundStyle(Color.black.opacity(0.55))
                }
                .frame(width: size, height: size)
            }
        }
        .padding(Spacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("QR-код для оплаты")
    }
}

#Preview {
    QRCodeView_PreviewHost()
}

private struct QRCodeView_PreviewHost: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            QRCodeView(string: "https://alfa-romeo.uk/pay/INV-2035-0042?amount=149900")
            QRCodeView(string: "https://alfa-romeo.uk/pay/short", size: 140)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.default.background)
        .environment(\.theme, .default)
    }
}
