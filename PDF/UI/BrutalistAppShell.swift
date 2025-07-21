import SwiftUI
import PDFKit

/// A wrapper view that applies brutalist design principles to the main app
struct BrutalistAppShell: View {
    @ObservedObject var viewModel: AppShellViewModel
    @State private var showFileImporter = false
    @State private var currentPageIndex: Int = 0
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @State private var selectedCitations: Set<Int> = []
    @State private var selectedCover: Int? = nil
    @State private var isPageSelectionMode: Bool = true

    var body: some View {
        ZStack {
            // Black background for grain to render on
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Brutalist header bar
                brutalistHeader

                // Main content area
                ZStack {
                    if viewModel.pdfDocument == nil && !viewModel.isLoading {
                        // No PDF loaded state
                        emptyState
                    } else if viewModel.isLoading {
                        // Loading state
                        loadingState
                    } else {
                        // PDF viewing state
                        mainPDFView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Toast notifications
            if showToast {
                VStack {
                    Spacer()

                    HStack {
                        Text(toastMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.4), lineWidth: 1)
                                    )
                                    .brutalistTexture(style: .grain, intensity: 0.2, color: .white)
                            )
                    }
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    loadPDF(from: url)
                }
            case .failure(let error):
                showToastMessage("Error: \(error.localizedDescription)")
            }
        }
    }

    // Brutalist header view
    private var brutalistHeader: some View {
        VStack(spacing: 0) {
            // Main header bar
            HStack {
                // Logo/Title as a clickable button to return to main menu
                Button {
                    withAnimation {
                        viewModel.selectedAppScene = .mainMenu
                    }
                } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))

                    BrutalistHeading(
                        text: "PDF",
                        size: 22,
                        color: Color(DesignTokens.brutalistPrimary),
                        tracking: 1.5,
                        addStroke: true,
                        strokeWidth: 0.8
                    )
                }
                    .contentShape(Rectangle()) // Make entire area clickable
                }
                .buttonStyle(PlainButtonStyle()) // Use plain style to maintain appearance
                .help("Return to Main Menu") // Add tooltip

                Spacer()

                // Controls
                HStack(spacing: 16) {
                    Button {
                        // Removed selection mode toggle button
                    } label: {
                        // Removed selection mode toggle button
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.pdfDocument == nil)

                    Button {
                        showFileImporter = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))

                            Text("OPEN PDF")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
            )

            // Technical line with metadata
            HStack {
                if viewModel.pdfDocument != nil {
                    BrutalistTechnicalText(
                        text: "PAGES: \(viewModel.pdfDocument?.pageCount ?? 0)",
                        color: Color(DesignTokens.brutalistPrimary).opacity(0.6),
                        size: 10
                    )

                    Spacer()

                    // Always show selection mode caption
                    BrutalistCaption(
                        text: "CITATIONS: \(selectedCitations.count) | COVER: \(selectedCover != nil ? "\(selectedCover! + 1)" : "NONE")",
                        prefix: "◆",
                        color: Color(DesignTokens.brutalistPrimary).opacity(0.8),
                        size: 10
                    )

                    Spacer()

                    // Always show apply selection button
                    if selectedCitations.count > 0 && selectedCover != nil {
                        Button {
                            viewModel.citationPageIndices = Array(selectedCitations)
                            viewModel.coverPageIndex = selectedCover
                            viewModel.showPreview = true
                            viewModel.selectedAppScene = .preview
                            showToastMessage("Pages selected successfully!")
                        } label: {
                            Text("APPLY SELECTION")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
            .frame(height: 22)
            .padding(.horizontal, 20)
            .background(Color.black.opacity(0.7))
        }
    }

    // Placeholder for poster-style icons and text (can be shared or redefined if different)
    private let posterSubElements: [(String?, String?, String?)] = [
        ("globe", "BCR.", nil),
        (nil, "—", nil),
        ("plus.circle.fill", "STATUS", "sun.max.fill") // Changed SPHERE to STATUS for context
    ]
    private let posterRightText = "SYSTEM IDLE"

    // Empty state view with brutalist "FIGHT" poster design
    private var emptyState: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Dominant Title Area (Pink Background)
                ZStack(alignment: .bottomLeading) {
                    DesignTokens.brutalistPrimary // Main pink color
                        .edgesIgnoringSafeArea(.top) // Extend to top edge if header is not opaque

                    VStack(alignment: .leading, spacing: 0) {
                        Text("NO PDF") // Main title
                            .font(.custom("Helvetica Black Original", size: min(geo.size.width * 0.30, geo.size.height * 0.25)))
                            .tracking(min(geo.size.width * -0.02, -8))
                            .lineSpacing(min(geo.size.width * -0.04, -15))
                            .foregroundColor(DesignTokens.brutalistBlack)
                            .padding(.leading, geo.size.width * 0.05)
                            .padding(.bottom, geo.size.height * 0.01) // Reduced bottom padding
                            .offset(y: geo.size.height * 0.02)

                        HStack(alignment: .center, spacing: geo.size.width * 0.02) {
                            ForEach(0..<posterSubElements.count, id: \.self) { index in
                                HStack(spacing: geo.size.width * 0.01) {
                                    if let icon1 = posterSubElements[index].0 {
                                        Image(systemName: icon1)
                                            .font(.system(size: min(geo.size.width * 0.025, 16), weight: .semibold))
                                            .foregroundColor(DesignTokens.brutalistBlack)
                                    }
                                    if let text = posterSubElements[index].1 {
                                        Text(text)
                                            .font(.custom("HelveticaNeue-Bold", size: min(geo.size.width * 0.025, 16)))
                                            .tracking(1)
                                            .foregroundColor(DesignTokens.brutalistBlack)
                                    }
                                    if let icon2 = posterSubElements[index].2 {
                                        Image(systemName: icon2)
                                            .font(.system(size: min(geo.size.width * 0.025, 16), weight: .semibold))
                                            .foregroundColor(DesignTokens.brutalistBlack)
                                    }
                                }
                            }
                            Spacer()
                            Text(posterRightText)
                                .font(.custom("HelveticaNeue-Bold", size: min(geo.size.width * 0.025, 16)))
                                .tracking(2)
                                .foregroundColor(DesignTokens.brutalistBlack)
                        }
                        .padding(.horizontal, geo.size.width * 0.05)
                        .padding(.bottom, geo.size.height * 0.03) // Increased bottom padding for separation
                    }
                }
                .frame(height: geo.size.height * 0.35) // Adjusted height for title area

                // Content Area (Black Background)
                ZStack {
                    // Color.black is already set by the parent ZStack in body
                    VStack(spacing: geo.size.height * 0.05) {
                        Spacer() // Pushes content down a bit

                        // Single Call-to-Action Card
                        MenuCardView(
                            imageName: "poster_image_panel_1", // Using one of the poster images
                            title: "OPEN PDF DOCUMENT",
                            iconName: "doc.badge.plus", // More relevant icon
                            action: {
                showFileImporter = true
                            },
                            height: geo.size.height * 0.28, // Make card reasonably large
                            geo: geo,
                            titleFontSize: min(geo.size.height * 0.28 * 0.18, 28), // Larger title for single card
                            iconFontSize: min(geo.size.height * 0.28 * 0.22, 36) // Larger icon for single card
                        )
                        .padding(.horizontal, geo.size.width * 0.1)

            BrutalistTechnicalText(
                            text: "PDF VIEWER IDLE // WAITING FOR INPUT",
                            color: DesignTokens.brutalistPrimary.opacity(0.6),
                            size: min(geo.size.width * 0.02, 12),
                addDecorators: true,
                align: .center
            )
                        .padding(.horizontal)

                        Spacer() // Pushes content up a bit
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: geo.size.height * 0.65) // Adjusted height for content area
            }
        }
    }

    // Loading state with brutalist design
    private var loadingState: some View {
        VStack(spacing: 24) {
            // Animated logo
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 40))
                .foregroundColor(Color(DesignTokens.brutalistPrimary))
                .rotationEffect(.degrees(Double.random(in: -5...5)))
                .animation(.easeInOut(duration: 2).repeatForever(), value: UUID())

            BrutalistTechnicalText(
                text: "LOADING PDF DOCUMENT",
                color: Color(DesignTokens.brutalistPrimary),
                size: 16,
                addDecorators: true,
                align: .center
            )

            // Progress indicator
            if let progress = viewModel.pdfLoadingProgress {
                VStack(spacing: 8) {
                    // Progress bar
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(height: 16)

                        Rectangle()
                            .fill(Color(DesignTokens.brutalistPrimary))
                            .frame(width: CGFloat(progress) * 300, height: 16)
                    }
                    .frame(width: 300)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                    )

                    // Percentage text
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
            } else {
                // Indeterminate loading
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color(DesignTokens.brutalistPrimary))
                            .frame(width: 8, height: 8)
                            .opacity(0.3 + Double(i) * 0.2)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(i) * 0.2),
                                value: UUID()
                            )
                    }
                }
            }

            BrutalistCaption(
                text: "PLEASE WAIT",
                prefix: "///",
                color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                size: 10
            )
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(
            Color.black.opacity(0.5)
                .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
        )
    }

    // Main PDF view with brutalist styling
    private var mainPDFView: some View {
        HStack(spacing: 0) {
            // Sidebar with thumbnails
            VStack(spacing: 0) {
                // Sidebar header
                HStack {
                    BrutalistTechnicalText(
                        text: "SELECT PAGES",
                        color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                        size: 12,
                        addDecorators: true
                    )

                    Spacer()

                    Text("\(viewModel.thumbnails.count)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.4))

                // Thumbnails list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(0..<viewModel.thumbnails.count, id: \.self) { index in
                            ThumbnailView(
                                index: index,
                                currentPage: $currentPageIndex,
                                document: viewModel.pdfDocument,
                                selectionMode: true,
                                isCitationSelected: selectedCitations.contains(index),
                                isCoverSelected: selectedCover == index,
                                viewModel: viewModel,
                                onPageTap: { selectedPage in
                                    handlePageSelection(pageIndex: selectedPage)
                                },
                                onCitationToggle: { selectedPage in
                                    toggleCitation(pageIndex: selectedPage)
                                },
                                onCoverToggle: { selectedPage in
                                    toggleCover(pageIndex: selectedPage)
                                }
                            )
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(8)
                }
            }
            .frame(width: 180)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
            )

            // Main PDF display
            ZStack {
                // PDF view
                if let document = viewModel.pdfDocument {
                    BrutalistPDFKitView(document: document, currentPage: $currentPageIndex)
                        .onChange(of: currentPageIndex) { _, _ in
                            // Optional haptic feedback when changing pages
                            #if os(macOS)
                            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                            #endif
                        }
                }
            }
            .background(Color.black.opacity(0.2))
        }
    }

    // Helper function to load PDF with error handling
    private func loadPDF(from url: URL) {
        Task {
            do {
                print("DEBUG: BrutalistAppShell - Starting PDF load from \(url.lastPathComponent)")

                // Ensure loading state is visible immediately
                await MainActor.run {
                    viewModel.isLoading = true
                    viewModel.selectedAppScene = .loading
                    print("DEBUG: BrutalistAppShell - Set loading state")
                }

                try await viewModel.loadPDF(from: url)

                await MainActor.run {
                    currentPageIndex = 0
                    showToastMessage("PDF loaded successfully")
                    print("DEBUG: BrutalistAppShell - PDF loaded successfully")
                }
            } catch {
                await MainActor.run {
                    showToastMessage("Error: \(error.localizedDescription)")
                    print("DEBUG: BrutalistAppShell - Failed to load PDF: \(error)")
                }
            }
        }
    }

    // Helper function to display toast messages
    private func showToastMessage(_ message: String) {
        withAnimation {
            toastMessage = message
            showToast = true
        }
    }

    // Handle page selection
    private func handlePageSelection(pageIndex: Int) {
        // In selection mode, we don't navigate but select pages
        return
    }

    // Toggle citation selection
    private func toggleCitation(pageIndex: Int) {
        if selectedCitations.contains(pageIndex) {
            selectedCitations.remove(pageIndex)
        } else {
            selectedCitations.insert(pageIndex)
        }
    }

    // Toggle cover selection
    private func toggleCover(pageIndex: Int) {
        if selectedCover == pageIndex {
            selectedCover = nil
        } else {
            selectedCover = pageIndex
        }
    }
}

