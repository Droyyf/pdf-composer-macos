import SwiftUI

struct GlassBackground: ViewModifier {
    var intensity: CGFloat = 0.5
    var cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base transparent layer instead of glass - increased opacity
                    Color.black.opacity(intensity * 0.15)

                    // Noise overlay for texture - increased opacity
                    NoisyOverlay().opacity(intensity * 0.4)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                // Top highlight gradient using brutalist color scheme
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(DesignTokens.brutalistPrimary).opacity(intensity * 0.7),
                                Color(DesignTokens.brutalistPrimary).opacity(intensity * 0.3),
                                Color(DesignTokens.brutalistPrimary).opacity(0),
                                Color(DesignTokens.brutalistPrimary).opacity(intensity * 0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(
                color: .black.opacity(intensity * 0.25),
                radius: 16,
                x: 0,
                y: 8
            )
            // Inner shadow for depth
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                    .stroke(Color.black.opacity(intensity * 0.1), lineWidth: 1)
                    .blur(radius: 4)
                    .offset(y: 2)
                    .mask(
                        RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous)
                            .fill(LinearGradient(
                                colors: [.clear, .black.opacity(intensity * 0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 1, style: .continuous))
            )
    }
}

extension View {
    func glassBackground(intensity: CGFloat = 0.5, cornerRadius: CGFloat = 24) -> some View {
        self.modifier(GlassBackground(intensity: intensity, cornerRadius: cornerRadius))
    }
}

// Preview
#Preview {
    VStack {
        Text("Regular Glass")
            .font(.title)
            .padding(40)
            .glassBackground()

        Text("Intense Glass")
            .font(.title)
            .padding(40)
            .glassBackground(intensity: 0.8)

        Text("Subtle Glass")
            .font(.title)
            .padding(40)
            .glassBackground(intensity: 0.3)
    }
    .padding(50)
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
}
