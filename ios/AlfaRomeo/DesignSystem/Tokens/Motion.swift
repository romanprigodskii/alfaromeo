import SwiftUI

/// Motion tokens (§13.1) — restrained, premium. Durations + reusable spring presets.
enum Motion {
    // ── Durations (seconds) ──
    static let instant: Double = 0.12
    static let quick: Double = 0.2
    static let standard: Double = 0.32
    static let slow: Double = 0.5

    // ── Spring presets ──
    /// Snappy, low overshoot — buttons, toggles, small state changes.
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
    /// Smooth — sheet / content transitions.
    static let smooth = Animation.spring(response: 0.45, dampingFraction: 0.9)
    /// Bouncy — playful emphasis (use sparingly).
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.65)
    /// Progress fills (goals / limits / GB).
    static let progress = Animation.spring(response: 0.6, dampingFraction: 0.95)
}
