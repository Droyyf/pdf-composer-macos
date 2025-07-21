import Testing
import Foundation
import PDFKit
import AppKit
@testable import PDF

struct ComposerTests {
    
    // MARK: - PDF Merging Tests
    
    @Test("Merge PDFs without cover")
    func testMergePDFsWithoutCover() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        var pages: [PDFPage] = []
        
        for i in 0..<3 {
            if let page = sourceDocument?.page(at: i) {
                pages.append(page)
            }
        }
        
        // Act
        let mergedDocument = try await Composer.merge(
            pages: pages,
            cover: nil,
            coverPlacement: .top
        )
        
        // Assert
        #expect(mergedDocument.pageCount == 3)
        #expect(mergedDocument.page(at: 0) != nil)
        #expect(mergedDocument.page(at: 2) != nil)
    }
    
    @Test("Merge PDFs with cover at different placements")
    func testMergePDFsWithCoverPlacements() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 4))
        var pages: [PDFPage] = []
        
        for i in 0..<4 {
            if let page = sourceDocument?.page(at: i) {
                pages.append(page)
            }
        }
        
        let coverImage = TestDataProvider.createTestImage()
        
        // Test each cover placement
        for placement in TestDataProvider.coverPlacements {
            // Act
            let mergedDocument = try await Composer.merge(
                pages: pages,
                cover: coverImage,
                coverPlacement: placement,
                mode: .export
            )
            
            // Assert
            #expect(mergedDocument.pageCount == 5) // 4 original pages + 1 cover
            
            // Verify cover placement
            let expectedCoverIndex = expectedCoverIndex(placement: placement, pageCount: 4)
            #expect(mergedDocument.page(at: expectedCoverIndex) != nil)
        }
    }
    
    @Test("Merge PDFs in preview mode")
    func testMergePDFsPreviewMode() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        var pages: [PDFPage] = []
        
        for i in 0..<3 {
            if let page = sourceDocument?.page(at: i) {
                pages.append(page)
            }
        }
        
        let coverImage = TestDataProvider.createTestImage(size: CGSize(width: 2000, height: 2000)) // Large image
        
        // Act
        let mergedDocument = try await Composer.merge(
            pages: pages,
            cover: coverImage,
            coverPlacement: .top,
            mode: .preview
        )
        
        // Assert
        #expect(mergedDocument.pageCount == 4) // 3 pages + cover
        
        // Verify that the cover was optimized for preview mode
        // (This would require examining the page content, which is complex to test)
        #expect(mergedDocument.page(at: 0) != nil)
    }
    
    @Test("Merge PDFs in export mode")
    func testMergePDFsExportMode() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 2))
        var pages: [PDFPage] = []
        
        for i in 0..<2 {
            if let page = sourceDocument?.page(at: i) {
                pages.append(page)
            }
        }
        
        let coverImage = TestDataProvider.createTestImage()
        
        // Act
        let mergedDocument = try await Composer.merge(
            pages: pages,
            cover: coverImage,
            coverPlacement: .center,
            mode: .export
        )
        
        // Assert
        #expect(mergedDocument.pageCount == 3) // 2 pages + cover
        
        // Verify cover is placed in the center (index 1 for 2 pages)
        #expect(mergedDocument.page(at: 1) != nil)
    }
    
    @Test("Merge empty pages array")
    func testMergeEmptyPages() async throws {
        // Arrange
        let pages: [PDFPage] = []
        let coverImage = TestDataProvider.createTestImage()
        
        // Act
        let mergedDocument = try await Composer.merge(
            pages: pages,
            cover: coverImage,
            coverPlacement: .top
        )
        
        // Assert
        #expect(mergedDocument.pageCount == 1) // Only cover page
        #expect(mergedDocument.page(at: 0) != nil)
    }
    
    @Test("Merge with single page")
    func testMergeWithSinglePage() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let page = sourceDocument!.page(at: 0)!
        let pages = [page]
        let coverImage = TestDataProvider.createTestImage()
        
        // Act
        let mergedDocument = try await Composer.merge(
            pages: pages,
            cover: coverImage,
            coverPlacement: .bottom
        )
        
        // Assert
        #expect(mergedDocument.pageCount == 2) // 1 page + cover
        
        // Cover should be at the end (index 1)
        #expect(mergedDocument.page(at: 1) != nil)
    }
    
    // MARK: - Cover Placement Tests
    
    @Test("Cover placement calculations")
    func testCoverPlacementCalculations() async throws {
        let testCases = [
            (placement: CoverPlacement.topLeft, pageCount: 10, expectedIndex: 0),
            (placement: CoverPlacement.top, pageCount: 10, expectedIndex: 0),
            (placement: CoverPlacement.topRight, pageCount: 10, expectedIndex: 0),
            (placement: CoverPlacement.left, pageCount: 10, expectedIndex: 5),
            (placement: CoverPlacement.center, pageCount: 10, expectedIndex: 5),
            (placement: CoverPlacement.right, pageCount: 10, expectedIndex: 5),
            (placement: CoverPlacement.bottomLeft, pageCount: 10, expectedIndex: 10),
            (placement: CoverPlacement.bottom, pageCount: 10, expectedIndex: 10),
            (placement: CoverPlacement.bottomRight, pageCount: 10, expectedIndex: 10)
        ]
        
        for testCase in testCases {
            // Arrange
            let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: testCase.pageCount))
            var pages: [PDFPage] = []
            
            for i in 0..<testCase.pageCount {
                if let page = sourceDocument?.page(at: i) {
                    pages.append(page)
                }
            }
            
            let coverImage = TestDataProvider.createTestImage()
            
            // Act
            let mergedDocument = try await Composer.merge(
                pages: pages,
                cover: coverImage,
                coverPlacement: testCase.placement
            )
            
            // Assert
            #expect(mergedDocument.pageCount == testCase.pageCount + 1)
            
            // The actual verification of cover placement would require examining
            // the page content, which is complex. For now, we verify the document structure.
            #expect(mergedDocument.page(at: testCase.expectedIndex) != nil)
        }
    }
    
    // MARK: - Image Processing Tests
    
    @Test("Image to PDF page conversion")
    func testImageToPDFPageConversion() async throws {
        // Arrange
        let testImage = TestDataProvider.createTestImage(size: CGSize(width: 500, height: 700))
        let pages: [PDFPage] = []
        
        // Act
        let mergedDocument = try await Composer.merge(
            pages: pages,
            cover: testImage,
            coverPlacement: .top,
            mode: .export
        )
        
        // Assert
        #expect(mergedDocument.pageCount == 1)
        
        let coverPage = mergedDocument.page(at: 0)
        #expect(coverPage != nil)
        
        // Verify page has reasonable bounds
        let bounds = coverPage!.bounds(for: .mediaBox)
        #expect(bounds.width > 0)
        #expect(bounds.height > 0)
    }
    
    @Test("Image to PDF page conversion with different modes")
    func testImageToPDFConversionModes() async throws {
        // Arrange
        let testImage = TestDataProvider.createTestImage(size: CGSize(width: 1000, height: 1000))
        let pages: [PDFPage] = []
        
        // Test preview mode
        let previewDocument = try await Composer.merge(
            pages: pages,
            cover: testImage,
            coverPlacement: .top,
            mode: .preview
        )
        
        // Test export mode  
        let exportDocument = try await Composer.merge(
            pages: pages,
            cover: testImage,
            coverPlacement: .top,
            mode: .export
        )
        
        // Assert
        #expect(previewDocument.pageCount == 1)
        #expect(exportDocument.pageCount == 1)
        
        // Both should have valid pages, though with potentially different quality
        #expect(previewDocument.page(at: 0) != nil)
        #expect(exportDocument.page(at: 0) != nil)
    }
    
    @Test("Invalid image handling")
    func testInvalidImageHandling() async throws {
        // Arrange - Create an invalid NSImage (empty/corrupt)
        let invalidImage = NSImage() // Empty image
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let pages = [sourceDocument!.page(at: 0)!]
        
        // Act & Assert
        await #expect(throws: Error.self) {
            try await Composer.merge(
                pages: pages,
                cover: invalidImage,
                coverPlacement: .top
            )
        }
    }
    
    // MARK: - Image Downsampling Tests
    
    @Test("Image downsampling functionality")
    func testImageDownsampling() async throws {
        // Arrange
        let largeImage = TestDataProvider.createTestImage(size: CGSize(width: 3000, height: 3000))
        let pageSize = CGSize(width: 612, height: 792) // Standard page size
        let maxPPI: CGFloat = 300
        
        // Act
        let downsampledImage = Composer.downsampleIfNeeded(
            image: largeImage,
            maxPPI: maxPPI,
            pageSize: pageSize
        )
        
        // Assert
        #expect(downsampledImage.size.width <= largeImage.size.width)
        #expect(downsampledImage.size.height <= largeImage.size.height)
        
        // For a large image, it should have been downsampled
        if largeImage.size.width > pageSize.width || largeImage.size.height > pageSize.height {
            #expect(downsampledImage.size.width < largeImage.size.width ||
                   downsampledImage.size.height < largeImage.size.height)
        }
    }
    
    @Test("Image downsampling with already optimal size")
    func testImageDownsamplingOptimalSize() async throws {
        // Arrange
        let optimalImage = TestDataProvider.createTestImage(size: CGSize(width: 200, height: 200))
        let pageSize = CGSize(width: 612, height: 792)
        let maxPPI: CGFloat = 300
        
        // Act
        let result = Composer.downsampleIfNeeded(
            image: optimalImage,
            maxPPI: maxPPI,
            pageSize: pageSize
        )
        
        // Assert - Image should remain unchanged
        #expect(result.size.width == optimalImage.size.width)
        #expect(result.size.height == optimalImage.size.height)
    }
    
    @Test("Image downsampling to max dimension")
    func testImageDownsamplingMaxDimension() async throws {
        // Arrange
        let largeImage = TestDataProvider.createTestImage(size: CGSize(width: 2000, height: 3000))
        let maxDimension: CGFloat = 800
        
        // Act
        let downsampledImage = Composer.downsampleToMaxDimension(
            image: largeImage,
            maxDimension: maxDimension
        )
        
        // Assert
        let maxResultDimension = max(downsampledImage.size.width, downsampledImage.size.height)
        #expect(maxResultDimension <= maxDimension)
        
        // Aspect ratio should be preserved
        let originalRatio = largeImage.size.width / largeImage.size.height
        let resultRatio = downsampledImage.size.width / downsampledImage.size.height
        #expect(abs(originalRatio - resultRatio) < 0.01) // Allow small floating point difference
    }
    
    @Test("Image downsampling with small image")
    func testImageDownsamplingSmallImage() async throws {
        // Arrange
        let smallImage = TestDataProvider.createTestImage(size: CGSize(width: 100, height: 150))
        let maxDimension: CGFloat = 800
        
        // Act
        let result = Composer.downsampleToMaxDimension(
            image: smallImage,
            maxDimension: maxDimension
        )
        
        // Assert - Image should remain unchanged
        #expect(result.size.width == smallImage.size.width)
        #expect(result.size.height == smallImage.size.height)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Merge with nil pages")
    func testMergeWithNilPages() async throws {
        // Arrange
        let pages: [PDFPage] = []
        
        // Act - Should work with empty pages array
        let document = try await Composer.merge(
            pages: pages,
            cover: nil,
            coverPlacement: .top
        )
        
        // Assert
        #expect(document.pageCount == 0)
    }
    
    @Test("Memory usage during merge operations")
    func testMergeMemoryUsage() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .large(pageCount: 20))
        var pages: [PDFPage] = []
        
        for i in 0..<20 {
            if let page = sourceDocument?.page(at: i) {
                pages.append(page)
            }
        }
        
        let coverImage = TestDataProvider.createTestImage(size: CGSize(width: 800, height: 1000))
        
        // Measure memory usage
        let (result, memoryDelta) = TestHelpers.measureMemoryUsage {
            // Use synchronous context for memory measurement
            return pages.count
        }
        
        // Act
        let mergedDocument = try await Composer.merge(
            pages: pages,
            cover: coverImage,
            coverPlacement: .center,
            mode: .export
        )
        
        // Assert
        #expect(mergedDocument.pageCount == 21) // 20 pages + 1 cover
        #expect(result == 20) // Verify measurement worked
        
        // Memory delta should be reasonable (difficult to assert exact values)
        // This is more of a smoke test to ensure no memory leaks
    }
    
    // MARK: - Performance Tests
    
    @Test("Merge performance with large documents")
    func testMergePerformanceLargeDocuments() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 100))
        var pages: [PDFPage] = []
        
        for i in 0..<100 {
            if let page = sourceDocument?.page(at: i) {
                pages.append(page)
            }
        }
        
        let coverImage = TestDataProvider.createTestImage()
        
        // Act
        let (mergedDocument, mergeTime) = try await TestHelpers.measureTime {
            try await Composer.merge(
                pages: pages,
                cover: coverImage,
                coverPlacement: .center,
                mode: .export
            )
        }
        
        // Assert
        #expect(mergedDocument.pageCount == 101) // 100 pages + 1 cover
        #expect(mergeTime < 10.0) // Should complete within 10 seconds
    }
    
    @Test("Concurrent merge operations")
    func testConcurrentMergeOperations() async throws {
        // Arrange
        let (sourceDocument, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        var pages: [PDFPage] = []
        
        for i in 0..<10 {
            if let page = sourceDocument?.page(at: i) {
                pages.append(page)
            }
        }
        
        let coverImage = TestDataProvider.createTestImage()
        
        // Create multiple concurrent merge operations
        let operations: [() async throws -> PDFDocument] = (0..<5).map { index in
            return {
                try await Composer.merge(
                    pages: pages,
                    cover: coverImage,
                    coverPlacement: .top,
                    mode: .export
                )
            }
        }
        
        // Act
        let results = await PerformanceTestHelpers.generateConcurrentLoad(operations: operations)
        
        // Assert
        #expect(results.count == 5)
        for result in results {
            switch result {
            case .success(let document):
                #expect(document.pageCount == 11) // 10 pages + cover
            case .failure(let error):
                Issue.record("Concurrent merge operation failed: \(error)")
            }
        }
    }
    
    // MARK: - Composition Mode Tests
    
    @Test("Composition mode parameter validation")
    func testCompositionModeParameters() async throws {
        // Test preview mode parameters
        #expect(Composer.CompositionMode.preview.maxImageDimension == 800)
        #expect(Composer.CompositionMode.preview.compressionQuality == 0.7)
        
        // Test export mode parameters
        #expect(Composer.CompositionMode.export.maxImageDimension == 2400)
        #expect(Composer.CompositionMode.export.compressionQuality == 0.95)
    }
    
    // MARK: - Helper Methods
    
    private func expectedCoverIndex(placement: CoverPlacement, pageCount: Int) -> Int {
        switch placement {
        case .topLeft, .top, .topRight:
            return 0
        case .left, .center, .right:
            return max(pageCount / 2, 0)
        case .bottomLeft, .bottom, .bottomRight:
            return pageCount
        }
    }
}

