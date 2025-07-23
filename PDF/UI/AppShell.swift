import SwiftUI
@preconcurrency import PDFKit
import MetalKit

// ExportFormat is available globally from ExportService.swift

// Add scene enum
enum AppScene: Hashable {
    case loading
    case main
    case preview
    case mainMenu
    case batchProcessing
    case pluginManager
    case cloudStorage
    // pageSelection removed - handled in BrutalistAppShell
}

// CompositionMode is defined in ExportService.swift as a global enum
// typealias CompositionMode = CompositionMode // Not needed since it's already global


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
    
    // Centralized thumbnail service
    let thumbnailService = ThumbnailService()
    
    // PDF service for batch processing and other operations
    let pdfService = PDFService()
    
    // Plugin system integration
    @Published var showingPluginManager = false
    @Published var showingPluginInstaller = false
    @Published var showingPluginErrors = false
    
    let pluginManager = PluginManager()
    let pluginErrorHandler: PluginErrorHandler
    let pluginMenuIntegration: PluginMenuIntegration
    
    // Cloud storage integration
    @Published var showingCloudStorage = false
    @Published var showingCloudAuth = false
    @Published var showingCloudExport = false
    
    private var loadingTask: Task<Void, Never>? = nil

    // Preview state
    @Published var showPreview: Bool = false {
        didSet {
            if showPreview {
                selectedAppScene = .preview
            }
        }
    }
    @Published var compositionMode: CompositionMode = .centerCitation
    @Published var exportFormat: ExportService.ExportFormat = .png
    @Published var coverPosition: CGPoint = CGPoint(x: 0.5, y: 0.5) // Center by default
    @Published var coverSize: CGSize = CGSize(width: 0.3, height: 0.3) // 30% of citation size by default

    init() {
        // Initialize plugin system components
        self.pluginErrorHandler = PluginErrorHandler(pluginManager: pluginManager)
        self.pluginMenuIntegration = PluginMenuIntegration(pluginManager: pluginManager)
        
        setupPluginSystemIntegration()
    }
    
    private func setupPluginSystemIntegration() {
        // Set up notification observers for plugin UI integration
        NotificationCenter.default.addObserver(
            forName: .showPluginManager,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showingPluginManager = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .showPluginInstaller,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showingPluginInstaller = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .showPluginErrors,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showingPluginErrors = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .reloadPlugins,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.pluginManager.scanForPlugins()
            }
        }
        
        // Cloud storage notification observers
        NotificationCenter.default.addObserver(
            forName: .showCloudStorage,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.selectedAppScene = .cloudStorage
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .showCloudAuth,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showingCloudAuth = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .exportToCloud,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showingCloudExport = true
            }
        }
        
        // Start plugin discovery
        Task {
            await pluginManager.scanForPlugins()
        }
    }

    func loadPDF(from url: URL) async throws {
        isLoading = true
        pdfLoadingProgress = 0.0
        print("DEBUG: Setting isLoading to true, current scene: \(selectedAppScene)")

        // Access security-scoped resource if needed
        let hasStartedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasStartedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Progress: Starting file validation (10%)
        await MainActor.run { self.pdfLoadingProgress = 0.1 }

        // SECURITY: Validate file before processing
        let securityValidator = PDFSecurityValidator(configuration: .default)
        do {
            try await securityValidator.validateFile(at: url)
            print("DEBUG: PDF security validation passed")
        } catch let securityError as PDFSecurityError {
            await MainActor.run {
                isLoading = false
                pdfLoadingProgress = nil
                print("DEBUG: PDF security validation failed: \(securityError.description)")
            }
            throw NSError(domain: "AppShellViewModel.Security", code: 100,
                          userInfo: [NSLocalizedDescriptionKey: "Security validation failed: \(securityError.description)"])
        } catch {
            await MainActor.run {
                isLoading = false
                pdfLoadingProgress = nil
                print("DEBUG: PDF security validation error: \(error.localizedDescription)")
            }
            throw NSError(domain: "AppShellViewModel.Security", code: 101,
                          userInfo: [NSLocalizedDescriptionKey: "Security validation error: \(error.localizedDescription)"])
        }

        // Progress: File validated, loading document (25%)
        await MainActor.run { self.pdfLoadingProgress = 0.25 }

        // Create PDF document
        guard let document = PDFDocument(url: url) else {
            await MainActor.run {
                isLoading = false
                pdfLoadingProgress = nil
                print("DEBUG: Failed to load PDF document")
            }
            throw NSError(domain: "AppShellViewModel", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF document."])
        }

        print("DEBUG: PDF document created, processing \(document.pageCount) pages")

        // Progress: Document loaded, validating content (40%)
        await MainActor.run { self.pdfLoadingProgress = 0.4 }

        // SECURITY: Validate the loaded document for additional security checks
        do {
            try await securityValidator.validateDocument(document)
            print("DEBUG: PDF document security validation passed")
        } catch let securityError as PDFSecurityError {
            await MainActor.run {
                isLoading = false
                pdfLoadingProgress = nil
                print("DEBUG: PDF document security validation failed: \(securityError.description)")
            }
            throw NSError(domain: "AppShellViewModel.Security", code: 102,
                          userInfo: [NSLocalizedDescriptionKey: "Document security validation failed: \(securityError.description)"])
        } catch {
            await MainActor.run {
                isLoading = false
                pdfLoadingProgress = nil
                print("DEBUG: PDF document security validation error: \(error.localizedDescription)")
            }
            throw NSError(domain: "AppShellViewModel.Security", code: 103,
                          userInfo: [NSLocalizedDescriptionKey: "Document security validation error: \(error.localizedDescription)"])
        }

        // Check for document validity
        if document.pageCount == 0 {
            await MainActor.run {
                isLoading = false
                pdfLoadingProgress = nil
                print("DEBUG: PDF has no pages")
            }
            throw NSError(domain: "AppShellViewModel", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "PDF has no pages."])
        }

        // Progress: Document validated, starting thumbnail generation (60%)
        await MainActor.run { self.pdfLoadingProgress = 0.6 }

        // Initialize thumbnails using centralized thumbnail service
        print("DEBUG: Starting batch thumbnail generation for \(document.pageCount) pages")
        
        // Generate thumbnails with progress tracking
        let pageIndices = Array(0..<document.pageCount)
        let batchSize = 10 // Process in batches for better progress updates
        var allThumbnailResults: [ThumbnailLoadingResult] = []
        
        let totalBatches = (pageIndices.count + batchSize - 1) / batchSize
        for batchIndex in 0..<totalBatches {
            let startIndex = batchIndex * batchSize
            let endIndex = min(startIndex + batchSize, pageIndices.count)
            let batchIndices = Array(pageIndices[startIndex..<endIndex])
            
            // Generate batch of thumbnails
            let batchResults = await thumbnailService.loadThumbnailsBatch(
                from: document,
                pageIndices: batchIndices,
                options: .standard
            )
            allThumbnailResults.append(contentsOf: batchResults)
            
            // Update progress during thumbnail generation (60% to 90%)
            let batchProgress = Double(batchIndex + 1) / Double(totalBatches)
            let currentProgress = 0.6 + (batchProgress * 0.3) // 60% + up to 30% more
            await MainActor.run { 
                self.pdfLoadingProgress = min(currentProgress, 0.9)
                print("DEBUG: Thumbnail progress: batch \(batchIndex + 1)/\(totalBatches), progress: \(Int(currentProgress * 100))%")
            }
        }
        
        // Use the collected results
        let thumbnailResults = allThumbnailResults
        
        // Progress: Thumbnails generated, finalizing (90%)
        await MainActor.run { self.pdfLoadingProgress = 0.9 }
        
        // Convert to NSImage array, sorted by pageIndex
        let sortedResults = thumbnailResults.sorted { $0.pageIndex < $1.pageIndex }
        let generatedThumbnails = sortedResults.map { $0.image }

        // Update the UI on the main thread - Complete (100%)
        await MainActor.run {
            print("DEBUG: Finished loading PDF, updating UI")
            self.pdfDocument = document
            self.thumbnails = generatedThumbnails
            self.pdfLoadingProgress = 1.0
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
        
        // Cancel thumbnail service operations
        thumbnailService.cancelAllLoading()
        thumbnailService.clearCache()
        
        pdfDocument = nil
        thumbnails = []
        resetSelection()
    }
    
    // Get optimized thumbnail for page using centralized service
    func getThumbnail(for pageIndex: Int) async -> NSImage? {
        // Try to get cached thumbnail first
        if let cachedThumbnail = await thumbnailService.getCachedThumbnail(for: pageIndex) {
            return cachedThumbnail
        }
        
        // Try placeholder
        if let placeholder = await thumbnailService.getPlaceholderThumbnail(for: pageIndex) {
            return placeholder
        }
        
        // Fall back to stored thumbnail array
        if pageIndex < thumbnails.count {
            return thumbnails[pageIndex]
        }
        
        // If we have a document, try loading on-demand
        if let document = pdfDocument {
            let result = await thumbnailService.loadThumbnail(
                from: document,
                pageIndex: pageIndex,
                options: .standard
            )
            return result?.image
        }
        
        return nil
    }
    
    // Check if thumbnail is loading using centralized service
    func isThumbnailLoading(_ pageIndex: Int) async -> Bool {
        return await thumbnailService.isThumbnailLoading(pageIndex: pageIndex)
    }
    
    // Preload thumbnails for viewport using centralized service
    func preloadThumbnailsForViewport(startIndex: Int, count: Int = 10) {
        guard let document = pdfDocument else { return }
        
        thumbnailService.preloadThumbnailsForViewport(
            from: document,
            startIndex: startIndex,
            count: count,
            options: .standard
        )
    }

    // Debug print the current state
    func debugPrintState() {
        print("PDF Document: \(pdfDocument != nil ? "Loaded" : "Not loaded")")
        if let doc = pdfDocument {
            print("PDF Pages: \(doc.pageCount)")
        }
        print("Thumbnails: \(thumbnails.count)")
        Task {
            let (loadingCount, cacheHitRate) = await thumbnailService.getCacheStatistics()
            print("Thumbnail Loading Count: \(loadingCount)")
            print("Cache Hit Rate: \(cacheHitRate)")
        }
        print("Citation Page Indices: \(citationPageIndices)")
        print("Cover Page Index: \(String(describing: coverPageIndex))")
        print("Current Scene: \(selectedAppScene)")
        print("Composition Mode: \(compositionMode.rawValue)")
        print("Export Format: \(exportFormat.rawValue)")
        print("Loading: \(isLoading)")
    }
    
}

