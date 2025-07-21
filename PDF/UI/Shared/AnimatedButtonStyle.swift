import SwiftUI

struct AnimatedButtonStyle: ButtonStyle {
    var scale: CGFloat = 1.05
    var intensity: CGFloat = 1.0
    var cornerRadius: CGFloat = 16
    var asymmetric: Bool = true
    var backgroundColor: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        ButtonStyleBody(
            configuration: configuration,
            scale: scale,
            intensity: intensity,
            cornerRadius: cornerRadius,
            asymmetric: asymmetric,
            backgroundColor: backgroundColor
        )
    }
}

// Separated implementation to avoid complex type-checking
private struct ButtonStyleBody: View {
    let configuration: ButtonStyle.Configuration
    let scale: CGFloat
    let intensity: CGFloat
    let cornerRadius: CGFloat
    let asymmetric: Bool
    let backgroundColor: Color?

    var body: some View {
        configuration.label
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(createBackground())
            .clipShape(createClipShape())
            .overlay(createBorderOverlay())
            // Transform effects
            .scaleEffect(configuration.isPressed ? 0.96 : scale)
            .rotationEffect(configuration.isPressed && asymmetric ? .degrees(-0.5) : .degrees(0))
            .offset(y: configuration.isPressed ? 2 * intensity : 0)
            // Shadows
            .shadow(
                color: applyShadowColor(),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 2 : 4
            )
            // Animation
            .animation(.spring(duration: 0.3, bounce: 0.7), value: configuration.isPressed)
    }

    // Helper to apply shadow color with proper opacity
    private func applyShadowColor() -> Color {
        let baseOpacity = configuration.isPressed ? 0.2 : 0.3
        let finalOpacity = baseOpacity * intensity
        return Color(DesignTokens.brutalistPrimary).opacity(finalOpacity)
    }

    // Create the background elements
    @ViewBuilder
    private func createBackground() -> some View {
        if let customColor = backgroundColor {
            // Use the custom background color if provided
            customColor
        } else {
            // Otherwise use the original complex background
            ZStack {
                // Base material - using transparent background instead of visual effect
                Color.black.opacity(0.1)

                // Color overlay using brutalist color scheme
                Color(DesignTokens.brutalistPrimary).opacity(configuration.isPressed ? 0.2 : 0.1)

                // Noise texture
                NoisyOverlay().opacity(0.15)

                // Bottom shadow for depth
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.0 : 0.1 * intensity))
                    .blur(radius: 4)
                    .offset(y: configuration.isPressed ? 0 : 4)
                    .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
    }

    // Create the clip shape - return a specific shape type instead of 'some Shape'
    private func createClipShape() -> AnyShape {
        if asymmetric {
            let shape = AsymmetricRoundedRectangle(cornerRadii: [
                .topLeading: cornerRadius * (configuration.isPressed ? 0.9 : 1.0),
                .topTrailing: cornerRadius * 0.7,
                .bottomLeading: cornerRadius * 0.8,
                .bottomTrailing: cornerRadius * (configuration.isPressed ? 0.7 : 1.1)
            ])
            return AnyShape(shape)
        } else {
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    // Create the border overlay
    @ViewBuilder
    private func createBorderOverlay() -> some View {
        Group {
            if asymmetric {
                AsymmetricRoundedRectangle(cornerRadii: [
                    .topLeading: cornerRadius * (configuration.isPressed ? 0.9 : 1.0),
                    .topTrailing: cornerRadius * 0.7,
                    .bottomLeading: cornerRadius * 0.8,
                    .bottomTrailing: cornerRadius * (configuration.isPressed ? 0.7 : 1.1)
                ])
                .stroke(
                    LinearGradient(
                        colors: createGradientColors(),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: configuration.isPressed ? 1.5 : 2
                )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: createGradientColors(),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: configuration.isPressed ? 1.5 : 2
                    )
            }
        }
    }

    // Create gradient colors for the border with appropriate opacity
    private func createGradientColors() -> [Color] {
        let whiteBaseOpacity = configuration.isPressed ? 0.3 : 0.6
        let accentBaseOpacity = configuration.isPressed ? 0.2 : 0.4
        let blackBaseOpacity = configuration.isPressed ? 0.1 : 0.2

        return [
            Color(DesignTokens.brutalistPrimary).opacity(whiteBaseOpacity * intensity),
            Color(DesignTokens.brutalistPrimary).opacity(accentBaseOpacity * intensity),
            Color.black.opacity(blackBaseOpacity * intensity)
        ]
    }
}

// Wrapper to convert any Shape to AnyShape
struct AnyShape: Shape, @unchecked Sendable {
    private let path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}

// Preview
#Preview {
    VStack(spacing: 20) {
        Button("Default") {}
            .buttonStyle(AnimatedButtonStyle(scale: 1.05, intensity: 1.0, cornerRadius: 16, asymmetric: true))

        Button("Intense") {}
            .buttonStyle(AnimatedButtonStyle(scale: 1.1, intensity: 1.5, cornerRadius: 16, asymmetric: true))

        Button("Symmetric") {}
            .buttonStyle(AnimatedButtonStyle(scale: 1.05, intensity: 1.0, cornerRadius: 16, asymmetric: false))

        Button("Sharp") {}
            .buttonStyle(AnimatedButtonStyle(scale: 1.05, intensity: 1.0, cornerRadius: 8, asymmetric: true))

        Button("Custom Background") {}
            .buttonStyle(AnimatedButtonStyle(scale: 1.05, intensity: 1.0, cornerRadius: 16, asymmetric: true, backgroundColor: .blue))
    }
    .padding(40)
    .background(
        LinearGradient(
            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}
