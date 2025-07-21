import Foundation
import PDFKit
import AppKit
import CoreImage

enum CoverPlacement: String, Codable, CaseIterable {
    case topLeft, top, topRight, left, center, right, bottomLeft, bottom, bottomRight
}

struct Composer {
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
        return try await Task.detached(priority: .userInitiated) {
            let document = PDFDocument()
            var insertIndex = 0
            
            if let cover = cover {
                // Optimize cover image based on mode
                let optimizedCover = mode == .preview ? downsampleIfNeeded(image: cover, maxPPI: 150, pageSize: cover.size) : cover
                let coverPage = try await imageToPDFPage(image: optimizedCover, mode: mode)
                insertIndex = coverInsertIndex(placement: coverPlacement, pageCount: pages.count)
                document.insert(coverPage, at: insertIndex)
            }
            
            // Use autoreleasepool for memory efficiency when processing multiple pages
            for (i, page) in pages.enumerated() {
                autoreleasepool {
                    let idx = (i < insertIndex) ? i : i + 1
                    document.insert(page, at: idx)
                }
            }
            
            return document
        }.value
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
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff) else {
                throw NSError(domain: "Composer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image for cover."])
            }
            
            // Use appropriate compression based on mode
            let compressionFactor = NSNumber(value: Float(1.0 - mode.compressionQuality))
            let compressionProperties: [NSBitmapImageRep.PropertyKey: Any] = [
                .compressionFactor: compressionFactor
            ]
            
            let pdfData = rep.representation(using: .jpeg, properties: compressionProperties) ?? tiff
            guard let pdfDoc = PDFDocument(data: pdfData), let page = pdfDoc.page(at: 0) else {
                throw NSError(domain: "Composer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF page from image."])
            }
            return page
        }.value
    }

    static func downsampleIfNeeded(image: NSImage, maxPPI: CGFloat = 300, pageSize: CGSize) -> NSImage {
        guard let rep = image.representations.first else { return image }
        
        let pixelsWide = image.size.width * CGFloat(rep.pixelsWide) / image.size.width
        let pixelsHigh = image.size.height * CGFloat(rep.pixelsHigh) / image.size.height
        let ppiX = pixelsWide / pageSize.width * 72.0
        let ppiY = pixelsHigh / pageSize.height * 72.0
        
        if ppiX <= maxPPI && ppiY <= maxPPI { return image }
        
        let scale = min(maxPPI / ppiX, maxPPI / ppiY)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        // Use memory-efficient downsampling with autoreleasepool
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
        let maxCurrentDimension = max(currentSize.width, currentSize.height)
        
        if maxCurrentDimension <= maxDimension {
            return image
        }
        
        let scale = maxDimension / maxCurrentDimension
        let newSize = CGSize(
            width: currentSize.width * scale,
            height: currentSize.height * scale
        )
        
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
