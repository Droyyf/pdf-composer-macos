import Foundation
import PDFKit
import AppKit

// MARK: - Thumbnail Loading Options
struct ThumbnailOptions {
    let size: CGSize
    let quality: CGFloat
    let useCache: Bool
    let priority: TaskPriority
    
    static let standard = ThumbnailOptions(
        size: CGSize(width: 160, height: 200),
        quality: 0.8,
        useCache: true,
        priority: .userInitiated
    )
    
    static let placeholder = ThumbnailOptions(
        size: CGSize(width: 80, height: 100),
        quality: 0.6,
        useCache: true,
        priority: .utility
    )
    
    static let highQuality = ThumbnailOptions(
        size: CGSize(width: 320, height: 400),
        quality: 0.95,
        useCache: true,
        priority: .userInitiated
    )
}

// MARK: - Thumbnail Loading Result
struct ThumbnailLoadingResult {
    let image: NSImage
    let pageIndex: Int
    let loadTime: TimeInterval
    let fromCache: Bool
}

// MARK: - Centralized Thumbnail Service
@MainActor
class ThumbnailService: ObservableObject {
    
    // MARK: - Properties
    private let pdfService = PDFService()
    private let thumbnailCache = ThumbnailCache()
    private var loadingTasks: [String: Task<NSImage?, Never>] = [:]
    
    // MARK: - Public Interface
    
    /// Loads a thumbnail for a specific page with comprehensive options
    func loadThumbnail(
        from document: PDFDocument,
        pageIndex: Int,
        options: ThumbnailOptions = .standard
    ) async -> ThumbnailLoadingResult? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let cacheKey = generateCacheKey(document: document, pageIndex: pageIndex, options: options)
        
        // Check if already loading this specific thumbnail
        if let existingTask = loadingTasks[cacheKey] {
            if let image = await existingTask.value {
                let loadTime = CFAbsoluteTimeGetCurrent() - startTime
                return ThumbnailLoadingResult(
                    image: image,
                    pageIndex: pageIndex,
                    loadTime: loadTime,
                    fromCache: false // Was loading, so not from cache
                )
            }
        }
        
        // Check cache first
        if options.useCache, let cachedImage = await thumbnailCache.getThumbnail(for: pageIndex) {
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            return ThumbnailLoadingResult(
                image: cachedImage,
                pageIndex: pageIndex,
                loadTime: loadTime,
                fromCache: true
            )
        }
        
        // Create loading task
        let task = Task(priority: options.priority) { () -> NSImage? in
            guard let page = document.page(at: pageIndex) else { return nil }
            
            // Use ThumbnailCache for async generation
            await self.thumbnailCache.generateThumbnailAsync(
                for: pageIndex,
                from: page,
                priority: options.priority
            )
            
            // Wait briefly for generation to complete
            try? await Task.sleep(for: .milliseconds(100))
            
            // Return the generated thumbnail
            return await self.thumbnailCache.getThumbnail(for: pageIndex)
        }
        
        loadingTasks[cacheKey] = task
        
        if let image = await task.value {
            loadingTasks.removeValue(forKey: cacheKey)
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            return ThumbnailLoadingResult(
                image: image,
                pageIndex: pageIndex,
                loadTime: loadTime,
                fromCache: false
            )
        }
        
