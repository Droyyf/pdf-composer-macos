import Foundation
import PDFKit
import AppKit
import CoreImage

enum CoverPlacement: String, Codable, CaseIterable {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case pdf = "PDF"
    var id: String { rawValue }
}

// MARK: - Composition Errors
enum CompositionError: LocalizedError, Equatable {
    case emptyPageList
    case excessivePageCount(count: Int, limit: Int)
    case invalidPage(index: Int, reason: String)
    case invalidCoverImage(reason: String)
    case coverProcessingFailed(underlyingError: String)
    case documentCreationFailed
    case memoryLimitExceeded
    case operationCancelled
    case resourceCleanupFailed(resource: String)
    
    var errorDescription: String? {
        switch self {
        case .emptyPageList:
            return "Cannot compose PDF: No pages provided"
        case .excessivePageCount(let count, let limit):
            return "Cannot compose PDF: Page count (\(count)) exceeds limit (\(limit)) to prevent memory issues"
        case .invalidPage(let index, let reason):
            return "Invalid page at index \(index): \(reason)"
        case .invalidCoverImage(let reason):
            return "Invalid cover image: \(reason)"
        case .coverProcessingFailed(let error):
            return "Failed to process cover image: \(error)"
        case .documentCreationFailed:
            return "Failed to create PDF document"
        case .memoryLimitExceeded:
            return "Operation cancelled due to memory constraints"
        case .operationCancelled:
            return "Composition operation was cancelled"
        case .resourceCleanupFailed(let resource):
            return "Failed to cleanup resource: \(resource)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyPageList:
            return "Ensure at least one valid PDF page is selected"
        case .excessivePageCount(_, let limit):
            return "Reduce the number of pages to \(limit) or fewer"
        case .invalidPage:
            return "Remove or replace the invalid page"
        case .invalidCoverImage:
            return "Use a valid image file (PNG, JPEG, TIFF, etc.)"
        case .coverProcessingFailed:
            return "Try using a smaller image or different format"
        case .memoryLimitExceeded:
            return "Try processing fewer pages at once or use smaller images"
        default:
            return nil
        }
    }
}

struct Composer {
    // MARK: - Configuration
    static let maxPageCount = 500 // Prevent excessive memory usage
    static let maxCoverImageSize: CGFloat = 50_000_000 // 50MB in bytes
    static let maxCoverDimension: CGFloat = 10_000 // 10k pixels max dimension
    enum CompositionMode {
        case preview
        case export
        
        var maxImageDimension: CGFloat {
            switch self {
            case .preview: return 800
            case .export: return 2400
            }
        }
        
        var compressionQuality: CGFloat {
            switch self {
            case .preview: return 0.7
            case .export: return 0.95
            }
        }
    }
    
    static func merge(pages: [PDFPage], cover: NSImage?, coverPlacement: CoverPlacement, mode: CompositionMode = .export) async throws -> PDFDocument {
        // Input validation
        try validateInputs(pages: pages, cover: cover)
        
        return try await Task.detached(priority: .userInitiated) {
            // Check for cancellation at start
            try Task.checkCancellation()
            
            let document = PDFDocument()
            var insertIndex = 0
            var createdResources: [AnyObject] = [] // Track resources for cleanup
            
            do {
                // Process cover if provided
                if let cover = cover {
                    try Task.checkCancellation()
                    
                    // Validate and optimize cover image
                    let validatedCover = try validateCoverImage(cover)
                    let optimizedCover = mode == .preview 
                        ? downsampleIfNeeded(image: validatedCover, maxPPI: 150, pageSize: validatedCover.size) 
                        : validatedCover
                    
                    let coverPage = try await imageToPDFPage(image: optimizedCover, mode: mode)
                    createdResources.append(coverPage)
                    
                    insertIndex = coverInsertIndex(placement: coverPlacement, pageCount: pages.count)
                    document.insert(coverPage, at: insertIndex)
                }
                
                // Process pages with validation and memory management
                try await processPages(pages: pages, document: document, insertIndex: insertIndex, createdResources: &createdResources)
                
                // Validate final document
                guard document.pageCount > 0 else {
                    throw CompositionError.documentCreationFailed
                }
                
                return document
                
            } catch {
                // Cleanup on failure
                try? cleanupResources(createdResources)
                
                // Re-throw with context
                if error is CompositionError {
                    throw error
                } else if error is CancellationError {
                    throw CompositionError.operationCancelled
                } else {
                    throw CompositionError.documentCreationFailed
                }
            }
        }.value
    }
    
