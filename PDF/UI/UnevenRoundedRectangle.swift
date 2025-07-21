import SwiftUI

struct UnevenRoundedRectangle: InsettableShape {
    var cornerRadii: [RectCorner: CGFloat]
    var style: RoundedCornerStyle = .continuous // Default to continuous

    // Helper to get radius for a specific corner, defaulting to 0
    private func radius(for corner: RectCorner) -> CGFloat {
        return cornerRadii[corner] ?? 0
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let tl = radius(for: .topLeading)
        let tr = radius(for: .topTrailing)
        let bl = radius(for: .bottomLeading)
        let br = radius(for: .bottomTrailing)

        // Ensure radii are not larger than half the min dimension of the rectangle side they are on
        let maxRadiusForWidth = rect.width / 2
        let maxRadiusForHeight = rect.height / 2

        let tlActual = min(tl, min(maxRadiusForWidth, maxRadiusForHeight))
        let trActual = min(tr, min(maxRadiusForWidth, maxRadiusForHeight))
        let blActual = min(bl, min(maxRadiusForWidth, maxRadiusForHeight))
        let brActual = min(br, min(maxRadiusForWidth, maxRadiusForHeight))

        // Prevent radii from overlapping if they are on the same side
        let topRadiiSum = tlActual + trActual
        let bottomRadiiSum = blActual + brActual
        let leftRadiiSum = tlActual + blActual
        let rightRadiiSum = trActual + brActual

        var scaleTop: CGFloat = 1.0
        var scaleBottom: CGFloat = 1.0
        var scaleLeft: CGFloat = 1.0
        var scaleRight: CGFloat = 1.0

        if topRadiiSum > rect.width { scaleTop = rect.width / topRadiiSum }
        if bottomRadiiSum > rect.width { scaleBottom = rect.width / bottomRadiiSum }
        if leftRadiiSum > rect.height { scaleLeft = rect.height / leftRadiiSum }
        if rightRadiiSum > rect.height { scaleRight = rect.height / rightRadiiSum }

        let tlScaled = tlActual * min(scaleTop, scaleLeft)
        let trScaled = trActual * min(scaleTop, scaleRight)
        let blScaled = blActual * min(scaleBottom, scaleLeft)
        let brScaled = brActual * min(scaleBottom, scaleRight)

        path.move(to: CGPoint(x: rect.minX + tlScaled, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - trScaled, y: rect.minY))
        path.addArc(center: CGPoint(x: rect.maxX - trScaled, y: rect.minY + trScaled), radius: trScaled, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - brScaled))
        path.addArc(center: CGPoint(x: rect.maxX - brScaled, y: rect.maxY - brScaled), radius: brScaled, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + blScaled, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + blScaled, y: rect.maxY - blScaled), radius: blScaled, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tlScaled))
        path.addArc(center: CGPoint(x: rect.minX + tlScaled, y: rect.minY + tlScaled), radius: tlScaled, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        path.closeSubpath()

        return path
    }

    // Implementation for InsettableShape
    func inset(by amount: CGFloat) -> some InsettableShape {
        var newRadii = cornerRadii
        newRadii[.topLeading] = max(0, (cornerRadii[.topLeading] ?? 0) - amount)
        newRadii[.topTrailing] = max(0, (cornerRadii[.topTrailing] ?? 0) - amount)
        newRadii[.bottomLeading] = max(0, (cornerRadii[.bottomLeading] ?? 0) - amount)
        newRadii[.bottomTrailing] = max(0, (cornerRadii[.bottomTrailing] ?? 0) - amount)
        return UnevenRoundedRectangle(cornerRadii: newRadii, style: self.style)
    }
}

#if DEBUG
struct UnevenRoundedRectangle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Using DesignTokens.brutalCorners:")
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.blue.opacity(0.7))
                .frame(width: 250, height: 120)
                .overlay(UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous).stroke(Color.black, lineWidth: 2))
                .overlay(Text("TL:\(String(format: "%.0f", DesignTokens.brutalCorners[.topLeading] ?? 0)) TR:\(String(format: "%.0f", DesignTokens.brutalCorners[.topTrailing] ?? 0))\\nBL:\(String(format: "%.0f", DesignTokens.brutalCorners[.bottomLeading] ?? 0)) BR:\(String(format: "%.0f", DesignTokens.brutalCorners[.bottomTrailing] ?? 0))").font(.caption).foregroundColor(.white))

            Text("Using DesignTokens.brutalCornersAlt:")
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCornersAlt, style: .continuous)
                .fill(Color.green.opacity(0.7))
                .frame(width: 250, height: 120)
                .overlay(UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCornersAlt, style: .continuous).stroke(Color.black, lineWidth: 2))


            Text("Custom Radii (Large):")
            UnevenRoundedRectangle(cornerRadii: [
                .topLeading: 60, .topTrailing: 10, .bottomLeading: 5, .bottomTrailing: 40
            ], style: .continuous)
            .fill(Color.orange.opacity(0.7))
            .frame(width: 250, height: 120)
            .overlay(UnevenRoundedRectangle(cornerRadii: [.topLeading: 60, .topTrailing: 10, .bottomLeading: 5, .bottomTrailing: 40], style: .continuous).stroke(Color.black, lineWidth: 2))

            Text("Radii larger than half side (should cap):")
            UnevenRoundedRectangle(cornerRadii: [
                .topLeading: 100, .topTrailing: 100, .bottomLeading: 20, .bottomTrailing: 20
            ], style: .continuous)
            .fill(Color.purple.opacity(0.7))
            .frame(width: 150, height: 80)
            .overlay(UnevenRoundedRectangle(cornerRadii: [.topLeading: 100, .topTrailing: 100, .bottomLeading: 20, .bottomTrailing: 20], style: .continuous).stroke(Color.black, lineWidth: 2))

        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
#endif
