import SwiftUI
import PDFKit
import Combine
import AppKit

// MARK: - Performance Utilities
class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    
    init(delay: TimeInterval) {
        self.delay = delay
    }
    
    func debounce(action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem!)
    }
    
    func cancel() {
        workItem?.cancel()
    }
}


// Add this class before the BrutalistPreviewView struct
// MARK: - Async Image Loader
@MainActor
class AsyncImageLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading = false
    @Published var progress: Double = 0.0
    
    private var task: Task<Void, Never>?
    private weak var memoryPressureSource: DispatchSourceMemoryPressure?
    
    enum ImageMode {
        case preview
        case export
        
        var maxDimension: CGFloat {
            switch self {
            case .preview: return 800  // Reduced for 70% memory savings
            case .export: return 2400 // High quality for export
            }
        }
        
        var compressionQuality: CGFloat {
            switch self {
            case .preview: return 0.7  // Balanced quality/size for previews
            case .export: return 0.95  // High quality for exports
            }
        }
    }
    
    init() {
        setupMemoryPressureMonitoring()
    }
    
    deinit {
        task?.cancel()
        memoryPressureSource?.cancel()
    }
    
    private func setupMemoryPressureMonitoring() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: .warning, queue: .main)
        source.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        source.resume()
        memoryPressureSource = source
    }
    
    private func handleMemoryPressure() {
        // Cancel current task and clear image on memory pressure
        cancel()
        image = nil
        PDFImageCache.shared.clearCache()
    }
    
    func loadImage(key: String, mode: ImageMode = .preview, creator: @escaping () async throws -> NSImage?) {
        // Cancel any existing task
        task?.cancel()
        
        // Create mode-specific cache key
        let cacheKey = "\(key)_\(mode == .preview ? "preview" : "export")"
        
        // Check cache first on main thread
        if let cachedImage = PDFImageCache.shared.getCachedImage(for: cacheKey) {
            self.image = cachedImage
            self.isLoading = false
            self.progress = 1.0
            return
        }
        
        // Start loading
        self.isLoading = true
        self.progress = 0.0
        
        task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Check for cancellation early
                try Task.checkCancellation()
                
                // Update progress incrementally for better UX
                await self.updateProgress(0.1)
                
                // Create image on background thread with memory-efficient approach
                let newImage = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSImage?, Error>) in
                    Task.detached(priority: .userInitiated) { [mode] in
                        do {
                            // Generate the base image
                            guard let baseImage = try await creator() else {
                                continuation.resume(returning: nil)
                                return
                            }
                            
                            // Apply downsampling for memory efficiency
                            let optimizedImage = await self.optimizeImageForMode(baseImage, mode: mode)
                            continuation.resume(returning: optimizedImage)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                try Task.checkCancellation()
                await self.updateProgress(0.8)
                
                // Validate and cache on main thread
                if let validImage = newImage,
                   validImage.size.width > 0 && validImage.size.height > 0 {
                    
                    // Store in cache with mode-specific key
                    PDFImageCache.shared.storeImage(validImage, forKey: cacheKey)
                    await self.updateProgress(1.0)
                    
                    try Task.checkCancellation()
                    self.image = validImage
                    self.isLoading = false
                } else {
                    await self.updateProgress(1.0)
                    if !Task.isCancelled {
                        self.isLoading = false
                    }
                }
            } catch is CancellationError {
                // Handle cancellation gracefully
                await MainActor.run {
                    self.isLoading = false
                    self.progress = 0.0
                }
            } catch {
                await MainActor.run {
                    if !Task.isCancelled {
                        print("⚠️ Failed to load image for key '\(key)': \(error.localizedDescription)")
                        self.isLoading = false
                        self.progress = 0.0
                    }
                }
            }
        }
    }
    
    private func optimizeImageForMode(_ image: NSImage, mode: ImageMode) -> NSImage {
        let currentSize = image.size
        let maxDimension = mode.maxDimension
        
        // Check if downsampling is needed
        if max(currentSize.width, currentSize.height) <= maxDimension {
            return image
        }
        
        // Calculate optimal size maintaining aspect ratio
        let aspectRatio = currentSize.width / currentSize.height
        let newSize: NSSize
        
        if currentSize.width > currentSize.height {
            newSize = NSSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = NSSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        // Create downsampled image with high quality
        let downsampledImage = NSImage(size: newSize)
        downsampledImage.lockFocus()
        
        // Use high-quality interpolation
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        
        downsampledImage.unlockFocus()
        
        return downsampledImage
    }
    
    private func updateProgress(_ value: Double) async {
        await MainActor.run { [weak self] in
            self?.progress = value
        }
    }
    
    func cancel() {
        task?.cancel()
        task = nil
        isLoading = false
        progress = 0.0
    }
}

// PDFImageCache - Enhanced shared image cache with memory management
class PDFImageCache {
    static let shared = PDFImageCache()
    private let cache = NSCache<NSString, NSImage>()
    private let queue = DispatchQueue(label: "PDFImageCache", qos: .utility)
    
    // Memory management constants
    private let maxMemoryUsage: Int = 200 * 1024 * 1024 // 200MB limit
    private let maxItemCount: Int = 50 // Maximum cached items
    
    private init() {
        setupCache()
        setupMemoryWarningObserver()
    }
    
    private func setupCache() {
        cache.countLimit = maxItemCount
        cache.totalCostLimit = maxMemoryUsage
        
        // Eviction callback for debugging
        cache.delegate = CacheDelegate()
    }
    
    private func setupMemoryWarningObserver() {
        // Use UIApplication memory warning for iOS or generic low memory notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: NSNotification.Name("LowMemoryWarning"),
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        // Aggressively clear cache on memory warning
        queue.async {
            self.cache.removeAllObjects()
            print("🧹 PDFImageCache cleared due to memory warning")
        }
    }
    
    func getCachedImage(for key: String) -> NSImage? {
        let cacheKey = NSString(string: key)
        return cache.object(forKey: cacheKey)
    }

    func getImage(for key: String, creator: () -> NSImage?) -> NSImage? {
        let cacheKey = NSString(string: key)
        if let cachedImage = cache.object(forKey: cacheKey) {
            // Validate cached image
            guard cachedImage.size.width > 0 && cachedImage.size.height > 0 else {
                print("⚠️ Cached image for key '\(key)' has invalid size, removing from cache")
                cache.removeObject(forKey: cacheKey)
                return nil
            }
            return cachedImage
        }

        // Create new image with error handling
        guard let newImage = creator() else {
            print("⚠️ Failed to create image for cache key: '\(key)'")
            return nil
        }
        
        // Validate new image before caching
        guard newImage.size.width > 0 && newImage.size.height > 0 else {
            print("⚠️ Created image for key '\(key)' has invalid size, not caching")
            return nil
        }

        // Calculate approximate memory cost
        let cost = Int(newImage.size.width * newImage.size.height * 4) // RGBA bytes
        cache.setObject(newImage, forKey: cacheKey, cost: cost)
        return newImage
    }

    func clearCache() {
        queue.async {
            self.cache.removeAllObjects()
            print("🧹 PDFImageCache manually cleared")
        }
    }

    func storeImage(_ image: NSImage, forKey key: String) {
        let cacheKey = NSString(string: key)
        let cost = Int(image.size.width * image.size.height * 4) // RGBA bytes
        cache.setObject(image, forKey: cacheKey, cost: cost)
    }
    
    // Get cache statistics
    func getCacheStats() -> (count: Int, estimatedSize: String) {
        let count = cache.countLimit > 0 ? min(cache.countLimit, maxItemCount) : 0
        let sizeInMB = Double(cache.totalCostLimit) / (1024 * 1024)
        return (count, String(format: "%.1f MB", sizeInMB))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Cache delegate for monitoring  
private class CacheDelegate: NSObject, NSCacheDelegate {
    @objc func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        print("🗑️ Cache evicting object due to memory pressure")
    }
}

// MARK: - Export Result Types
enum ExportResult {
    case success(index: Int, url: URL)
    case failure(index: Int, error: String)
}

struct BrutalistPreviewView: View {
    @ObservedObject var viewModel: AppShellViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showFileExporter = false
    @State private var showCloudExporter = false
    @State private var selectedMode: CompositionMode = .centerCitation
    @State private var selectedFormat: ExportService.ExportFormat = .png
    @State private var showToast: Bool = false
    @State private var toastMessage: String = ""
    @StateObject private var cloudManager = CloudStorageManager.shared
    @State private var refreshID = UUID()
    @State private var showOrnateFrame: Bool = false
    @State private var selectedHorizontalFrame: String = "frameH"
    @State private var selectedVerticalFrame: String = "frameV"
    @State private var showFrameSelector: Bool = false
    @State private var isAnalyzing: Bool = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomValue: CGFloat = 1.0
    
    // Task management for proper cancellation
    @State private var activeTasks: Set<UUID> = []
    @State private var taskCancellables: [UUID: AnyCancellable] = [:]
    
    // Animation states
    @State private var isTransitioning = false

    // Task management methods
    private func cancelAllActiveTasks() {
        for (taskId, cancellable) in taskCancellables {
            cancellable.cancel()
        }
        taskCancellables.removeAll()
        activeTasks.removeAll()
    }
    
    private func addActiveTask(_ taskId: UUID, cancellable: AnyCancellable) {
        activeTasks.insert(taskId)
        taskCancellables[taskId] = cancellable
    }
    
    private func removeActiveTask(_ taskId: UUID) {
        activeTasks.remove(taskId)
        taskCancellables.removeValue(forKey: taskId)
    }
    
    // Replace private imageCache with reference to the shared cache
    // This keeps the helper method for convenience in this class
    private func getCachedImage(for key: String, creator: () -> NSImage?) -> NSImage? {
        return PDFImageCache.shared.getImage(for: key, creator: creator)
    }

    // Get all available frames from the asset catalog
    private var availableFrames: [String] {
        // Get actual available frames based on what exists in assets
        let allFrames = ["frameH", "frameV"]  // Known working frames
        return allFrames.filter { NSImage(named: $0) != nil }
    }

    // Current frame based on mode
    private var currentFrame: String {
        selectedMode == .centerCitation ? selectedHorizontalFrame : selectedVerticalFrame
    }
    
    // MARK: - Preview Content Views
    
    @ViewBuilder
    private var previewContent: some View {
        if let doc = viewModel.pdfDocument,
           let coverIdx = viewModel.coverPageIndex,
           coverIdx < doc.pageCount,
           !viewModel.citationPageIndices.isEmpty,
           viewModel.citationPageIndices.allSatisfy({ $0 < doc.pageCount }),
           let coverPage = doc.page(at: coverIdx) {
            
            validPreviewContent(doc: doc, coverPage: coverPage)
        } else {
            noContentSelectedView
        }
    }
    
    @ViewBuilder
    private func validPreviewContent(doc: PDFDocument, coverPage: PDFPage) -> some View {
        // Preview content area - different container based on mode
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .brutalistTexture(style: .noise, intensity: 0.2, color: .white)

            VStack(spacing: 8) {
                previewModeContent(doc: doc, coverPage: coverPage)
                
                // Count of citation pages if more than one
                if viewModel.citationPageIndices.count > 1 {
                    BrutalistTechnicalText(
                        text: "\(viewModel.citationPageIndices.count) CITATION PAGES SELECTED",
                        color: Color(DesignTokens.brutalistPrimary),
                        size: 12,
                        addDecorators: true,
                        align: .center
                    )
                }
            }
            .padding(5) // Reduced padding for more content space
        }
        // Restore proper aspect ratio constraints for containers
        .aspectRatio(selectedMode == .centerCitation ? 1.6 : 0.8, contentMode: .fit)
        .frame(
            minHeight: 400,
            idealHeight: 600,
            maxHeight: 800
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .strokeBorder(
                    isTransitioning ? 
                        Color(DesignTokens.brutalistPrimary).opacity(0.8) : 
                        Color(DesignTokens.brutalistPrimary).opacity(0.5), 
                    lineWidth: isTransitioning ? 2 : 1
                )
                .animation(.easeInOut(duration: 0.3), value: isTransitioning)
        )
        .padding(.horizontal, 24)
        .scaleEffect(isTransitioning ? 0.98 : 1.0)
        .opacity(isTransitioning ? 0.8 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: selectedMode)
        .animation(.easeInOut(duration: 0.3), value: isTransitioning)
    }
    