    // MARK: - Input Validation
    private static func validateInputs(pages: [PDFPage], cover: NSImage?) throws {
        // Check for empty pages
        guard !pages.isEmpty else {
            throw CompositionError.emptyPageList
        }
        
        // Check page count limits
        guard pages.count <= maxPageCount else {
            throw CompositionError.excessivePageCount(count: pages.count, limit: maxPageCount)
        }
        
        // Validate each page
        for (index, page) in pages.enumerated() {
            let bounds = page.bounds(for: .mediaBox)
            guard bounds.width > 0 && bounds.height > 0 else {
                throw CompositionError.invalidPage(index: index, reason: "Page has invalid bounds")
            }
            
            // Check for reasonable page dimensions (prevent memory issues)
            let maxDimension = max(bounds.width, bounds.height)
            guard maxDimension <= 14400 else { // 200 inches at 72 DPI
                throw CompositionError.invalidPage(index: index, reason: "Page dimensions too large (\(Int(maxDimension)) points)")
            }
        }
    }
    
    private static func validateCoverImage(_ cover: NSImage) throws -> NSImage {
        // Check basic validity
        guard cover.isValid, let rep = cover.representations.first else {
            throw CompositionError.invalidCoverImage(reason: "Image is not valid or has no representations")
        }
        
        // Check dimensions
        let size = cover.size
        guard size.width > 0 && size.height > 0 else {
            throw CompositionError.invalidCoverImage(reason: "Image has invalid dimensions")
        }
        
        let maxDimension = max(size.width, size.height)
        guard maxDimension <= maxCoverDimension else {
            throw CompositionError.invalidCoverImage(reason: "Image too large (\(Int(maxDimension)) points, max \(Int(maxCoverDimension)))")
        }
        
        // Estimate memory usage (rough calculation)
        let pixelCount = CGFloat(rep.pixelsWide) * CGFloat(rep.pixelsHigh)
        let estimatedBytes = pixelCount * 4 // 4 bytes per pixel (RGBA)
        guard estimatedBytes <= maxCoverImageSize else {
            throw CompositionError.invalidCoverImage(reason: "Image too large in memory (\(Int(estimatedBytes / 1_000_000))MB, max \(Int(maxCoverImageSize / 1_000_000))MB)")
        }
        
        return cover
    }
    
