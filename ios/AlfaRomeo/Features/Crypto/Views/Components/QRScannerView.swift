import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// QR-сканер адреса для «Отправить по QR» (§10.8). REAL AVFoundation capture on a device; on the
/// simulator (no camera) — or when camera access is denied — it falls back to a graceful panel
/// («вставить демо-адрес» / «из буфера»), so the send flow always completes.
///
/// Note: a real-device camera prompt also needs `NSCameraUsageDescription` in the app Info.plist —
/// that's an app-config key outside `Features/Crypto/`, so it's not set here. The simulator path never
/// requests authorization (the `targetEnvironment(simulator)` guard short-circuits first), so the demo
/// is crash-free; on device the usage string would be required for the live camera path.
struct QRScannerView: View {
    /// The asset being sent — used to offer a network-appropriate demo address in the fallback.
    let asset: String
    var onResult: (String) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private enum CamState { case checking, scanning, denied, unavailable }
    @State private var state: CamState = .checking
    @State private var pasteFailed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch state {
            case .checking:
                ProgressView().controlSize(.large).tint(.white)
            case .scanning:
                #if canImport(UIKit)
                CameraScanner { code in handle(code) }
                    .ignoresSafeArea()
                reticle
                #else
                fallback(reason: .unavailable)
                #endif
            case .denied:
                fallback(reason: .denied)
            case .unavailable:
                fallback(reason: .unavailable)
            }

            VStack {
                topBar
                Spacer()
            }
        }
        .task { await resolveState() }
    }

    // MARK: Camera-state resolution

    private func resolveState() async {
        #if targetEnvironment(simulator)
        state = .unavailable   // simulator has no camera — never touch authorization
        #else
        guard AVCaptureDevice.default(for: .video) != nil else { state = .unavailable; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state = .scanning
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            state = granted ? .scanning : .denied
        default:
            state = .denied
        }
        #endif
    }

    private func handle(_ raw: String) {
        let decoded = SendCryptoModel.decodeAddress(raw)
        guard !decoded.isEmpty else { return }
        onResult(decoded)
        dismiss()
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Text("Сканировать QR-адрес")
                .font(BrandFont.headline).foregroundStyle(.white)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26)).foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть")
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.md)
    }

    private var reticle: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(.white, lineWidth: 3)
                .frame(width: 230, height: 230)
                .shadow(radius: 8)
            Text("Наведите камеру на QR-код адреса")
                .font(BrandFont.callout).foregroundStyle(.white)
            Spacer()
        }
    }

    // MARK: Fallback (simulator / denied)

    private enum FallbackReason { case unavailable, denied }

    private func fallback(reason: FallbackReason) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: reason == .denied ? "camera.fill.badge.ellipsis" : "qrcode.viewfinder")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))

            VStack(spacing: Spacing.xs) {
                Text(reason == .denied ? "Нет доступа к камере" : "Камера недоступна")
                    .font(BrandFont.title).foregroundStyle(.white)
                Text(reason == .denied
                     ? "Разрешите доступ к камере в Настройках или вставьте адрес вручную."
                     : "На симуляторе нет камеры. Вставьте адрес из буфера или подставьте демо-адрес для проверки потока.")
                    .font(BrandFont.callout).foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Spacing.screen)

            VStack(spacing: Spacing.sm) {
                Button { pasteFromClipboard() } label: {
                    label("Вставить из буфера", "doc.on.clipboard")
                }
                Button { onResult(demoAddress); dismiss() } label: {
                    label("Подставить демо-адрес", "wand.and.stars")
                }
            }
            .padding(.horizontal, Spacing.screen)

            if pasteFailed {
                Text("В буфере нет похожего на адрес текста.")
                    .font(BrandFont.caption).foregroundStyle(theme.warning)
            }
        }
        .padding(Spacing.screen)
    }

    private func label(_ title: String, _ icon: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(title).font(BrandFont.callout.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private func pasteFromClipboard() {
        #if canImport(UIKit)
        let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let decoded = SendCryptoModel.decodeAddress(clip)
        if decoded.count >= 8 {
            onResult(decoded)
            dismiss()
        } else {
            withAnimation { pasteFailed = true }
        }
        #else
        withAnimation { pasteFailed = true }
        #endif
    }

    /// A network-appropriate placeholder address for the fallback (mock — not a real wallet).
    private var demoAddress: String {
        switch asset.uppercased() {
        case "BTC":  return "bc1q9yh8d0sx3qr0m7v2lk4e6m9c3a1b2c3d4e5f6"
        case "TON":  return "EQByaR3minzb4vWZ7r0M1n2o3p4Q5r6S7t8U9v0W1xYz2aB"
        default:     return "0x71C7656EC7ab88b098defB751B7401B5f6d8976F" // EVM (ETH/USDT/USDC/…)
        }
    }
}

#if canImport(UIKit)

/// AVFoundation QR capture surface (device only). Reads `.qr` metadata and reports the first code.
private struct CameraScanner: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCode = onCode
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: (String) -> Void = { _ in }

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "crypto.qr.session")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var handled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        sessionQueue.async { [weak self] in self?.session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !handled,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        handled = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        onCode(value)
    }
}

#endif
