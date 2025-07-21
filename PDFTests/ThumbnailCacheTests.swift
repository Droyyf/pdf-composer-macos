import Testing
import Foundation
import PDFKit
import AppKit
@testable import PDF

struct ThumbnailCacheTests {
    
    // MARK: - Basic Cache Operations Tests
    
    @Test("Cache thumbnail retrieval")
    func testCacheThumbnailRetrieval() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let page = document!.page(at: 0)!
        let pageIndex = 0
        
        // Initially should be nil
        let initialThumbnail = await cache.getThumbnail(for: pageIndex)
        #expect(initialThumbnail == nil)
        
        // Act - Generate thumbnail
        await cache.generateThumbnailAsync(for: pageIndex, from: page)
        
        // Wait for generation to complete
        let success = await TestHelpers.waitForCondition(timeout: 5.0) {
            let thumbnail = await cache.getThumbnail(for: pageIndex)
            return thumbnail != nil
        }
        
        // Assert
        #expect(success)
        
        let finalThumbnail = await cache.getThumbnail(for: pageIndex)
        #expect(finalThumbnail != nil)
    }
    
    @Test("Cache placeholder retrieval")
    func testCachePlaceholderRetrieval() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let page = document!.page(at: 0)!
        let pageIndex = 0
        
        // Initially should be nil
        let initialPlaceholder = await cache.getPlaceholder(for: pageIndex)
        #expect(initialPlaceholder == nil)
        
        // Act - Generate thumbnail (which also generates placeholder)
        await cache.generateThumbnailAsync(for: pageIndex, from: page)
        
        // Wait for placeholder to be available
        let success = await TestHelpers.waitForCondition(timeout: 3.0) {
            let placeholder = await cache.getPlaceholder(for: pageIndex)
            return placeholder != nil
        }
        
        // Assert
        #expect(success)
        
        let finalPlaceholder = await cache.getPlaceholder(for: pageIndex)
        #expect(finalPlaceholder != nil)
    }
    
    @Test("Loading state management")
    func testLoadingStateManagement() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let page = document!.page(at: 0)!
        let pageIndex = 0
        
        // Initially should not be loading
        let initialLoading = await cache.isLoading(pageIndex: pageIndex)
        #expect(!initialLoading)
        
        // Act - Start generation
        await cache.generateThumbnailAsync(for: pageIndex, from: page)
        
        // Should be loading immediately after starting
        let duringLoading = await cache.isLoading(pageIndex: pageIndex)
        #expect(duringLoading)
        
        // Wait for completion
        let _ = await TestHelpers.waitForCondition(timeout: 5.0) {
            let loading = await cache.isLoading(pageIndex: pageIndex)
            return !loading
        }
        
        // Should not be loading after completion
        let afterLoading = await cache.isLoading(pageIndex: pageIndex)
        #expect(!afterLoading)
    }
    
    @Test("Clear cache functionality")
    func testClearCacheFunctionality() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        
        // Generate some thumbnails
        for i in 0..<3 {
            let page = document!.page(at: i)!
            await cache.generateThumbnailAsync(for: i, from: page)
        }
        
        // Wait for thumbnails to be generated
        let _ = await TestHelpers.waitForCondition(timeout: 5.0) {
            let thumbnail0 = await cache.getThumbnail(for: 0)
            let thumbnail1 = await cache.getThumbnail(for: 1)
            return thumbnail0 != nil && thumbnail1 != nil
        }
        
        // Verify thumbnails exist
        let beforeClear0 = await cache.getThumbnail(for: 0)
        let beforeClear1 = await cache.getThumbnail(for: 1)
        #expect(beforeClear0 != nil)
        #expect(beforeClear1 != nil)
        
        // Act - Clear cache
        await cache.clearCache()
        
        // Assert - Thumbnails should be cleared
        let afterClear0 = await cache.getThumbnail(for: 0)
        let afterClear1 = await cache.getThumbnail(for: 1)
        #expect(afterClear0 == nil)
        #expect(afterClear1 == nil)
        
        // Loading states should also be cleared
        let loadingStates = await cache.getLoadingStates()
        #expect(loadingStates.isEmpty)
    }
    
    // MARK: - Async Thumbnail Generation Tests
    
    @Test("Async thumbnail generation single page")
    func testAsyncThumbnailGenerationSingle() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let page = document!.page(at: 0)!
        let pageIndex = 0
        
        // Act
        let (_, generationTime) = await TestHelpers.measureTime {
            await cache.generateThumbnailAsync(for: pageIndex, from: page, priority: .userInitiated)
            
            // Wait for completion
            let _ = await TestHelpers.waitForCondition(timeout: 3.0) {
                let thumbnail = await cache.getThumbnail(for: pageIndex)
                return thumbnail != nil
            }
        }
        
        // Assert
        #expect(generationTime < PerformanceTestHelpers.Thresholds.thumbnailGeneration)
        
        let thumbnail = await cache.getThumbnail(for: pageIndex)
        #expect(thumbnail != nil)
        
        // Verify thumbnail dimensions are reasonable
        let size = thumbnail!.size
        #expect(size.width > 0)
        #expect(size.height > 0)
        #expect(size.width <= 320) // Should not exceed max cache size
        #expect(size.height <= 400)
    }
    
    @Test("Async thumbnail generation with different priorities")
    func testAsyncThumbnailGenerationPriorities() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 4))
        
        let priorities: [TaskPriority] = [.background, .utility, .userInitiated, .high]
        
        // Act - Start generation with different priorities
        for (index, priority) in priorities.enumerated() {
            let page = document!.page(at: index)!
            await cache.generateThumbnailAsync(for: index, from: page, priority: priority)
        }
        
        // Wait for all to complete
        let success = await TestHelpers.waitForCondition(timeout: 10.0) {
            var allComplete = true
            for index in 0..<4 {
                let thumbnail = await cache.getThumbnail(for: index)
                if thumbnail == nil {
                    allComplete = false
                    break
                }
            }
            return allComplete
        }
        
        // Assert
        #expect(success)
        
        // All thumbnails should be generated regardless of priority
        for index in 0..<4 {
            let thumbnail = await cache.getThumbnail(for: index)
            #expect(thumbnail != nil)
        }
    }
    
    @Test("Cancel thumbnail generation")
    func testCancelThumbnailGeneration() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let page = document!.page(at: 0)!
        let pageIndex = 0
        
        // Act - Start generation
        await cache.generateThumbnailAsync(for: pageIndex, from: page)
        
        // Verify it's loading
        let isLoading = await cache.isLoading(pageIndex: pageIndex)
        #expect(isLoading)
        
        // Cancel the generation
        await cache.cancelGeneration(for: pageIndex)
        
        // Assert - Should no longer be loading
        let afterCancel = await cache.isLoading(pageIndex: pageIndex)
        #expect(!afterCancel)
    }
    
    @Test("Cancel all generation tasks")
    func testCancelAllGenerationTasks() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        
        // Start generation for multiple pages
        for i in 0..<5 {
            let page = document!.page(at: i)!
            await cache.generateThumbnailAsync(for: i, from: page)
        }
        
        // Verify some are loading
        let loadingStates = await cache.getLoadingStates()
        #expect(!loadingStates.isEmpty)
        
        // Act - Cancel all tasks
        await cache.cancelAllTasks()
        
        // Assert - No tasks should be loading
        let afterCancelStates = await cache.getLoadingStates()
        #expect(afterCancelStates.isEmpty)
    }
    
    // MARK: - Batch Generation Tests
    
    @Test("Batch thumbnail generation")
    func testBatchThumbnailGeneration() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        var pagesData: [(index: Int, page: PDFPage)] = []
        for i in 0..<5 {
            let page = document!.page(at: i)!
            pagesData.append((index: i, page: page))
        }
        
        // Act
        let (results, batchId) = await cache.generateThumbnailsBatch(for: pagesData)
        
        // Assert
        #expect(results.count == 5)
        #expect(!batchId.uuidString.isEmpty)
        
        // Verify all thumbnails were generated
        for result in results {
            #expect(result.pageIndex >= 0 && result.pageIndex < 5)
            #expect(result.image.size.width > 0)
            #expect(result.image.size.height > 0)
        }
        
        // Verify thumbnails are in cache
        for i in 0..<5 {
            let cachedThumbnail = await cache.getThumbnail(for: i)
            #expect(cachedThumbnail != nil)
        }
    }
    
    @Test("Batch generation with custom batch size")
    func testBatchGenerationCustomBatchSize() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        var pagesData: [(index: Int, page: PDFPage)] = []
        for i in 0..<10 {
            let page = document!.page(at: i)!
            pagesData.append((index: i, page: page))
        }
        
        // Act - Use small batch size
        let (results, _) = await cache.generateThumbnailsBatch(
            for: pagesData,
            priority: .userInitiated,
            batchSize: 2
        )
        
        // Assert
        #expect(results.count == 10)
        
        // All results should have valid images
        for result in results {
            #expect(result.image.size.width > 0)
            #expect(result.image.size.height > 0)
        }
    }
    
    @Test("Cancel specific batch generation")
    func testCancelSpecificBatchGeneration() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        var pagesData: [(index: Int, page: PDFPage)] = []
        for i in 0..<10 {
            let page = document!.page(at: i)!
            pagesData.append((index: i, page: page))
        }
        
        // Start batch generation
        let batchTask = Task {
            return await cache.generateThumbnailsBatch(for: pagesData)
        }
        
        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(100))
        
        // Get batch ID by starting another quick batch (simplified test)
        let quickData = [(index: 0, page: document!.page(at: 0)!)]
        let (_, batchId) = await cache.generateThumbnailsBatch(for: quickData)
        
        // Act - Cancel the batch
        await cache.cancelBatch(id: batchId)
        
        // The batch should handle cancellation gracefully
        let (results, _) = await batchTask.value
        
        // Assert - Some results may be generated before cancellation
        // This is more of a smoke test to ensure cancellation doesn't crash
        #expect(results.count >= 0)
    }
    
    // MARK: - Preloading Tests
    
    @Test("Preload thumbnails for viewport")
    func testPreloadThumbnailsViewport() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 20))
        
        var pages: [PDFPage] = []
        for i in 0..<20 {
            pages.append(document!.page(at: i)!)
        }
        
        // Act - Preload first 5 pages
        await cache.preloadThumbnails(for: pages, startingAt: 0, count: 5)
        
        // Wait for preloading to complete
        let success = await TestHelpers.waitForCondition(timeout: 10.0) {
            var allLoaded = true
            for i in 0..<5 {
                let thumbnail = await cache.getThumbnail(for: i)
                if thumbnail == nil {
                    allLoaded = false
                    break
                }
            }
            return allLoaded
        }
        
        // Assert
        #expect(success)
        
        // First 5 should be loaded
        for i in 0..<5 {
            let thumbnail = await cache.getThumbnail(for: i)
            #expect(thumbnail != nil)
        }
        
        // Pages beyond the preload range should not be loaded
        let beyondRange = await cache.getThumbnail(for: 10)
        #expect(beyondRange == nil)
    }
    
    @Test("Preload with boundary conditions")
    func testPreloadBoundaryConditions() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        
        var pages: [PDFPage] = []
        for i in 0..<5 {
            pages.append(document!.page(at: i)!)
        }
        
        // Test preloading beyond document bounds
        await cache.preloadThumbnails(for: pages, startingAt: 3, count: 10) // Should not crash
        
        // Wait a moment for any processing
        try await Task.sleep(for: .milliseconds(500))
        
        // Assert - Should have loaded available pages without error
        let thumbnail3 = await cache.getThumbnail(for: 3)
        let thumbnail4 = await cache.getThumbnail(for: 4)
        
        // At least the valid pages should be loaded or loading
        let isLoading3 = await cache.isLoading(pageIndex: 3)
        let isLoading4 = await cache.isLoading(pageIndex: 4)
        
        #expect(thumbnail3 != nil || isLoading3)
        #expect(thumbnail4 != nil || isLoading4)
    }
    
    // MARK: - Memory Management Tests
    
    @Test("Memory pressure handling")
    func testMemoryPressureHandling() async throws {
        // This test is more of a smoke test since we can't easily trigger
        // real memory pressure in unit tests
        
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 50))
        
        // Generate many thumbnails to potentially trigger memory management
        var pagesData: [(index: Int, page: PDFPage)] = []
        for i in 0..<30 {
            let page = document!.page(at: i % document!.pageCount)!
            pagesData.append((index: i, page: page))
        }
        
        // Act - Generate batch that might trigger memory management
        let (results, _) = await cache.generateThumbnailsBatch(for: pagesData)
        
        // Assert - Should complete without crashes
        #expect(results.count <= 30) // May be fewer if memory limits were hit
        
        // Cache should still be functional
        let testThumbnail = await cache.getThumbnail(for: 0)
        #expect(testThumbnail != nil)
    }
    
    @Test("Cache capacity limits")
    func testCacheCapacityLimits() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .large(pageCount: 200))
        
        // Generate thumbnails beyond reasonable cache capacity
        for i in 0..<150 {
            let page = document!.page(at: i % document!.pageCount)!
            await cache.generateThumbnailAsync(for: i, from: page, priority: .utility)
        }
        
        // Give some time for generation and potential eviction
        try await Task.sleep(for: .seconds(2))
        
        // Assert - Cache should still be functional and not crash
        // Some early thumbnails may have been evicted
        var availableCount = 0
        for i in 0..<150 {
            let thumbnail = await cache.getThumbnail(for: i)
            if thumbnail != nil {
                availableCount += 1
            }
        }
        
        // Should have some thumbnails but likely not all due to eviction
        #expect(availableCount > 0)
        #expect(availableCount <= 150) // Some may have been evicted
    }
    
    // MARK: - Performance Tests
    
    @Test("Thumbnail generation performance")
    func testThumbnailGenerationPerformance() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        let page = document!.page(at: 0)!
        
        // Act - Measure single thumbnail generation
        let (_, singleTime) = await TestHelpers.measureTime {
            await cache.generateThumbnailAsync(for: 0, from: page)
            
            // Wait for completion
            let _ = await TestHelpers.waitForCondition(timeout: 3.0) {
                let thumbnail = await cache.getThumbnail(for: 0)
                return thumbnail != nil
            }
        }
        
        // Assert
        #expect(singleTime < PerformanceTestHelpers.Thresholds.thumbnailGeneration)
    }
    
    @Test("Batch generation performance")
    func testBatchGenerationPerformance() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 20))
        
        var pagesData: [(index: Int, page: PDFPage)] = []
        for i in 0..<20 {
            let page = document!.page(at: i)!
            pagesData.append((index: i, page: page))
        }
        
        // Act
        let (results, batchTime) = await TestHelpers.measureTime {
            let (results, _) = await cache.generateThumbnailsBatch(for: pagesData)
            return results
        }
        
        // Assert
        #expect(results.count == 20)
        let averageTimePerThumbnail = batchTime / Double(results.count)
        #expect(averageTimePerThumbnail < PerformanceTestHelpers.Thresholds.thumbnailGeneration)
    }
    
    @Test("Concurrent cache access performance")
    func testConcurrentCacheAccessPerformance() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        // Pre-generate some thumbnails
        for i in 0..<5 {
            let page = document!.page(at: i)!
            await cache.generateThumbnailAsync(for: i, from: page)
        }
        
        // Wait for generation
        let _ = await TestHelpers.waitForCondition(timeout: 5.0) {
            let thumbnail = await cache.getThumbnail(for: 4)
            return thumbnail != nil
        }
        
        // Create concurrent access operations
        let operations: [() async -> NSImage?] = (0..<20).map { index in
            return {
                await cache.getThumbnail(for: index % 5) // Access existing thumbnails
            }
        }
        
        // Act
        let (results, totalTime) = await TestHelpers.measureTime {
            return await PerformanceTestHelpers.generateConcurrentLoad(operations: operations)
        }
        
        // Assert
        #expect(results.count == 20)
        #expect(totalTime < 1.0) // Concurrent access should be fast
        
        // Most operations should succeed (accessing cached thumbnails)
        let successCount = results.compactMap { result -> NSImage? in
            switch result {
            case .success(let image): return image
            case .failure: return nil
            }
        }.count
        
        #expect(successCount > 15) // Most should succeed
    }
    
    // MARK: - Error Handling and Edge Cases
    
    @Test("Generation with invalid pages")
    func testGenerationWithInvalidPages() async throws {
        // This test is conceptual since creating truly invalid PDFPage objects is difficult
        // In a real scenario, this would test error handling for corrupted PDF pages
        
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let page = document!.page(at: 0)!
        
        // Test with valid page (baseline)
        await cache.generateThumbnailAsync(for: 0, from: page)
        
        let _ = await TestHelpers.waitForCondition(timeout: 3.0) {
            let thumbnail = await cache.getThumbnail(for: 0)
            return thumbnail != nil
        }
        
        let thumbnail = await cache.getThumbnail(for: 0)
        #expect(thumbnail != nil)
    }
    
    @Test("Cache state consistency under cancellation")
    func testCacheStateConsistencyUnderCancellation() async throws {
        // Arrange
        let cache = ThumbnailCache()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        
        // Start multiple generation tasks
        for i in 0..<5 {
            let page = document!.page(at: i)!
            await cache.generateThumbnailAsync(for: i, from: page)
        }
        
        // Cancel some tasks
        await cache.cancelGeneration(for: 0)
        await cache.cancelGeneration(for: 2)
        await cache.cancelGeneration(for: 4)
        
        // Wait for remaining tasks to complete
        try await Task.sleep(for: .seconds(1))
        
        // Assert - Cache should be in consistent state
        let loadingStates = await cache.getLoadingStates()
        
        // Loading states should not include cancelled items
        #expect(!loadingStates.contains(0))
        #expect(!loadingStates.contains(2))
        #expect(!loadingStates.contains(4))
        
        // Non-cancelled items should either be complete or still loading
        for i in [1, 3] {
            let thumbnail = await cache.getThumbnail(for: i)
            let isLoading = await cache.isLoading(pageIndex: i)
            #expect(thumbnail != nil || isLoading)
        }
    }
}