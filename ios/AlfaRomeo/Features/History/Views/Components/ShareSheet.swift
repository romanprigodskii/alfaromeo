import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A file ready to share, wrapped so `.sheet(item:)` can present the system share sheet (§9.4 «чек»,
/// «экспорт PDF/CSV» — открыть / сохранить / отправить). Identity is the file URL.
struct SharePayload: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}

#if canImport(UIKit)
/// Thin wrapper over `UIActivityViewController` — the real iOS share sheet (open in…, save to Files,
/// AirDrop, …). Presented via `.sheet(item:)` once a document has been generated.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