    @ViewBuilder
    private func previewModeContent(doc: PDFDocument, coverPage: PDFPage) -> some View {
        if selectedMode == .centerCitation {
            centerCitationView(doc: doc, coverPage: coverPage)
        } else {
            customOverlayView(doc: doc, coverPage: coverPage)
        }
    }
    
    @ViewBuilder
    private func centerCitationView(doc: PDFDocument, coverPage: PDFPage) -> some View {
        // Multiple citation pages: show all as a scrollable list of pairs
        ZoomableScrollView(zoomScale: $zoomScale, lastZoomValue: $lastZoomValue) {
            VStack(spacing: 24) {
                ForEach(viewModel.citationPageIndices.sorted(), id: \.self) { citationIdx in
                    if let citationPage = doc.page(at: citationIdx) {
                        ImprovedSideBySideView(citationPage: citationPage, coverPage: coverPage, showFrame: showOrnateFrame, frameName: selectedHorizontalFrame)
                            .id("side_by_side_\(citationIdx)_\(refreshID)")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private func customOverlayView(doc: PDFDocument, coverPage: PDFPage) -> some View {
        // Custom overlay view: show all selected citation pages
        // If only one citation page, no need for a list but still zoomable
        if viewModel.citationPageIndices.count == 1, 
           let citationIdx = viewModel.citationPageIndices.first, 
           let citationPage = doc.page(at: citationIdx) {
            singleCustomOverlayView(citationPage: citationPage, coverPage: coverPage, citationIdx: citationIdx)
        } else {
            multipleCustomOverlayView(doc: doc, coverPage: coverPage)
        }
    }
    
    @ViewBuilder
    private func singleCustomOverlayView(citationPage: PDFPage, coverPage: PDFPage, citationIdx: Int) -> some View {
        ZoomableScrollView(zoomScale: $zoomScale, lastZoomValue: $lastZoomValue) {
            ImprovedCustomOverlayView(
                citationPage: citationPage,
                coverPage: coverPage,
                coverPosition: $viewModel.coverPosition,
                coverSize: $viewModel.coverSize,
                showFrame: showOrnateFrame,
                frameName: selectedVerticalFrame
            )
            .id("custom_\(citationIdx)_\(refreshID)")
            .frame(maxWidth: .infinity)
        }
    }
    
    @ViewBuilder
    private func multipleCustomOverlayView(doc: PDFDocument, coverPage: PDFPage) -> some View {
        // Multiple citation pages: show all as a scrollable list
        ZoomableScrollView(zoomScale: $zoomScale, lastZoomValue: $lastZoomValue) {
            VStack(spacing: 24) {
                ForEach(viewModel.citationPageIndices.sorted(), id: \.self) { citationIdx in
                    if let citationPage = doc.page(at: citationIdx) {
                        ImprovedCustomOverlayView(
                            citationPage: citationPage,
                            coverPage: coverPage,
                            coverPosition: $viewModel.coverPosition,
                            coverSize: $viewModel.coverSize,
                            showFrame: showOrnateFrame,
                            frameName: selectedVerticalFrame
                        )
                        .id("custom_\(citationIdx)_\(refreshID)")
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var noContentSelectedView: some View {
        // No content selected view
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.7))

            BrutalistBlockText(
                title: "No Content Selected",
                subtitle: "MISSING SELECTIONS",
                description: "Return to the main view and ensure you have selected both citation pages and a cover page.",
                textColor: Color.white,
                showTechnicalElements: true,
                alignment: .center
            )
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .brutalistTexture(style: .grain, intensity: 0.2, color: .white)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }

    var body: some View {
        ZStack {
            // Black background for grain to render on
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 10) {
                // Brutalist header
                brutalistHeader

                // Mode selector
                modeSelector
                    .padding(.horizontal, 24)

                // Preview content
                previewContent

                // Action buttons
                HStack(spacing: 20) {
                    // Local Export button
                    Button {
                        showFileExporter = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                                .font(.system(size: 14, weight: .bold))

                            Text("EXPORT \(selectedFormat.rawValue)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.citationPageIndices.isEmpty || viewModel.coverPageIndex == nil)
                    
                    // Cloud Export button (only show if accounts are connected)
                    if cloudManager.hasAnyConnectedAccounts {
                        Button {
                            showCloudExporter = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "cloud.arrow.up")
                                    .font(.system(size: 14, weight: .bold))

                                Text("EXPORT TO CLOUD (\(cloudManager.connectedProviders.count) ACCOUNT\(cloudManager.connectedProviders.count == 1 ? "" : "S"))")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .fill(Color(DesignTokens.brutalistPrimary).opacity(0.1))
                                    .overlay(
                                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.6), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(viewModel.citationPageIndices.isEmpty || viewModel.coverPageIndex == nil)
                    } else {
                        // Show disabled cloud export button with suggestion
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "cloud.slash")
                                    .font(.system(size: 14, weight: .bold))

                                Text("CLOUD EXPORT")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .fill(Color.black.opacity(0.2))
                                    .overlay(
                                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            
                            Text("Connect cloud accounts in settings")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Return button
                    Button {
                        // Return to main view - fix race condition
                        withAnimation {
                            viewModel.showPreview = false
                            viewModel.selectedAppScene = .mainMenu
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))

                            Text("RETURN")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 20)

                Spacer()

                // Technical footer
                Text("RAW · INDUSTRIAL · FUNCTIONAL · STRUCTURAL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .kerning(2)
                    .foregroundColor(Color(DesignTokens.brutalistPrimary).opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding([.trailing, .bottom], 24)
            }
            .padding(.top, 20)

            // Enhanced Toast notifications with smooth animations
            if showToast {
                VStack {
                    Spacer()

                    HStack {
                        // Add icon for better visual feedback
                        Image(systemName: toastMessage.contains("EXPORT") ? "arrow.down.circle.fill" : 
                                         toastMessage.contains("ERROR") ? "exclamationmark.triangle.fill" : 
                                         "info.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        
                        Text(toastMessage)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                    .background(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.6), lineWidth: 1)
                            )
                            .brutalistTexture(style: .grain, intensity: 0.2, color: .white)
                            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .padding(.bottom, 20)
                    .padding(.horizontal, 24)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 1.1))
                        )
                    )
                    .onAppear {
                        // Auto-hide toast after 3 seconds with proper state management
                        let hideTask = Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            if showToast && !Task.isCancelled {
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        showToast = false
                                    }
                                }
                            }
                        }
                        
                        // Track the task for potential cancellation
                        let taskId = UUID()
                        let cancellable = AnyCancellable {
                            hideTask.cancel()
                        }
                        addActiveTask(taskId, cancellable: cancellable)
                    }
                }
            }
        }
        .onChange(of: showFileExporter) { isPresented in
            if isPresented {
                showFileExporter = false // Reset immediately
                DispatchQueue.main.async {
                    showSavePanel()
                }
            }
        }
        .sheet(isPresented: $showCloudExporter) {
            if let pdfDocument = viewModel.pdfDocument {
                cloudExportSheet(pdfDocument: pdfDocument)
            }
        }
        .onAppear {
            selectedMode = viewModel.compositionMode
            selectedFormat = viewModel.exportFormat
        }
        .onDisappear {
            // Cancel all active tasks when view disappears
            cancelAllActiveTasks()
        }
        .onChange(of: selectedMode) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isTransitioning = true
                zoomScale = 1.0  // Reset zoom when switching modes
            }
            
            // Complete transition after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isTransitioning = false
            }
        }
        .onChange(of: showOrnateFrame) { newValue in
            withAnimation(.easeInOut(duration: 0.25)) {
                isTransitioning = true
                zoomScale = 1.0
                if newValue {
                    refreshID = UUID()  // Only refresh when enabling frames
                }
            }
            
            // Complete transition after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                isTransitioning = false
            }
        }
    }

    // MARK: - Header Components
    
    @ViewBuilder
    private var headerTitle: some View {
        BrutalistHeading(
            text: "COMPOSITION PREVIEW",
            size: 24,
            color: Color(DesignTokens.brutalistPrimary),
            tracking: 1.5,
            addStroke: true,
            strokeWidth: 0.8
        )
    }
    
    @ViewBuilder  
    private var headerBackButton: some View {
        Button {
            withAnimation {
                viewModel.showPreview = false
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
    }
    
    @ViewBuilder
    private var headerMainBar: some View {
        HStack {
            headerTitle
            Spacer()
            headerBackButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
        )
    }
    
    @ViewBuilder
    private var headerMetadataText: some View {
        BrutalistTechnicalText(
            text: "MODE:  \(selectedMode.rawValue.uppercased()) · FORMAT: \(selectedFormat.rawValue.uppercased())",
            color: Color.white.opacity(0.6),
            size: 10,
            addDecorators: false,
            align: .leading
        )
    }
    
    @ViewBuilder
    private var headerFormatButtons: some View {
        HStack(spacing: 12) {
            ForEach(ExportService.ExportFormat.allCases, id: \.self) { format in
                Button {
                    selectedFormat = format
                    viewModel.exportFormat = format
                    withAnimation {
                        showToast = true
                        toastMessage = "FORMAT CHANGED TO \(format.rawValue.uppercased())"
                    }
                } label: {
                    Text(format.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(selectedFormat == format ?
                                      Color(DesignTokens.brutalistPrimary).opacity(0.4) :
                                      Color.black.opacity(0.2))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(selectedFormat == format ?
                                                      Color(DesignTokens.brutalistPrimary).opacity(0.8) :
                                                      Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    @ViewBuilder
    private var headerTechnicalLine: some View {
        HStack {
            headerMetadataText
            Spacer()
            headerFormatButtons
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.4))
    }

    // Brutalist header view
    private var brutalistHeader: some View {
        VStack(spacing: 0) {
            headerMainBar
            headerTechnicalLine
        }
    }

    // MARK: - Mode Selector Components
    
    @ViewBuilder
    private var modeSelectorTitle: some View {
        BrutalistTechnicalText(
            text: "COMPOSITION MODE",
            color: Color.white.opacity(0.7),
            size: 10,
            addDecorators: true,
            align: .leading
        )
    }
    
    @ViewBuilder
    private var frameToggle: some View {
        Toggle(isOn: $showOrnateFrame) {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 12, weight: .medium))

                Text("FRAME")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(showOrnateFrame ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.6))
        }
        .toggleStyle(SwitchToggleStyle(tint: Color(DesignTokens.brutalistPrimary)))
    }
    
    @ViewBuilder
    private func frameSelectorButton(for frame: String) -> some View {
        Button {
            showFrameSelector.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(frame)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundColor(Color(DesignTokens.brutalistPrimary))
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showFrameSelector) {
            frameSelectorPopover
        }
    }
    
    @ViewBuilder
    private var frameSelectorPopover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("SELECT FRAME")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                Divider()
                    .background(Color.white.opacity(0.2))

                // List of available frames
                ForEach(filteredFrames, id: \.self) { frameName in
                    frameOption(frameName)
                }
            }
            .frame(width: 200)
        }
        .frame(minHeight: 200)
        .background(Color.black.opacity(0.9))
    }
    
    private var filteredFrames: [String] {
        availableFrames.filter { frame in
            if selectedMode == .centerCitation {
                return frame.hasPrefix("frame") && (frame.hasSuffix("H") || frame.contains("H"))
            } else {
                return frame.hasPrefix("frame") && (frame.hasSuffix("V") || frame.contains("V"))
            }
        }
    }
    
    @ViewBuilder
    private func frameOption(_ frameName: String) -> some View {
        Button {
            // Select the frame
            if selectedMode == .centerCitation {
                selectedHorizontalFrame = frameName
            } else {
                selectedVerticalFrame = frameName
            }
            refreshID = UUID() // Force refresh
            showFrameSelector = false
        } label: {
            HStack {
                Text(frameName)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))

                Spacer()

                // Show checkmark for selected frame
                if frameName == currentSelectedFrame {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .foregroundColor(.white)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(
                    frameName == currentSelectedFrame ?
                    Color(DesignTokens.brutalistPrimary).opacity(0.3) :
                    Color.clear
                )
        )
    }
    
    private var currentSelectedFrame: String {
        selectedMode == .centerCitation ? selectedHorizontalFrame : selectedVerticalFrame
    }
    
    @ViewBuilder
    private var centerCitationFrameControls: some View {
        HStack(spacing: 12) {
            frameToggle
            
            if showOrnateFrame {
                Group {
                    frameSelectorButton(for: selectedHorizontalFrame)
                    createAnalyzeButton(for: selectedHorizontalFrame)
                }
            }
        }
    }
    
    @ViewBuilder
    private var customFrameControls: some View {
        HStack(spacing: 12) {
            frameToggle
            
            if showOrnateFrame {
                Group {
                    frameSelectorButton(for: selectedVerticalFrame)
                    createAnalyzeButton(for: selectedVerticalFrame)
                }
            }
        }
    }
    
    @ViewBuilder
    private var frameControlsSection: some View {
        HStack {
            modeSelectorTitle
            Spacer()
            
            // Show frame toggle and related controls
            if selectedMode == .centerCitation {
                centerCitationFrameControls
            } else {
                customFrameControls
            }
        }
        .padding(.bottom, 4)
    }
    
    @ViewBuilder
    private var sideBySideButton: some View {
        Button {
            selectedMode = .centerCitation
            viewModel.compositionMode = .centerCitation
            refreshID = UUID() // Force refresh
        } label: {
            HStack {
                Image(systemName: "rectangle.split.2x1")
                    .font(.system(size: 14, weight: .medium))

                Text("SIDE BY SIDE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(selectedMode == .centerCitation ? Color(DesignTokens.brutalistPrimary).opacity(0.3) : Color.black.opacity(0.2))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(selectedMode == .centerCitation ? Color(DesignTokens.brutalistPrimary) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(selectedMode == .centerCitation ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var customOverlayButton: some View {
        Button {
            selectedMode = .fullPage
            viewModel.compositionMode = .fullPage
            refreshID = UUID() // Force refresh
        } label: {
            HStack {
                Image(systemName: "rectangle.center.inset.filled")
                    .font(.system(size: 14, weight: .medium))

                Text("CUSTOM OVERLAY")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(selectedMode == .fullPage ? Color(DesignTokens.brutalistPrimary).opacity(0.3) : Color.black.opacity(0.2))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(selectedMode == .fullPage ? Color(DesignTokens.brutalistPrimary) : Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .foregroundColor(selectedMode == .fullPage ? Color(DesignTokens.brutalistPrimary) : .white.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private var modeButtons: some View {
        HStack(spacing: 10) {
            sideBySideButton
            customOverlayButton
        }
    }

    // Mode selector view
    private var modeSelector: some View {
        VStack(spacing: 1) {
            frameControlsSection
            modeButtons
        }
    }

    // Enhanced export handling with async processing and progress tracking
    private func handleExport(to directory: URL) async {
        // Don't clear cache - reuse preview images for consistent results
        let taskId = UUID()
        
        // Show immediate feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            showToast = true
            toastMessage = "STARTING EXPORT..."
        }

        // Enhanced validation with specific error messages
        guard let doc = viewModel.pdfDocument else {
            showToastError(message: "Export failed: No PDF document loaded")
            return
        }
        
        guard let coverIdx = viewModel.coverPageIndex else {
            showToastError(message: "Export failed: No cover page selected")
            return
        }
        
        guard coverIdx < doc.pageCount else {
            showToastError(message: "Export failed: Cover page index (\(coverIdx + 1)) exceeds document page count (\(doc.pageCount))")
            return
        }
        
        guard !viewModel.citationPageIndices.isEmpty else {
            showToastError(message: "Export failed: No citation pages selected")
            return
        }
        
        guard viewModel.citationPageIndices.allSatisfy({ $0 < doc.pageCount }) else {
            let invalidIndices = viewModel.citationPageIndices.filter { $0 >= doc.pageCount }
            showToastError(message: "Export failed: Citation page indices \(invalidIndices.map { $0 + 1 }) exceed document page count (\(doc.pageCount))")
            return
        }
        
        guard let coverPage = doc.page(at: coverIdx) else {
            showToastError(message: "Export failed: Unable to load cover page \(coverIdx + 1)")
            return
        }

        // No need for security scoped resource access when using NSSavePanel
        // The save panel already grants the necessary permissions

        var successCount = 0
        var errorMessages: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let baseName = doc.documentURL?.deletingPathExtension().lastPathComponent ?? "export"

        // Get the appropriate frame name based on composition mode
        let frameToUse = selectedMode == .centerCitation ? selectedHorizontalFrame : selectedVerticalFrame

        // Process exports using structured concurrency with TaskGroup for better performance
        let exportTask = Task {
            let totalPages = viewModel.citationPageIndices.count
            let sortedIndices = viewModel.citationPageIndices.sorted()
            
            // Use TaskGroup for concurrent processing while maintaining progress tracking
            await withTaskGroup(of: ExportResult.self) { group in
                var completedCount = 0
                
                for (index, citationIdx) in sortedIndices.enumerated() {
                    // Check for cancellation early
                    if Task.isCancelled {
                        await MainActor.run {
                            showToastError(message: "Export cancelled")
                        }
                        return
                    }
                    
                    // Add task to group for background processing
                    group.addTask { [selectedMode, selectedFormat, showOrnateFrame, frameToUse, coverPosition = viewModel.coverPosition, coverSize = viewModel.coverSize] in
                        // Run on background queue for better performance
                        return await Task.detached(priority: .userInitiated) {
                            do {
                                guard let citationPage = doc.page(at: citationIdx) else {
                                    return ExportResult.failure(index: citationIdx, error: "Could not load citation page \(citationIdx+1)")
                                }
                                
                                // Validate page content
                                let pageBounds = citationPage.bounds(for: .cropBox)
                                guard pageBounds.width > 0 && pageBounds.height > 0 else {
                                    return ExportResult.failure(index: citationIdx, error: "Citation page \(citationIdx+1) has invalid dimensions")
                                }
                                
                                let filename = "\(baseName)+CitationPage_\(citationIdx+1)"
                                
                                // Compose image with memory-efficient approach
                                let outputImage: NSImage
                                
                                // Use autoreleasepool for memory management during composition
                                outputImage = try await autoreleasepool {
                                    if selectedMode == .centerCitation {
                                        return brutalistComposeSideBySide(citation: citationPage, cover: coverPage, applyFrame: showOrnateFrame, frameName: frameToUse, isPreview: false)
                                    } else {
                                        return brutalistComposeCustom(citation: citationPage, cover: coverPage, coverPosition: coverPosition, coverSize: coverSize, applyFrame: showOrnateFrame, frameName: frameToUse, isPreview: false)
                                    }
                                }
                                
                                // Validate composed image
                                guard outputImage.size.width > 0 && outputImage.size.height > 0 else {
                                    return ExportResult.failure(index: citationIdx, error: "Generated image for page \(citationIdx+1) has invalid size")
                                }
                                
                                // Export to file format
                                let outputURL: URL
                                let outputData: Data
                                
                                switch selectedFormat {
                                case .png:
                                    guard let pngData = outputImage.pngData(), pngData.count > 0 else {
                                        return ExportResult.failure(index: citationIdx, error: "PNG export failed for page \(citationIdx+1): Unable to convert to PNG format")
                                    }
                                    outputURL = directory.appendingPathComponent(filename).appendingPathExtension("png")
                                    outputData = pngData
                                    
                                case .pdf:
                                    guard let pdfData = brutalistImageToPDFData(image: outputImage), pdfData.count > 0 else {
                                        return ExportResult.failure(index: citationIdx, error: "PDF export failed for page \(citationIdx+1): Unable to convert to PDF format")
                                    }
                                    outputURL = directory.appendingPathComponent(filename).appendingPathExtension("pdf")
                                    outputData = pdfData
                                    
                                case .jpeg:
                                    guard let tiffData = outputImage.tiffRepresentation,
                                          let bitmapImageRep = NSBitmapImageRep(data: tiffData),
                                          let jpegData = bitmapImageRep.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: 0.1)]) else {
                                        return ExportResult.failure(index: citationIdx, error: "JPEG export failed for page \(citationIdx+1): Unable to convert to JPEG format")
                                    }
                                    outputURL = directory.appendingPathComponent(filename).appendingPathExtension("jpeg")
                                    outputData = jpegData
                                    
                                case .webp:
                                    // WebP export - fallback to PNG since WebP isn't natively supported
                                    guard let pngData = outputImage.pngData(), pngData.count > 0 else {
                                        return ExportResult.failure(index: citationIdx, error: "WebP export failed for page \(citationIdx+1): Unable to convert to WebP format")
                                    }
                                    outputURL = directory.appendingPathComponent(filename).appendingPathExtension("webp")
                                    outputData = pngData
                                }
                                
                                // Write file atomically
                                try outputData.write(to: outputURL, options: .atomic)
                                
                                // Verify file was written successfully
                                guard FileManager.default.fileExists(atPath: outputURL.path) else {
                                    return ExportResult.failure(index: citationIdx, error: "File was not created at expected location")
                                }
                                
                                return ExportResult.success(index: citationIdx, url: outputURL)
                                
                            } catch {
                                return ExportResult.failure(index: citationIdx, error: "Export failed: \(error.localizedDescription)")
                            }
                        }.value
                    }
                    
                    // Limit concurrent tasks to prevent memory pressure (process 2 at a time)
                    if group.isEmpty == false && (index + 1) % 2 == 0 {
                        // Wait for some tasks to complete before adding more
                        for await result in group {
                            completedCount += 1
                            
                            // Update progress on main thread
                            let progress = Double(completedCount) / Double(totalPages)
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    showToast = true
                                    toastMessage = "EXPORTING PAGE \(completedCount)/\(totalPages)..."
                                }
                            }
                            
                            // Process result
                            switch result {
                            case .success(_, let url):
                                successCount += 1
                            case .failure(let index, let error):
                                errorMessages.append("Export failed for page \(index+1): \(error)")
                            }
                            
                            break // Only process one result to maintain flow control
                        }
                    }
                }
                
                // Process remaining results
                for await result in group {
                    completedCount += 1
                    
                    // Update progress on main thread
                    let progress = Double(completedCount) / Double(totalPages)
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            showToast = true
                            toastMessage = "EXPORTING PAGE \(completedCount)/\(totalPages)..."
                        }
                    }
                    
                    // Process result
                    switch result {
                    case .success(_, let url):
                        successCount += 1
                    case .failure(let index, let error):
                        errorMessages.append("Export failed for page \(index+1): \(error)")
                    }
                }
            }
            
            // Show final results on main thread
            await MainActor.run {
                if successCount > 0 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showToast = true
                        toastMessage = "EXPORTED \(successCount) \(selectedFormat.rawValue.uppercased()) FILE(S) TO FOLDER"
                    }
                }
                if !errorMessages.isEmpty {
                    showToastError(message: errorMessages.joined(separator: "\n"))
                }
                
                removeActiveTask(taskId)
            }
        }
        
        // Track the export task for cancellation
        let cancellable = AnyCancellable {
            exportTask.cancel()
        }
        addActiveTask(taskId, cancellable: cancellable)
    }
    
