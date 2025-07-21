import SwiftUI
// Import other modules if needed for ColorExtensions

enum DesignTokens {
    // Original colors
    static let bg900 = Color(hex: "#0E0E0E")
    static let fg100 = Color(hex: "#F2F2F2")
    static let accent = Color(hex: "#7EFF5A")

    // Updated color scheme as requested
    static let brutalistBlack = Color(hex: "#000000") // Pure black background as in reference image
    static let brutalistWhite = Color(hex: "#FFFFFF")
    static let brutalistPrimary = Color(hex: "#c5879b") // Main color from user's request
    static let brutalistSecondary = Color(hex: "#d4d4d4") // Secondary color from user's request
    static let brutalistAccent = Color(hex: "#c5879b") // Same as primary for consistency
    static let brutalistGray = Color(hex: "#333541") // Keeping original dark gray for other elements

    // Opacity settings for transparent UI
    static let backgroundOpacity: CGFloat = 0.8 // 80% opacity as requested
    static let windowVibrancyLevel: CGFloat = 0.7
    static let noiseIntensity: CGFloat = 0.4

    // Radii - brutalist designs often use sharp corners or mix of rounded and sharp
    static let radiusSm: CGFloat = 6
    static let radiusLg: CGFloat = 12
    static let radiusXL: CGFloat = 24        // For large container elements
    static let radiusAsymmetric: [CGFloat] = [3, 16, 6, 0] // For asymmetric corners [TL, TR, BR, BL]

    // Spacing grid - now with asymmetric options
    static let grid: CGFloat = 8
    static let gridLarge: CGFloat = 16
    static let gridXL: CGFloat = 24
    static let gridXXL: CGFloat = 40
    static let gridAsymmetric: [CGFloat] = [8, 24, 12, 16] // Uneven spacing values [top, right, bottom, left]

    // Typography
    static let interFont = "Inter Variable"
    static let soehneMonoFont = "Söhne Mono Variable"
    static let brutalistDisplayFont = "Helvetica Neue"

    // Font weights - brutalist often uses very bold or very light weights
    static let fontWeightUltra: Font.Weight = .black
    static let fontWeightHeavy: Font.Weight = .heavy
    static let fontWeightLight: Font.Weight = .light

    // Font sizes for brutalist typography
    static let fontSizeXS: CGFloat = 12
    static let fontSizeSM: CGFloat = 16
    static let fontSizeMD: CGFloat = 20
    static let fontSizeLG: CGFloat = 28
    static let fontSizeXL: CGFloat = 38
    static let fontSizeXXL: CGFloat = 60

    // Line heights for brutalist typography (often extreme)
    static let lineHeightTight: CGFloat = 0.9
    static let lineHeightNormal: CGFloat = 1.2
    static let lineHeightWide: CGFloat = 1.5

    // Border widths - brutalist often uses thick borders
    static let borderWidthThin: CGFloat = 1
    static let borderWidthMedium: CGFloat = 2
    static let borderWidthThick: CGFloat = 4
    static let borderWidthExtraThick: CGFloat = 8

    // Shadow values for brutalist depth
    static let shadowOffsetLarge = CGSize(width: 8, height: 8)
    static let shadowRadiusSharp: CGFloat = 0
    static let shadowRadiusSmooth: CGFloat = 15

    // Animation durations - brutalist can use both fast and slow animations
    static let durationFast: Double = 0.2
    static let durationNormal: Double = 0.4
    static let durationSlow: Double = 0.8

    // Brutalist spring animations
    static let springSnappy = Spring(response: 0.3, dampingRatio: 0.7)
    static let springBouncy = Spring(response: 0.5, dampingRatio: 0.4)
    static let springSmooth = Spring(response: 0.6, dampingRatio: 0.8)
    static let springSharp = Spring(response: 0.2, dampingRatio: 1.0)
    
    // Animation curves for common UI interactions
    static let cardTapAnimation = Animation.spring(springSnappy)
    static let navigationAnimation = Animation.spring(springSmooth)
    static let loadingAnimation = Animation.easeInOut(duration: durationNormal)
    static let errorAnimation = Animation.spring(springBouncy)
    
    // Accessibility
    static let minimumTouchTarget: CGFloat = 44 // Apple's minimum touch target
    static let accessibilityScaleFactor: CGFloat = 1.2 // For larger text sizes
    
    // Responsive Design Breakpoints
    static let compactWidth: CGFloat = 600
    static let regularWidth: CGFloat = 900
    static let compactHeight: CGFloat = 700
    static let regularHeight: CGFloat = 1000
    
