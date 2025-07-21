import SwiftUI

// MARK: - Page Selection View
struct PageSelectionView: View {
    @ObservedObject var viewModel: AppShellViewModel
    @State private var selectedCitations: Set<Int> = []
    @State private var selectedCover: Int?
    @State private var animateBackground = false

    var body: some View {
        // Break up the complex view into smaller components
        PageSelectionContent(
            viewModel: viewModel,
            selectedCitations: $selectedCitations,
            selectedCover: $selectedCover,
            animateBackground: $animateBackground
        )
    }
}

// Extract the content into a separate view to reduce complexity
struct PageSelectionContent: View {
    @ObservedObject var viewModel: AppShellViewModel
    @Binding var selectedCitations: Set<Int>
    @Binding var selectedCover: Int?
    @Binding var animateBackground: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Animated noisy background (TerminalNoiseBackground) is removed.
                // The view will now rely on the global window background for its base effects.

                VStack(spacing: DesignTokens.grid * 2) {
                    // Header section
                    headerSection(geo: geo)

                    // Instructions text
                    instructionsText(geo: geo)

                    // Thumbnails section
                    thumbnailsSection(geo: geo)

                    // Buttons section
                    buttonsSection(geo: geo)
                }
                .padding(DesignTokens.grid * 3)
                .background(
                    BrutalistVisualEffectView(
                        material: .hudWindow,
                        blendingMode: .withinWindow,
                        emphasized: false
                    )
                    .overlay(
                        Image("AccentTexture2")
                            .resizable()
                            .scaledToFill()
                            .opacity(0.4)
                            .blendMode(.multiply)
                            .allowsHitTesting(false)
                    )
                )
                .overlay(gradientBorder(geo: geo))
                .clipShape(UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCornersAlt, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.9)
                .rotation3DEffect(.degrees(1), axis: (x: 1, y: 0, z: 0))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - View Components

