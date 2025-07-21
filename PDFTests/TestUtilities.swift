import Foundation
import PDFKit
import AppKit
import Testing
@testable import PDF

// MARK: - Mock PDF Generator

class MockPDFGenerator {
    
    enum PDFType {
        case simple(pageCount: Int)
        case withImages(pageCount: Int)
        case encrypted
        case corrupted
        case large(pageCount: Int) // For performance testing
        case empty
        case malicious // Contains JavaScript
    }
    
    /// Generates a mock PDF document for testing
    static func generatePDF(type: PDFType) -> (document: PDFDocument?, data: Data?) {
        switch type {
        case .simple(let pageCount):
            return generateSimplePDF(pageCount: pageCount)
        case .withImages(let pageCount):
            return generatePDFWithImages(pageCount: pageCount)
        case .encrypted:
            return generateEncryptedPDF()
        case .corrupted:
            return generateCorruptedPDF()
        case .large(let pageCount):
            return generateLargePDF(pageCount: pageCount)
        case .empty:
            return generateEmptyPDF()
        case .malicious:
            return generateMaliciousPDF()
        }
    }
    
    /// Creates a temporary file URL for testing
    static func createTemporaryFileURL(filename: String = "test.pdf") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(filename)
    }
    
    /// Writes PDF data to a temporary file and returns the URL
    static func writeToTemporaryFile(data: Data, filename: String = "test.pdf") -> URL? {
        let url = createTemporaryFileURL(filename: filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
    
    // MARK: - Private PDF Generation Methods
    
    private static func generateSimplePDF(pageCount: Int) -> (PDFDocument?, Data?) {
        let document = PDFDocument()
        
        for i in 0..<pageCount {
            let page = createTextPage(content: "Test Page \(i + 1)\n\nThis is a simple test page for unit testing.\n\nPage number: \(i + 1) of \(pageCount)")
            document.insert(page, at: i)
        }
        
        return (document, document.dataRepresentation())
    }
    
    private static func generatePDFWithImages(pageCount: Int) -> (PDFDocument?, Data?) {
        let document = PDFDocument()
        
        for i in 0..<pageCount {
            let page = createImagePage(pageNumber: i + 1)
            document.insert(page, at: i)
        }
        
        return (document, document.dataRepresentation())
    }
    
    private static func generateEncryptedPDF() -> (PDFDocument?, Data?) {
        // Note: PDFKit doesn't easily support creating encrypted PDFs programmatically
        // This would normally require external tools or libraries
        // For testing, we'll simulate by returning nil document but valid-looking data
        let simpleData = "Encrypted PDF simulation".data(using: .utf8)!
        return (nil, simpleData)
    }
    
    private static func generateCorruptedPDF() -> (PDFDocument?, Data?) {
        // Create invalid PDF data
        let corruptedData = "This is not a valid PDF file".data(using: .utf8)!
        return (nil, corruptedData)
    }
    
    private static func generateLargePDF(pageCount: Int) -> (PDFDocument?, Data?) {
        let document = PDFDocument()
        
        for i in 0..<pageCount {
            // Create pages with more content for larger file size
            let content = String(repeating: "Large PDF test content line \(i + 1). ", count: 100)
            let page = createTextPage(content: content)
            document.insert(page, at: i)
        }
        
        return (document, document.dataRepresentation())
    }
    
    private static func generateEmptyPDF() -> (PDFDocument?, Data?) {
        let document = PDFDocument()
        return (document, document.dataRepresentation())
    }
    
    private static func generateMaliciousPDF() -> (PDFDocument?, Data?) {
        // Create a PDF with simulated JavaScript content
        let document = PDFDocument()
        let page = createTextPage(content: "Test PDF with JavaScript simulation")
        document.insert(page, at: 0)
        
        // Simulate JavaScript by creating data that contains JS patterns
        let baseData = document.dataRepresentation() ?? Data()
        let jsContent = "/JavaScript this.print() app.alert()".data(using: .utf8)!
        let maliciousData = baseData + jsContent
        
        return (document, maliciousData)
    }
    
    // MARK: - Page Creation Helpers
    
    private static func createTextPage(content: String, size: CGSize = CGSize(width: 612, height: 792)) -> PDFPage {
        // Create a PDF page with text content
        let page = PDFPage()
        
        // Create text content using NSAttributedString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        
        let attributedString = NSAttributedString(string: content, attributes: attributes)
        
        // Create a simple annotation with the text (simplified approach)
        let textRect = CGRect(x: 50, y: 50, width: size.width - 100, height: size.height - 100)
        
        // For a more realistic PDF page, we'd use Core Graphics to draw text
        // This is a simplified version for testing purposes
        page.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
        
        return page
    }
    
    private static func createImagePage(pageNumber: Int, size: CGSize = CGSize(width: 612, height: 792)) -> PDFPage {
        // Create a test image
        let image = createTestImage(size: CGSize(width: 200, height: 200), pageNumber: pageNumber)
        
        // Convert image to PDF page
        let page = PDFPage()
        page.setBounds(CGRect(origin: .zero, size: size), for: .mediaBox)
        
        // Add image representation to page (simplified)
        // In a real implementation, we'd draw the image onto the page using Core Graphics
        
        return page
    }
    
    private static func createTestImage(size: CGSize, pageNumber: Int) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Draw a simple test image
        NSColor.lightGray.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        NSColor.black.setFill()
        let text = "Page \(pageNumber)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ]
        
        let textSize = text.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: attributes)
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Test Data Provider

class TestDataProvider {
    
    /// Provides various file sizes for testing file size validation
    static let fileSizes = [
        ("small", 1024), // 1KB
        ("medium", 50 * 1024 * 1024), // 50MB
        ("large", 100 * 1024 * 1024), // 100MB
        ("oversized", 150 * 1024 * 1024) // 150MB
    ]
    
    /// Provides various page counts for testing
    static let pageCounts = [0, 1, 10, 50, 100, 500, 1000, 1500]
    
    /// Provides test file extensions
    static let fileExtensions = ["pdf", "PDF", "txt", "doc", "jpg", "png"]
    
    /// Provides test MIME types
    static let mimeTypes = [
        "application/pdf",
        "text/plain",
        "image/jpeg",
        "application/octet-stream"
    ]
    
    /// Creates test NSImage instances
    static func createTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }
    
    /// Creates test cover placement configurations
    static let coverPlacements: [CoverPlacement] = CoverPlacement.allCases
    
    /// Creates test export formats
    static let exportFormats: [ExportFormat] = [.pdf, .png]
    
    /// Creates test thumbnail sizes
    static let thumbnailSizes = [
        CGSize(width: 80, height: 100),   // Placeholder size
        CGSize(width: 160, height: 200),  // Standard size
        CGSize(width: 320, height: 400)   // High quality size
    ]
}

