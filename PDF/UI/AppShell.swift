import SwiftUI
@preconcurrency import PDFKit
import MetalKit

// Add scene enum
enum AppScene: Hashable {
    case loading
    case main
    case preview
    case mainMenu
    // pageSelection removed - handled in BrutalistAppShell
}

enum CompositionMode: String, CaseIterable, Identifiable {
    case sideBySide = "Side by Side"
    case custom = "Custom"
    var id: String { rawValue }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case pdf = "PDF"
    var id: String { rawValue }
}

@MainActor
class AppShellViewModel: ObservableObject {
    @Published var selectedAppScene: AppScene = .mainMenu
    @Published var isLoading: Bool = false
    @Published var pdfDocument: PDFDocument? = nil
    @Published var thumbnails: [NSImage] = []
    @Published var citationPageIndices: [Int] = []
    @Published var coverPageIndex: Int? = nil
    // showPageSelection removed - page selection handled in BrutalistAppShell
    @Published var pdfLoadingProgress: Double? = nil
    
    // Optimized thumbnail cache
    @Published var thumbnailCache = ThumbnailCache()
    private var loadingTask: Task<Void, Never>? = nil

    // Preview state
    @Published var showPreview: Bool = false {
        didSet {
            if showPreview {
                selectedAppScene = .preview
            }
        }
    }
    @Published var compositionMode: CompositionMode = .custom
    @Published var exportFormat: ExportFormat = .png
    @Published var coverPosition: CGPoint = CGPoint(x: 0.5, y: 0.5) // Center by default
    @Published var coverSize: CGSize = CGSize(width: 0.3, height: 0.3) // 30% of citation size by default

    func loadPDF(from url: URL) async throws {
        isLoading = true
        print("DEBUG: Setting isLoading to true, current scene: \(selectedAppScene)")

        // Access security-scoped resource if needed
        let hasStartedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasStartedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Create PDF document
        guard let document = PDFDocument(url: url) else {
            await MainActor.run {
                isLoading = false
                print("DEBUG: Failed to load PDF document")
            }
            throw NSError(domain: "AppShellViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF document."])
        }

        print("DEBUG: PDF document created, processing \(document.pageCount) pages")

