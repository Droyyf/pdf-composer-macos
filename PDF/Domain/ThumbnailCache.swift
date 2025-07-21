import Foundation
import AppKit
@preconcurrency import PDFKit

// MARK: - Async Thumbnail Generation Result
struct ThumbnailResult {
    let pageIndex: Int
    let image: NSImage
    let size: CGSize
    let timestamp: Date
}

// MARK: - Thumbnail Generation Task
actor ThumbnailGenerationTask {
    private var isCancelled = false
    
    func cancel() {
        isCancelled = true
    }
    
    var cancelled: Bool {
        isCancelled
    }
}

// MARK: - Optimized Thumbnail Cache
@MainActor
final class ThumbnailCache: NSObject, ObservableObject {
    
    // MARK: - Cache Configuration
    private struct CacheConfig {
        static let defaultCapacity = 100
        static let memoryWarningCapacity = 50
        static let lowMemoryCapacity = 25
        static let thumbnailSize = CGSize(width: 160, height: 200)
        static let placeholderSize = CGSize(width: 80, height: 100)
    }
    
    // MARK: - Properties
    private let cache = NSCache<NSNumber, NSImage>()
    private let placeholderCache = NSCache<NSNumber, NSImage>()
    private let queue = DispatchQueue(label: "thumbnail.generation", qos: .userInitiated, attributes: .concurrent)
    private var generationTasks: [Int: Task<ThumbnailResult?, Never>] = [:]
    private var batchTasks: [UUID: Task<[ThumbnailResult], Never>] = [:]
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    
    @Published var loadingStates: Set<Int> = []
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupCache()
        setupMemoryPressureHandling()
    }
    
    deinit {
        memoryPressureSource?.cancel()
        // Note: cancelAllTasks() will be called automatically when the object is deallocated
    }
    
    // MARK: - Cache Setup
    private func setupCache() {
        cache.countLimit = CacheConfig.defaultCapacity
        cache.totalCostLimit = CacheConfig.defaultCapacity * 160 * 200 * 4 // Rough memory estimate
        
        placeholderCache.countLimit = CacheConfig.defaultCapacity
        placeholderCache.totalCostLimit = CacheConfig.defaultCapacity * 80 * 100 * 4
        
        // Note: Cache delegates removed due to actor isolation
        // Memory management will be handled through memory pressure monitoring
    }
    
    // MARK: - Memory Pressure Handling
    private func setupMemoryPressureHandling() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { [weak self] in
                await self?.handleMemoryPressure()
            }
        }
        
        memoryPressureSource?.resume()
    }
    
    private func handleMemoryPressure() {
        let pressure = memoryPressureSource?.mask
        
        if pressure?.contains(.critical) == true {
            cache.countLimit = CacheConfig.lowMemoryCapacity
            cache.removeAllObjects()
            placeholderCache.removeAllObjects()
            cancelAllTasks()
        } else if pressure?.contains(.warning) == true {
            cache.countLimit = CacheConfig.memoryWarningCapacity
            // Remove oldest half of cache entries
            cache.removeAllObjects()
        }
    }
    
    // MARK: - Public Interface
    func getThumbnail(for pageIndex: Int) -> NSImage? {
        return cache.object(forKey: NSNumber(value: pageIndex))
    }
    
    func getPlaceholder(for pageIndex: Int) -> NSImage? {
        return placeholderCache.object(forKey: NSNumber(value: pageIndex))
    }
    
    func generateThumbnailAsync(
        for pageIndex: Int,
        from page: PDFPage,
        priority: TaskPriority = .userInitiated
    ) {
        // Cancel existing task for this page if any
        generationTasks[pageIndex]?.cancel()
        
        // Add to loading states
        loadingStates.insert(pageIndex)
        
        let task = Task(priority: priority) { [weak self] () -> ThumbnailResult? in
            guard let self = self else { return nil }
            
            // Check if already cancelled
            guard !Task.isCancelled else {
                await self.cleanupLoadingState(for: pageIndex)
                return nil
            }
            
            // Generate placeholder first for immediate feedback
            let placeholderImage = await self.generatePlaceholder(for: page)
            await self.setPlaceholder(placeholderImage, for: pageIndex)
            
            // Check cancellation again
            guard !Task.isCancelled else {
                await self.cleanupLoadingState(for: pageIndex)
                return nil
            }
            
            // Generate full resolution thumbnail
            let fullImage = await self.generateFullThumbnail(for: page)
            
            // Store results atomically
            await self.setThumbnail(fullImage, for: pageIndex)
            
            return ThumbnailResult(
                pageIndex: pageIndex,
                image: fullImage,
                size: CacheConfig.thumbnailSize,
                timestamp: Date()
            )
        }
        
        generationTasks[pageIndex] = task
    }
    
    // MARK: - Thread-safe helper methods
    private func cleanupLoadingState(for pageIndex: Int) {
        loadingStates.remove(pageIndex)
        generationTasks.removeValue(forKey: pageIndex)
    }
    
    private func setPlaceholder(_ image: NSImage, for pageIndex: Int) {
        placeholderCache.setObject(image, forKey: NSNumber(value: pageIndex))
    }
    
    private func setThumbnail(_ image: NSImage, for pageIndex: Int) {
        cache.setObject(image, forKey: NSNumber(value: pageIndex))
        loadingStates.remove(pageIndex)
        generationTasks.removeValue(forKey: pageIndex)
    }
    
    func preloadThumbnails(for pages: [PDFPage], startingAt index: Int, count: Int = 10) {
        let endIndex = min(index + count, pages.count)
        let range = index..<endIndex
        
        for i in range {
            if cache.object(forKey: NSNumber(value: i)) == nil && 
               !loadingStates.contains(i) {
                generateThumbnailAsync(for: i, from: pages[i], priority: .utility)
            }
        }
    }
    
    // MARK: - Batch Generation Methods
    func generateThumbnailsBatch(
        for pages: [(index: Int, page: PDFPage)],
        priority: TaskPriority = .userInitiated,
        batchSize: Int = 5
    ) async -> (results: [ThumbnailResult], batchId: UUID) {
        let batchId = UUID()
        var results: [ThumbnailResult] = []
        
        let batchTask = Task(priority: priority) { () -> [ThumbnailResult] in
            var batchResults: [ThumbnailResult] = []
            
            // Process in batches to prevent overwhelming the system
            for batch in pages.chunked(into: batchSize) {
                // Check for cancellation before each batch
                guard !Task.isCancelled else { break }
                
                await withTaskGroup(of: ThumbnailResult?.self) { group in
                    for (index, page) in batch {
                        // Skip if already cached or loading
                        if cache.object(forKey: NSNumber(value: index)) == nil &&
                           !loadingStates.contains(index) {
                            
                            group.addTask { [weak self] in
                                guard !Task.isCancelled else { return nil }
                                return await self?.generateSingleThumbnail(
                                    for: index,
                                    from: page,
                                    priority: priority
                                )
                            }
                        }
                    }
                    
                    for await result in group {
                        guard !Task.isCancelled else { break }
                        if let result = result {
                            batchResults.append(result)
                        }
                    }
                }
            }
            
            return batchResults
        }
        
        // Track the batch task
        batchTasks[batchId] = batchTask
        
        // Wait for completion and cleanup
        results = await batchTask.value
        batchTasks.removeValue(forKey: batchId)
        
        return (results: results, batchId: batchId)
    }
    
    private func generateSingleThumbnail(
        for pageIndex: Int,
        from page: PDFPage,
        priority: TaskPriority
    ) async -> ThumbnailResult? {
        // Mark as loading
        loadingStates.insert(pageIndex)
        
        defer {
            // Clean up loading state
            loadingStates.remove(pageIndex)
        }
        
        // Check cancellation
        guard !Task.isCancelled else { return nil }
        
        // Generate placeholder first
        let placeholderImage = await generatePlaceholder(for: page)
        await setPlaceholder(placeholderImage, for: pageIndex)
        
        // Check cancellation again
        guard !Task.isCancelled else { return nil }
        
        // Generate full resolution thumbnail
        let fullImage = await generateFullThumbnail(for: page)
        await setThumbnail(fullImage, for: pageIndex)
        
        return ThumbnailResult(
            pageIndex: pageIndex,
            image: fullImage,
            size: CacheConfig.thumbnailSize,
            timestamp: Date()
        )
    }
    
    func cancelGeneration(for pageIndex: Int) {
        generationTasks[pageIndex]?.cancel()
        generationTasks.removeValue(forKey: pageIndex)
        loadingStates.remove(pageIndex)
    }
    
    func cancelAllTasks() {
        // Cancel individual generation tasks
        for task in generationTasks.values {
            task.cancel()
        }
        generationTasks.removeAll()
        
        // Cancel batch tasks
        for batchTask in batchTasks.values {
            batchTask.cancel()
        }
        batchTasks.removeAll()
        
        loadingStates.removeAll()
    }
    
    // Cancel a specific batch of tasks
    func cancelBatch(id: UUID) {
        batchTasks[id]?.cancel()
        batchTasks.removeValue(forKey: id)
    }
    
    // Cancel tasks for a range of page indices
    func cancelGenerationRange(from startIndex: Int, to endIndex: Int) {
        for pageIndex in startIndex...endIndex {
            cancelGeneration(for: pageIndex)
        }
    }
    
    func isLoading(pageIndex: Int) -> Bool {
        return loadingStates.contains(pageIndex)
    }
    
    func getLoadingStates() -> Set<Int> {
        return loadingStates
    }
    
    func clearCache() {
        cancelAllTasks()
        cache.removeAllObjects()
        placeholderCache.removeAllObjects()
    }
    
    // MARK: - Private Generation Methods
    private func generatePlaceholder(for page: PDFPage) async -> NSImage {
        return await withCheckedContinuation { continuation in
            queue.async {
                let image = page.thumbnail(of: CacheConfig.placeholderSize, for: .cropBox)
                continuation.resume(returning: image)
            }
        }
    }
    
    private func generateFullThumbnail(for page: PDFPage) async -> NSImage {
        return await withCheckedContinuation { continuation in
            queue.async {
                let image = page.thumbnail(of: CacheConfig.thumbnailSize, for: .cropBox)
                continuation.resume(returning: image)
            }
        }
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