    private func showSavePanel() {
        let savePanel = NSSavePanel()
        savePanel.title = "Choose Export Location"
        savePanel.message = "Select a folder to save your exported files"
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = true
        savePanel.nameFieldStringValue = "PDF_Export_\(Date().timeIntervalSince1970)"
        
        // Set the file type based on selected format
        switch selectedFormat {
        case .png:
            savePanel.allowedContentTypes = [.png]
            savePanel.nameFieldStringValue += ".png"
        case .pdf:
            savePanel.allowedContentTypes = [.pdf]
        case .jpeg:
            savePanel.allowedContentTypes = [.jpeg]
            savePanel.nameFieldStringValue += ".jpeg"
        case .webp:
            savePanel.allowedContentTypes = [.webP]
            savePanel.nameFieldStringValue += ".webp"
        }
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Get the parent directory for export
                let directory = url.deletingLastPathComponent()
                Task {
                    await handleExport(to: directory)
                }
            }
        }
    }
    
    // MARK: - Cloud Export Sheet
    
    @ViewBuilder
    private func cloudExportSheet(pdfDocument: PDFDocument) -> some View {
        // Create a temporary file for the composed PDF
        if let composedFileURL = createTemporaryComposedPDF(pdfDocument: pdfDocument) {
            CloudStoragePickerView(
                localFileURL: composedFileURL,
                onComplete: { request, account in
                    // Handle successful cloud upload
                    showCloudExporter = false
                    showToastMessage("Successfully uploaded to \(account.provider.displayName)")
                    
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: composedFileURL)
                },
                onCancel: {
                    // Handle cancel
                    showCloudExporter = false
                    
                    // Clean up temporary file
                    try? FileManager.default.removeItem(at: composedFileURL)
                }
            )
        } else {
            // Fallback view if PDF creation fails
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.red)
                
                Text("Failed to prepare PDF for cloud export")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Button("Close") {
                    showCloudExporter = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(40)
            .background(Color.black)
        }
    }
    
    private func createTemporaryComposedPDF(pdfDocument: PDFDocument) -> URL? {
        // Create temporary directory for export
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("cloud_export_\(UUID().uuidString).pdf")
        
        do {
            // Create the composed PDF based on current composition mode
            let composedPDF = createComposedPDF(pdfDocument: pdfDocument)
            
            // Write to temporary file
            guard let pdfData = composedPDF.dataRepresentation() else {
                print("Failed to get PDF data representation")
                return nil
            }
            
            try pdfData.write(to: tempURL)
            return tempURL
            
        } catch {
            print("Failed to create temporary PDF for cloud export: \(error)")
            return nil
        }
    }
    
    private func createComposedPDF(pdfDocument: PDFDocument) -> PDFDocument {
        guard let coverIdx = viewModel.coverPageIndex,
              coverIdx < pdfDocument.pageCount,
              let coverPage = pdfDocument.page(at: coverIdx),
              !viewModel.citationPageIndices.isEmpty else {
            return pdfDocument // Return original if no composition needed
        }
        
        let newPDF = PDFDocument()
        
        // Add composed pages based on current mode
        for (index, citationIdx) in viewModel.citationPageIndices.enumerated() {
            guard citationIdx < pdfDocument.pageCount,
                  let citationPage = pdfDocument.page(at: citationIdx) else {
                continue
            }
            
            // Create composed image based on current mode
            let composedImage: NSImage
            switch selectedMode {
            case .centerCitation:
                composedImage = brutalistComposeBase(
                    citation: citationPage,
                    applyFrame: showOrnateFrame,
                    frameName: currentFrame
                )
            case .leftAlign:
                composedImage = brutalistComposeSideBySide(
                    citation: citationPage,
                    cover: coverPage,
                    applyFrame: showOrnateFrame,
                    frameName: currentFrame,
                    isPreview: false
                )
            case .rightAlign:
                // Use viewModel's cover position and size
                composedImage = brutalistComposeCustom(
                    citation: citationPage,
                    cover: coverPage,
                    coverPosition: viewModel.coverPosition,
                    coverSize: viewModel.coverSize,
                    applyFrame: showOrnateFrame,
                    frameName: currentFrame,
                    isPreview: false
                )
            case .fullPage:
                composedImage = brutalistComposeBase(
                    citation: citationPage,
                    applyFrame: showOrnateFrame,
                    frameName: currentFrame
                )
            }
            
            // Convert composed image to PDF page
            if let pdfPage = PDFPage(image: composedImage) {
                newPDF.insert(pdfPage, at: index)
            }
        }
        
        return newPDF
    }
    
    private func showToastMessage(_ message: String) {
        withAnimation {
            showToast = true
            toastMessage = message
        }
    }

    private func showToastError(message: String) {
        withAnimation {
            showToast = true
            toastMessage = message
        }
    }

    // Test frame analysis for a given frame
    private func testFrameAnalysis(frameName: String) {
        // Validate frame name
        guard !frameName.isEmpty else {
            showToastError(message: "Cannot analyze frame: Empty frame name")
            return
        }
        
        // Check if frame exists
        guard NSImage(named: frameName) != nil else {
            showToastError(message: "Cannot analyze frame: '\(frameName)' not found in assets")
            return
        }
        
        if let insets = FrameConfigProvider.analyzeAndUpdate(frameName: frameName) {
            // Validate insets are reasonable
            let totalHorizontal = insets.leading + insets.trailing
            let totalVertical = insets.top + insets.bottom
            
            if totalHorizontal >= 0.9 || totalVertical >= 0.9 {
                showToastError(message: "Frame analysis warning: Insets are very large (H:\(String(format: "%.1f%%", totalHorizontal * 100)), V:\(String(format: "%.1f%%", totalVertical * 100))). Content area may be too small.")
            } else {
                // Force a UI refresh to apply the new insets
                refreshID = UUID()
                
                // Show a toast with the analysis results
                showToastError(message: "Frame \(frameName) analyzed and applied. Insets: T:\(String(format: "%.2f", insets.top)) L:\(String(format: "%.2f", insets.leading)) B:\(String(format: "%.2f", insets.bottom)) R:\(String(format: "%.2f", insets.trailing))")
            }
        } else {
            showToastError(message: "Failed to analyze frame: \(frameName). Check that the image has transparent content areas.")
        }
    }

    // Helper method to create an analyze button
    private func createAnalyzeButton(for frameName: String) -> some View {
        Button {
            // Start with an analysis notification
            showToastError(message: "Analyzing frame \(frameName)...")

            // Use a slight delay to allow the UI to update first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                testFrameAnalysis(frameName: frameName)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))

                Text("ANALYZE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .foregroundColor(.white.opacity(0.7))
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help("Analyze frame to calculate optimal insets for content placement")
    }
}

// MARK: - Enhanced Progress Indicator
struct BrutalistProgressIndicator: View {
    let progress: Double
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            VStack(spacing: 8) {
                // Animated loading bars
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Rectangle()
                            .fill(Color(DesignTokens.brutalistPrimary))
                            .frame(width: 4, height: 20)
                            .opacity(progress > Double(index) * 0.2 ? 1.0 : 0.3)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                                value: progress
                            )
                    }
                }
                
                // Progress percentage
                BrutalistTechnicalText(
                    text: "RENDERING \(Int(progress * 100))%",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 10,
                    addDecorators: true,
                    align: .center
                )
            }
            .padding(12)
            .background(
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
            )
            .overlay(
                Rectangle()
                    .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
            )
        }
    }
}