        // Check for document validity
        if document.pageCount == 0 {
            await MainActor.run {
                isLoading = false
                print("DEBUG: PDF has no pages")
            }
            throw NSError(domain: "AppShellViewModel", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "PDF has no pages."])
        }

        // Initialize thumbnails array with placeholders and start async generation
        var placeholderThumbnails: [NSImage] = []
        print("DEBUG: Starting async thumbnail generation for \(document.pageCount) pages")
        
        // Create placeholder thumbnails for immediate UI response
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                // Generate low-res placeholder synchronously for immediate display
                let placeholder = page.thumbnail(of: CGSize(width: 80, height: 100), for: .cropBox)
                placeholderThumbnails.append(placeholder)
                
                // Start async high-res thumbnail generation
                await MainActor.run {
                    self.thumbnailCache.generateThumbnailAsync(for: i, from: page)
                }
            }
            
            // Update loading progress
            await MainActor.run {
                self.pdfLoadingProgress = Double(i + 1) / Double(document.pageCount)
                print("DEBUG: Loading progress \(self.pdfLoadingProgress ?? 0)")
            }
        }
        
        // Preload first visible thumbnails with higher priority
        if document.pageCount > 0 {
            let visibleRange = min(10, document.pageCount)
            for i in 0..<visibleRange {
                if let page = document.page(at: i) {
                    await MainActor.run {
                        self.thumbnailCache.generateThumbnailAsync(for: i, from: page, priority: .userInitiated)
                    }
                }
            }
        }

        // Update the UI on the main thread
        await MainActor.run {
            print("DEBUG: Finished loading PDF, updating UI")
            self.pdfDocument = document
            self.thumbnails = placeholderThumbnails
            self.isLoading = false

            // Update scene state
            if self.showPreview {
                print("DEBUG: Setting scene to preview")
                self.selectedAppScene = .preview
            } else {
                print("DEBUG: Setting scene to main")
                // Use main scene which has the preferred page selection UI
                self.selectedAppScene = .main
            }
            print("DEBUG: Final scene state: \(self.selectedAppScene), isLoading: \(self.isLoading)")
        }
    }

    // Reset selection state
    func resetSelection() {
        citationPageIndices = []
        coverPageIndex = nil
    }

    // Clear document and state
    func clearDocument() {
        loadingTask?.cancel()
        loadingTask = nil
        thumbnailCache.clearCache()
        pdfDocument = nil
        thumbnails = []
        resetSelection()
    }
    
    // Get optimized thumbnail for page
    func getThumbnail(for pageIndex: Int) -> NSImage? {
        // Try to get full resolution thumbnail first
        if let fullThumbnail = thumbnailCache.getThumbnail(for: pageIndex) {
            return fullThumbnail
        }
        
        // Fall back to placeholder if available
        if let placeholder = thumbnailCache.getPlaceholder(for: pageIndex) {
            return placeholder
        }
        
        // Fall back to stored thumbnail array
        if pageIndex < thumbnails.count {
            return thumbnails[pageIndex]
        }
        
        return nil
    }
    
    // Check if thumbnail is loading
    func isThumbnailLoading(_ pageIndex: Int) -> Bool {
        return thumbnailCache.loadingStates.contains(pageIndex)
    }
    
    // Preload thumbnails for viewport
    func preloadThumbnailsForViewport(startIndex: Int, count: Int = 10) {
        guard let document = pdfDocument else { return }
        
        let endIndex = min(startIndex + count, document.pageCount)
        for i in startIndex..<endIndex {
            if let page = document.page(at: i),
               thumbnailCache.getThumbnail(for: i) == nil,
               !thumbnailCache.loadingStates.contains(i) {
                thumbnailCache.generateThumbnailAsync(for: i, from: page, priority: .utility)
            }
        }
    }

    // Debug print the current state
    func debugPrintState() {
        print("PDF Document: \(pdfDocument != nil ? "Loaded" : "Not loaded")")
        if let doc = pdfDocument {
            print("PDF Pages: \(doc.pageCount)")
        }
        print("Thumbnails: \(thumbnails.count)")
        print("Loading States: \(thumbnailCache.loadingStates)")
        print("Citation Page Indices: \(citationPageIndices)")
        print("Cover Page Index: \(String(describing: coverPageIndex))")
        print("Current Scene: \(selectedAppScene)")
        print("Composition Mode: \(compositionMode.rawValue)")
        print("Export Format: \(exportFormat.rawValue)")
        print("Loading: \(isLoading)")
    }
}

@MainActor
class AppBackgroundModel: ObservableObject {
    @Published var backgroundVM = BackgroundEffectViewModel()
    @Published var noiseIntensity: CGFloat = 0.2
    @Published var noiseSpeed: CGFloat = 1.0
    @Published var colorShift: CGFloat = 0.0

    init() {
        startNoiseAnimation()
    }

    func startNoiseAnimation() {
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: true)) {
            colorShift = 1.0
        }

        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            noiseIntensity = 0.3
        }
    }
}

// New private struct for the loading indicator's background
private struct LoadingIndicatorBackgroundView: View {
    var body: some View {
        BrutalistVisualEffectView(
            material: .hudWindow,
            blendingMode: .withinWindow,
            emphasized: false
        )
        .overlay(
            Image("AccentTexture2")
                .resizable()
                .scaledToFill()
                .opacity(0.7)
                .blendMode(.overlay)
                .allowsHitTesting(false)
        )
        .clipShape(UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous))
    }
}

struct AppShell: View {
    @StateObject var viewModel = AppShellViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base background - pure black
                Color.black
                    .ignoresSafeArea()

