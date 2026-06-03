import SwiftUI

/// A pulsing placeholder block for the loading state (§10.2 «скелетоны»). Respects Reduce Motion.
struct SkeletonBlock: View {
    var height: CGFloat
    var width: CGFloat? = nil
    var radius: CGFloat = Radius.md

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(theme.elevated)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(pulsing ? 0.5 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// The dashboard skeleton — a low-fidelity echo of the loaded layout (§10.2).
struct HomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            SkeletonBlock(height: 44, radius: Radius.lg)            // AI insight line
            SkeletonBlock(height: 116)                              // balance hero
            block(titleWidth: 120, body: 184, bodyRadius: Radius.lg) // cards carousel
            block(titleWidth: 90,  body: 132)                       // accounts
            block(titleWidth: 150, body: 96)                        // crypto
        }
    }

    private func block(titleWidth: CGFloat, body: CGFloat, bodyRadius: CGFloat = Radius.md) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SkeletonBlock(height: 22, width: titleWidth)
            SkeletonBlock(height: body, radius: bodyRadius)
        }
    }
}