    // Dynamic spacing based on screen size
    static func responsiveSpacing(for size: CGSize, base: CGFloat = grid) -> CGFloat {
        let area = size.width * size.height
        let scaleFactor = min(max(area / 640000, 0.8), 1.5) // Scale between 0.8x and 1.5x
        return base * scaleFactor
    }
    
    // Dynamic font sizing
    static func responsiveFontSize(for size: CGSize, base: CGFloat) -> CGFloat {
        let minDimension = min(size.width, size.height)
        let scaleFactor = min(max(minDimension / 600, 0.8), 1.4)
        return base * scaleFactor
    }

    // Layout constants
    static let containerMaxWidth: CGFloat = 1200

    // Helper function for asymmetric corner radius
    static func asymmetricCornerRadius(topLeading: CGFloat = 0, topTrailing: CGFloat = 0,
                                       bottomTrailing: CGFloat = 0, bottomLeading: CGFloat = 0) -> [RectCorner: CGFloat] {
        return [
            .topLeading: topLeading,
            .topTrailing: topTrailing,
            .bottomTrailing: bottomTrailing,
            .bottomLeading: bottomLeading
        ]
    }
    
    // Responsive layout configuration - ensures consistent layout regardless of window size
    static func layoutConfiguration(for geometry: GeometryProxy) -> ResponsiveLayout {
        // Never allow stacking - always maintain side-by-side layout for bottom cards
        let isCompact = false // Force non-compact behavior to maintain layout structure
        return ResponsiveLayout(
            isCompact: isCompact,
            cardSpacing: max(responsiveSpacing(for: geometry.size, base: grid), 8),
            sectionPadding: max(responsiveSpacing(for: geometry.size, base: gridLarge), 12),
            titleSize: max(responsiveFontSize(for: geometry.size, base: fontSizeXL), 20),
            bodySize: max(responsiveFontSize(for: geometry.size, base: fontSizeMD), 14)
        )
    }
    
    // Brutalist presets
    static let brutalCorners = asymmetricCornerRadius(topLeading: 24, topTrailing: 4, bottomTrailing: 24, bottomLeading: 0)
    static let brutalCornersAlt = asymmetricCornerRadius(topLeading: 0, topTrailing: 20, bottomTrailing: 0, bottomLeading: 20)
}

// MARK: - Responsive Layout Configuration
struct ResponsiveLayout {
    let isCompact: Bool
    let cardSpacing: CGFloat
    let sectionPadding: CGFloat
    let titleSize: CGFloat
    let bodySize: CGFloat
    
    var cardHeight: (main: CGFloat, secondary: CGFloat) {
        // Fixed card heights that scale with window size but maintain proportions
        return (main: 200, secondary: 160)
    }
    
    var shouldStackCards: Bool {
        // Never stack cards - always maintain side-by-side layout
        return false
    }
}

// Additional brutalist text styles
extension Text {
    func brutalistHeading() -> some View {
        self.font(.system(size: DesignTokens.fontSizeXL, weight: DesignTokens.fontWeightUltra))
            .tracking(2)
            .lineSpacing(DesignTokens.lineHeightTight)
    }

    func brutalistTitle() -> some View {
        self.font(.system(size: DesignTokens.fontSizeLG, weight: DesignTokens.fontWeightHeavy))
            .tracking(1)
            .lineSpacing(DesignTokens.lineHeightNormal)
    }

    func brutalistBody() -> some View {
        self.font(.system(size: DesignTokens.fontSizeMD, weight: DesignTokens.fontWeightLight))
            .tracking(0.5)
            .lineSpacing(DesignTokens.lineHeightWide)
    }

    func brutalistMono() -> some View {
        self.font(.system(size: DesignTokens.fontSizeSM, weight: .regular, design: .monospaced))
            .tracking(0)
    }
}

// Asymmetric padding extension
extension View {
    func asymmetricPadding(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) -> some View {
        self
            .padding(.top, top)
            .padding(.leading, leading)
            .padding(.bottom, bottom)
            .padding(.trailing, trailing)
    }

    func brutalistPadding() -> some View {
        self.asymmetricPadding(
            top: DesignTokens.gridAsymmetric[0],
            leading: DesignTokens.gridAsymmetric[3],
            bottom: DesignTokens.gridAsymmetric[2],
            trailing: DesignTokens.gridAsymmetric[1]
        )
    }
}
