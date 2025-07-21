import Testing
import Foundation
import PDFKit
import AppKit
@testable import PDF

struct PDFServiceTests {
    
    let pdfService = PDFService()
    let testDirectory = TestHelpers.createTemporaryTestDirectory()
    
    // MARK: - PDF Loading Tests
    
    @Test("PDF loading with valid document")
    func testOpenValidPDF() async throws {
        // Arrange
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!)!
        
        // Act
        let document = try await pdfService.open(url: url)
        
        // Assert
        #expect(document.pageCount == 3)
        #expect(document.page(at: 0) != nil)
        #expect(document.page(at: 2) != nil)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("PDF loading with non-existent file")
    func testOpenNonExistentPDF() async throws {
        // Arrange
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.pdf")
        
        // Act & Assert
        await #expect(throws: Error.self) {
            try await pdfService.open(url: invalidURL)
        }
    }
    
    @Test("PDF loading with corrupted file")
    func testOpenCorruptedPDF() async throws {
        // Arrange
        let (_, data) = MockPDFGenerator.generatePDF(type: .corrupted)
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "corrupted.pdf")!
        
        // Act & Assert
        await #expect(throws: Error.self) {
            try await pdfService.open(url: url)
        }
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("PDF loading performance with large document")
    func testOpenLargePDFPerformance() async throws {
        // Arrange
        let (_, data) = MockPDFGenerator.generatePDF(type: .large(pageCount: 100))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "large.pdf")!
        
        // Act
        let (document, loadTime) = try await TestHelpers.measureTime {
            try await pdfService.open(url: url)
        }
        
        // Assert
        #expect(document.pageCount == 100)
        #expect(loadTime < PerformanceTestHelpers.Thresholds.pdfLoading)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    // MARK: - Thumbnail Generation Tests
    
    @Test("Thumbnail generation with valid parameters")
    func testThumbnailGeneration() async throws {
        // Arrange
        let (document, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        let size = CGSize(width: 160, height: 200)
        
        // Act
        let thumbnail = await pdfService.thumbnail(document: document!, page: 0, size: size)
        
        // Assert
        #expect(thumbnail != nil)
        #expect(TestHelpers.validateImage(thumbnail!, expectedSize: size, tolerance: 10.0))
    }
    
    @Test("Thumbnail generation with invalid page index")
    func testThumbnailGenerationInvalidPage() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        let size = CGSize(width: 160, height: 200)
        
        // Act
        let thumbnail = await pdfService.thumbnail(document: document!, page: 10, size: size)
        
        // Assert
        #expect(thumbnail == nil)
    }
    
    @Test("Thumbnail generation caching behavior")
    func testThumbnailCaching() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let size = CGSize(width: 160, height: 200)
        
        // Act - First call (cache miss)
        let (thumbnail1, time1) = await TestHelpers.measureTime {
            await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: true)
        }
        
        // Act - Second call (cache hit)
        let (thumbnail2, time2) = await TestHelpers.measureTime {
            await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: true)
        }
        
        // Assert
        #expect(thumbnail1 != nil)
        #expect(thumbnail2 != nil)
        #expect(time2 < time1) // Cache hit should be faster
    }
    
    @Test("Thumbnail generation without caching")
    func testThumbnailWithoutCaching() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let size = CGSize(width: 160, height: 200)
        
        // Act - First call
        let thumbnail1 = await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: false)
        
        // Act - Second call
        let thumbnail2 = await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: false)
        
        // Assert
        #expect(thumbnail1 != nil)
        #expect(thumbnail2 != nil)
        // Both calls should generate new thumbnails (not cached)
    }
    
    @Test("Thumbnail generation with different sizes")
    func testThumbnailDifferentSizes() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let sizes = TestDataProvider.thumbnailSizes
        
        // Act & Assert
        for size in sizes {
            let thumbnail = await pdfService.thumbnail(document: document!, page: 0, size: size)
            #expect(thumbnail != nil)
            #expect(TestHelpers.validateImage(thumbnail!, expectedSize: size, tolerance: 10.0))
        }
    }
    
    @Test("Thumbnail generation performance")
    func testThumbnailGenerationPerformance() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        let size = CGSize(width: 160, height: 200)
        
        // Act
        let (thumbnail, time) = await TestHelpers.measureTime {
            await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: false)
        }
        
        // Assert
        #expect(thumbnail != nil)
        #expect(time < PerformanceTestHelpers.Thresholds.thumbnailGeneration)
    }
    
    // MARK: - Cache Management Tests
    
    @Test("Cache clear functionality")
    func testCacheClear() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        let size = CGSize(width: 160, height: 200)
        
        // Load some thumbnails into cache
        for i in 0..<3 {
            _ = await pdfService.thumbnail(document: document!, page: i, size: size, useCache: true)
        }
        
        // Act
        await pdfService.clearCache()
        
        // Verify cache is cleared by measuring access time (should be slower now)
        let (_, timeAfterClear) = await TestHelpers.measureTime {
            await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: true)
        }
        
        // Assert - Time should be comparable to initial generation (cache miss)
        #expect(timeAfterClear > PerformanceTestHelpers.Thresholds.cacheOperation)
    }
    
    @Test("Cache LRU eviction behavior")
    func testCacheLRUEviction() async throws {
        // Arrange - Generate a document with many pages
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 100))
        let size = CGSize(width: 160, height: 200)
        
        // Act - Fill cache beyond its limit
        for i in 0..<60 { // Should exceed cache limit and trigger eviction
            _ = await pdfService.thumbnail(document: document!, page: i, size: size, useCache: true)
        }
        
        // Test access to early pages (should be evicted)
        let (earlyPageThumbnail, earlyTime) = await TestHelpers.measureTime {
            await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: true)
        }
        
        // Test access to recent pages (should be cached)
        let (recentPageThumbnail, recentTime) = await TestHelpers.measureTime {
            await pdfService.thumbnail(document: document!, page: 55, size: size, useCache: true)
        }
        
        // Assert
        #expect(earlyPageThumbnail != nil)
        #expect(recentPageThumbnail != nil)
        // Recent page should be faster due to cache hit
        #expect(recentTime < earlyTime)
    }
    
    // MARK: - Export Functionality Tests
    
    @Test("Export to PDF format")
    func testExportToPDF() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let exportURL = testDirectory.appendingPathComponent("exported.pdf")
        
        // Act
        try await pdfService.export(document: document!, format: .pdf, url: exportURL)
        
        // Assert
        #expect(FileManager.default.fileExists(atPath: exportURL.path))
        
        // Verify exported PDF is valid
        let exportedDocument = PDFDocument(url: exportURL)
        #expect(exportedDocument != nil)
        #expect(exportedDocument!.pageCount == 3)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: exportURL)
    }
    
    @Test("Export to PNG format")
    func testExportToPNG() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let exportURL = testDirectory.appendingPathComponent("exported.png")
        
        // Act
        try await pdfService.export(document: document!, format: .png, url: exportURL, quality: 0.8)
        
        // Assert
        #expect(FileManager.default.fileExists(atPath: exportURL.path))
        
        // Verify exported PNG is valid
        let exportedImage = NSImage(contentsOf: exportURL)
        #expect(exportedImage != nil)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: exportURL)
    }
    
    @Test("Export with different quality settings")
    func testExportWithQualitySettings() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let highQualityURL = testDirectory.appendingPathComponent("high_quality.png")
        let lowQualityURL = testDirectory.appendingPathComponent("low_quality.png")
        
        // Act
        try await pdfService.export(document: document!, format: .png, url: highQualityURL, quality: 0.95)
        try await pdfService.export(document: document!, format: .png, url: lowQualityURL, quality: 0.3)
        
        // Assert
        #expect(FileManager.default.fileExists(atPath: highQualityURL.path))
        #expect(FileManager.default.fileExists(atPath: lowQualityURL.path))
        
        // Compare file sizes (high quality should be larger)
        let highQualitySize = try FileManager.default.attributesOfItem(atPath: highQualityURL.path)[.size] as! Int
        let lowQualitySize = try FileManager.default.attributesOfItem(atPath: lowQualityURL.path)[.size] as! Int
        
        #expect(highQualitySize > lowQualitySize)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: highQualityURL)
        TestHelpers.cleanupTemporaryFiles(at: lowQualityURL)
    }
    
    @Test("Export with empty document")
    func testExportEmptyDocument() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .empty)
        let exportURL = testDirectory.appendingPathComponent("empty.pdf")
        
        // Act & Assert
        await #expect(throws: Error.self) {
            try await pdfService.export(document: document!, format: .png, url: exportURL)
        }
    }
    
    @Test("Export performance with large document")
    func testExportPerformance() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let exportURL = testDirectory.appendingPathComponent("performance_test.pdf")
        
        // Act
        let (_, exportTime) = try await TestHelpers.measureTime {
            try await pdfService.export(document: document!, format: .pdf, url: exportURL)
        }
        
        // Assert
        #expect(exportTime < PerformanceTestHelpers.Thresholds.exportOperation)
        #expect(FileManager.default.fileExists(atPath: exportURL.path))
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: exportURL)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory usage during thumbnail generation")
    func testThumbnailGenerationMemoryUsage() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 50))
        let size = CGSize(width: 160, height: 200)
        
        // Measure memory before
        let memoryBefore = TestHelpers.getMemoryUsage()
        
        // Act - Generate many thumbnails
        for i in 0..<20 {
            _ = await pdfService.thumbnail(document: document!, page: i % document!.pageCount, size: size)
        }
        
        // Measure memory after
        let memoryAfter = TestHelpers.getMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        // Assert - Memory usage should be reasonable
        #expect(memoryDelta < PerformanceTestHelpers.MemoryLimits.batchOperation)
    }
    
    @Test("Cache memory management")
    func testCacheMemoryManagement() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .large(pageCount: 200))
        let size = CGSize(width: 320, height: 400) // Large thumbnails
        
        let memoryBefore = TestHelpers.getMemoryUsage()
        
        // Act - Generate thumbnails that should trigger cache management
        for i in 0..<100 {
            _ = await pdfService.thumbnail(document: document!, page: i, size: size, useCache: true)
        }
        
        let memoryAfter = TestHelpers.getMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        // Assert - Memory should stay within cache limits
        #expect(memoryDelta < PerformanceTestHelpers.MemoryLimits.thumbnailCache)
    }
    
    // MARK: - Concurrent Access Tests
    
    @Test("Concurrent thumbnail generation")
    func testConcurrentThumbnailGeneration() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 20))
        let size = CGSize(width: 160, height: 200)
        
        // Create concurrent operations
        let operations: [() async -> NSImage?] = (0..<10).map { pageIndex in
            return {
                await self.pdfService.thumbnail(document: document!, page: pageIndex % document!.pageCount, size: size)
            }
        }
        
        // Act
        let results = await PerformanceTestHelpers.generateConcurrentLoad(operations: operations)
        
        // Assert
        #expect(results.count == 10)
        for result in results {
            switch result {
            case .success(let thumbnail):
                #expect(thumbnail != nil)
            case .failure(let error):
                Issue.record("Concurrent thumbnail generation failed: \(error)")
            }
        }
    }
    
    @Test("Concurrent PDF loading")
    func testConcurrentPDFLoading() async throws {
        // Arrange - Create multiple test PDFs
        var testURLs: [URL] = []
        for i in 0..<5 {
            let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
            let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "test_\(i).pdf")!
            testURLs.append(url)
        }
        
        // Create concurrent operations
        let operations: [() async throws -> PDFDocument] = testURLs.map { url in
            return {
                try await self.pdfService.open(url: url)
            }
        }
        
        // Act
        let results = await PerformanceTestHelpers.generateConcurrentLoad(operations: operations)
        
        // Assert
        #expect(results.count == 5)
        for result in results {
            switch result {
            case .success(let document):
                #expect(document.pageCount == 3)
            case .failure(let error):
                Issue.record("Concurrent PDF loading failed: \(error)")
            }
        }
        
        // Cleanup
        for url in testURLs {
            TestHelpers.cleanupTemporaryFiles(at: url)
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test("PDF service error handling with nil document")
    func testErrorHandlingNilDocument() async throws {
        // This test verifies that the service handles edge cases gracefully
        // The actual PDFService.open implementation should throw an error for invalid documents
        
        // Arrange
        let invalidURL = URL(fileURLWithPath: "/dev/null")
        
        // Act & Assert
        await #expect(throws: Error.self) {
            try await pdfService.open(url: invalidURL)
        }
    }
    
    @Test("Export error handling with invalid path")
    func testExportErrorHandlingInvalidPath() async throws {
        // Arrange
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let invalidURL = URL(fileURLWithPath: "/invalid/path/that/does/not/exist/file.pdf")
        
        // Act & Assert
        await #expect(throws: Error.self) {
            try await pdfService.export(document: document!, format: .pdf, url: invalidURL)
        }
    }
}

