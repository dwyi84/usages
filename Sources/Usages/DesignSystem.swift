import SwiftUI

/// Shared visual language for the popover.
///
/// CopyNinja and NightOwl deliberately leave the root SwiftUI view transparent
/// so the native `NSPopover` vibrancy (the blurred desktop behind the popover)
/// shows through. Cards are then painted with low-opacity, theme-aware fills
/// instead of opaque `NSColor` surfaces. This file keeps those values in one
/// place so every card, tile and panel stays consistent.
public enum DS {
    public enum Spacing {
        public static let xxs: CGFloat = 2
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
    }
    
    public enum Radius {
        public static let pill: CGFloat = 6
        public static let tile: CGFloat = 8
        public static let card: CGFloat = 12
    }
    
    public enum Font {
        public static let brand = SwiftUI.Font.system(size: 13.5, weight: .semibold, design: .rounded)
        public static let meta = SwiftUI.Font.system(size: 9.5, weight: .regular)
        public static let cardTitle = SwiftUI.Font.system(size: 12.5, weight: .semibold)
        public static let section = SwiftUI.Font.system(size: 10, weight: .semibold)
        public static let label = SwiftUI.Font.system(size: 10.5, weight: .medium)
        public static let value = SwiftUI.Font.system(size: 10.5, weight: .semibold, design: .monospaced)
        public static let micro = SwiftUI.Font.system(size: 9, weight: .regular)
        public static let microStrong = SwiftUI.Font.system(size: 9, weight: .semibold)
    }
    
    public static var cardFill: Color { Color.primary.opacity(0.02) }
    public static var tileFill: Color { Color.primary.opacity(0.05) }
    public static var stroke: Color { Color.primary.opacity(0.14) }
    public static var subtleStroke: Color { Color.primary.opacity(0.10) }
    public static var separator: Color { Color.primary.opacity(0.14) }
    public static var track: Color { Color.primary.opacity(0.14) }
    public static var textSecondary: Color { Color.primary.opacity(0.66) }
    public static var textTertiary: Color { Color.primary.opacity(0.48) }
}

// MARK: - View modifiers

private struct GlassCardModifier: ViewModifier {
    let radius: CGFloat
    let fill: Color
    let stroke: Color
    let shadow: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.thinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 0.75)
            )
            .shadow(
                color: shadow ? Color.black.opacity(0.04) : .clear,
                radius: 10,
                x: 0,
                y: 3
            )
    }
}

private struct GlassTileModifier: ViewModifier {
    let radius: CGFloat
    let fill: Color
    let stroke: Color
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 0.6)
            )
    }
}

public extension View {
    /// Outer provider card: translucent, gently elevated, rounded.
    func glassCard(
        radius: CGFloat = DS.Radius.card,
        fill: Color = DS.cardFill,
        stroke: Color = DS.stroke,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassCardModifier(radius: radius, fill: fill, stroke: stroke, shadow: shadow))
    }
    
    /// Inner panel/tile inside a card: flatter, quieter.
    func glassTile(
        radius: CGFloat = DS.Radius.tile,
        fill: Color = DS.tileFill,
        stroke: Color = DS.subtleStroke
    ) -> some View {
        modifier(GlassTileModifier(radius: radius, fill: fill, stroke: stroke))
    }
    
    func dsPill() -> some View {
        self
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .glassTile(radius: DS.Radius.pill)
    }
}

struct SoftDivider: View {
    var body: some View {
        Rectangle()
            .fill(DS.separator)
            .frame(height: 0.75)
    }
}
