import SwiftUI

// MARK: - Modifier

extension View {
    /// Applies the current view as a mask over an underlying color fill that implicitly animates when the
    /// color changes with the specified `Animation`.
    ///
    /// This is especially useful for `Text` whose foreground color does not animate yet as of iOS 14.5.
    ///
    /// - parameter color:     The color to render.
    /// - parameter animation: The animation configuration to use to animate the color changes.
    ///
    /// - returns: A `View` whose fill color is animated when changed.
    func animatingColor(_ color: Color, animation: Animation = .default) -> some View {
        return AnimatableColorMask(color: color, animation: animation, makeView: { self })
    }
}

// MARK: - Implementation

private struct AnimatableColorMask<T: View>: View {
    let color: Color
    let animation: Animation
    let makeView: () -> T

    var body: some View {
        makeView()
            .opacity(0) // Don't actually render the original view, we only use it for layout.
            .overlay(
                Rectangle()
                    .foregroundColor(color) // Rectangles have an animatable foreground color.
                    .animation(animation, value: color) // Animate only when the color value changes.
                    .mask(makeView()) // Apply the original view as a mask.
            )
    }
}
