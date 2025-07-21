import SwiftUI

// MARK: - Image Loading State
@MainActor
class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading = false
    @Published var loadingError: String?
    
    private static let cache = NSCache<NSString, NSImage>()
    
    func loadImage(named imageName: String) {
        let key = NSString(string: imageName)
        
        // Check cache first
        if let cachedImage = Self.cache.object(forKey: key) {
            self.image = cachedImage
            return
        }
        
        // Load from bundle
        isLoading = true
        Task {
            if let bundleImage = NSImage(named: imageName) {
                await MainActor.run {
                    Self.cache.setObject(bundleImage, forKey: key)
                    self.image = bundleImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.loadingError = "Failed to load image: \(imageName)"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Card Configuration
struct CardConfiguration {
    let height: CGFloat
    let iconSize: CGFloat
    let titleSize: CGFloat
    let padding: CGFloat
    let borderWidth: CGFloat
    
    static func responsive(height: CGFloat) -> CardConfiguration {
        return CardConfiguration(
            height: height,
            iconSize: min(height * 0.2, 30),
            titleSize: min(height * 0.15, 22),
            padding: min(height * 0.1, 15),
            borderWidth: 2
        )
    }
}

// MARK: - Reusable Card View for the Main Menu
struct MenuCardView: View {
    let imageName: String
    let title: String
    let iconName: String
    let action: () -> Void
    var isDisabled: Bool = false
    var isLoading: Bool = false
    var enableHover: Bool = true
    let height: CGFloat
    let geo: GeometryProxy
    var titleFontSize: CGFloat?
    var iconFontSize: CGFloat?
    
    @StateObject private var imageLoader = ImageLoader()
    @State private var isPressed = false
    @State private var animateOnAppear = false
    @State private var isHovered = false
    
    private let borderColor = Color(hex: "c5879b")
    private let config: CardConfiguration
    
    init(imageName: String, title: String, iconName: String, action: @escaping () -> Void, isDisabled: Bool = false, isLoading: Bool = false, enableHover: Bool = true, height: CGFloat, geo: GeometryProxy, titleFontSize: CGFloat? = nil, iconFontSize: CGFloat? = nil) {
        self.imageName = imageName
        self.title = title
        self.iconName = iconName
        self.action = action
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.enableHover = enableHover
        self.height = height
        self.geo = geo
        self.titleFontSize = titleFontSize
        self.iconFontSize = iconFontSize
        self.config = CardConfiguration.responsive(height: height)
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack(alignment: .bottomLeading) {
                // Optimized image loading with fallback
                imageView
                    .frame(height: height)
                    .clipped()
                    .overlay(duotoneOverlay)
                    .overlay(contrastOverlay)
                    .overlay(hoverOverlay)
                    .overlay(loadingOverlay)

                // Card content
                cardContent
                    .padding(config.padding)
            }
            .frame(height: height)
            .background(DesignTokens.brutalistGray)
            .cornerRadius(4)
            .overlay(borderOverlay)
            .brutalistTexture(style: .noise, intensity: 0.35, color: .white)
            .shadow(
                color: DesignTokens.brutalistBlack.opacity(isPressed ? 0.3 : (isHovered && enableHover ? 0.7 : 0.5)),
                radius: isPressed ? 4 : (isHovered && enableHover ? 12 : 8),
                x: isPressed ? 2 : (isHovered && enableHover ? 6 : 4),
                y: isPressed ? 2 : (isHovered && enableHover ? 6 : 4)
            )
            .scaleEffect(isPressed ? 0.98 : (isHovered && enableHover ? 1.02 : 1.0))
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .animation(DesignTokens.cardTapAnimation, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
        .scaleEffect(animateOnAppear ? 1.0 : 0.9)
        .opacity(animateOnAppear ? 1.0 : 0.0)
        .onAppear {
            imageLoader.loadImage(named: imageName)
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.1)) {
                animateOnAppear = true
            }
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            if enableHover {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Computed Properties
    
    private var accessibilityLabelText: String {
        if isLoading {
            return "\(title) - Loading"
        } else {
            return title
        }
    }
    
    private var accessibilityHintText: String {
        if isLoading {
            return "Please wait, processing your request"
        } else {
            return "Tap to \(title.lowercased())"
        }
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        guard !isLoading else { return }
        
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        #endif
        
        action()
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var imageView: some View {
        Group {
            if imageLoader.isLoading {
                loadingPlaceholder
            } else if let image = imageLoader.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                errorPlaceholder
            }
        }
    }
    
    @ViewBuilder
    private var loadingPlaceholder: some View {
        Rectangle()
            .foregroundColor(DesignTokens.brutalistGray)
            .overlay(
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: borderColor))
                    .scaleEffect(0.8)
            )
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if isLoading {
            Rectangle()
                .foregroundColor(DesignTokens.brutalistBlack.opacity(0.4))
                .overlay(
                    VStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignTokens.brutalistWhite))
                            .scaleEffect(1.2)
                        
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(DesignTokens.brutalistWhite)
                            .fontWeight(.medium)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .animation(DesignTokens.loadingAnimation, value: isLoading)
        }
    }
    
    @ViewBuilder
    private var errorPlaceholder: some View {
        Rectangle()
            .foregroundColor(DesignTokens.brutalistGray.opacity(0.3))
            .overlay(
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .light))
                        .foregroundColor(DesignTokens.brutalistSecondary.opacity(0.6))
                    Text("No Image")
                        .font(.caption2)
                        .foregroundColor(DesignTokens.brutalistSecondary.opacity(0.6))
                }
            )
    }
    
    @ViewBuilder
    private var duotoneOverlay: some View {
        Color(hex: "c5879b")
            .opacity(0.65)
            .blendMode(.multiply)
    }
    
    @ViewBuilder
    private var contrastOverlay: some View {
        Color.black.opacity(0.2)
    }
    
    @ViewBuilder
    private var hoverOverlay: some View {
        if isHovered && enableHover {
            Color(hex: "c5879b")
                .opacity(0.15)
                .blendMode(.overlay)
                .transition(.opacity)
        }
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: geo.size.height * 0.01) {
            Image(systemName: iconName)
                .font(.system(size: iconFontSize ?? config.iconSize, weight: .bold))
                .foregroundColor(DesignTokens.brutalistSecondary.opacity(0.9))

            Text(title)
                .font(.custom("HelveticaNeue-Bold", size: titleFontSize ?? config.titleSize))
                .foregroundColor(DesignTokens.brutalistWhite)
                .textStroke(color: DesignTokens.brutalistBlack.opacity(0.5), width: 0.5)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
    }
    
    @ViewBuilder
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(borderColor, lineWidth: (isHovered && enableHover) ? config.borderWidth + 1 : config.borderWidth)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// The Color extension has been moved to ColorExtensions.swift

#if DEBUG
// Preview for MenuCardView (optional, but good for isolation)
struct MenuCardView_Previews: PreviewProvider {
    static var previews: some View {
        GeometryReader { geoProxy in
            VStack(spacing: 20) {
                MenuCardView(
                    imageName: "poster_image_panel_1",
                    title: "SAMPLE CARD",
                    iconName: "star.fill",
                    action: { print("Card Tapped") },
                    height: 200,
                    geo: geoProxy
                )
                
                MenuCardView(
                    imageName: "invalid_image_name",
                    title: "ERROR STATE CARD",
                    iconName: "exclamationmark.triangle",
                    action: { print("Error Card Tapped") },
                    isDisabled: true,
                    height: 150,
                    geo: geoProxy
                )
                
                MenuCardView(
                    imageName: "poster_image_panel_3",
                    title: "CUSTOM SIZED FONT CARD",
                    iconName: "heart.fill",
                    action: { print("Custom Card Tapped") },
                    height: 150,
                    geo: geoProxy,
                    titleFontSize: 28,
                    iconFontSize: 32
                )
            }
            .padding()
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
    }
}
#endif