// MARK: - Mock Classes for Testing

class MockThumbnailCache {
    private var cache: [Int: NSImage] = [:]
    private var loadingStates: Set<Int> = []
    
    func getThumbnail(for pageIndex: Int) -> NSImage? {
        return cache[pageIndex]
    }
    
    func setThumbnail(_ image: NSImage, for pageIndex: Int) {
        cache[pageIndex] = image
    }
    
    func isLoading(_ pageIndex: Int) -> Bool {
        return loadingStates.contains(pageIndex)
    }
    
    func setLoading(_ pageIndex: Int, loading: Bool) {
        if loading {
            loadingStates.insert(pageIndex)
        } else {
            loadingStates.remove(pageIndex)
        }
    }
    
    func clearCache() {
        cache.removeAll()
        loadingStates.removeAll()
    }
}

class MockPDFService {
    var shouldFailOpen = false
    var shouldFailExport = false
    var mockThumbnails: [String: NSImage] = [:]
    
    func open(url: URL) throws -> PDFDocument {
        if shouldFailOpen {
            throw NSError(domain: "MockPDFService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock failure"])
        }
        
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        return document!
    }
    
    func thumbnail(document: PDFDocument, page: Int, size: CGSize, useCache: Bool = true) -> NSImage? {
        let key = "\(page)_\(Int(size.width))x\(Int(size.height))"
        return mockThumbnails[key] ?? TestDataProvider.createTestImage(size: size)
    }
    
    func export(document: PDFDocument, format: ExportFormat, url: URL, quality: CGFloat = 0.9) throws {
        if shouldFailExport {
            throw NSError(domain: "MockPDFService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock export failure"])
        }
        
        // Create mock export data
        let data = "Mock exported data".data(using: .utf8)!
        try data.write(to: url)
    }
}