// MARK: - Array Extension for Batching
private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
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
                        } else if viewModel.selectedAppScene == .batchProcessing {
                            BatchProcessingView(pdfService: viewModel.pdfService)
                                .onAppear {
                                    print("DEBUG: Showing BatchProcessingView")
                                }
                        } else if viewModel.selectedAppScene == .pluginManager {
                            PluginManagerView()
                                .onAppear {
                                    print("DEBUG: Showing PluginManagerView")
                                }
                        } else if viewModel.selectedAppScene == .cloudStorage {
                            CloudStorageAccountsView()
                                .onAppear {
                                    print("DEBUG: Showing CloudStorageAccountsView")
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
        // Plugin UI integration
        .sheet(isPresented: $viewModel.showingPluginManager) {
            PluginManagerView()
        }
        .sheet(isPresented: $viewModel.showingPluginInstaller) {
            PluginInstallerView(pluginManager: viewModel.pluginManager)
        }
        .sheet(isPresented: $viewModel.showingPluginErrors) {
            PluginErrorView()
        }
        
        // Cloud storage UI integration
        .sheet(isPresented: $viewModel.showingCloudAuth) {
            CloudStorageAuthView()
        }
        .sheet(isPresented: $viewModel.showingCloudExport) {
            if let pdfDocument = viewModel.pdfDocument {
                // We'll create a temporary URL for the cloud export
                // In a real implementation, you'd want to handle this more elegantly
                CloudStoragePickerView(
                    localFileURL: URL(fileURLWithPath: "/tmp/temp_export.pdf"),
                    onComplete: { account, remotePath in
                        viewModel.showingCloudExport = false
                        // Handle successful cloud export
                    },
                    onCancel: {
                        viewModel.showingCloudExport = false
                    }
                )
            }
        }
    }
    
    // MARK: - Optimized Combined Texture Overlay
    
    @ViewBuilder
    private func globalHeavyGrainOverlay(geo: GeometryProxy) -> some View {
        // Combined texture rendering using Canvas for optimal GPU performance
        Canvas { context, size in
            // Create a single render pass combining all texture effects
            
            // Base layer setup
            context.opacity = 1.0
            
            // Load texture images if available
            if NSImage(named: "AccentTexture5") != nil,
               NSImage(named: "AccentTexture4") != nil {
                
                let rect = CGRect(origin: .zero, size: size)
                
                // Layer 1: AccentTexture5 with overlay blend
                context.blendMode = .overlay
                context.opacity = 1.0
                if let resolvedTexture5 = context.resolveSymbol(id: "texture5") {
                    context.draw(resolvedTexture5, in: rect)
                }
                
                // Layer 2: AccentTexture4 with soft light blend
                context.blendMode = .softLight
                context.opacity = 0.85
                if let resolvedTexture4 = context.resolveSymbol(id: "texture4") {
                    context.draw(resolvedTexture4, in: rect)
                }
            }
            
            // Combined procedural texture effects
            context.blendMode = .overlay
            context.opacity = 0.6
            
            // Grain pattern simulation
            let grainSize: CGFloat = 2.0
            for x in stride(from: 0, to: size.width, by: grainSize) {
                for y in stride(from: 0, to: size.height, by: grainSize) {
                    let intensity = CGFloat.random(in: 0.3...1.0)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: grainSize, height: grainSize)),
                        with: .color(.white.opacity(intensity * 0.15))
                    )
                }
            }
            
            // Distressed texture simulation
            context.blendMode = .softLight
            context.opacity = 0.4
            let distressPoints = Int(size.width * size.height / 5000)
            for _ in 0..<distressPoints {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let radius = CGFloat.random(in: 0.5...2.0)
                let intensity = CGFloat.random(in: 0.2...0.8)
                
                context.fill(
                    Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(intensity * 0.2))
                )
            }
            
        } symbols: {
            // Pre-resolved texture symbols for efficient rendering
            if let texture5 = NSImage(named: "AccentTexture5") {
                Image(nsImage: texture5)
                    .resizable()
                    .tag("texture5")
            }
            if let texture4 = NSImage(named: "AccentTexture4") {
                Image(nsImage: texture4)
                    .resizable()
                    .tag("texture4")
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .background(
            // Fallback AppKit-based heavy noise for additional depth
            NoisyOverlay(intensity: 2.0, asymmetric: true, blendingMode: "overlayBlendMode")
                .opacity(0.6)
        )
    }
}

#Preview {
    AppShell()
}