// MARK: - Enhanced Image Loader
@MainActor
class EnhancedImageLoader: ObservableObject {
    @Published var image: NSImage?
    @Published var isLoading = false
    @Published var progress: Double = 0.0
    
    private var task: Task<Void, Never>?
    
    func loadImage(key: String, creator: @escaping () async -> NSImage?) {
        task?.cancel()
        
        // Check cache first
        if let cachedImage = PDFImageCache.shared.getCachedImage(for: key) {
            self.image = cachedImage
            self.isLoading = false
            self.progress = 1.0
            return
        }
        
        self.isLoading = true
        self.progress = 0.0
        
        task = Task { [weak self] in
            guard let self = self else { return }
            
            await self.updateProgress(0.1)
            
            if let newImage = await creator() {
                try? Task.checkCancellation()
                await self.updateProgress(0.8)
                
                PDFImageCache.shared.storeImage(newImage, forKey: key)
                await self.updateProgress(1.0)
                
                try? Task.checkCancellation()
                self.image = newImage
                self.isLoading = false
            } else {
                self.isLoading = false
                self.progress = 0.0
            }
        }
    }
    
    private func updateProgress(_ value: Double) async {
        self.progress = value
    }
    
    func cancel() {
        task?.cancel()
        isLoading = false
        progress = 0.0
    }
}

// MARK: - Rebuilt Side-by-Side Preview
struct ImprovedSideBySideView: View {
    let citationPage: PDFPage
    let coverPage: PDFPage
    var showFrame: Bool = false
    var frameName: String = "frameH"
    
    @State private var citationImage: NSImage?
    @State private var coverImage: NSImage?
    @State private var isLoading = true
    
    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                BrutalistProgressIndicator(
                    progress: 0.5,
                    isVisible: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let citationImage = citationImage, let coverImage = coverImage {
                // Side-by-side layout with no gaps
                HStack(spacing: 0) {
                    // Citation image (left side)
                    Image(nsImage: citationImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width / 2, height: geometry.size.height)
                        .clipped()
                    
                    // Cover image (right side) 
                    Image(nsImage: coverImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width / 2, height: geometry.size.height)
                        .clipped()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    
                    Text("RENDER ERROR")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            loadImages()
        }
        .onChange(of: showFrame) { 
            loadImages()
        }
        .onChange(of: frameName) {
            loadImages()
        }
    }
    
    private func loadImages() {
        isLoading = true
        
        Task {
            // Scale images appropriately for preview while maintaining aspect ratios
            let citationBounds = citationPage.bounds(for: .cropBox)
            let coverBounds = coverPage.bounds(for: .cropBox)
            
            // Scale to reasonable preview sizes while maintaining aspect ratios
            let previewScale: CGFloat = 600 // Max dimension for side-by-side preview
            
            let citationScale = min(previewScale / citationBounds.width, previewScale / citationBounds.height)
            let citationPreviewSize = CGSize(
                width: citationBounds.width * citationScale,
                height: citationBounds.height * citationScale
            )
            
            let coverScale = min(previewScale / coverBounds.width, previewScale / coverBounds.height)
            let coverPreviewSize = CGSize(
                width: coverBounds.width * coverScale,
                height: coverBounds.height * coverScale
            )
            
            // Render at scaled preview sizes
            let citationImg = await renderPDFImage(citationPage, targetSize: citationPreviewSize)
            let coverImg = await renderPDFImage(coverPage, targetSize: coverPreviewSize)
            
            await MainActor.run {
                self.citationImage = citationImg
                self.coverImage = coverImg
                self.isLoading = false
            }
        }
    }
    
    private func renderPDFImage(_ page: PDFPage, targetSize: CGSize) async -> NSImage? {
        return await Task.detached {
            let pageRect = page.bounds(for: .cropBox)
            let image = NSImage(size: targetSize)
            
            image.lockFocus()
            defer { image.unlockFocus() }
            
            // White background
            NSColor.white.setFill()
            NSRect(origin: .zero, size: targetSize).fill()
            
            // Calculate scaling to fit the target size
            let scaleX = targetSize.width / pageRect.width
            let scaleY = targetSize.height / pageRect.height
            let scale = min(scaleX, scaleY) // Use min to fit completely without cropping
            
            let scaledWidth = pageRect.width * scale
            let scaledHeight = pageRect.height * scale
            
            // Center the content
            let offsetX = (targetSize.width - scaledWidth) / 2
            let offsetY = (targetSize.height - scaledHeight) / 2
            
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.translateBy(x: offsetX, y: offsetY)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
                
                page.draw(with: .cropBox, to: context)
                context.restoreGState()
            }
            
            return image
        }.value
    }
}

// MARK: - Rebuilt Custom Overlay Preview
struct ImprovedCustomOverlayView: View {
    let citationPage: PDFPage
    let coverPage: PDFPage
    @Binding var coverPosition: CGPoint
    @Binding var coverSize: CGSize
    var showFrame: Bool = false
    var frameName: String = "frameV"
    
    @State private var citationImage: NSImage?
    @State private var coverImage: NSImage?
    @State private var isLoading = true
    @State private var currentScale: CGFloat = 0.25 // Start at 25% size
    
