//
//  PDFTests.swift
//  PDFTests
//
//  Created by Droy — on 16/05/2025.
//

import Testing
import Foundation
import PDFKit
import AppKit
@testable import PDF

// MARK: - Integration Tests for ThumbnailService

struct ThumbnailServiceTests {
    
    @Test("ThumbnailService basic functionality")
    func testThumbnailServiceBasicFunctionality() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        
        // Act
        let result = await service.loadThumbnail(
            from: document!,
            pageIndex: 0,
            options: .standard
        )
        
        // Assert
        #expect(result != nil)
        #expect(result!.pageIndex == 0)
        #expect(result!.image.size.width > 0)
        #expect(result!.image.size.height > 0)
        #expect(result!.loadTime >= 0)
    }
    
    @Test("ThumbnailService batch loading")
    func testThumbnailServiceBatchLoading() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        let pageIndices = [0, 2, 4, 6, 8]
        
        // Act
        let results = await service.loadThumbnailsBatch(
            from: document!,
            pageIndices: pageIndices,
            options: .standard
        )
        
        // Assert
        #expect(results.count == 5)
        
        for result in results {
            #expect(pageIndices.contains(result.pageIndex))
            #expect(result.image.size.width > 0)
            #expect(result.image.size.height > 0)
        }
    }
    
    @Test("ThumbnailService cache functionality")
    func testThumbnailServiceCacheFunctionality() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        
        // Act - First load (cache miss)
        let result1 = await service.loadThumbnail(from: document!, pageIndex: 0, options: .standard)
        
        // Act - Second load (cache hit)
        let result2 = await service.loadThumbnail(from: document!, pageIndex: 0, options: .standard)
        
        // Assert
        #expect(result1 != nil)
        #expect(result2 != nil)
        #expect(result2!.fromCache == true || result2!.loadTime < result1!.loadTime)
    }
    
    @Test("ThumbnailService different quality options")
    func testThumbnailServiceQualityOptions() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        
        let qualityOptions = [
            ThumbnailOptions.placeholder,
            ThumbnailOptions.standard,
            ThumbnailOptions.highQuality
        ]
        
        // Act & Assert
        for option in qualityOptions {
            let result = await service.loadThumbnail(from: document!, pageIndex: 0, options: option)
            
            #expect(result != nil)
            #expect(result!.image.size.width > 0)
            #expect(result!.image.size.height > 0)
            
            // Higher quality should generally produce larger images
            // (This is a rough check since exact sizes depend on content)
        }
    }
    
    @Test("ThumbnailService viewport preloading")
    func testThumbnailServiceViewportPreloading() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 20))
        
        // Act - Preload first 5 pages
        await service.preloadThumbnailsForViewport(from: document!, startIndex: 0, count: 5)
        
        // Wait a moment for preloading to start
        try await Task.sleep(for: .milliseconds(500))
        
        // Check if some thumbnails are cached or loading
        let cachedThumbnail = await service.getCachedThumbnail(for: 0)
        let isLoading = await service.isThumbnailLoading(pageIndex: 1)
        
        // Assert - At least some activity should be happening
        let hasActivity = cachedThumbnail != nil || isLoading
        #expect(hasActivity)
    }
    
    @Test("ThumbnailService legacy compatibility")
    func testThumbnailServiceLegacyCompatibility() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let size = CGSize(width: 100, height: 120)
        
        // Act - Use legacy method signature
        let thumbnail = await service.thumbnail(document: document!, page: 0, size: size, useCache: true)
        
        // Assert
        #expect(thumbnail != nil)
        #expect(TestHelpers.validateImage(thumbnail!, expectedSize: size, tolerance: 20.0))
    }
    
    @Test("ThumbnailService error handling")
    func testThumbnailServiceErrorHandling() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        
        // Act - Request invalid page index
        let result = await service.loadThumbnail(from: document!, pageIndex: 100, options: .standard)
        
        // Assert - Should handle gracefully
        #expect(result == nil)
    }
    
    @Test("ThumbnailService cancel operations")
    func testThumbnailServiceCancelOperations() async throws {
        // Arrange
        let service = await ThumbnailService()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        // Start loading multiple thumbnails
        let pageIndices = Array(0..<5)
        let _ = Task {
            await service.loadThumbnailsBatch(from: document!, pageIndices: pageIndices)
        }
        
        // Give tasks a moment to start
        try await Task.sleep(for: .milliseconds(100))
        
        // Act - Cancel operations
        await service.cancelAllLoading()
        
        // Wait a moment
        try await Task.sleep(for: .milliseconds(200))
        
        // Assert - System should still be functional
        let quickResult = await service.loadThumbnail(from: document!, pageIndex: 0, options: .placeholder)
        let stillLoading = await service.isThumbnailLoading(pageIndex: 0)
        let systemFunctional = quickResult != nil || stillLoading
        #expect(systemFunctional)
    }
}
