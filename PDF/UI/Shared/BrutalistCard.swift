import SwiftUI

struct BrutalistCard: View {
    var title: String
    var subtitle: String?
    var accent: Color = Color(DesignTokens.brutalistPrimary)
    var image: Image?
    var cornerStyle: BrutalistCornerStyle = .asymmetric

    enum BrutalistCornerStyle {
        case sharp
        case asymmetric
        case technical

        var cornerRadii: [RectCorner: CGFloat] {
            switch self {
            case .sharp:
                return DesignTokens.asymmetricCornerRadius(topLeading: 0, topTrailing: 0, bottomTrailing: 0, bottomLeading: 0)
            case .asymmetric:
                return DesignTokens.brutalCorners
            case .technical:
                return DesignTokens.asymmetricCornerRadius(topLeading: 12, topTrailing: 0, bottomTrailing: 4, bottomLeading: 16)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with technical markings
            HStack {
                Text(title)
                    .font(.custom(DesignTokens.brutalistDisplayFont, size: DesignTokens.fontSizeMD))
                    .fontWeight(.heavy)
                    .tracking(1.2)
                    .textStroke(color: accent.opacity(0.7), width: 0.8)
                    .foregroundColor(accent)

                Spacer()

                // Technical decorative elements
                HStack(spacing: 4) {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                    Text("333")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(accent)
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 10))
                        .foregroundColor(accent)
                }
            }
            .padding(.horizontal, DesignTokens.grid * 2)
            .padding(.top, DesignTokens.grid * 2)
            .padding(.bottom, DesignTokens.grid)

            // Divider line
            Rectangle()
                .fill(accent.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, DesignTokens.grid)

            // Content area
            ZStack(alignment: .bottomLeading) {
                if let image = image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(minHeight: 120)
                        .clipped()
                        // Noise overlay
                        .overlay(
                            NoisyOverlay(intensity: 0.2)
                        )
                }

                // Grid overlay
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(accent.opacity(0.3))
                                .frame(width: 1, height: 6)
                        }
                    }

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.top, 4)
                    }
                }
                .padding(DesignTokens.grid * 1.5)
            }

            // Technical footer
            HStack(spacing: DesignTokens.grid) {
                ForEach(["P.1", "///", "BCR"], id: \.self) { label in
                    Text(label)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(accent.opacity(0.8))
                }

                Spacer()

                Text("HATE BY LOVE")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(accent.opacity(0.8))
            }
            .padding(.horizontal, DesignTokens.grid * 2)
            .padding(.vertical, DesignTokens.grid)
        }
        .background(Color(DesignTokens.brutalistBlack))
        .clipShape(UnevenRoundedRectangle(cornerRadii: cornerStyle.cornerRadii, style: .continuous))
        .overlay(
            UnevenRoundedRectangle(cornerRadii: cornerStyle.cornerRadii, style: .continuous)
                .strokeBorder(accent.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        BrutalistCard(
            title: "FIGHT",
            subtitle: "Digital display status",
            image: Image(systemName: "eye.fill")
        )
        .frame(height: 240)

        BrutalistCard(
            title: "CLEAR INTENT",
            subtitle: "Visual data",
            accent: Color.orange,
            cornerStyle: .technical
        )
        .frame(height: 180)

        BrutalistCard(
            title: "BRUTALIST",
            subtitle: "System interface",
            accent: Color(DesignTokens.brutalistPrimary),
            cornerStyle: .sharp
        )
        .frame(height: 160)
    }
    .padding()
    .background(Color(DesignTokens.bg900))
}
