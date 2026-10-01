import SwiftUI

/// A static `fill` placeholder block for the loading state (§10.2 «скелетоны», DESIGN §5: skeletons
/// in `fill`, no shimmer).
struct SkeletonBlock: View {
    var height: CGFloat
    var width: CGFloat? = nil
    var radius: CGFloat = Radius.chip

    @Environment(\.theme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(theme.fill)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .accessibilityHidden(true)
    }
}

/// The dashboard skeleton: a low-fidelity echo of the loaded layout (§10.2).
struct HomeSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.sm) {           // balance hero + AI line
                SkeletonBlock(height: 15, width: 110)
                SkeletonBlock(height: 40, width: 220)
                SkeletonBlock(height: 15, width: 260)
            }
            VStack(alignment: .leading, spacing: Spacing.sm + 2) {      // cards shelf
                SkeletonBlock(height: 22, width: 90)
                SkeletonBlock(height: CardsCarousel.cardWidth / CardArt.aspectRatio,
                              width: CardsCarousel.cardWidth, radius: CardArt.cornerRadius)
            }
            VStack(alignment: .leading, spacing: Spacing.sm + 2) {      // accounts
                SkeletonBlock(height: 22, width: 90)
                GroupedSection {
                    SkeletonRow()
                    SkeletonRow()
                    SkeletonRow()
                }
            }
        }
    }
}