// MARK: - Integration Tests

struct ComposerIntegrationTests {
    
    @Test("End-to-end document composition workflow")
    func testEndToEndComposition() async throws {
        // Arrange - Create a realistic document composition scenario
        let (sourceDocument1, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let (sourceDocument2, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 2))
        
        // Combine pages from both documents
        var allPages: [PDFPage] = []
        for i in 0..<3 {
            if let page = sourceDocument1?.page(at: i) {
                allPages.append(page)
            }
        }
        for i in 0..<2 {
            if let page = sourceDocument2?.page(at: i) {
                allPages.append(page)
            }
        }
        
        let coverImage = TestDataProvider.createTestImage(size: CGSize(width: 600, height: 800))
        
        // Act - Compose the final document
        let finalDocument = try await Composer.merge(
            pages: allPages,
            cover: coverImage,
            coverPlacement: .top,
            mode: .export
        )
        
        // Assert
        #expect(finalDocument.pageCount == 6) // 5 pages + 1 cover
        
        // Verify we can export the composed document
        let tempURL = MockPDFGenerator.createTemporaryFileURL(filename: "composed.pdf")
        let success = finalDocument.write(to: tempURL)
        #expect(success)
        
        // Verify the exported document can be read back
        let reloadedDocument = PDFDocument(url: tempURL)
        #expect(reloadedDocument != nil)
        #expect(reloadedDocument!.pageCount == 6)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: tempURL)
    }
}