                // Main content area
                VStack(alignment: .leading, spacing: 0) {
                    // Main content with terminal-style styling
                    Group {
                        if viewModel.isLoading {
                            // Show loading view when isLoading is true
                            BrutalistLoadingView(
                                progress: viewModel.pdfLoadingProgress,
                                totalPages: viewModel.pdfDocument?.pageCount
                            )
                                .onAppear {
                                    print("DEBUG: Showing BrutalistLoadingView, isLoading: \(viewModel.isLoading)")
                                }
                        } else if viewModel.selectedAppScene == .mainMenu {
                            MainMenuView(viewModel: viewModel)
                                .onAppear {
                                    print("DEBUG: Showing MainMenuView")
                                }
                        // .pageSelection scene removed - page selection is handled in BrutalistAppShell
                        } else if viewModel.showPreview || viewModel.selectedAppScene == .preview {
                            // Prioritize showing preview when either property is set
                            BrutalistPreviewView(viewModel: viewModel)
                                .onAppear {
                                    print("DEBUG: Showing BrutalistPreviewView")
                                }
                        } else if viewModel.selectedAppScene == .main {
                            BrutalistAppShell(viewModel: viewModel)
                                .onAppear {
                                    print("DEBUG: Showing BrutalistAppShell")
                                }
                        } else {
                            // Loading or other scenes
                            ZStack {
                                BrutalistLoadingView(
                                    progress: viewModel.pdfLoadingProgress,
                                    totalPages: viewModel.pdfDocument?.pageCount
                                )
                                    .onAppear {
                                        print("DEBUG: Showing fallback BrutalistLoadingView")
                                    }
                            }
                        }
                    }
                    .animation(.spring(duration: 0.5, bounce: 0.7), value: viewModel.selectedAppScene)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Global heavy grain overlay applied on top of everything
                globalHeavyGrainOverlay(geo: geo)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: viewModel.selectedAppScene) { oldValue, newValue in
            print("DEBUG: Scene changed from \(oldValue) to \(newValue)")
        }
        .onChange(of: viewModel.isLoading) { oldValue, newValue in
            print("DEBUG: isLoading changed from \(oldValue) to \(newValue)")
        }
    }
    
    // MARK: - Global Heavy Grain Overlay
    
    @ViewBuilder
    private func globalHeavyGrainOverlay(geo: GeometryProxy) -> some View {
        ZStack {
            // Multiple layers of texture for heavy grain effect across entire app
            
            // Layer 1: AccentTexture5 with maximum intensity for prominent grain
            Image("AccentTexture5")
                .resizable()
                .scaledToFill()
                .opacity(1.0)
                .blendMode(.overlay)
                .frame(width: geo.size.width, height: geo.size.height)
            
            // Layer 2: AccentTexture4 for additional depth and contrast
            Image("AccentTexture4")
                .resizable()
                .scaledToFill()
                .opacity(0.85)
                .blendMode(.softLight)
                .frame(width: geo.size.width, height: geo.size.height)
            
            // Layer 3: Heavy programmatic grain pattern
            BrutalistTexture(style: .grain, intensity: 1.0, color: .white)
                .blendMode(.overlay)
                .frame(width: geo.size.width, height: geo.size.height)
            
            // Layer 4: Distressed texture for brutalist feel
            BrutalistTexture(style: .distressed, intensity: 0.8, color: .white)
                .blendMode(.softLight)
                .frame(width: geo.size.width, height: geo.size.height)
            
            // Layer 5: Additional heavy noise pattern
            BrutalistTexture(style: .noise, intensity: 1.0, color: .white)
                .blendMode(.overlay)
                .frame(width: geo.size.width, height: geo.size.height)
            
            // Layer 6: AppKit-based heavy noise overlay with maximum intensity
            NoisyOverlay(intensity: 4.0, asymmetric: true, blendingMode: "overlayBlendMode")
                .frame(width: geo.size.width, height: geo.size.height)
                .opacity(1.0)
        }
    }
}

#Preview {
    AppShell()
}
