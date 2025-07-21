import SwiftUI

// MARK: - Text Stroke Modifier

struct TextStrokeModifier: ViewModifier {
    let color: Color
    let width: CGFloat

    func body(content: Content) -> some View {
        ZStack {
            // Create 8 offset copies of the text for a thicker stroke
            // Diagonal offsets
            let diagonalOffset = width / 2.0 // Adjusted for a more accurate visual stroke width
            // Cardinal offsets (slightly more than diagonal for a rounder feel)
            let cardinalOffset = width * 0.65 // Experiment with this factor

            content.offset(x:  diagonalOffset, y:  diagonalOffset).foregroundColor(color)
            content.offset(x: -diagonalOffset, y: -diagonalOffset).foregroundColor(color)
            content.offset(x:  diagonalOffset, y: -diagonalOffset).foregroundColor(color)
            content.offset(x: -diagonalOffset, y:  diagonalOffset).foregroundColor(color)

            // Cardinal offsets
            content.offset(x:  cardinalOffset, y:  0).foregroundColor(color)
            content.offset(x: -cardinalOffset, y:  0).foregroundColor(color)
            content.offset(x:  0, y:  cardinalOffset).foregroundColor(color)
            content.offset(x:  0, y: -cardinalOffset).foregroundColor(color)

            // Original text on top
            content
        }
    }
}

extension View {
    func textStroke(color: Color, width: CGFloat) -> some View {
        self.modifier(TextStrokeModifier(color: color, width: width))
    }
}