    private func headerSection(geo: GeometryProxy) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: { viewModel.selectedAppScene = .mainMenu }) {
                    Label {
                        Text("Back")
                            .font(.custom("HelveticaNeue-Bold", size: max(10, geo.size.width * 0.018)))
                            .foregroundStyle(Color.primary)
                            .textStroke(color: Color.primary, width: 1.2)
                            .lineSpacing(max(10, geo.size.width * 0.018) * -0.1)
                    } icon: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: max(10, geo.size.width * 0.018)))
                            .foregroundStyle(Color.primary)
                    }
                }
                .buttonStyle(AnimatedButtonStyle(scale: 1.1, intensity: 1.2, cornerRadius: 8))
                .padding(.leading)

                Spacer()

                // Completely rebuilt PDF button with direct ZStack approach
                ZStack {
                    // Background with border
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))

                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(DesignTokens.brutalistPrimary), lineWidth: 1.5)

                    // Content
                    HStack(spacing: 5) {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: max(14, geo.size.width * 0.022), weight: .bold))
                            .foregroundStyle(Color(DesignTokens.brutalistPrimary))

                        Text("PDF")
                            .font(.custom("HelveticaNeue-Bold", size: max(14, geo.size.width * 0.022)))
                            .tracking(2)
                            .foregroundStyle(Color(DesignTokens.brutalistPrimary))
                    }
                }
                .frame(width: max(80, geo.size.width * 0.08), height: max(36, geo.size.height * 0.04))
                .onTapGesture {
                    print("PDF button tap gesture triggered")
                    viewModel.selectedAppScene = .mainMenu
                }
                .padding(.trailing)
                .zIndex(100) // Ensure it's on top of other elements
                .accessibilityLabel("Return to main menu")
            }

            // Bold asymmetric header
            Text("SELECT PAGES")
                .font(.custom("HelveticaNeue-Bold", size: min(geo.size.width * 0.07, geo.size.height * 0.08)))
                .tracking(2)
                .foregroundStyle(.primary)
                .textStroke(color: .primary, width: 1.2)
                .lineSpacing(min(geo.size.width * 0.07, geo.size.height * 0.08) * -0.1)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 2, y: 2)
                .rotationEffect(.degrees(animateBackground ? 0 : -1))
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: animateBackground)
                .onAppear { animateBackground = true }
                .padding(.top, 10)
        }
    }

    private func instructionsText(geo: GeometryProxy) -> some View {
        Text("Tap to select/deselect citation pages. Long-press to set cover page.")
            .font(.custom("HelveticaNeue-Bold", size: max(9, geo.size.width * 0.015)))
            .foregroundColor(Color(DesignTokens.brutalistPrimary))
            .textStroke(color: Color(DesignTokens.brutalistPrimary), width: 1.2)
            .lineSpacing(max(9, geo.size.width * 0.015) * -0.1)
            .padding(.bottom, DesignTokens.grid)
    }

    private func thumbnailsSection(geo: GeometryProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            LazyHStack(spacing: DesignTokens.grid) {
                ForEach(0..<(viewModel.pdfDocument?.pageCount ?? 0), id: \.self) { idx in
                    OptimizedThumbnailView(
                        pageIndex: idx,
                        viewModel: viewModel,
                        selectedCitations: $selectedCitations,
                        selectedCover: $selectedCover,
                        geo: geo
                    )
                    .onAppear {
                        // Preload nearby thumbnails when this one appears
                        viewModel.preloadThumbnailsForViewport(startIndex: max(0, idx - 2), count: 5)
                    }
                }
            }
            .padding(10)
        }
        .padding(.horizontal)
        .background( // Reverted to BrutalistVisualEffectView with AccentTexture2
            BrutalistVisualEffectView(
                material: .hudWindow,
                blendingMode: .withinWindow,
                emphasized: false
            )
            .overlay(
                Image("AccentTexture2") // Changed to AccentTexture2
                    .resizable()
                    .scaledToFill()
                    .opacity(0.4) // Consistent opacity
                    .blendMode(.multiply) // Consistent blend mode
                    .allowsHitTesting(false)
            )
        )
        .clipShape(UnevenRoundedRectangle(cornerRadii: DesignTokens.asymmetricCornerRadius(topLeading: 16, topTrailing: 8, bottomTrailing: 16, bottomLeading: 8), style: .continuous))
    }

    // Legacy thumbnail view - kept for fallback
    private func thumbnailView(for idx: Int, image: NSImage, geo: GeometryProxy) -> some View {
        let panelFullWidth = geo.size.width
        let desiredThumbnailCount: CGFloat = 4.5
        // Estimate available width for thumbnails inside the scrollview, considering the 90% main panel and some padding
        let scrollContentWidth = panelFullWidth * 0.9 * 0.9 // Main panel is 90% of geo, estimate scrollview content is 90% of that
        let totalHStackSpacing = (desiredThumbnailCount - 1) * DesignTokens.grid
        let hstackPadding: CGFloat = 2 * 10 // HStack's own padding

        let thumbnailWidth = max(50, (scrollContentWidth - totalHStackSpacing - hstackPadding) / desiredThumbnailCount)
        let thumbnailHeight = thumbnailWidth * 1.4

        return VStack {
            Image(nsImage: image)
                .resizable()
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .cornerRadius(8)
                .overlay(thumbnailOverlay(for: idx))
                .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
                .accessibilityLabel("Page \(idx+1) thumbnail")
                .help(selectedCitations.contains(idx) ? "Citation page" : (selectedCover == idx ? "Cover page" : ""))
                .onTapGesture {
                    if selectedCitations.contains(idx) {
                        selectedCitations.remove(idx)
                    } else {
                        selectedCitations.insert(idx)
                    }
                }
                .onLongPressGesture {
                    if selectedCover == idx {
                        selectedCover = nil
                    } else {
                        selectedCover = idx
                    }
                }

            Text("Page \(idx+1)")
                .font(.custom("HelveticaNeue-Bold", size: max(9, geo.size.width * 0.015)))
                .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.8))
                .textStroke(color: Color(DesignTokens.brutalistPrimary).opacity(0.8), width: 1.2)
                .lineSpacing(max(9, geo.size.width * 0.015) * -0.1)
        }
        .padding(8)
        .background(
            BrutalistVisualEffectView(
                material: .hudWindow,
                blendingMode: .withinWindow,
                emphasized: false
            )
            .overlay(
                Image("AccentTexture2") // Changed to AccentTexture2
                    .resizable()
                    .scaledToFill()
                    .opacity(0.3) // Slightly less for thumbnails, or make it 0.4 for full consistency
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
            )
        )
        .clipShape(UnevenRoundedRectangle(cornerRadii: DesignTokens.asymmetricCornerRadius(topLeading: 8, topTrailing: 4, bottomTrailing: 8, bottomLeading: 4), style: .continuous))
    }

    private func thumbnailOverlay(for idx: Int) -> some View {
        let strokeColor: Color
        if selectedCitations.contains(idx) {
            strokeColor = Color(DesignTokens.brutalistPrimary)
        } else if selectedCover == idx {
            strokeColor = Color.blue
        } else {
            strokeColor = Color.clear
        }

        let lineWidth = selectedCitations.contains(idx) || selectedCover == idx ? 4.0 : 0.0

        return RoundedRectangle(cornerRadius: 8)
            .stroke(strokeColor, lineWidth: lineWidth)
    }

    private func buttonsSection(geo: GeometryProxy) -> some View {
        HStack(spacing: DesignTokens.grid) {
            Button(action: {
                if !selectedCitations.isEmpty, let cover = selectedCover {
                    viewModel.citationPageIndices = Array(selectedCitations)
                    viewModel.coverPageIndex = cover
                    viewModel.showPageSelection = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.showPreview = true
                    }
                }
            }) {
                Text("PREVIEW COMPOSITION")
                    .font(.custom("HelveticaNeue-Bold", size: max(10, geo.size.width * 0.018)))
                    .foregroundStyle(Color.primary)
                    .textStroke(color: Color.primary, width: 1.2)
                    .lineSpacing(max(10, geo.size.width * 0.018) * -0.1)
            }
            .buttonStyle(AnimatedButtonStyle(scale: 1.05, intensity: 1.3, cornerRadius: 8))
            .disabled(selectedCitations.isEmpty || selectedCover == nil)
            .accessibilityLabel("Preview Composition")

            Button("CANCEL") {
                viewModel.showPageSelection = false
                viewModel.selectedAppScene = .mainMenu
            }
            .font(.custom("HelveticaNeue-Bold", size: max(10, geo.size.width * 0.018)))
            .foregroundStyle(Color.primary)
            .textStroke(color: Color.primary, width: 1.2)
            .lineSpacing(max(10, geo.size.width * 0.018) * -0.1)
            .buttonStyle(AnimatedButtonStyle(scale: 1.05, intensity: 1.3, cornerRadius: 8))
        }
        .padding(.top, DesignTokens.grid)
    }

    private func gradientBorder(geo: GeometryProxy) -> some View {
        let gradientColors = [
            Color(DesignTokens.brutalistPrimary).opacity(0.5),
            Color(DesignTokens.brutalistPrimary).opacity(0.2),
            Color.clear,
            Color(DesignTokens.brutalistPrimary).opacity(0.2)
        ]

        return UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCornersAlt, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 2
            )
    }
}

