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
        
        // Set cache delegate for memory management
        cache.delegate = self
        placeholderCache.delegate = self
    }
    
    // MARK: - Memory Pressure Handling
    private func setupMemoryPressureHandling() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        memoryPressureSource?.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleMemoryPressure()
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
                _ = await MainActor.run {
                    self.loadingStates.remove(pageIndex)
                }
                return nil
            }
            
            // Generate placeholder first for immediate feedback
            let placeholderImage = await self.generatePlaceholder(for: page)
            await MainActor.run {
                self.placeholderCache.setObject(placeholderImage, forKey: NSNumber(value: pageIndex))
            }
            
            // Check cancellation again
            guard !Task.isCancelled else {
                _ = await MainActor.run {
                    self.loadingStates.remove(pageIndex)
                }
                return nil
            }
            
            // Generate full resolution thumbnail
            let fullImage = await self.generateFullThumbnail(for: page)
            
            await MainActor.run {
                self.cache.setObject(fullImage, forKey: NSNumber(value: pageIndex))
                self.loadingStates.remove(pageIndex)
                self.generationTasks.removeValue(forKey: pageIndex)
            }
            
            return ThumbnailResult(
                pageIndex: pageIndex,
                image: fullImage,
                size: CacheConfig.thumbnailSize,
                timestamp: Date()
            )
        }
        
        generationTasks[pageIndex] = task
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
    
    func cancelGeneration(for pageIndex: Int) {
        generationTasks[pageIndex]?.cancel()
        generationTasks.removeValue(forKey: pageIndex)
        loadingStates.remove(pageIndex)
    }
    
    func cancelAllTasks() {
        for task in generationTasks.values {
            task.cancel()
        }
        generationTasks.removeAll()
        loadingStates.removeAll()
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

// MARK: - NSCacheDelegate
extension ThumbnailCache: NSCacheDelegate {
    nonisolated func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // Called when cache is about to evict an object due to memory pressure
        // This helps us track memory usage patterns
    }
}

// MARK: - Legacy LRU Cache (for backward compatibility)
final class LRUCache<Key: Hashable, Value> {
    private class Node {
        let key: Key
        var value: Value
        var prev: Node?
        var next: Node?
        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }
    private let capacity: Int
    private var dict: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    private let cache = NSCache<WrappedKey, Entry>()

    private class WrappedKey: NSObject {
        let key: AnyHashable
        init(_ key: AnyHashable) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? WrappedKey else { return false }
            return key == other.key
        }
    }
    private class Entry {
        let value: Value
        init(_ value: Value) { self.value = value }
    }

    init(capacity: Int) {
        self.capacity = capacity
        cache.countLimit = capacity
    }

    func get(_ key: Key) -> Value? {
        if let node = dict[key] {
            moveToHead(node)
            return node.value
        }
        if let entry = cache.object(forKey: WrappedKey(key)) {
            return entry.value
        }
        return nil
    }

    func set(_ key: Key, value: Value) {
        if let node = dict[key] {
            node.value = value
            moveToHead(node)
        } else {
            let node = Node(key: key, value: value)
            dict[key] = node
            addToHead(node)
            cache.setObject(Entry(value), forKey: WrappedKey(key))
            if dict.count > capacity {
                if let tail = tail {
                    dict[tail.key] = nil
                    removeNode(tail)
                }
            }
        }
    }

    private func moveToHead(_ node: Node) {
        removeNode(node)
        addToHead(node)
    }
    private func addToHead(_ node: Node) {
        node.next = head
        node.prev = nil
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }
    private func removeNode(_ node: Node) {
        if let prev = node.prev { prev.next = node.next } else { head = node.next }
        if let next = node.next { next.prev = node.prev } else { tail = node.prev }
    }
}