    // MARK: - Page Processing
    private static func processPages(pages: [PDFPage], document: PDFDocument, insertIndex: Int, createdResources: inout [AnyObject]) async throws {
        // Process pages in batches to prevent memory spikes
        let batchSize = min(50, pages.count)
        
        for batchStart in stride(from: 0, to: pages.count, by: batchSize) {
            try Task.checkCancellation()
            
            let batchEnd = min(batchStart + batchSize, pages.count)
            let batch = Array(pages[batchStart..<batchEnd])
            
            // Process batch with autoreleasepool for memory management
            // Note: PDFDocument is not thread-safe, so we process pages sequentially
            for (i, page) in batch.enumerated() {
                try Task.checkCancellation()
                
                let globalIndex = batchStart + i
                autoreleasepool {
                    let idx = (globalIndex < insertIndex) ? globalIndex : globalIndex + 1
                    document.insert(page, at: idx)
                }
            }
            
            // Small delay between batches to allow memory cleanup
            if batchEnd < pages.count {
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
    }
    
    // MARK: - Resource Cleanup
    private static func cleanupResources(_ resources: [AnyObject]) throws {
        for _ in resources {
            // Specific cleanup logic could go here
            // For now, just allow ARC to handle cleanup
        }
    }

    private static func coverInsertIndex(placement: CoverPlacement, pageCount: Int) -> Int {
        switch placement {
        case .topLeft, .top, .topRight: return 0
        case .left, .center, .right: return max(pageCount / 2, 0)
        case .bottomLeft, .bottom, .bottomRight: return pageCount
        }
    }

    private static func imageToPDFPage(image: NSImage, mode: CompositionMode = .export) async throws -> PDFPage {
        return try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            
            do {
                // Get TIFF representation with error handling
                guard let tiff = image.tiffRepresentation else {
                    throw CompositionError.coverProcessingFailed(underlyingError: "Cannot get TIFF representation of image")
                }
                
                guard let rep = NSBitmapImageRep(data: tiff) else {
                    throw CompositionError.coverProcessingFailed(underlyingError: "Cannot create bitmap representation from TIFF data")
                }
                
                try Task.checkCancellation()
                
                // Use appropriate compression based on mode
                let compressionFactor = NSNumber(value: Float(1.0 - mode.compressionQuality))
                let compressionProperties: [NSBitmapImageRep.PropertyKey: Any] = [
                    .compressionFactor: compressionFactor
                ]
                
                // Try to create compressed representation, fallback to TIFF
                let compressedData = rep.representation(using: .jpeg, properties: compressionProperties)
                let finalData = compressedData ?? tiff
                
                try Task.checkCancellation()
                
                guard let pdfDoc = PDFDocument(data: finalData), let page = pdfDoc.page(at: 0) else {
                    throw CompositionError.coverProcessingFailed(underlyingError: "Failed to create PDF page from image data")
                }
                
                // Validate the created page
                let pageBounds = page.bounds(for: .mediaBox)
                guard pageBounds.width > 0 && pageBounds.height > 0 else {
                    throw CompositionError.coverProcessingFailed(underlyingError: "Created PDF page has invalid bounds")
                }
                
                return page
                
            } catch {
                if error is CompositionError {
                    throw error
                } else if error is CancellationError {
                    throw CompositionError.operationCancelled
                } else {
                    throw CompositionError.coverProcessingFailed(underlyingError: error.localizedDescription)
                }
            }
        }.value
    }

    static func downsampleIfNeeded(image: NSImage, maxPPI: CGFloat = 300, pageSize: CGSize) -> NSImage {
        guard let rep = image.representations.first else { return image }
        
        // Prevent division by zero
        guard pageSize.width > 0 && pageSize.height > 0 else { return image }
        
        let pixelsWide = image.size.width * CGFloat(rep.pixelsWide) / image.size.width
        let pixelsHigh = image.size.height * CGFloat(rep.pixelsHigh) / image.size.height
        let ppiX = pixelsWide / pageSize.width * 72.0
        let ppiY = pixelsHigh / pageSize.height * 72.0
        
        if ppiX <= maxPPI && ppiY <= maxPPI { return image }
        
        let scale = min(maxPPI / ppiX, maxPPI / ppiY)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        // Validate new size
        guard newSize.width > 0 && newSize.height > 0 && newSize.width <= maxCoverDimension && newSize.height <= maxCoverDimension else {
            return image // Return original if downsampling would create invalid size
        }
        
        // Use memory-efficient downsampling with autoreleasepool and error handling
        return autoreleasepool {
            let newImage = NSImage(size: newSize)
            newImage.lockFocus()
            defer { newImage.unlockFocus() }
            
            // Use high-quality interpolation for better results
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
            
            return newImage
        }
    }
    
    // Enhanced downsampling function for better memory control
    static func downsampleToMaxDimension(image: NSImage, maxDimension: CGFloat) -> NSImage {
        let currentSize = image.size
        
        // Validate input parameters
        guard maxDimension > 0 && currentSize.width > 0 && currentSize.height > 0 else {
            return image
        }
        
        let maxCurrentDimension = max(currentSize.width, currentSize.height)
        
        if maxCurrentDimension <= maxDimension {
            return image
        }
        
        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(
            width: currentSize.width * scale,
            height: currentSize.height * scale
        )
        
        // Validate calculated size
        guard newSize.width > 0 && newSize.height > 0 && 
              newSize.width <= maxCoverDimension && newSize.height <= maxCoverDimension else {
            return image
        }
        
        return autoreleasepool {
            let newImage = NSImage(size: newSize)
            newImage.lockFocus()
            defer { newImage.unlockFocus() }
            
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: CGRect(origin: .zero, size: newSize))
            
            return newImage
        }
    }
}
