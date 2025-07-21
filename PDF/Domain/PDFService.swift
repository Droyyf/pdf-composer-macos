import Foundation
import PDFKit
import AppKit

actor PDFService {
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB cache limit
    private var thumbnailCache: [String: NSImage] = [:]
    private var cacheSize = 0
    
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
        if useCache, let cachedThumbnail = thumbnailCache[cacheKey] {
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
                await self?.cacheThumbnail(thumbnail, forKey: cacheKey)
            }
            
            return thumbnail
        }.value
    }
    
    private func cacheThumbnail(_ image: NSImage, forKey key: String) {
        let imageSize = Int(image.size.width * image.size.height * 4) // Approximate RGBA size
        
        // Clean cache if it would exceed limit
        if cacheSize + imageSize > maxCacheSize {
            clearOldestCacheEntries()
        }
        
        thumbnailCache[key] = image
        cacheSize += imageSize
    }
    
    private func clearOldestCacheEntries() {
        // Simple cleanup - remove half the cache
        let keysToRemove = Array(thumbnailCache.keys.prefix(thumbnailCache.count / 2))
        for key in keysToRemove {
            thumbnailCache.removeValue(forKey: key)
        }
        cacheSize = cacheSize / 2 // Approximate
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
        thumbnailCache.removeAll()
        cacheSize = 0
    }
}