// PDF Kit wrapper for SwiftUI
struct BrutalistPDFKitView: NSViewRepresentable {
    var document: PDFDocument
    @Binding var currentPage: Int

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.displayDirection = .horizontal
        pdfView.delegate = context.coordinator

        // Set initial page
        if let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update document if needed
        if pdfView.document != document {
            pdfView.document = document
        }

        // Update current page if changed externally
        if let page = document.page(at: currentPage), pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PDFViewDelegate {
        var parent: BrutalistPDFKitView

        init(_ parent: BrutalistPDFKitView) {
            self.parent = parent
        }

        func pdfViewPageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }

            let pageIndex = document.index(for: currentPage)

            // Update binding
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
    }
}

// MARK: - Async Thumbnail Image Component
struct AsyncThumbnailImage<Content: View, Placeholder: View, Failure: View>: View {
    let pageIndex: Int
    let page: PDFPage
    let thumbnailService: ThumbnailService
    let targetSize: CGSize
    let content: (NSImage) -> Content
    let placeholder: () -> Placeholder
    let failure: (Error) -> Failure
    
    @State private var image: NSImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Group {
            if let image = image {
                content(image)
            } else if let error = error {
                failure(error)
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: pageIndex) { oldValue, newValue in
            if oldValue != newValue {
                loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() {
        guard !isLoading else { return }
        
        Task {
            // Reset state
            await MainActor.run {
                error = nil
                isLoading = true
            }
            
            do {
                // First try to get cached thumbnail
                if let cachedImage = await thumbnailService.getCachedThumbnail(for: pageIndex) {
                    await MainActor.run {
                        self.image = cachedImage
                        self.isLoading = false
                    }
                    return
                }
                
                // Check for placeholder while generating
                if let placeholder = await thumbnailService.getPlaceholderThumbnail(for: pageIndex) {
                    await MainActor.run {
                        self.image = placeholder
                    }
                }
                
                // Load thumbnail using ThumbnailService
                let loadingOptions = ThumbnailLoadingOptions(
                    targetSize: targetSize,
                    useCache: true,
                    priority: .userInitiated
                )
                
                let result = await thumbnailService.loadThumbnail(
                    document: nil,
                    pageIndex: pageIndex,
                    page: page,
                    options: loadingOptions
                )
                
                await MainActor.run {
                    if let thumbnailImage = result.image {
                        self.image = thumbnailImage
                        self.isLoading = false
                    } else {
                        self.error = ThumbnailError.generationFailed("Failed to load thumbnail")
                        self.isLoading = false
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Thumbnail Error Types
enum ThumbnailError: LocalizedError {
    case generationTimeout
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .generationTimeout:
            return "Thumbnail generation timed out"
        case .generationFailed(let message):
            return "Thumbnail generation failed: \(message)"
        }
    }
}

// Updated Thumbnail view component with selection support
struct ThumbnailView: View {
    let index: Int
    @Binding var currentPage: Int
    let document: PDFDocument?
    let selectionMode: Bool
    let isCitationSelected: Bool
    let isCoverSelected: Bool
    @ObservedObject var viewModel: AppShellViewModel
    let onPageTap: (Int) -> Void
    let onCitationToggle: (Int) -> Void
    let onCoverToggle: (Int) -> Void

    // MARK: - Helper Views for Type Checker Performance
    @ViewBuilder
    private func thumbnailImageView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 120)
            .background(Color.white)
            .overlay(thumbnailBorder)
    }
    
    @ViewBuilder
    private func thumbnailPlaceholderView() -> some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 120)
                .background(Color.white)
                .overlay(thumbnailBorder)
            
            VStack(spacing: 2) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.gray)
                Text("Loading...")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }
    
    @ViewBuilder
    private func thumbnailErrorView(page: PDFPage) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.red.opacity(0.1))
                .frame(height: 120)
                .background(Color.white)
                .overlay(thumbnailBorder)
            
            Image(nsImage: page.thumbnail(of: CGSize(width: 160, height: 200), for: .cropBox))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 120)
                .opacity(0.8)
        }
    }
    
    @ViewBuilder
    private var thumbnailBorder: some View {
        Rectangle()
            .strokeBorder(
                index == currentPage && !selectionMode ? Color(DesignTokens.brutalistPrimary) : Color.clear,
                lineWidth: 2
            )
    }

    var body: some View {
        VStack(spacing: 4) {
            // Optimized async thumbnail loading
            if let doc = document, let page = doc.page(at: index) {
                ZStack {
                    ThumbnailImageView.standard(
                        document: doc,
                        pageIndex: index,
                        thumbnailService: viewModel.thumbnailService
                    )

                    // Selection indicators
                    if selectionMode {
                        VStack {
                            HStack {
                                Spacer()

                                // Citation select button
                                Button {
                                    onCitationToggle(index)
                                } label: {
                                    Image(systemName: isCitationSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isCitationSelected ? Color(DesignTokens.brutalistPrimary) : Color.white.opacity(0.7))
                                        .font(.system(size: 18, weight: .bold))
                                        .padding(4)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .offset(x: 4, y: 4)

                                // Cover select button
                                Button {
                                    onCoverToggle(index)
                                } label: {
                                    Image(systemName: isCoverSelected ? "star.fill" : "star")
                                        .foregroundColor(isCoverSelected ? .blue : Color.white.opacity(0.7))
                                        .font(.system(size: 16, weight: .bold))
                                        .padding(4)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .offset(x: 4, y: 4)
                            }

                            Spacer()
                        }
                    }
                }
                .onTapGesture {
                    onPageTap(index)
                }

                HStack {
                    // Page number
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)

                    Spacer()

                    // Selection indicators (text)
                    if !selectionMode {
                        HStack(spacing: 6) {
                            if viewModel.citationPageIndices.contains(index) {
                                Text("CIT")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(DesignTokens.brutalistPrimary).opacity(0.2))
                                    )
                            }

                            if viewModel.coverPageIndex == index {
                                Text("CVR")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.blue)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.blue.opacity(0.2))
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(index == currentPage && !selectionMode ? 0.4 : 0.2))
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }

    // Border color based on selection state
    private var borderColor: Color {
        if selectionMode {
            if isCitationSelected && isCoverSelected {
                return Color.purple.opacity(0.7)
            } else if isCitationSelected {
                return Color(DesignTokens.brutalistPrimary).opacity(0.7)
            } else if isCoverSelected {
                return Color.blue.opacity(0.7)
            } else {
                return Color.white.opacity(0.2)
            }
        } else {
            return index == currentPage ? Color(DesignTokens.brutalistPrimary).opacity(0.5) : Color.white.opacity(0.2)
        }
    }
}

// Preview
#Preview {
    BrutalistAppShell(viewModel: AppShellViewModel())
}
