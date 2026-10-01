import CoreGraphics

/// Spacing scale (docs/DESIGN.md §4).
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48

    /// Screen side margin.
    static let screen: CGFloat = 16
    /// Vertical gap between sections on a screen.
    static let section: CGFloat = 28
    /// Vertical padding inside a list row.
    static let rowVertical: CGFloat = 12
    /// Minimum list row height (single line).
    static let rowMinHeight: CGFloat = 52
    /// Minimum list row height with a subtitle.
    static let rowMinHeightTwoLine: CGFloat = 60
}

/// Corner-radius tokens (docs/DESIGN.md §4): card/section 16, button 14, input 12, chip 8,
/// avatar/glyph circle = full (use `Circle()`).
enum Radius {
    static let xs: CGFloat = 6
    /// Chips, badges, small tiles.
    static let sm: CGFloat = 8
    /// Buttons.
    static let md: CGFloat = 14
    /// Cards and grouped sections.
    static let lg: CGFloat = 16
    /// Large floating surfaces (rare).
    static let xl: CGFloat = 20
    static let pill: CGFloat = 999

    // Named aliases
    static let chip: CGFloat = 8
    static let input: CGFloat = 12
    static let button: CGFloat = 14
    static let card: CGFloat = 16
    static let section: CGFloat = 16
}
