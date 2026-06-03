import SwiftUI
import CoreImage.CIFilterBuiltins
#if canImport(UIKit)
import UIKit
#endif

/// Принять крипту (§9.6): адрес / QR / «запросить у контакта», с выбором сети. The address is the
/// profile's custodial wallet address (mock); a real QR is generated from it. Receiving is free and
/// available on every tier.
struct ReceiveCryptoView: View {
    @Environment(\.theme) private var theme
    @State private var store = CryptoStore.shared
    @State private var network: CryptoNetwork?
    @State private var copied = false
    @State private var requested = false
    @State private var showRequest = false

    let asset: String

    init(asset: String?) { self.asset = (asset ?? "BTC").uppercased() }

    private var networks: [CryptoNetwork] { CryptoCatalog.networks(for: asset) }
    private var address: String {
        store.bankWallet(asset: asset)?.address ?? "ro_\(asset.lowercased())_demo_a1b2c3d4e5"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.md) {
                    AssetGlyph(symbol: asset, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Принять \(asset)").font(BrandFont.headline).foregroundStyle(theme.textPrimary)
                        Text("Сеть: \(network?.name ?? networks.first?.name ?? "")").font(BrandFont.caption).foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                qrCard

                NetworkFeePicker(networks: networks, selected: $network)

                SecondaryButton(title: copied ? "Адрес скопирован" : "Скопировать адрес",
                                icon: copied ? "checkmark" : "doc.on.doc") {
                    copyAddress()
                }
                Button { showRequest = true } label: {
                    Label(requested ? "Запрос отправлен · ещё раз" : "Запросить у контакта", systemImage: requested ? "checkmark.circle" : "person.crop.circle.badge.plus")
                        .font(BrandFont.callout.weight(.medium))
                        .foregroundStyle(requested ? theme.success : (theme.accentCrypto.first ?? theme.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)
        }
        .background(theme.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        .navigationTitle("Принять")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if network == nil { network = networks.first } }
        .sheet(isPresented: $showRequest) {
            RequestCryptoSheet(asset: asset, address: address) { _, _ in requested = true }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(theme.background)
        }
    }

    private var qrCard: some View {
        SurfaceCard {
            VStack(spacing: Spacing.md) {
                qrImage
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .padding(Spacing.sm)
                    .background(.white, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                Text(address)
                    .font(BrandFont.mono(13))
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, Spacing.md)
                Text("Отправляйте только \(asset) в сети \(network?.name ?? "")")
                    .font(BrandFont.micro).foregroundStyle(theme.warning)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var qrImage: Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(address.utf8)
        if let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
           let cg = context.createCGImage(output, from: output.extent) {
            #if canImport(UIKit)
            return Image(uiImage: UIImage(cgImage: cg))
            #else
            return Image(systemName: "qrcode")
            #endif
        }
        return Image(systemName: "qrcode")
    }

    private func copyAddress() {
        #if canImport(UIKit)
        UIPasteboard.general.string = address
        #endif
        withAnimation { copied = true }
    }
}

#Preview {
    NavigationStack {
        ReceiveCryptoView(asset: "BTC")
            .environment(\.theme, .default)
    }
}