    var body: some View {
        GeometryReader { geometry in
            if isLoading {
                BrutalistProgressIndicator(
                    progress: 0.5,
                    isVisible: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let citationImage = citationImage, let coverImage = coverImage {
                ZStack {
                    // Citation background (fills entire area)
                    Image(nsImage: citationImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    
                    // Cover overlay (draggable and resizable)
                    RebuildCoverOverlay(
                        coverImage: coverImage,
                        position: $coverPosition,
                        scale: $currentScale,
                        containerSize: geometry.size,
                        citationSize: geometry.size
                    )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                // Error state
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    
                    Text("RENDER ERROR")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
            }
        }
        .onAppear {
            loadImages()
            initializeCoverPosition()
        }
        .onChange(of: showFrame) {
            loadImages()
        }
        .onChange(of: frameName) {
            loadImages()
        }
        .onChange(of: currentScale) {
            // Update coverSize binding when scale changes
            coverSize = CGSize(width: currentScale, height: currentScale)
        }
    }
    
    private func loadImages() {
        isLoading = true
        
        Task {
            // Scale images appropriately for preview while maintaining aspect ratios
            let citationBounds = citationPage.bounds(for: .cropBox)
            let coverBounds = coverPage.bounds(for: .cropBox)
            
            // Scale to reasonable preview sizes while maintaining aspect ratios
            let previewScale: CGFloat = 800 // Max dimension for preview
            
            let citationScale = min(previewScale / citationBounds.width, previewScale / citationBounds.height)
            let citationPreviewSize = CGSize(
                width: citationBounds.width * citationScale,
                height: citationBounds.height * citationScale
            )
            
            let coverScale = min(previewScale / coverBounds.width, previewScale / coverBounds.height)
            let coverPreviewSize = CGSize(
                width: coverBounds.width * coverScale,
                height: coverBounds.height * coverScale
            )
            
            // Render at scaled preview sizes
            let citationImg = await renderPDFImage(citationPage, targetSize: citationPreviewSize)
            let coverImg = await renderPDFImage(coverPage, targetSize: coverPreviewSize)
            
            await MainActor.run {
                self.citationImage = citationImg
                self.coverImage = coverImg
                self.isLoading = false
            }
        }
    }
    
    private func initializeCoverPosition() {
        // Initialize cover position to top-center if not set
        if coverPosition == .zero {
            coverPosition = CGPoint(x: 0.5, y: 0.2) // Top center
        }
        // Initialize scale from coverSize if available
        if coverSize.width > 0 {
            currentScale = coverSize.width
        }
    }
    
    private func renderPDFImage(_ page: PDFPage, targetSize: CGSize) async -> NSImage? {
        return await Task.detached {
            let pageRect = page.bounds(for: .cropBox)
            let image = NSImage(size: targetSize)
            
            image.lockFocus()
            defer { image.unlockFocus() }
            
            // White background
            NSColor.white.setFill()
            NSRect(origin: .zero, size: targetSize).fill()
            
            // Calculate scaling to fit the target size
            let scaleX = targetSize.width / pageRect.width
            let scaleY = targetSize.height / pageRect.height
            let scale = min(scaleX, scaleY)
            
            let scaledWidth = pageRect.width * scale
            let scaledHeight = pageRect.height * scale
            
            // Center the content
            let offsetX = (targetSize.width - scaledWidth) / 2
            let offsetY = (targetSize.height - scaledHeight) / 2
            
            if let context = NSGraphicsContext.current?.cgContext {
                context.saveGState()
                context.translateBy(x: offsetX, y: offsetY)
                context.scaleBy(x: scale, y: scale)
                context.translateBy(x: -pageRect.origin.x, y: -pageRect.origin.y)
                
                page.draw(with: .cropBox, to: context)
                context.restoreGState()
            }
            
            return image
        }.value
    }
}

// MARK: - Rebuilt Cover Overlay Component
struct RebuildCoverOverlay: View {
    let coverImage: NSImage
    @Binding var position: CGPoint
    @Binding var scale: CGFloat
    let containerSize: CGSize
    let citationSize: CGSize
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @GestureState private var magnification: CGFloat = 1.0
    
    var body: some View {
        let coverSize = CGSize(
            width: containerSize.width * scale * magnification,
            height: containerSize.height * scale * magnification
        )
        
        Image(nsImage: coverImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: coverSize.width, height: coverSize.height)
            .position(
                x: max(coverSize.width/2, min(containerSize.width - coverSize.width/2, position.x * containerSize.width + dragOffset.width)),
                y: max(coverSize.height/2, min(containerSize.height - coverSize.height/2, position.y * containerSize.height + dragOffset.height))
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
            .overlay(
                // Resize handles
                Group {
                    if isDragging || magnification != 1.0 {
                        // Corner resize handles
                        Circle()
                            .fill(Color(DesignTokens.brutalistPrimary))
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .position(
                                x: coverSize.width - 10,
                                y: coverSize.height - 10
                            )
                    }
                }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        // Update the binding position and constrain within citation bounds
                        let newX = max(0, min(1, (position.x * containerSize.width + value.translation.width) / containerSize.width))
                        let newY = max(0, min(1, (position.y * containerSize.height + value.translation.height) / containerSize.height))
                        
                        position = CGPoint(x: newX, y: newY)
                        dragOffset = .zero
                        isDragging = false
                    }
            )
            .scaleEffect(magnification)
            .gesture(
                MagnificationGesture()
                    .updating($magnification) { currentState, gestureState, transaction in
                        gestureState = currentState
                    }
                    .onEnded { value in
                        // Update scale with limits (10% to 80% of container)
                        let newScale = max(0.1, min(0.8, scale * value))
                        scale = newScale
                    }
            )
    }
}


// Simple side-by-side composition view - show images as-is
struct SideBySideView: View {
    let citationPage: PDFPage
    let coverPage: PDFPage
    var showFrame: Bool = false
    var frameName: String = "frameH"
    
    @StateObject private var imageLoader = AsyncImageLoader()
    @State private var loadingTask: Task<Void, Never>?

    var body: some View {
        Group {
            // Render composed image or show progress
            if let image = imageLoader.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if imageLoader.isLoading {
                // Show progress indicator
                BrutalistProgressIndicator(
                    progress: imageLoader.progress,
                    isVisible: true
                )
            } else {
                // Fallback error state - brutalist error styling
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    
                    BrutalistTechnicalText(
                        text: "RENDER ERROR",
                        color: Color(DesignTokens.brutalistPrimary),
                        size: 12,
                        addDecorators: true,
                        align: .center
                    )
                    
                    Text("Failed to render preview composition")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .background(
                    Rectangle()
                        .fill(Color.black.opacity(0.6))
                        .brutalistTexture(style: .noise, intensity: 0.3, color: .white)
                )
                .overlay(
                    Rectangle()
                        .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                )
            }
        }
        .onAppear {
            loadImageAsync()
        }
        .onDisappear {
            // Cancel loading when view disappears
            loadingTask?.cancel()
            imageLoader.cancel()
        }
        .onChange(of: showFrame) {
            loadImageAsync()
        }
        .onChange(of: frameName) {
            loadImageAsync()
        }
    }
    
    private func loadImageAsync() {
        // Cancel any existing task
        loadingTask?.cancel()
        imageLoader.cancel()
        
        let frameExists = NSImage(named: frameName) != nil
        let citationHash = citationPage.string?.hash ?? 0
        let coverHash = coverPage.string?.hash ?? 0
        let key = "sideBySide_\(frameName)_\(showFrame && frameExists)_\(citationHash)_\(coverHash)"
        
        imageLoader.loadImage(key: key, mode: .preview) {
            return try await withCheckedThrowingContinuation { continuation in
                Task.detached(priority: .userInitiated) {
                    do {
                        let image = brutalistComposeSideBySide(
                            citation: citationPage,
                            cover: coverPage,
                            applyFrame: showFrame && frameExists,
                            frameName: frameName
                        )
                        continuation.resume(returning: image)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

}

// Custom overlay composition view
struct CustomOverlayView: View {
    let citationPage: PDFPage
    let coverPage: PDFPage
    @Binding var coverPosition: CGPoint
    @Binding var coverSize: CGSize
    @State private var isResizing = false
    @State private var isDragging = false
    @State private var cachedCoverImage: NSImage? = nil
    @State private var cachedBackgroundImage: NSImage? = nil
    @State private var isLoadingCover = false
    @State private var coverProgress: Double = 0.0
    var showFrame: Bool = false
    var frameName: String = "frameV"

    // Get frame insets from centralized provider
    private var frameInsets: EdgeInsets {
        return FrameConfigProvider.getInsets(for: frameName).edgeInsets
    }

    var body: some View {
        ZStack {
            // BACKGROUND: Citation and frame
            // Load background on appear
            if cachedBackgroundImage == nil {
                Color.clear.onAppear {
                    let frameExists = NSImage(named: frameName) != nil
                    cachedBackgroundImage = renderBaseComposition(
                        citation: citationPage,
                        showFrame: showFrame && frameExists,
                        frameName: frameName
                    )
                }
            }

            // Display background - fill completely
            if let backgroundImage = cachedBackgroundImage {
                Image(nsImage: backgroundImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            }

            // Remove cover loading for now - just test visibility

            // ALWAYS SHOW A VISIBLE COVER - TESTING
            Rectangle()
                .fill(Color.blue.opacity(0.8))
                .frame(width: 300, height: 300)
                .overlay(
                    Text("COVER TEST")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
                .overlay(
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 5)
                )
        }
        .onDisappear {
            // Clean up cached images when view disappears
            cachedBackgroundImage = nil
            cachedCoverImage = nil
        }
        .onChange(of: showFrame) {
            // Force re-render background
            cachedBackgroundImage = nil
        }
        .onChange(of: frameName) {
            // Force re-render background
            cachedBackgroundImage = nil
        }
    }

    // Render just the background (citation + frame) without the cover - simple version
    private func renderBaseComposition(
        citation: PDFPage,
        showFrame: Bool,
        frameName: String
    ) -> NSImage? {
        // Use a fixed aspect ratio that fills the view properly
        let renderSize = CGSize(width: 600, height: 800)

        // Create the composed image
        let composed = NSImage(size: renderSize)
        
        composed.lockFocus()
        defer { composed.unlockFocus() }

        // Fill with white background
        NSColor.white.set()
        NSRect(origin: .zero, size: renderSize).fill()

        // Draw citation page to completely fill the background
        let citationImg = renderPDFPageToImage(
            citation, 
            size: renderSize, 
            renderMode: .fill
        )
        citationImg.draw(in: NSRect(origin: .zero, size: renderSize), from: .zero, operation: .sourceOver, fraction: 1.0)

        // Draw frame if enabled
        if showFrame {
            if let frameImg = NSImage(named: frameName) ?? NSImage(named: "frameV") {
                frameImg.draw(in: NSRect(origin: .zero, size: renderSize), from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }

        return composed
    }
}

// Separate view to handle the cover overlay and interactions
struct CoverOverlay: View {
    let coverImage: NSImage?
    @Binding var position: CGPoint
    @Binding var size: CGSize
    @Binding var isDragging: Bool
    @Binding var isResizing: Bool
    let frameInsets: EdgeInsets

    // Use gesture states to track ongoing gestures without modifying state during update
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var resizeOffset: CGSize = .zero
    @State private var dragStartPosition: CGPoint = .zero
    @State private var resizeStartSize: CGSize = .zero
    @State private var isLoadingCover = false
    @State private var coverProgress: Double = 0.0

    var body: some View {
        GeometryReader { geo in
            // Calculate content area - ensure minimum size
            let minContentWidth = max(200, geo.size.width * (1 - frameInsets.leading - frameInsets.trailing))
            let minContentHeight = max(200, geo.size.height * (1 - frameInsets.top - frameInsets.bottom))
            let contentWidth = minContentWidth
            let contentHeight = minContentHeight
            let contentX = geo.size.width * frameInsets.leading
            let contentY = geo.size.height * frameInsets.top

            // Calculate cover dimensions and position - ensure minimum visible size
            let minSize: CGFloat = 150 // Minimum size to ensure visibility
            let coverWidth = max(minSize, contentWidth * size.width)
            let coverHeight = max(minSize, contentHeight * size.height)

            // Base position
            let baseX = contentX + (contentWidth * position.x) - (coverWidth / 2)
            let baseY = contentY + (contentHeight * position.y) - (coverHeight / 2)

            // Drag offset in screen coordinates
            let draggedX = baseX + dragOffset.width
            let draggedY = baseY + dragOffset.height

            // Calculate resized dimensions in screen coordinates
            let resizedWidth = coverWidth + resizeOffset.width
            let resizedHeight = coverHeight + resizeOffset.height

            ZStack {
                // Cover image with current position and size - center and make visible
                if let image = coverImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .overlay(
                            Rectangle()
                                .stroke(Color.green, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.8), radius: 6, x: 3, y: 3)
                        .drawingGroup()
                } else {
                    // Show prominent placeholder when no cover image
                    Rectangle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 200, height: 200)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .overlay(
                            VStack {
                                Text("NO COVER")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("IMAGE LOADED")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        )
                        .overlay(
                            Rectangle()
                                .stroke(Color.yellow, lineWidth: 4)
                        )
                }
                
                if isLoadingCover {
                    // Show loading indicator for cover
                    VStack(spacing: 4) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(DesignTokens.brutalistPrimary)))
                            .scaleEffect(0.8)
                        
                        Text("\(Int(coverProgress * 100))%")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    }
                    .frame(width: resizedWidth, height: resizedHeight)
                    .position(x: draggedX + resizedWidth/2, y: draggedY + resizedHeight/2)
                    .background(
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: resizedWidth, height: resizedHeight)
                    )
                }

                // Resize handle - improved visibility and interaction
                ZStack {
                    // Outer ring for better visibility
                    Circle()
                        .strokeBorder(Color(DesignTokens.brutalistPrimary), lineWidth: 2)
                        .background(Circle().fill(Color.black.opacity(0.8)))
                        .frame(width: 24, height: 24)
                    
                    // Inner handle
                    Circle()
                        .fill(Color(DesignTokens.brutalistPrimary))
                        .frame(width: 12, height: 12)
                    
                    // Resize icon
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.black)
                }
                .position(x: draggedX + resizedWidth - 12, y: draggedY + resizedHeight - 12)
                .opacity(isDragging || isResizing ? 1.0 : 0.7)
                .scaleEffect(isDragging || isResizing ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .animation(.easeInOut(duration: 0.2), value: isResizing)
                .gesture(
                    // Resize gesture on the handle
                    DragGesture()
                        .updating($resizeOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onChanged { _ in
                            if resizeStartSize == .zero {
                                resizeStartSize = size
                            }
                            isResizing = true
                        }
                        .onEnded { value in
                            // Convert to normalized coordinates
                            let deltaWidth = value.translation.width / contentWidth
                            let deltaHeight = value.translation.height / contentHeight

                            // Apply to size with constraints
                            var newWidth = resizeStartSize.width + deltaWidth
                            var newHeight = resizeStartSize.height + deltaHeight

                            // Clamp to valid range with better bounds checking
                            let minSizeNormalized = max(40 / contentWidth, 0.05)
                            let maxSizeNormalized = 0.8
                            newWidth = max(minSizeNormalized, min(newWidth, maxSizeNormalized))
                            newHeight = max(minSizeNormalized, min(newHeight, maxSizeNormalized))

                            // Update size
                            size = CGSize(width: newWidth, height: newHeight)
                            resizeStartSize = .zero
                            isResizing = false
                        }
                )
            }
            // Drag gesture for the entire cover area
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .updating($dragOffset) { value, state, _ in
                        // Only apply drag if we're not near the resize handle
                        let handleX = baseX + coverWidth - 12
                        let handleY = baseY + coverHeight - 12
                        let hitDistance: CGFloat = 30

                        if abs(value.startLocation.x - handleX) < hitDistance &&
                           abs(value.startLocation.y - handleY) < hitDistance {
                            // Near resize handle, don't apply drag
                            return
                        }

                        // Otherwise, apply drag offset directly to view
                        state = value.translation
                    }
                    .onChanged { _ in
                        if dragStartPosition == .zero {
                            dragStartPosition = position
                        }
                    }
                    .onEnded { value in
                        // Convert pixel offset to normalized position
                        let dx = value.translation.width / contentWidth
                        let dy = value.translation.height / contentHeight

                        // Apply to position with constraints
                        var newX = dragStartPosition.x + dx
                        var newY = dragStartPosition.y + dy

                        // Improved bounds checking with padding
                        let halfW = size.width / 2
                        let halfH = size.height / 2
                        let padding: CGFloat = 0.05 // 5% padding from edges
                        
                        // Ensure the cover stays within bounds with padding
                        let minX = max(halfW, padding)
                        let maxX = min(1 - halfW, 1 - padding)
                        let minY = max(halfH, padding)
                        let maxY = min(1 - halfH, 1 - padding)
                        
                        newX = min(max(minX, newX), maxX)
                        newY = min(max(minY, newY), maxY)

                        // Update position
                        position = CGPoint(x: newX, y: newY)
                        dragStartPosition = .zero
                        isDragging = false
                    }
            )
            .onChange(of: dragOffset) { newValue in
                isDragging = newValue != .zero
            }
            .onChange(of: resizeOffset) { newValue in
                isResizing = newValue != .zero
            }
        }
    }
}

// MARK: - Performance Monitoring
class PerformanceMonitor {
    static func measureTime<T>(operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        if timeElapsed > 0.1 { // Log operations taking longer than 100ms
            print("⏱️ \(operation) took \(String(format: "%.2f", timeElapsed))s")
        }
        
        return result
    }
    
    static func logMemoryUsage(context: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsage = Double(info.resident_size) / (1024 * 1024) // Convert to MB
            if memoryUsage > 100 { // Log if using more than 100MB
                print("📊 Memory usage at \(context): \(String(format: "%.1f", memoryUsage)) MB")
            }
        }
    }
}

// Enhanced helper function to render a PDFPage with performance monitoring
enum PDFRenderMode {
    case fit           // Fit entire page, may have white space
    case fill          // Fill entire area, may crop content
    case adaptiveFit    // Smart fit that minimizes white space while preserving content
    case adaptiveFill   // Smart fill that maximizes space usage with minimal cropping
}

func renderPDFPageToImage(_ page: PDFPage, size: CGSize, box: PDFDisplayBox = .cropBox, isPreview: Bool = true, renderMode: PDFRenderMode = .adaptiveFit) -> NSImage {
    return PerformanceMonitor.measureTime(operation: "PDF page render (\(Int(size.width))x\(Int(size.height)))") {
        // Optimize size for preview mode to reduce memory usage
        let optimizedSize = isPreview ? optimizeSizeForPreview(size) : size
        let image = NSImage(size: optimizedSize)
        
        // Ensure proper resource cleanup and memory management
        defer {
            NSGraphicsContext.current?.flushGraphics()
            
            // Force memory cleanup for large images
            if optimizedSize.width * optimizedSize.height > 4_000_000 { // > 4MP
                PerformanceMonitor.logMemoryUsage(context: "after large PDF render")
                // Trigger garbage collection for large renders
                autoreleasepool {
                    // Empty pool to force cleanup
                }
            }
        }
        
        image.lockFocus()
        defer { image.unlockFocus() }
        
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            print("⚠️ Failed to get graphics context for PDF rendering")
            return image
        }
        
        ctx.saveGState()
        defer { ctx.restoreGState() }
        
        // Optimize rendering quality based on mode
        if isPreview {
            // Balanced quality for previews
            ctx.interpolationQuality = .medium
            ctx.setShouldAntialias(true)
            ctx.setAllowsAntialiasing(true)
        } else {
            // High quality for exports
            ctx.interpolationQuality = .high
            ctx.setShouldAntialias(true)
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldSubpixelPositionFonts(true)
            ctx.setShouldSubpixelQuantizeFonts(true)
        }
        
        // White background for PDFs with transparency
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: optimizedSize))
        
        // Calculate the transform based on render mode with adaptive logic
        let pdfBounds = page.bounds(for: box)
        guard pdfBounds.width > 0 && pdfBounds.height > 0 else {
            print("⚠️ Invalid PDF bounds: \(pdfBounds)")
            return image
        }
        
        let scaleX = optimizedSize.width / pdfBounds.width
        let scaleY = optimizedSize.height / pdfBounds.height
        let targetRatio = optimizedSize.width / optimizedSize.height
        let pdfRatio = pdfBounds.width / pdfBounds.height
        
        let scale: CGFloat
        var cropArea: CGRect = CGRect.zero // Track what area of PDF to show
        
        switch renderMode {
        case .fit:
            // FIT mode: Use min scale to fit the entire page (may leave white space)
            scale = min(scaleX, scaleY)
            cropArea = pdfBounds // Show entire PDF
            
        case .fill:
            // FILL mode: Use max scale to fill the entire area (may crop content)
            scale = max(scaleX, scaleY)
            // Calculate what portion of PDF will be visible
            let visibleWidth = min(pdfBounds.width, optimizedSize.width / scale)
            let visibleHeight = min(pdfBounds.height, optimizedSize.height / scale)
            cropArea = CGRect(
                x: pdfBounds.origin.x + (pdfBounds.width - visibleWidth) / 2,
                y: pdfBounds.origin.y + (pdfBounds.height - visibleHeight) / 2,
                width: visibleWidth,
                height: visibleHeight
            )
            
        case .adaptiveFit:
            // ADAPTIVE FIT: Conservative approach - prioritize content preservation for citations
            let ratioSimilarity = min(targetRatio, pdfRatio) / max(targetRatio, pdfRatio)
            let cropAmount = 1.0 - (min(scaleX, scaleY) / max(scaleX, scaleY))
            
            // Be more conservative for citations - only use fill for very similar ratios
            if ratioSimilarity > 0.90 && cropAmount < 0.10 {
                // Use fill only for nearly identical ratios with minimal cropping
                scale = max(scaleX, scaleY)
                let visibleWidth = min(pdfBounds.width, optimizedSize.width / scale)
                let visibleHeight = min(pdfBounds.height, optimizedSize.height / scale)
                cropArea = CGRect(
                    x: pdfBounds.origin.x + (pdfBounds.width - visibleWidth) / 2,
                    y: pdfBounds.origin.y,
                    width: visibleWidth,
                    height: visibleHeight
                )
            } else {
                // Use fit to preserve all content for citations
                scale = min(scaleX, scaleY)
                cropArea = pdfBounds
            }
            
        case .adaptiveFill:
            // ADAPTIVE FILL: Maximize space usage while preserving top content for covers
            let widthExcess = pdfBounds.width * scaleY - optimizedSize.width
            let heightExcess = pdfBounds.height * scaleX - optimizedSize.height
            
            if abs(widthExcess) < abs(heightExcess) {
                // Width is closer to fitting - scale to width and crop height from bottom
                scale = scaleX
                let visibleHeight = optimizedSize.height / scale
                // Always preserve top content for covers - crop only from bottom
                cropArea = CGRect(
                    x: pdfBounds.origin.x,
                    y: pdfBounds.origin.y, // Start from top
                    width: pdfBounds.width,
                    height: min(visibleHeight, pdfBounds.height)
                )
            } else {
                // Height is closer to fitting - scale to height and crop width from center
                scale = scaleY
                let visibleWidth = optimizedSize.width / scale
                let cropX = pdfBounds.origin.x + (pdfBounds.width - visibleWidth) / 2 // Center horizontally
                cropArea = CGRect(
                    x: max(pdfBounds.origin.x, cropX),
                    y: pdfBounds.origin.y,
                    width: min(visibleWidth, pdfBounds.width),
                    height: pdfBounds.height
                )
            }
        }
        
        // Calculate the final scaled size based on crop area
        let scaledWidth = cropArea.width * scale
        let scaledHeight = cropArea.height * scale
        
        // Center the PDF in the target area
        let offsetX = (optimizedSize.width - scaledWidth) / 2
        let offsetY = (optimizedSize.height - scaledHeight) / 2
        
        // Apply transforms with crop area offset
        ctx.translateBy(x: offsetX, y: offsetY)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -cropArea.origin.x, y: -cropArea.origin.y)
        
        // Set clipping rect to crop area if needed
        if renderMode == .fill || renderMode == .adaptiveFill {
            ctx.clip(to: cropArea)
        }
        
        // Safely draw the PDF page with memory protection
        autoreleasepool {
            do {
                page.draw(with: box, to: ctx)
            } catch {
                print("⚠️ Failed to draw PDF page: \(error.localizedDescription)")
            }
        }
        
        return image
    }
}

// Helper function to optimize image size for preview mode
private func optimizeSizeForPreview(_ size: CGSize) -> CGSize {
    let maxPreviewDimension: CGFloat = 800 // Match AsyncImageLoader preview size
    let maxDimension = max(size.width, size.height)
    
    if maxDimension <= maxPreviewDimension {
        return size
    }
    
    let scale = maxPreviewDimension / maxDimension
    return CGSize(width: size.width * scale, height: size.height * scale)
}

// Helper function to render only the base composition (citation + frame)
func brutalistComposeBase(citation: PDFPage, applyFrame: Bool = false, frameName: String) -> NSImage {
    // Use a portrait-oriented size for vertical frames - better proportions
    let size = CGSize(width: 1800, height: 2600) // Better width-to-height ratio (was 1600x2800)

    // Get frame insets from the provider
    let frameInsets = FrameConfigProvider.getInsets(for: frameName)

    // Calculate content area based on insets
    let contentWidth = size.width * (1 - frameInsets.leading - frameInsets.trailing)
    let contentHeight = size.height * (1 - frameInsets.top - frameInsets.bottom)
    let contentX = size.width * frameInsets.leading
    let contentY = size.height * frameInsets.top

    // Calculate content rectangle
    let contentRect = NSRect(
        x: contentX,
        y: contentY,
        width: contentWidth,
        height: contentHeight
    )

    // Create the composed image with transparent background
    let composed = NSImage(size: size)
    composed.lockFocus()

    // Create transparent background
    NSColor.clear.set()
    NSRect(origin: .zero, size: size).fill()

    // Draw frame first if enabled - ensure the frame exists before trying to draw
    if applyFrame {
        let frameImg: NSImage?

        // Try with exact name first
        if let exactFrame = NSImage(named: frameName) {
            frameImg = exactFrame
        }
        // If that fails and this is a custom mode (vertical frame), try a fallback
        else if frameName.hasSuffix("V") || frameName.contains("V") {
            frameImg = NSImage(named: "frameV")
        }
        // For horizontal frame fallback
        else {
            frameImg = NSImage(named: "frameH")
        }

        // Draw the frame if we found one
        if let frameImg = frameImg {
            frameImg.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        } else {
            // If no frame was found, draw white background in content area only
            NSColor.white.set()
            contentRect.fill()

            // Log the issue
            print("⚠️ Failed to load frame image: \(frameName)")
        }
    } else {
        // No frame: draw white background only in content area
        NSColor.white.set()
        contentRect.fill()
    }

    // Draw citation in content area with reasonable resolution (2x for retina displays)
    let citationImg = renderPDFPageToImage(citation, size: NSSize(width: contentRect.width * 2, height: contentRect.height * 2), renderMode: .adaptiveFit)
    citationImg.draw(in: contentRect, from: .zero, operation: .sourceOver, fraction: 1.0)

    composed.unlockFocus()
    return composed
}

// Helper view for maintaining aspect ratio
struct AspectRatio<Content: View>: View {
    let ratio: CGFloat
    let content: (CGFloat) -> Content

    init(_ ratio: CGFloat, @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.ratio = ratio
        self.content = content
    }

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width, geo.size.height * ratio)
            let height = width / ratio

            ZStack(alignment: .center) {
                content(width)
                    .frame(width: width, height: height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// Helper function for side-by-side composition
func aspectFitRect(for imageSize: NSSize, in targetRect: NSRect) -> NSRect {
    let imageAspect = imageSize.width / imageSize.height
    let targetAspect = targetRect.width / targetRect.height
    var drawSize = NSSize.zero
    if imageAspect > targetAspect {
        // Image is wider: scale by width, letterbox top/bottom
        drawSize.width = targetRect.width
        drawSize.height = targetRect.width / imageAspect
    } else {
        // Image is taller: scale by height, letterbox sides
        drawSize.height = targetRect.height
        drawSize.width = targetRect.height * imageAspect
    }
    let drawOrigin = NSPoint(
        x: targetRect.origin.x + (targetRect.width - drawSize.width) / 2,
        y: targetRect.origin.y + (targetRect.height - drawSize.height) / 2
    )
    return NSRect(origin: drawOrigin, size: drawSize)
}

func brutalistComposeSideBySide(citation: PDFPage, cover: PDFPage, applyFrame: Bool = false, frameName: String, isPreview: Bool = true) -> NSImage {
    return autoreleasepool {
        // Use page dimensions to avoid cropping
        let citationBounds = citation.bounds(for: .cropBox)
        let coverBounds = cover.bounds(for: .cropBox)
        
        // Calculate canvas size - use the taller page height and combine widths
        let canvasHeight = max(citationBounds.height, coverBounds.height)
        let canvasWidth = citationBounds.width + coverBounds.width
        let scaledSize = CGSize(width: canvasWidth, height: canvasHeight)
        
        // Create composition image
        let composedImage = NSImage(size: scaledSize)
        
        composedImage.lockFocus()
        defer { 
            composedImage.unlockFocus()
            if !isPreview {
                NSGraphicsContext.current?.flushGraphics()
            }
        }
        
        // Fill background
        NSColor.white.set()
        NSRect(origin: .zero, size: scaledSize).fill()
        
        // Draw citation page on left side without cropping
        let citationRect = NSRect(x: 0, y: 0, width: citationBounds.width, height: canvasHeight)
        let citationImage = renderPDFPageToImage(
            citation,
            size: CGSize(width: citationBounds.width, height: canvasHeight),
            renderMode: .fit
        )
        citationImage.draw(in: citationRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        // Draw cover page on right side without cropping
        let coverRect = NSRect(x: citationBounds.width, y: 0, width: coverBounds.width, height: canvasHeight)
        let coverImage = renderPDFPageToImage(
            cover,
            size: CGSize(width: coverBounds.width, height: canvasHeight),
            renderMode: .fit
        )
        coverImage.draw(in: coverRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        
        return composedImage
    }
}

// Simplified custom overlay composition - citation full size + cover overlay at 25%
func brutalistComposeCustom(citation: PDFPage, cover: PDFPage, coverPosition: CGPoint, coverSize: CGSize, applyFrame: Bool = false, frameName: String, isPreview: Bool = true) -> NSImage {
    // Use the citation page dimensions as the base canvas size
    let citationBounds = citation.bounds(for: .cropBox)
    let size = CGSize(width: citationBounds.width, height: citationBounds.height)

    let composed = NSImage(size: size)
    composed.lockFocus()
    defer { composed.unlockFocus() }

    // White background
    NSColor.white.set()
    NSRect(origin: .zero, size: size).fill()

    // Draw citation page filling the entire canvas without cropping
    let citationImg = renderPDFPageToImage(citation, size: size, renderMode: .fit)
    citationImg.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)

    // Calculate cover overlay at 25% size
    let coverScale: CGFloat = 0.25
    let coverWidth = size.width * coverScale
    let coverHeight = size.height * coverScale
    
    // Position cover based on coverPosition (center if not specified)
    let coverX = (size.width * coverPosition.x) - (coverWidth / 2)
    let coverY = (size.height * (1 - coverPosition.y)) - (coverHeight / 2) // Flip Y coordinate
    
    // Draw cover overlay without cropping
    let coverImg = renderPDFPageToImage(cover, size: NSSize(width: coverWidth, height: coverHeight), renderMode: .fit)
    coverImg.draw(
        in: NSRect(x: coverX, y: coverY, width: coverWidth, height: coverHeight),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )

    return composed
}

// Helper function to convert image to PDF with better error handling
func brutalistImageToPDFData(image: NSImage) -> Data? {
    // Validate input image
    guard image.size.width > 0 && image.size.height > 0 else {
        print("⚠️ Cannot convert to PDF: Invalid image size \(image.size)")
        return nil
    }
    
    guard image.representations.first != nil else {
        print("⚠️ Cannot convert to PDF: No image representations found")
        return nil
    }
    
    let pdf = PDFDocument()
    
    // Create PDF page from image with error handling
    guard let pdfPage = PDFPage(image: image) else {
        print("⚠️ Cannot convert to PDF: Failed to create PDF page from image")
        return nil
    }
    
    // Validate PDF page bounds
    let pageBounds = pdfPage.bounds(for: .cropBox)
    guard pageBounds.width > 0 && pageBounds.height > 0 else {
        print("⚠️ Cannot convert to PDF: PDF page has invalid bounds \(pageBounds)")
        return nil
    }
    
    pdf.insert(pdfPage, at: 0)
    
    // Generate PDF data with validation
    guard let pdfData = pdf.dataRepresentation(), pdfData.count > 0 else {
        print("⚠️ Cannot convert to PDF: Failed to generate PDF data or data is empty")
        return nil
    }
    
    return pdfData
}

// --- Begin: FrameConfig, FramedPDFThumbnail, SideBySideFramedView ---

struct FrameConfig: Equatable {
    let contentScale: CGFloat
    let contentOffsetX: CGFloat
    let contentOffsetY: CGFloat
    let aspectRatio: CGFloat

    static let ornateClassicFrame = FrameConfig(
        contentScale: 0.65,
        contentOffsetX: 0.0,
        contentOffsetY: 0.0,
        aspectRatio: 0.7
    )
    static let ornateGoldFrame = FrameConfig(
        contentScale: 0.42,
        contentOffsetX: 0.0,
        contentOffsetY: -0.01,
        aspectRatio: 0.7
    )
    static let ornateGoldFrameLeftPage = FrameConfig(
        contentScale: 0.42,
        contentOffsetX: -0.005,
        contentOffsetY: -0.01,
        aspectRatio: 0.7
    )
    static let ornateGoldFrameRightPage = FrameConfig(
        contentScale: 0.42,
        contentOffsetX: 0.005,
        contentOffsetY: -0.01,
        aspectRatio: 0.7
    )
}

struct FramedPDFThumbnail: View {
    let pdfImage: Image
    let frameImage: Image
    let config: FrameConfig
    let size: CGSize
    let showDebug: Bool

    init(pdfImage: Image,
         frameImage: Image,
         config: FrameConfig = .ornateGoldFrame,
         size: CGSize = CGSize(width: 300, height: 420),
         showDebug: Bool = false) {
        self.pdfImage = pdfImage
        self.frameImage = frameImage
        self.config = config
        self.size = size
        self.showDebug = showDebug
    }

    var body: some View {
        ZStack {
            if showDebug {
                Color.gray.opacity(0.3)
                    .frame(width: size.width, height: size.height)
            }
            frameImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
            pdfImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: size.width * config.contentScale,
                    height: size.height * config.contentScale
                )
                .offset(
                    x: size.width * config.contentOffsetX,
                    y: size.height * config.contentOffsetY
                )
                .clipShape(Rectangle())
                .border(showDebug ? Color.red : Color.clear, width: 2)
        }
        .frame(width: size.width, height: size.height)
    }
}

struct SideBySideFramedView: View {
    let leftImage: Image
    let rightImage: Image
    let frameImage: Image
    let showDebug: Bool

    // Frame and window constants
    let frameSize = CGSize(width: 1280, height: 853)
    let leftWindow = CGRect(x: 137, y: 158, width: 300, height: 530)
    let rightWindow = CGRect(x: 810, y: 159, width: 306, height: 529)

    // Helper for aspect fit in SwiftUI
    func aspectFitProxy(image: Image, window: CGRect) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: window.width, height: window.height)
            .clipped()
    }

    var body: some View {
        ZStack {
            // Frame background
            frameImage
                .resizable()
                .frame(width: frameSize.width, height: frameSize.height)
                .aspectRatio(contentMode: .fit)

            // Left page (aspect fit)
            aspectFitProxy(image: leftImage, window: leftWindow)
                .position(x: leftWindow.midX, y: leftWindow.midY)

            // Right page (aspect fit)
            aspectFitProxy(image: rightImage, window: rightWindow)
                .position(x: rightWindow.midX, y: rightWindow.midY)

            // Optional: Debug rectangles
            if showDebug {
                Rectangle()
                    .stroke(Color.red, lineWidth: 2)
                    .frame(width: leftWindow.width, height: leftWindow.height)
                    .position(x: leftWindow.midX, y: leftWindow.midY)
                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: rightWindow.width, height: rightWindow.height)
                    .position(x: rightWindow.midX, y: rightWindow.midY)
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
    }
}
// --- End: FrameConfig, FramedPDFThumbnail, SideBySideFramedView ---

// FrameConfigProvider to centralize frame configuration
struct FrameConfigProvider {
    // Structure to define frame insets for any frame
    struct FrameInsets {
        let top: CGFloat
        let leading: CGFloat
        let bottom: CGFloat
        let trailing: CGFloat

        // Convert to SwiftUI EdgeInsets
        var edgeInsets: EdgeInsets {
            return EdgeInsets(
                top: top,
                leading: leading,
                bottom: bottom,
                trailing: trailing
            )
        }
    }

    // Static configuration cache for all frames
    // Pre-configured frames plus analyzed frames will be stored here
    static var configurations: [String: FrameInsets] = [
        // Horizontal frames
        "frameH": FrameInsets(top: 0.10, leading: 0.10, bottom: 0.10, trailing: 0.10),

        // Vertical frames
        "frameV": FrameInsets(top: 0.15, leading: 0.12, bottom: 0.15, trailing: 0.12)
    ]

    // Get insets for a specific frame
    static func getInsets(for frameName: String) -> FrameInsets {
        // First, try to get from cache
        if let cached = configurations[frameName] {
            return cached
        }

        // If not in cache, analyze the frame and cache the result
        if let analyzed = FrameAnalyzer.analyzeFrame(named: frameName) {
            // Store in the cache for future use
            configurations[frameName] = analyzed
            print("✅ Auto-analyzed frame: \(frameName) - T:\(analyzed.top) L:\(analyzed.leading) B:\(analyzed.bottom) R:\(analyzed.trailing)")
            return analyzed
        }

        // Return default values if analysis fails
        print("⚠️ Using default insets for frame: \(frameName)")
        let defaultInsets = FrameInsets(top: 0.10, leading: 0.10, bottom: 0.10, trailing: 0.10)
        configurations[frameName] = defaultInsets // Cache the default to avoid repeated analysis attempts
        return defaultInsets
    }

    // Manually analyze and update a frame's configuration
    static func analyzeAndUpdate(frameName: String) -> FrameInsets? {
        if let analyzed = FrameAnalyzer.analyzeFrame(named: frameName) {
            configurations[frameName] = analyzed
            return analyzed
        }
        return nil
    }

    // Clear cached configurations
    static func clearCache() {
        configurations = [
            "frameH": FrameInsets(top: 0.10, leading: 0.10, bottom: 0.10, trailing: 0.10),
            "frameV": FrameInsets(top: 0.15, leading: 0.12, bottom: 0.15, trailing: 0.12)
        ]
    }
}

// Automatic frame analyzer to detect transparent regions
class FrameAnalyzer {
    // Default threshold for considering a pixel transparent
    private static let transparencyThreshold: CGFloat = 0.1

    // Analyze a frame image and return the calculated insets
    static func analyzeFrame(named frameName: String) -> FrameConfigProvider.FrameInsets? {
        // Get the image from the asset catalog
        guard let image = NSImage(named: frameName) else {
            print("❌ Failed to load frame image: \(frameName)")
            return nil
        }

        // Convert to bitmap for pixel-level access
        guard let bitmap = getBitmapData(from: image) else {
            print("❌ Failed to convert frame to bitmap: \(frameName)")
            return nil
        }

        // Get dimensions
        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        // Scan for transparent regions
        var topInset: Int = height
        var leadingInset: Int = width
        var bottomInset: Int = height
        var trailingInset: Int = width

        // Horizontal scan for top and bottom insets
        for y in 0..<height {
            var topRowHasContent = false
            var bottomRowHasContent = false

            for x in 0..<width {
                // Check pixel at (x, y) for top
                if !isPixelTransparent(bitmap: bitmap, x: x, y: y) {
                    topRowHasContent = true
                }

                // Check pixel at (x, height-1-y) for bottom
                if !isPixelTransparent(bitmap: bitmap, x: x, y: height-1-y) {
                    bottomRowHasContent = true
                }
            }

            // If we found content in this row, check if it's the smallest inset
            if topRowHasContent && y < topInset {
                topInset = y
            }

            if bottomRowHasContent && (height-1-y) > (height - bottomInset) {
                bottomInset = height - (height-1-y)
            }

            // If we found both, we can stop scanning
            if topInset < height && bottomInset < height {
                break
            }
        }

        // Vertical scan for leading and trailing insets
        for x in 0..<width {
            var leadingColHasContent = false
            var trailingColHasContent = false

            for y in 0..<height {
                // Check pixel at (x, y) for leading
                if !isPixelTransparent(bitmap: bitmap, x: x, y: y) {
                    leadingColHasContent = true
                }

                // Check pixel at (width-1-x, y) for trailing
                if !isPixelTransparent(bitmap: bitmap, x: width-1-x, y: y) {
                    trailingColHasContent = true
                }
            }

            // If we found content in this column, check if it's the smallest inset
            if leadingColHasContent && x < leadingInset {
                leadingInset = x
            }

            if trailingColHasContent && (width-1-x) > (width - trailingInset) {
                trailingInset = width - (width-1-x)
            }

            // If we found both, we can stop scanning
            if leadingInset < width && trailingInset < width {
                break
            }
        }

        // Find the main content area within the frame
        let contentStart = findContentStart(bitmap: bitmap,
                                          width: width,
                                          height: height,
                                          topInset: topInset,
                                          leadingInset: leadingInset)

        let contentEnd = findContentEnd(bitmap: bitmap,
                                      width: width,
                                      height: height,
                                      bottomInset: bottomInset,
                                      trailingInset: trailingInset)

        // Convert to normalized values (0.0 - 1.0)
        let normalizedTop = CGFloat(contentStart.y) / CGFloat(height)
        let normalizedLeading = CGFloat(contentStart.x) / CGFloat(width)
        let normalizedBottom = CGFloat(height - contentEnd.y) / CGFloat(height)
        let normalizedTrailing = CGFloat(width - contentEnd.x) / CGFloat(width)

        print("✅ Frame analysis for \(frameName):")
        print("   Size: \(width)x\(height)")
        print("   Content area: (\(contentStart.x), \(contentStart.y)) to (\(contentEnd.x), \(contentEnd.y))")
        print("   Insets: T:\(normalizedTop) L:\(normalizedLeading) B:\(normalizedBottom) R:\(normalizedTrailing)")

        return FrameConfigProvider.FrameInsets(
            top: normalizedTop,
            leading: normalizedLeading,
            bottom: normalizedBottom,
            trailing: normalizedTrailing
        )
    }

    // Helper function to convert NSImage to bitmap data
    private static func getBitmapData(from image: NSImage) -> NSBitmapImageRep? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        return NSBitmapImageRep(cgImage: cgImage)
    }

    // Helper function to check if a pixel is transparent
    private static func isPixelTransparent(bitmap: NSBitmapImageRep, x: Int, y: Int) -> Bool {
        // Get alpha value at pixel (x,y)
        guard let alphaValue = bitmap.colorAt(x: x, y: y)?.alphaComponent else {
            return true // Default to transparent if we can't get color
        }

        // Consider pixel transparent if alpha is below threshold
        return alphaValue < transparencyThreshold
    }

    // Find the starting point of the content area
    private static func findContentStart(bitmap: NSBitmapImageRep, width: Int, height: Int,
                                       topInset: Int, leadingInset: Int) -> (x: Int, y: Int) {
        var contentStartX = leadingInset
        var contentStartY = topInset

        // Refine content start by finding the first fully transparent row/column after the frame edge
        // Horizontal scan from leading edge
        outerX: for x in leadingInset..<width/2 {
            // Check for a column of transparent pixels
            var isColumnTransparent = true
            for y in topInset..<height-topInset {
                if !isPixelTransparent(bitmap: bitmap, x: x, y: y) {
                    isColumnTransparent = false
                    break
                }
            }

            if isColumnTransparent {
                contentStartX = x
                break outerX
            }
        }

        // Vertical scan from top edge
        outerY: for y in topInset..<height/2 {
            // Check for a row of transparent pixels
            var isRowTransparent = true
            for x in 0..<width {
                if !isPixelTransparent(bitmap: bitmap, x: x, y: y) {
                    isRowTransparent = false
                    break
                }
            }

            if isRowTransparent {
                contentStartY = y
                break outerY
            }
        }

        return (contentStartX, contentStartY)
    }

    // Find the ending point of the content area
    private static func findContentEnd(bitmap: NSBitmapImageRep, width: Int, height: Int,
                                     bottomInset: Int, trailingInset: Int) -> (x: Int, y: Int) {
        var contentEndX = width - trailingInset
        var contentEndY = height - bottomInset

        // Refine content end by finding the last fully transparent row/column before the frame edge
        // Horizontal scan from trailing edge
        outerX: for x in (width/2..<(width-trailingInset)).reversed() {
            // Check for a column of transparent pixels
            var isColumnTransparent = true
            for y in bottomInset..<height-bottomInset {
                if !isPixelTransparent(bitmap: bitmap, x: x, y: y) {
                    isColumnTransparent = false
                    break
                }
            }

            if isColumnTransparent {
                contentEndX = x
                break outerX
            }
        }

        // Vertical scan from bottom edge
        outerY: for y in (height/2..<(height-bottomInset)).reversed() {
            // Check for a row of transparent pixels
            var isRowTransparent = true
            for x in 0..<width {
                if !isPixelTransparent(bitmap: bitmap, x: x, y: y) {
                    isRowTransparent = false
                    break
                }
            }

            if isRowTransparent {
                contentEndY = y
                break outerY
            }
        }

        return (contentEndX, contentEndY)
    }
}

// Enhanced ZoomableScrollView with performance optimizations
struct ZoomableScrollView<Content: View>: View {
    let content: Content
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomValue: CGFloat
    
    @State private var scrollOffset: CGPoint = .zero
    @State private var isZooming = false
    private let zoomDebouncer = Debouncer(delay: 0.05) // Debounce zoom updates

    init(zoomScale: Binding<CGFloat>, lastZoomValue: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._zoomScale = zoomScale
        self._lastZoomValue = lastZoomValue
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    content
                        .scaleEffect(zoomScale, anchor: .center)
                        .frame(
                            minWidth: max(geometry.size.width, geometry.size.width * zoomScale),
                            minHeight: max(geometry.size.height, geometry.size.height * zoomScale)
                        )
                        .id("zoomable-content")
                        .animation(
                            isZooming ? .none : .easeOut(duration: 0.2),
                            value: zoomScale
                        )
                }
                .scrollDisabled(false)
                .clipped()
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            isZooming = true
                            
                            // Debounce zoom updates for better performance
                            zoomDebouncer.debounce {
                                let delta = value / lastZoomValue
                                lastZoomValue = value

                                // Apply zoom with practical limits
                                let newZoom = zoomScale * delta
                                zoomScale = min(max(newZoom, 0.1), 10.0) // Wider zoom range
                            }
                        }
                        .onEnded { _ in
                            // Reset for next gesture with smooth transition
                            withAnimation(.easeOut(duration: 0.3)) {
                                isZooming = false
                                lastZoomValue = 1.0
                                
                                // Snap to reasonable zoom levels
                                if zoomScale < 0.3 {
                                    zoomScale = 0.25
                                } else if zoomScale > 8.0 {
                                    zoomScale = 8.0
                                }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    // Double-tap to reset zoom
                    withAnimation(.easeInOut(duration: 0.3)) {
                        zoomScale = 1.0
                    }
                }
            }
        }
    }
}

// Preview
#Preview {
    let viewModel = AppShellViewModel()
    return BrutalistPreviewView(viewModel: viewModel)
}

