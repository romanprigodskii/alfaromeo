import SwiftUI

/// Motion tokens (docs/DESIGN.md §9): 150–250 ms, ease-out, motion only conveys state. No bounces.
/// The legacy spring names are kept for source compatibility and now resolve to ease-out curves.
enum Motion {
    // ── Durations (seconds) ──
    static let instant: Double = 0.12
    static let quick: Double = 0.18
    static let standard: Double = 0.25
    static let slow: Double = 0.35

    /// Ease-out (quart-like): fast start, soft landing.
    static func easeOut(_ duration: Double) -> Animation {
        .timingCurve(0.25, 1, 0.5, 1, duration: duration)
    }

    // ── Presets ──
    /// Small state changes: press, toggle, selection, value change.
    static let snappy = easeOut(0.18)
    /// Content and sheet transitions.
    static let smooth = easeOut(0.25)
    /// Legacy name. No bounces in this system; same as ``smooth``.
    static let bouncy = easeOut(0.25)
    /// Progress fills (goals / limits / GB).
    static let progress = easeOut(0.35)
}