        loadingTasks.removeValue(forKey: cacheKey)
        return nil
    }
    
    /// Loads thumbnails for multiple pages efficiently
    func loadThumbnailsBatch(
        from document: PDFDocument,
        pageIndices: [Int],
        options: ThumbnailOptions = .standard
    ) async -> [ThumbnailLoadingResult] {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Prepare pages data
        let pagesData = pageIndices.compactMap { pageIndex -> (index: Int, page: PDFPage)? in
            guard let page = document.page(at: pageIndex) else { return nil }
            return (index: pageIndex, page: page)
        }
        
        // Use ThumbnailCache batch generation
        let (thumbnailResults, _) = await thumbnailCache.generateThumbnailsBatch(
            for: pagesData,
            priority: options.priority
        )
        
        // Convert to ThumbnailLoadingResult
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        return thumbnailResults.map { result in
            ThumbnailLoadingResult(
                image: result.image,
                pageIndex: result.pageIndex,
                loadTime: loadTime / Double(thumbnailResults.count), // Average load time
                fromCache: false
            )
        }
    }
    
    /// Preloads thumbnails for a viewport efficiently
    func preloadThumbnailsForViewport(
        from document: PDFDocument,
        startIndex: Int,
        count: Int = 10,
        options: ThumbnailOptions = .standard
    ) {
        let endIndex = min(startIndex + count, document.pageCount)
        let pageIndices = Array(startIndex..<endIndex)
        
        Task(priority: options.priority) { [weak self] in
            _ = await self?.loadThumbnailsBatch(
                from: document,
                pageIndices: pageIndices,
                options: options
            )
        }
    }
    
    /// Gets a cached thumbnail immediately if available
    func getCachedThumbnail(for pageIndex: Int) async -> NSImage? {
        return await thumbnailCache.getThumbnail(for: pageIndex)
    }
    
    /// Gets a placeholder thumbnail immediately if available
    func getPlaceholderThumbnail(for pageIndex: Int) async -> NSImage? {
        return await thumbnailCache.getPlaceholder(for: pageIndex)
    }
    
    /// Checks if a thumbnail is currently being loaded
    func isThumbnailLoading(pageIndex: Int) async -> Bool {
        return await thumbnailCache.isLoading(pageIndex: pageIndex)
    }
    
    /// Cancels loading for a specific page
    func cancelThumbnailLoading(for pageIndex: Int) {
        Task {
            await thumbnailCache.cancelGeneration(for: pageIndex)
        }
    }
    
    /// Cancels all loading tasks
    func cancelAllLoading() {
        // Cancel local loading tasks
        for task in loadingTasks.values {
            task.cancel()
        }
        loadingTasks.removeAll()
        
        // Cancel cache loading tasks
        Task {
            await thumbnailCache.cancelAllTasks()
        }
    }
    
    /// Clears all cached thumbnails
    func clearCache() {
        Task {
            await thumbnailCache.clearCache()
        }
    }
    
    /// Gets cache statistics for debugging/monitoring
    func getCacheStatistics() async -> (loadingCount: Int, cacheHitRate: Double) {
        let loadingStates = await thumbnailCache.getLoadingStates()
        // Cache hit rate would need to be tracked over time - simplified for now
        return (loadingCount: loadingStates.count, cacheHitRate: 0.8)
    }
    
    // MARK: - Legacy Support Methods
    
    /// Legacy method that matches the original PDFService.thumbnail signature
    /// This allows for easier migration from existing code
    func thumbnail(
        document: PDFDocument,
        page: Int,
        size: CGSize,
        useCache: Bool = true
    ) async -> NSImage? {
        let options = ThumbnailOptions(
            size: size,
            quality: 0.8,
            useCache: useCache,
            priority: .userInitiated
        )
        
        let result = await loadThumbnail(
            from: document,
            pageIndex: page,
            options: options
        )
        
        return result?.image
    }
    
    /// Direct page thumbnail generation (bypassing cache for specific use cases)
    func generateDirectThumbnail(
        from page: PDFPage,
        size: CGSize,
        quality: CGFloat = 0.8
    ) async -> NSImage? {
        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                return page.thumbnail(of: size, for: .cropBox)
            }
        }.value
    }
    
    // MARK: - Private Helpers
    
    private func generateCacheKey(document: PDFDocument, pageIndex: Int, options: ThumbnailOptions) -> String {
        let documentId = document.documentURL?.absoluteString ?? "unknown"
        return "\(documentId)_\(pageIndex)_\(Int(options.size.width))x\(Int(options.size.height))_\(options.quality)"
    }
}

// MARK: - Thumbnail Service Extensions for Convenience

extension ThumbnailService {
    /// Convenience method for standard thumbnail loading
    func loadStandardThumbnail(from document: PDFDocument, pageIndex: Int) async -> NSImage? {
        let result = await loadThumbnail(from: document, pageIndex: pageIndex, options: .standard)
        return result?.image
    }
    
    /// Convenience method for placeholder thumbnail loading
    func loadPlaceholderThumbnail(from document: PDFDocument, pageIndex: Int) async -> NSImage? {
        let result = await loadThumbnail(from: document, pageIndex: pageIndex, options: .placeholder)
        return result?.image
    }
    
    /// Convenience method for high-quality thumbnail loading
    func loadHighQualityThumbnail(from document: PDFDocument, pageIndex: Int) async -> NSImage? {
        let result = await loadThumbnail(from: document, pageIndex: pageIndex, options: .highQuality)
        return result?.image
    }
}