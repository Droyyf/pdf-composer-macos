import SwiftUI

struct BrutalistTexture: View {
    enum TextureStyle: CaseIterable, Hashable {
        case noise
        case grain
        case analog
        case distressed
        case grid
    }

    var style: TextureStyle = .noise
    var intensity: CGFloat = 0.3
    var color: Color = .white
    var animated: Bool = false

    @State private var phase: CGFloat = 0

    var body: some View {
        ZStack {
            switch style {
            case .noise:
                noisePattern
            case .grain:
                grainPattern
            case .analog:
                analogPattern
            case .distressed:
                distressedPattern
            case .grid:
                gridPattern
            }
        }
        .blendMode(.overlay)
        .opacity(intensity)
        .onAppear {
            if animated {
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
        }
    }

    // Noise texture - random static pattern
    private var noisePattern: some View {
        Canvas { context, size in
            // Draw noise by placing tiny rectangles randomly
            context.opacity = 0.7

            for _ in 0..<Int(size.width * size.height / 40) {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let width = CGFloat.random(in: 0.5...1.5)
                let height = CGFloat.random(in: 0.5...1.5)

                let rect = CGRect(x: x, y: y, width: width, height: height)
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    // Film grain texture - more uniform noise
    private var grainPattern: some View {
        Canvas { context, size in
            // Create a grain effect with small dots in a semi-regular pattern
            context.opacity = 0.6

            let gridSize: CGFloat = 2

            for x in stride(from: 0, to: size.width, by: gridSize) {
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    if Bool.random() {
                        let randomOffset = CGFloat.random(in: -1...1)
                        let rect = CGRect(
                            x: x + randomOffset,
                            y: y + randomOffset,
                            width: Bool.random() ? 1 : 0.5,
                            height: Bool.random() ? 1 : 0.5
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }

    // Analog scan lines and artifacts
    private var analogPattern: some View {
        Canvas { context, size in
            // Horizontal scan lines
            for y in stride(from: 0, to: size.height, by: 3) {
                let path = Path(CGRect(x: 0, y: y, width: size.width, height: 0.8))
                context.opacity = CGFloat.random(in: 0.1...0.3)
                context.fill(path, with: .color(color))
            }

            // Random digital artifacts - larger blocks
            context.opacity = 0.5

            for _ in 0..<15 {
                let width = CGFloat.random(in: 5...20)
                let height = CGFloat.random(in: 1...3)
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)

                let rect = CGRect(x: x, y: y, width: width, height: height)
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    // Distressed texture - scratches and weathered look
    private var distressedPattern: some View {
        Canvas { context, size in
            context.opacity = 0.6

            // Draw random scratches
            for _ in 0..<30 {
                var path = Path()
                let startX = CGFloat.random(in: 0..<size.width)
                let startY = CGFloat.random(in: 0..<size.height)
                path.move(to: CGPoint(x: startX, y: startY))

                let length = CGFloat.random(in: 10...60)
                let angle = CGFloat.random(in: 0..<2 * .pi)
                let endX = startX + length * cos(angle)
                let endY = startY + length * sin(angle)

                path.addLine(to: CGPoint(x: endX, y: endY))

                context.stroke(path, with: .color(color), lineWidth: CGFloat.random(in: 0.3...0.8))
            }

            // Add some splotches for a weathered look
            for _ in 0..<20 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)
                let radius = CGFloat.random(in: 1...5)

                let blotch = Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius))
                context.opacity = CGFloat.random(in: 0.05...0.2)
                context.fill(blotch, with: .color(color))
            }
        }
    }

    // Grid/technical pattern
    private var gridPattern: some View {
        Canvas { context, size in
            context.opacity = 0.4

            // Main grid lines - vertical
            for x in stride(from: 0, to: size.width, by: 20) {
                let path = Path(CGRect(x: x, y: 0, width: 0.5, height: size.height))
                context.fill(path, with: .color(color))
            }

            // Main grid lines - horizontal
            for y in stride(from: 0, to: size.height, by: 20) {
                let path = Path(CGRect(x: 0, y: y, width: size.width, height: 0.5))
                context.fill(path, with: .color(color))
            }

            // Add some random technical markings
            for _ in 0..<10 {
                let x = CGFloat.random(in: 0..<size.width)
                let y = CGFloat.random(in: 0..<size.height)

                if Bool.random() {
                    // Crosshair
                    let crosshairPath = Path { path in
                        path.move(to: CGPoint(x: x - 5, y: y))
                        path.addLine(to: CGPoint(x: x + 5, y: y))
                        path.move(to: CGPoint(x: x, y: y - 5))
                        path.addLine(to: CGPoint(x: x, y: y + 5))
                    }
                    context.stroke(crosshairPath, with: .color(color), lineWidth: 0.5)
                } else {
                    // Circle marker
                    let circlePath = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                    context.stroke(circlePath, with: .color(color), lineWidth: 0.5)
                }
            }

            // Add rotation indicator based on phase (if animated)
            let rotationPath = Path { path in
                let center = CGPoint(x: size.width * 0.9, y: size.height * 0.1)
                let radius: CGFloat = 10

                path.addArc(center: center,
                           radius: radius,
                           startAngle: .degrees(0),
                           endAngle: .degrees(Double(phase)),
                           clockwise: false)
            }
            context.stroke(rotationPath, with: .color(color), lineWidth: 0.8)
        }
    }
}

// MARK: - Overlay textures to apply to other views
struct BrutalistTextureModifier: ViewModifier {
    var style: BrutalistTexture.TextureStyle
    var intensity: CGFloat
    var color: Color
    var animated: Bool

    func body(content: Content) -> some View {
        content.overlay(
            BrutalistTexture(
                style: style,
                intensity: intensity,
                color: color,
                animated: animated
            )
        )
    }
}

extension View {
    func brutalistTexture(
        style: BrutalistTexture.TextureStyle = .noise,
        intensity: CGFloat = 0.3,
        color: Color = .white,
        animated: Bool = false
    ) -> some View {
        self.modifier(BrutalistTextureModifier(
            style: style,
            intensity: intensity,
            color: color,
            animated: animated
        ))
    }
    
    /// Apply AccentTexture5 as an overlay with enhanced visibility
    func accentTexture5Overlay(intensity: CGFloat = 0.6, blendMode: BlendMode = .overlay) -> some View {
        self.overlay(
            Image("AccentTexture5")
                .resizable()
                .scaledToFill()
                .opacity(intensity)
                .blendMode(blendMode)
                .allowsHitTesting(false)
        )
    }
    
    /// Apply multiple texture layers for enhanced grain effect
    func enhancedGrainOverlay(intensity: CGFloat = 0.7) -> some View {
        self.overlay(
            ZStack {
                // Base AccentTexture5 with high visibility
                Image("AccentTexture5")
                    .resizable()
                    .scaledToFill()
                    .opacity(intensity * 0.8)
                    .blendMode(.overlay)
                
                // Additional texture layers for depth
                Image("AccentTexture4")
                    .resizable()
                    .scaledToFill()
                    .opacity(intensity * 0.3)
                    .blendMode(.softLight)
                
                // Programmatic grain for additional texture
                BrutalistTexture(style: .grain, intensity: intensity * 0.4, color: .white)
                    .blendMode(.overlay)
            }
            .allowsHitTesting(false)
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ForEach(BrutalistTexture.TextureStyle.allCases, id: \.self) { style in
            VStack {
                Text(String(describing: style).uppercased())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)

                Rectangle()
                    .fill(Color(DesignTokens.brutalistPrimary))
                    .frame(height: 100)
                    .brutalistTexture(
                        style: style,
                        intensity: 0.4,
                        color: .white,
                        animated: style == BrutalistTexture.TextureStyle.grid
                    )
                    .clipShape(UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous))
            }
        }
    }
    .padding()
    .background(Color(DesignTokens.brutalistBlack))
}