// MARK: - Test Assertions and Helpers

struct TestHelpers {
    
    /// Measures execution time of an async operation
    static func measureTime<T>(operation: () async throws -> T) async rethrows -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        return (result: result, time: endTime - startTime)
    }
    
    /// Measures memory usage during an operation
    static func measureMemoryUsage<T>(operation: () throws -> T) rethrows -> (result: T, memoryDelta: Int) {
        let memoryBefore = getMemoryUsage()
        let result = try operation()
        let memoryAfter = getMemoryUsage()
        return (result: result, memoryDelta: memoryAfter - memoryBefore)
    }
    
    /// Gets current memory usage in bytes
    static func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    /// Creates a temporary directory for test files
    static func createTemporaryTestDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("PDFTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        return testDir
    }
    
    /// Cleans up temporary test files
    static func cleanupTemporaryFiles(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Validates that an image has expected properties
    static func validateImage(_ image: NSImage, expectedSize: CGSize, tolerance: CGFloat = 1.0) -> Bool {
        let size = image.size
        return abs(size.width - expectedSize.width) <= tolerance && 
               abs(size.height - expectedSize.height) <= tolerance
    }
    
    /// Waits for an async condition to be met
    static func waitForCondition(
        timeout: TimeInterval = 5.0,
        checkInterval: TimeInterval = 0.1,
        condition: () async -> Bool
    ) async -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if await condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(Int(checkInterval * 1000)))
        }
        
        return false
    }
}

// MARK: - Performance Test Helpers

struct PerformanceTestHelpers {
    
    /// Standard performance thresholds for different operations
    struct Thresholds {
        static let thumbnailGeneration: TimeInterval = 0.5 // 500ms
        static let pdfLoading: TimeInterval = 2.0 // 2 seconds
        static let cacheOperation: TimeInterval = 0.1 // 100ms
        static let exportOperation: TimeInterval = 5.0 // 5 seconds
    }
    
    /// Standard memory usage limits
    struct MemoryLimits {
        static let thumbnailCache = 100 * 1024 * 1024 // 100MB
        static let singleThumbnail = 1024 * 1024 // 1MB
        static let batchOperation = 50 * 1024 * 1024 // 50MB
    }
    
    /// Creates a large PDF for performance testing
    static func createLargeTestPDF(pageCount: Int) -> (PDFDocument?, Data?) {
        return MockPDFGenerator.generatePDF(type: .large(pageCount: pageCount))
    }
    
    /// Generates load for concurrent testing
    static func generateConcurrentLoad<T>(
        operations: [() async throws -> T],
        maxConcurrency: Int = 10
    ) async -> [Result<T, Error>] {
        return await withTaskGroup(of: Result<T, Error>.self, returning: [Result<T, Error>].self) { group in
            var results: [Result<T, Error>] = []
            var activeCount = 0
            var operationIndex = 0
            
            // Add initial operations up to max concurrency
            while operationIndex < operations.count && activeCount < maxConcurrency {
                let operation = operations[operationIndex]
                group.addTask {
                    do {
                        let result = try await operation()
                        return .success(result)
                    } catch {
                        return .failure(error)
                    }
                }
                operationIndex += 1
                activeCount += 1
            }
            
            // Collect results and add remaining operations
            for await result in group {
                results.append(result)
                activeCount -= 1
                
                // Add next operation if available
                if operationIndex < operations.count {
                    let operation = operations[operationIndex]
                    group.addTask {
                        do {
                            let result = try await operation()
                            return .success(result)
                        } catch {
                            return .failure(error)
                        }
                    }
                    operationIndex += 1
                    activeCount += 1
                }
            }
            
            return results
        }
    }
}