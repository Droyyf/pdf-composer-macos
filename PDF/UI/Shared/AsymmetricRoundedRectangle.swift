import SwiftUI

/// A custom shape that supports different corner radii for each corner
public enum RectCorner: CaseIterable, Sendable {
    case topLeading
    case topTrailing
    case bottomTrailing
    case bottomLeading
}

/// A rounded rectangle shape with customizable corner radii for each corner
public struct AsymmetricRoundedRectangle: Shape, Sendable {
    private let cornerRadii: [RectCorner: CGFloat]

    /// Initialize with a dictionary of corner radii
    /// - Parameter cornerRadii: Dictionary mapping corners to their radius values
    public init(cornerRadii: [RectCorner: CGFloat]) {
        self.cornerRadii = cornerRadii
    }

    /// Create a rounded rectangle with the same radius for all corners
    /// - Parameter radius: The corner radius to apply to all corners
    public init(radius: CGFloat) {
        var radii = [RectCorner: CGFloat]()
        for corner in RectCorner.allCases {
            radii[corner] = radius
        }
        self.cornerRadii = radii
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        // Get radius for each corner, defaulting to 0 if not specified
        let topLeadingRadius = cornerRadii[.topLeading] ?? 0
        let topTrailingRadius = cornerRadii[.topTrailing] ?? 0
        let bottomTrailingRadius = cornerRadii[.bottomTrailing] ?? 0
        let bottomLeadingRadius = cornerRadii[.bottomLeading] ?? 0

        // Start from top-left (top-leading) corner
        path.move(to: CGPoint(x: rect.minX + topLeadingRadius, y: rect.minY))

        // Top edge and top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - topTrailingRadius, y: rect.minY))
        if topTrailingRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - topTrailingRadius, y: rect.minY + topTrailingRadius),
                radius: topTrailingRadius,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
        }

        // Right edge and bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailingRadius))
        if bottomTrailingRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomTrailingRadius, y: rect.maxY - bottomTrailingRadius),
                radius: bottomTrailingRadius,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
        }

        // Bottom edge and bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + bottomLeadingRadius, y: rect.maxY))
        if bottomLeadingRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeadingRadius, y: rect.maxY - bottomLeadingRadius),
                radius: bottomLeadingRadius,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
        }

        // Left edge and back to top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeadingRadius))
        if topLeadingRadius > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + topLeadingRadius, y: rect.minY + topLeadingRadius),
                radius: topLeadingRadius,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 20) {
        // Regular rounded rectangle
        AsymmetricRoundedRectangle(radius: 15)
            .fill(Color.blue)
            .frame(width: 200, height: 100)
            .overlay(Text("Equal Corners").foregroundColor(.white))

        // Asymmetric rounded rectangle
        AsymmetricRoundedRectangle(cornerRadii: [
            .topLeading: 30,
            .topTrailing: 0,
            .bottomTrailing: 20,
            .bottomLeading: 5
        ])
        .fill(Color.red)
        .frame(width: 200, height: 100)
        .overlay(Text("Asymmetric Corners").foregroundColor(.white))

        // Brutalist style
        AsymmetricRoundedRectangle(cornerRadii: [
            .topLeading: 40,
            .topTrailing: 0,
            .bottomTrailing: 40,
            .bottomLeading: 0
        ])
        .stroke(LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ), lineWidth: 3)
        .background(
            AsymmetricRoundedRectangle(cornerRadii: [
                .topLeading: 40,
                .topTrailing: 0,
                .bottomTrailing: 40,
                .bottomLeading: 0
            ])
            .fill(Color.black)
        )
        .frame(width: 200, height: 100)
        .overlay(Text("Brutalist Style").foregroundColor(.white))
    }
    .padding()
}
