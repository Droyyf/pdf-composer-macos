import Foundation
import PDFKit
import AppKit

actor PDFService {
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB cache limit
    private let cache = NSCache<NSString, NSImage>()
    private var accessOrder: [String] = [] // Track access order for LRU
    private var cacheSizes: [String: Int] = [:] // Track actual sizes
    private var currentCacheSize = 0
    
    init() {
        // Set reasonable limits on the NSCache
        cache.countLimit = 500 // Maximum number of thumbnails
        cache.totalCostLimit = maxCacheSize
    }
    
    func open(url: URL) async throws -> PDFDocument {
        return try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: url) else {
                throw NSError(domain: "PDFService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF."])
            }
            return document
        }.value
    }

    func thumbnail(document: PDFDocument, page: Int, size: CGSize, useCache: Bool = true) async -> NSImage? {
        let cacheKey = "\(document.documentURL?.absoluteString ?? "unknown")_\(page)_\(Int(size.width))x\(Int(size.height))"
        
        // Check cache first if enabled
        if useCache, let cachedThumbnail = cache.object(forKey: NSString(string: cacheKey)) {
            // Update LRU order
            updateAccessOrder(for: cacheKey)
            return cachedThumbnail
        }
        
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let pdfPage = document.page(at: page) else { return nil }
            
            // Use memory-efficient thumbnail generation
            let thumbnail = autoreleasepool {
                return pdfPage.thumbnail(of: size, for: .cropBox)
            }
            
            // Cache if enabled and under size limit
            if useCache {
                await self?.cacheThumbnail(thumbnail, forKey: cacheKey, size: size)
            }
            
            return thumbnail
        }.value
    }
    
    private func cacheThumbnail(_ image: NSImage, forKey key: String, size: CGSize) {
        // Calculate accurate bitmap size based on actual image representation
        let imageSize = calculateImageSize(image, targetSize: size)
        
        // Clean cache if it would exceed limit
        while currentCacheSize + imageSize > maxCacheSize && !accessOrder.isEmpty {
            evictOldestEntry()
        }
        
        // Store in both NSCache and our tracking structures
        cache.setObject(image, forKey: NSString(string: key), cost: imageSize)
        cacheSizes[key] = imageSize
        currentCacheSize += imageSize
        
        // Update LRU order
        updateAccessOrder(for: key)
    }
    
    private func calculateImageSize(_ image: NSImage, targetSize: CGSize) -> Int {
        // More accurate size calculation considering actual bitmap data
        guard let representation = image.representations.first as? NSBitmapImageRep else {
            // Fallback to target size calculation
            return Int(targetSize.width * targetSize.height * 4) // RGBA
        }
        
        // Calculate based on actual representation
        let bytesPerPixel = representation.bitsPerPixel / 8
        return representation.pixelsWide * representation.pixelsHigh * max(bytesPerPixel, 4)
    }
    
    private func updateAccessOrder(for key: String) {
        // Remove if already exists
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        // Add to end (most recently used)
        accessOrder.append(key)
    }
    
    private func evictOldestEntry() {
        guard let oldestKey = accessOrder.first else { return }
        
        // Remove from all tracking structures
        accessOrder.removeFirst()
        cache.removeObject(forKey: NSString(string: oldestKey))
        
        if let size = cacheSizes.removeValue(forKey: oldestKey) {
            currentCacheSize -= size
        }
    }

    func export(document: PDFDocument, format: ExportFormat, url: URL, quality: CGFloat = 0.9) async throws {
        try await Task.detached(priority: .userInitiated) {
            switch format {
            case .pdf:
                guard document.write(to: url) else {
                    throw NSError(domain: "PDFService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to export PDF."])
                }
            case .png:
                guard let page = document.page(at: 0) else {
                    throw NSError(domain: "PDFService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No page to export."])
                }
                
                // Use memory-efficient image generation with autoreleasepool
                let image = autoreleasepool {
                    return page.thumbnail(of: CGSize(width: 2480, height: 3508), for: .mediaBox)
                }
                
                guard let tiffData = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData) else {
                    throw NSError(domain: "PDFService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create image representation."])
                }
                
                // Use specified quality for PNG compression
                let compressionFactor = NSNumber(value: Float(1.0 - quality))
                guard let output = bitmap.representation(using: .png, properties: [.compressionFactor: compressionFactor]) else {
                    throw NSError(domain: "PDFService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to encode image."])
                }
                try output.write(to: url)
            }
        }.value
    }
    
    func clearCache() {
        cache.removeAllObjects()
        accessOrder.removeAll()
        cacheSizes.removeAll()
        currentCacheSize = 0
    }
}