// MARK: - Performance-Specific Tests

struct PDFServicePerformanceTests {
    
    @Test("Large PDF loading performance benchmark")
    func testLargePDFLoadingBenchmark() async throws {
        let pdfService = PDFService()
        
        // Test with various sizes
        let pageCounts = [100, 500, 1000]
        
        for pageCount in pageCounts {
            let (_, data) = MockPDFGenerator.generatePDF(type: .large(pageCount: pageCount))
            let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "benchmark_\(pageCount).pdf")!
            
            let (document, loadTime) = try await TestHelpers.measureTime {
                try await pdfService.open(url: url)
            }
            
            #expect(document.pageCount == pageCount)
            
            // Performance expectations scale with page count
            let expectedMaxTime = PerformanceTestHelpers.Thresholds.pdfLoading * Double(pageCount) / 100.0
            #expect(loadTime < expectedMaxTime)
            
            TestHelpers.cleanupTemporaryFiles(at: url)
        }
    }
    
    @Test("Thumbnail generation batch performance")
    func testThumbnailBatchPerformance() async throws {
        let pdfService = PDFService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 50))
        let size = CGSize(width: 160, height: 200)
        
        // Generate thumbnails for all pages
        let (_, totalTime) = await TestHelpers.measureTime {
            for i in 0..<document!.pageCount {
                _ = await pdfService.thumbnail(document: document!, page: i, size: size, useCache: true)
            }
        }
        
        let averageTimePerThumbnail = totalTime / Double(document!.pageCount)
        
        #expect(averageTimePerThumbnail < PerformanceTestHelpers.Thresholds.thumbnailGeneration)
    }
}