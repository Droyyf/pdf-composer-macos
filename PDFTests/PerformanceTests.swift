import Testing
import Foundation
import PDFKit
import AppKit
@testable import PDF

struct PerformanceTests {
    
    // MARK: - PDF Loading Performance Tests
    
    @Test("Large PDF loading performance")
    func testLargePDFLoadingPerformance() async throws {
        let pdfService = PDFService()
        
        // Test with progressively larger documents
        let testCases = [
            (pages: 50, name: "Medium"),
            (pages: 100, name: "Large"),
            (pages: 200, name: "XLarge")
        ]
        
        for testCase in testCases {
            let (_, data) = MockPDFGenerator.generatePDF(type: .large(pageCount: testCase.pages))
            let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "\(testCase.name.lowercased()).pdf")!
            
            let (document, loadTime) = await TestHelpers.measureTime {
                try await pdfService.open(url: url)
            }
            
            #expect(document.pageCount == testCase.pages)
            
            // Performance scales with document size
            let maxExpectedTime = PerformanceTestHelpers.Thresholds.pdfLoading * Double(testCase.pages) / 50.0
            #expect(loadTime < maxExpectedTime, "Loading \(testCase.pages) pages took \(loadTime)s, expected < \(maxExpectedTime)s")
            
            TestHelpers.cleanupTemporaryFiles(at: url)
        }
    }
    
    @Test("Concurrent PDF loading performance")
    func testConcurrentPDFLoadingPerformance() async throws {
        let pdfService = PDFService()
        
        // Create multiple test PDFs
        var testURLs: [URL] = []
        for i in 0..<10 {
            let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 20))
            let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "concurrent_\(i).pdf")!
            testURLs.append(url)
        }
        
        // Create concurrent loading operations
        let operations: [() async throws -> PDFDocument] = testURLs.map { url in
            return {
                try await pdfService.open(url: url)
            }
        }
        
        // Measure concurrent performance
        let (results, totalTime) = await TestHelpers.measureTime {
            return await PerformanceTestHelpers.generateConcurrentLoad(operations: operations, maxConcurrency: 5)
        }
        
        // Assert performance
        #expect(results.count == 10)
        #expect(totalTime < 15.0) // Should complete within 15 seconds
        
        let averageTimePerDocument = totalTime / Double(results.count)
        #expect(averageTimePerDocument < 2.0)
        
        // Verify all succeeded
        for result in results {
            switch result {
            case .success(let document):
                #expect(document.pageCount == 20)
            case .failure(let error):
                Issue.record("Concurrent PDF loading failed: \(error)")
            }
        }
        
        // Cleanup
        for url in testURLs {
            TestHelpers.cleanupTemporaryFiles(at: url)
        }
    }
    
    // MARK: - Thumbnail Generation Performance Tests
    
    @Test("Thumbnail generation performance at different sizes")
    func testThumbnailGenerationPerformanceSizes() async throws {
        let pdfService = PDFService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 20))
        
        let testSizes = [
            CGSize(width: 80, height: 100),   // Small
            CGSize(width: 160, height: 200),  // Medium
            CGSize(width: 320, height: 400),  // Large
            CGSize(width: 640, height: 800)   // XLarge
        ]
        
        for size in testSizes {
            let (thumbnail, generationTime) = await TestHelpers.measureTime {
                await pdfService.thumbnail(document: document!, page: 0, size: size, useCache: false)
            }
            
            #expect(thumbnail != nil)
            
            // Larger thumbnails should take more time but still be reasonable
            let sizeMultiplier = (size.width * size.height) / (80 * 100) // Relative to smallest size
            let maxExpectedTime = PerformanceTestHelpers.Thresholds.thumbnailGeneration * sqrt(sizeMultiplier)
            
            #expect(generationTime < maxExpectedTime, 
                   "Thumbnail \(Int(size.width))x\(Int(size.height)) took \(generationTime)s, expected < \(maxExpectedTime)s")
        }
    }
    
    @Test("Batch thumbnail generation performance")
    func testBatchThumbnailGenerationPerformance() async throws {
        let thumbnailService = ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 50))
        
        let batchSizes = [5, 10, 20, 50]
        
        for batchSize in batchSizes {
            let pageIndices = Array(0..<batchSize)
            
            let (results, batchTime) = await TestHelpers.measureTime {
                await thumbnailService.loadThumbnailsBatch(
                    from: document!,
                    pageIndices: pageIndices,
                    options: .standard
                )
            }
            
            #expect(results.count == batchSize)
            
            let averageTimePerThumbnail = batchTime / Double(batchSize)
            #expect(averageTimePerThumbnail < PerformanceTestHelpers.Thresholds.thumbnailGeneration)
            
            // Batch processing should be more efficient than individual generation
            // (This is hard to test precisely, but we can ensure it's reasonable)
            #expect(batchTime < Double(batchSize) * PerformanceTestHelpers.Thresholds.thumbnailGeneration)
        }
    }
    
    @Test("Thumbnail cache performance")
    func testThumbnailCachePerformance() async throws {
        let thumbnailCache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 100))
        
        // Generate initial thumbnails
        var pagesData: [(index: Int, page: PDFPage)] = []
        for i in 0..<20 {
            let page = document!.page(at: i)!
            pagesData.append((index: i, page: page))
        }
        
        // Warm up the cache
        let (_, warmupTime) = await TestHelpers.measureTime {
            let (_, _) = await thumbnailCache.generateThumbnailsBatch(for: pagesData)
        }
        
        // Wait for completion
        let _ = await TestHelpers.waitForCondition(timeout: 10.0) {
            let thumbnail = await thumbnailCache.getThumbnail(for: 19)
            return thumbnail != nil
        }
        
        // Test cache hit performance
        let (cachedResults, cacheTime) = await TestHelpers.measureTime {
            var results: [NSImage?] = []
            for i in 0..<20 {
                let thumbnail = await thumbnailCache.getThumbnail(for: i)
                results.append(thumbnail)
            }
            return results
        }
        
        // Cache hits should be much faster
        let averageCacheTime = cacheTime / Double(cachedResults.count)
        #expect(averageCacheTime < PerformanceTestHelpers.Thresholds.cacheOperation)
        #expect(cacheTime < warmupTime / 5) // Cache should be at least 5x faster
        
        // All cached items should be retrieved
        let nonNilCount = cachedResults.compactMap { $0 }.count
        #expect(nonNilCount == 20)
    }
    
    // MARK: - Memory Performance Tests
    
    @Test("Memory usage during thumbnail generation")
    func testMemoryUsageThumbnailGeneration() async throws {
        let thumbnailCache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .large(pageCount: 100))
        
        let memoryBefore = TestHelpers.getMemoryUsage()
        
        // Generate many thumbnails
        var pagesData: [(index: Int, page: PDFPage)] = []
        for i in 0..<50 {
            let page = document!.page(at: i)!
            pagesData.append((index: i, page: page))
        }
        
        let (results, generationTime) = await TestHelpers.measureTime {
            let (results, _) = await thumbnailCache.generateThumbnailsBatch(for: pagesData)
            return results
        }
        
        let memoryAfter = TestHelpers.getMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        // Assert reasonable memory usage
        #expect(results.count == 50)
        #expect(memoryDelta < PerformanceTestHelpers.MemoryLimits.batchOperation)
        #expect(generationTime < 30.0) // Should complete within 30 seconds
        
        // Memory per thumbnail should be reasonable
        let memoryPerThumbnail = memoryDelta / 50
        #expect(memoryPerThumbnail < PerformanceTestHelpers.MemoryLimits.singleThumbnail)
    }
    
    @Test("Memory pressure simulation")
    func testMemoryPressureSimulation() async throws {
        let thumbnailCache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .large(pageCount: 200))
        
        // Generate thumbnails until cache management kicks in
        var totalGenerated = 0
        let maxIterations = 20
        
        for iteration in 0..<maxIterations {
            let startIndex = iteration * 10
            let endIndex = min(startIndex + 10, 200)
            
            var pagesData: [(index: Int, page: PDFPage)] = []
            for i in startIndex..<endIndex {
                let page = document!.page(at: i)!
                pagesData.append((index: i, page: page))
            }
            
            let (results, _) = await thumbnailCache.generateThumbnailsBatch(for: pagesData)
            totalGenerated += results.count
            
            // Memory measurement after each batch
            let currentMemory = TestHelpers.getMemoryUsage()
            
            // Ensure memory stays within reasonable bounds
            if currentMemory > PerformanceTestHelpers.MemoryLimits.thumbnailCache * 2 {
                Issue.record("Memory usage exceeded safe limits: \(currentMemory / (1024*1024))MB")
                break
            }
        }
        
        #expect(totalGenerated > 50) // Should have generated a reasonable number
        
        // Cache should still be functional
        let testThumbnail = await thumbnailCache.getThumbnail(for: 0)
        #expect(testThumbnail != nil || await thumbnailCache.isLoading(pageIndex: 0))
    }
    
    // MARK: - Document Composition Performance Tests
    
    @Test("Large document composition performance")
    func testLargeDocumentCompositionPerformance() async throws {
        // Arrange
        let (sourceDoc1, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 50))
        let (sourceDoc2, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 50))
        
        var allPages: [PDFPage] = []
        for i in 0..<50 {
            allPages.append(sourceDoc1!.page(at: i)!)
            allPages.append(sourceDoc2!.page(at: i)!)
        }
        
        let coverImage = TestDataProvider.createTestImage(size: CGSize(width: 800, height: 1000))
        
        // Act
        let (composedDoc, compositionTime) = await TestHelpers.measureTime {
            try await Composer.merge(
                pages: allPages,
                cover: coverImage,
                coverPlacement: .top,
                mode: .export
            )
        }
        
        // Assert
        #expect(composedDoc.pageCount == 101) // 100 pages + cover
        #expect(compositionTime < 20.0) // Should complete within 20 seconds
        
        // Verify document integrity
        #expect(composedDoc.page(at: 0) != nil) // Cover page
        #expect(composedDoc.page(at: 50) != nil) // Middle page
        #expect(composedDoc.page(at: 100) != nil) // Last page
    }
    
    @Test("Composition with image optimization performance")
    func testCompositionImageOptimizationPerformance() async throws {
        // Arrange - Create a large cover image
        let largeCoverImage = TestDataProvider.createTestImage(size: CGSize(width: 3000, height: 4000))
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        var pages: [PDFPage] = []
        for i in 0..<10 {
            pages.append(document!.page(at: i)!)
        }
        
        // Test both preview and export modes
        let modes: [Composer.CompositionMode] = [.preview, .export]
        
        for mode in modes {
            let (composedDoc, compositionTime) = await TestHelpers.measureTime {
                try await Composer.merge(
                    pages: pages,
                    cover: largeCoverImage,
                    coverPlacement: .top,
                    mode: mode
                )
            }
            
            #expect(composedDoc.pageCount == 11) // 10 pages + cover
            
            // Preview mode should be faster due to optimization
            if mode == .preview {
                #expect(compositionTime < 10.0)
            } else {
                #expect(compositionTime < 15.0)
            }
        }
    }
    
    // MARK: - Export Performance Tests
    
    @Test("Export performance different formats")
    func testExportPerformanceDifferentFormats() async throws {
        let pdfService = PDFService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 20))
        
        let testFormats: [ExportFormat] = [.pdf, .png]
        
        for format in testFormats {
            let exportURL = TestHelpers.createTemporaryTestDirectory()
                .appendingPathComponent("export_test.\(format.rawValue.lowercased())")
            
            let (_, exportTime) = await TestHelpers.measureTime {
                try await pdfService.export(document: document!, format: format, url: exportURL)
            }
            
            #expect(FileManager.default.fileExists(atPath: exportURL.path))
            #expect(exportTime < PerformanceTestHelpers.Thresholds.exportOperation)
            
            TestHelpers.cleanupTemporaryFiles(at: exportURL)
        }
    }
    
    @Test("Concurrent export operations performance")
    func testConcurrentExportOperationsPerformance() async throws {
        let pdfService = PDFService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        // Create concurrent export operations
        var exportURLs: [URL] = []
        let operations: [() async throws -> Void] = (0..<5).map { index in
            let exportURL = TestHelpers.createTemporaryTestDirectory()
                .appendingPathComponent("concurrent_export_\(index).pdf")
            exportURLs.append(exportURL)
            
            return {
                try await pdfService.export(document: document!, format: .pdf, url: exportURL)
            }
        }
        
        // Execute concurrent exports
        let (results, totalTime) = await TestHelpers.measureTime {
            return await PerformanceTestHelpers.generateConcurrentLoad(operations: operations)
        }
        
        // Assert performance
        #expect(results.count == 5)
        #expect(totalTime < 15.0) // Should complete within 15 seconds
        
        // Verify all exports succeeded
        for (index, result) in results.enumerated() {
            switch result {
            case .success:
                #expect(FileManager.default.fileExists(atPath: exportURLs[index].path))
            case .failure(let error):
                Issue.record("Concurrent export failed: \(error)")
            }
        }
        
        // Cleanup
        for url in exportURLs {
            TestHelpers.cleanupTemporaryFiles(at: url)
        }
    }
    
    // MARK: - Security Validation Performance Tests
    
    @Test("Security validation performance large files")
    func testSecurityValidationPerformanceLargeFiles() async throws {
        let validator = PDFSecurityValidator()
        
        let testSizes = [50, 100, 200] // Page counts
        
        for size in testSizes {
            let (_, data) = MockPDFGenerator.generatePDF(type: .large(pageCount: size))
            let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "security_test_\(size).pdf")!
            
            let (_, validationTime) = await TestHelpers.measureTime {
                try await validator.validateFile(at: url)
            }
            
            // Validation time should scale reasonably with file size
            let maxExpectedTime = 5.0 + (Double(size) / 50.0) * 2.0 // Base + scaling factor
            #expect(validationTime < maxExpectedTime, 
                   "Validation of \(size) pages took \(validationTime)s, expected < \(maxExpectedTime)s")
            
            TestHelpers.cleanupTemporaryFiles(at: url)
        }
    }
    
    @Test("Concurrent security validation performance")
    func testConcurrentSecurityValidationPerformance() async throws {
        let validator = PDFSecurityValidator()
        
        // Create multiple test files
        var testURLs: [URL] = []
        for i in 0..<8 {
            let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 25))
            let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "concurrent_validation_\(i).pdf")!
            testURLs.append(url)
        }
        
        // Create concurrent validation operations
        let operations: [() async throws -> Void] = testURLs.map { url in
            return {
                try await validator.validateFile(at: url)
            }
        }
        
        // Execute concurrent validations
        let (results, totalTime) = await TestHelpers.measureTime {
            return await PerformanceTestHelpers.generateConcurrentLoad(operations: operations, maxConcurrency: 4)
        }
        
        // Assert performance
        #expect(results.count == 8)
        #expect(totalTime < 20.0) // Should complete within 20 seconds
        
        // Verify all validations succeeded
        for result in results {
            switch result {
            case .success:
                // Expected
                break
            case .failure(let error):
                Issue.record("Concurrent validation failed: \(error)")
            }
        }
        
        // Cleanup
        for url in testURLs {
            TestHelpers.cleanupTemporaryFiles(at: url)
        }
    }
    
    // MARK: - Overall System Performance Tests
    
    @Test("End-to-end workflow performance")
    func testEndToEndWorkflowPerformance() async throws {
        // Simulate a complete user workflow
        let pdfService = PDFService()
        let thumbnailService = ThumbnailService()
        let validator = PDFSecurityValidator()
        
        // Create test PDF
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 30))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "workflow_test.pdf")!
        
        let (_, totalTime) = await TestHelpers.measureTime {
            // Step 1: Security validation
            try await validator.validateFile(at: url)
            
            // Step 2: Load PDF
            let document = try await pdfService.open(url: url)
            
            // Step 3: Generate thumbnails for first 10 pages
            let pageIndices = Array(0..<min(10, document.pageCount))
            let _ = await thumbnailService.loadThumbnailsBatch(from: document, pageIndices: pageIndices)
            
            // Step 4: Compose with cover
            let coverImage = TestDataProvider.createTestImage()
            var pages: [PDFPage] = []
            for i in 0..<min(10, document.pageCount) {
                pages.append(document.page(at: i)!)
            }
            
            let composedDoc = try await Composer.merge(
                pages: pages,
                cover: coverImage,
                coverPlacement: .top,
                mode: .export
            )
            
            // Step 5: Export final document
            let exportURL = TestHelpers.createTemporaryTestDirectory()
                .appendingPathComponent("workflow_final.pdf")
            
            try await pdfService.export(document: composedDoc, format: .pdf, url: exportURL)
            
            TestHelpers.cleanupTemporaryFiles(at: exportURL)
        }
        
        // Assert - Complete workflow should be reasonably fast
        #expect(totalTime < 30.0, "Complete workflow took \(totalTime)s, expected < 30s")
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("System stress test")
    func testSystemStressTest() async throws {
        // This test simulates high load on the system
        let pdfService = PDFService()
        let thumbnailService = ThumbnailService()
        
        let (document, _) = MockPDFGenerator.generatePDF(type: .large(pageCount: 100))
        let memoryBefore = TestHelpers.getMemoryUsage()
        
        let (_, stressTime) = await TestHelpers.measureTime {
            // Multiple concurrent operations
            await withTaskGroup(of: Void.self) { group in
                // Thumbnail generation tasks
                for i in 0..<5 {
                    group.addTask {
                        let startIndex = i * 20
                        let pageIndices = Array(startIndex..<min(startIndex + 20, document!.pageCount))
                        let _ = await thumbnailService.loadThumbnailsBatch(from: document!, pageIndices: pageIndices)
                    }
                }
                
                // PDF operations
                group.addTask {
                    for i in 0..<20 {
                        let _ = await pdfService.thumbnail(document: document!, page: i % document!.pageCount, 
                                                         size: CGSize(width: 100, height: 120), useCache: true)
                    }
                }
            }
        }
        
        let memoryAfter = TestHelpers.getMemoryUsage()
        let memoryDelta = memoryAfter - memoryBefore
        
        // Assert system handles stress reasonably
        #expect(stressTime < 60.0, "Stress test took \(stressTime)s, expected < 60s")
        #expect(memoryDelta < PerformanceTestHelpers.MemoryLimits.thumbnailCache * 2)
        
        // System should still be responsive
        let quickThumbnail = await pdfService.thumbnail(document: document!, page: 0, 
                                                       size: CGSize(width: 80, height: 100))
        #expect(quickThumbnail != nil)
    }
}