// MARK: - Optimized Thumbnail View
struct OptimizedThumbnailView: View {
    let pageIndex: Int
    @ObservedObject var viewModel: AppShellViewModel
    @Binding var selectedCitations: Set<Int>
    @Binding var selectedCover: Int?
    let geo: GeometryProxy
    
    // Computed properties for performance
    private var isSelected: Bool {
        selectedCitations.contains(pageIndex)
    }
    
    private var isCover: Bool {
        selectedCover == pageIndex
    }
    
    private var isLoading: Bool {
        viewModel.isThumbnailLoading(pageIndex)
    }
    
    private var thumbnailSize: CGSize {
        let panelFullWidth = geo.size.width
        let desiredThumbnailCount: CGFloat = 4.5
        let scrollContentWidth = panelFullWidth * 0.9 * 0.9
        let totalHStackSpacing = (desiredThumbnailCount - 1) * DesignTokens.grid
        let hstackPadding: CGFloat = 2 * 10
        
        let thumbnailWidth = max(50, (scrollContentWidth - totalHStackSpacing - hstackPadding) / desiredThumbnailCount)
        let thumbnailHeight = thumbnailWidth * 1.4
        
        return CGSize(width: thumbnailWidth, height: thumbnailHeight)
    }
    
    var body: some View {
        VStack {
            thumbnailImageView
            thumbnailLabel
        }
        .padding(8)
        .background(thumbnailBackground)
        .clipShape(UnevenRoundedRectangle(
            cornerRadii: DesignTokens.asymmetricCornerRadius(
                topLeading: 8, 
                topTrailing: 4, 
                bottomTrailing: 8, 
                bottomLeading: 4
            ), 
            style: .continuous
        ))
    }
    
    private var thumbnailImageView: some View {
        Group {
            if let thumbnail = viewModel.getThumbnail(for: pageIndex) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .cornerRadius(8)
                    .overlay(thumbnailOverlay)
                    .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
            } else {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color(DesignTokens.brutalistPrimary))
                            } else {
                                Image(systemName: "doc.text")
                                    .font(.title2)
                                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
                            }
                        }
                    )
                    .overlay(thumbnailOverlay)
            }
        }
        .accessibilityLabel("Page \(pageIndex+1) thumbnail")
        .help(accessibilityHelpText)
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture {
            handleLongPress()
        }
    }
    
    private var thumbnailLabel: some View {
        Text("Page \(pageIndex+1)")
            .font(.custom("HelveticaNeue-Bold", size: max(9, geo.size.width * 0.015)))
            .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.8))
            .textStroke(color: Color(DesignTokens.brutalistPrimary).opacity(0.8), width: 1.2)
            .lineSpacing(max(9, geo.size.width * 0.015) * -0.1)
    }
    
    private var thumbnailBackground: some View {
        BrutalistVisualEffectView(
            material: .hudWindow,
            blendingMode: .withinWindow,
            emphasized: false
        )
        .overlay(
            Image("AccentTexture2")
                .resizable()
                .scaledToFill()
                .opacity(0.3)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        )
    }
    
    private var thumbnailOverlay: some View {
        let strokeColor: Color
        if isSelected {
            strokeColor = Color(DesignTokens.brutalistPrimary)
        } else if isCover {
            strokeColor = Color.blue
        } else {
            strokeColor = Color.clear
        }
        
        let lineWidth = (isSelected || isCover) ? 4.0 : 0.0
        
        return RoundedRectangle(cornerRadius: 8)
            .stroke(strokeColor, lineWidth: lineWidth)
    }
    
    private var accessibilityHelpText: String {
        if isSelected {
            return "Citation page"
        } else if isCover {
            return "Cover page"
        } else {
            return ""
        }
    }
    
    private func handleTap() {
        if isSelected {
            selectedCitations.remove(pageIndex)
        } else {
            selectedCitations.insert(pageIndex)
        }
    }
    
    private func handleLongPress() {
        if isCover {
            selectedCover = nil
        } else {
            selectedCover = pageIndex
        }
    }
}
