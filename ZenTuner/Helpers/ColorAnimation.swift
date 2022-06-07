import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

// MARK: - Modifier

extension View {
    /// Applies a foreground color modifier that supports animating between the `from` and `to` colors, blending with
    /// them according to the `percentToColor` value, where `0` is the `from` color and `1` is the `to` color.
    ///
    /// This is especially useful for `Text` whose foreground color which only became animatable in iOS 16 & macOS 13.
    ///
    /// - parameter from:           The color to render when `percentToColor` is `0`.
    /// - parameter to:             The color to render when `percentToColor` is `1`.
    /// - parameter percentToColor: The percentage of the `to` color to blend.
    ///
    /// - returns: A `View` whose foreground color is animated when changed.
    @available(iOS, deprecated: 16)
    @available(macOS, deprecated: 13)
    @available(watchOS, deprecated: 9)
    func animatingForegroundColor(from: Color, to: Color, percentToColor: Double) -> some View {
        return self
            .modifier(ColorAnimation(from: from, to: to, percentToColor: percentToColor))
    }
}

// MARK: - Implementation

// From https://gist.github.com/mattyoung/52947aff8524ed3c86d6ebd695dcfc86
private struct ColorAnimation: AnimatableModifier {
    var animatableData: Double
    private let rgbaPair: [(Double, Double)]

    init(from: Color, to: Color, percentToColor: Double) {
        animatableData = percentToColor
        let fromComponents = PlatformColor(from).cgColor.components!
        let toComponents = PlatformColor(to).cgColor.components!
        rgbaPair = Array(zip(fromComponents.map(Double.init), toComponents.map(Double.init)))
    }

    func body(content: Content) -> some View {
        content
            .foregroundColor(mixedColor)
    }

    // This is a very basic implementation of a color interpolation between two values.
    private var mixedColor: Color {
        let rgba = rgbaPair.map { $0.0 + ($0.1 - $0.0) * animatableData }
        return Color(red: rgba[0], green: rgba[1], blue: rgba[2], opacity: rgba[3])
    }
}
