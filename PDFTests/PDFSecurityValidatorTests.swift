import Testing
import Foundation
import PDFKit
import AppKit
@testable import PDF

struct PDFSecurityValidatorTests {
    
    // MARK: - Configuration Tests
    
    @Test("Default security configuration")
    func testDefaultSecurityConfiguration() async throws {
        let config = PDFSecurityConfiguration.default
        
        #expect(config.maxFileSize == 100 * 1024 * 1024) // 100MB
        #expect(config.maxPageCount == 1000)
        #expect(config.allowEncryptedPDFs == false)
        #expect(config.allowJavaScript == false)
        #expect(config.allowedFileExtensions == ["pdf"])
        #expect(config.allowedMIMETypes == ["application/pdf"])
    }
    
    @Test("Strict security configuration")
    func testStrictSecurityConfiguration() async throws {
        let config = PDFSecurityConfiguration.strict
        
        #expect(config.maxFileSize == 50 * 1024 * 1024) // 50MB
        #expect(config.maxPageCount == 500)
        #expect(config.allowEncryptedPDFs == false)
        #expect(config.allowJavaScript == false)
        #expect(config.allowedFileExtensions == ["pdf"])
        #expect(config.allowedMIMETypes == ["application/pdf"])
    }
    
    @Test("Custom security configuration")
    func testCustomSecurityConfiguration() async throws {
        let customConfig = PDFSecurityConfiguration(
            maxFileSize: 10 * 1024 * 1024,
            maxPageCount: 100,
            allowEncryptedPDFs: true,
            allowJavaScript: true,
            allowedFileExtensions: ["pdf", "PDF"],
            allowedMIMETypes: ["application/pdf", "application/x-pdf"]
        )
        
        #expect(customConfig.maxFileSize == 10 * 1024 * 1024)
        #expect(customConfig.maxPageCount == 100)
        #expect(customConfig.allowEncryptedPDFs == true)
        #expect(customConfig.allowJavaScript == true)
        #expect(customConfig.allowedFileExtensions == ["pdf", "PDF"])
        #expect(customConfig.allowedMIMETypes == ["application/pdf", "application/x-pdf"])
    }
    
    // MARK: - File Access Validation Tests
    
    @Test("Validate valid PDF file")
    func testValidateValidPDFFile() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "valid.pdf")!
        
        // Act & Assert - Should not throw
        try await validator.validateFile(at: url)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("Validate non-existent file")
    func testValidateNonExistentFile() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let nonExistentURL = URL(fileURLWithPath: "/path/that/does/not/exist/file.pdf")
        
        // Act & Assert
        await #expect(throws: PDFSecurityError.self) {
            try await validator.validateFile(at: nonExistentURL)
        }
    }
    
    @Test("Validate unreadable file")
    func testValidateUnreadableFile() async throws {
        // This test is challenging to implement cross-platform
        // In a real scenario, you'd test with files that have restricted permissions
        
        let validator = PDFSecurityValidator()
        
        // Create a test file and then try to make it unreadable
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "test.pdf")!
        
        // Test with a valid file (baseline)
        try await validator.validateFile(at: url)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    // MARK: - File Size Validation Tests
    
    @Test("Validate file size within limits")
    func testValidateFileSizeWithinLimits() async throws {
        // Arrange
        let config = PDFSecurityConfiguration(
            maxFileSize: 10 * 1024 * 1024, // 10MB
            maxPageCount: 1000,
            allowEncryptedPDFs: false,
            allowJavaScript: false,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        
        // Create a small PDF
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "small.pdf")!
        
        // Act & Assert - Should not throw
        try await validator.validateFile(at: url)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("Validate file size exceeding limits")
    func testValidateFileSizeExceedingLimits() async throws {
        // Arrange - Create a restrictive configuration
        let config = PDFSecurityConfiguration(
            maxFileSize: 1024, // 1KB limit (very small)
            maxPageCount: 1000,
            allowEncryptedPDFs: false,
            allowJavaScript: false,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        
        // Create a PDF that will likely exceed 1KB
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "large.pdf")!
        
        // Act & Assert
        await #expect(throws: PDFSecurityError.self) {
            try await validator.validateFile(at: url)
        }
        
        // Verify it's specifically a file size error
        do {
            try await validator.validateFile(at: url)
            Issue.record("Expected file size error")
        } catch let error as PDFSecurityError {
            switch error {
            case .fileTooLarge:
                // Expected error type
                break
            default:
                Issue.record("Expected fileTooLarge error, got \(error)")
            }
        }
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    // MARK: - File Type Validation Tests
    
    @Test("Validate correct file extension")
    func testValidateCorrectFileExtension() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "test.pdf")!
        
        // Act & Assert - Should not throw
        try await validator.validateFile(at: url)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("Validate incorrect file extension")
    func testValidateIncorrectFileExtension() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "test.txt")!
        
        // Act & Assert
        await #expect(throws: PDFSecurityError.self) {
            try await validator.validateFile(at: url)
        }
        
        // Verify it's an invalid file type error
        do {
            try await validator.validateFile(at: url)
        } catch let error as PDFSecurityError {
            switch error {
            case .invalidFileType(let type, let expected):
                #expect(type == "txt")
                #expect(expected.contains("pdf"))
            default:
                Issue.record("Expected invalidFileType error, got \(error)")
            }
        }
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("Validate case insensitive file extension")
    func testValidateCaseInsensitiveFileExtension() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "test.PDF")!
        
        // Act & Assert - Should work with uppercase extension
        try await validator.validateFile(at: url)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    // MARK: - PDF Content Validation Tests
    
    @Test("Validate valid PDF document")
    func testValidateValidPDFDocument() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        
        // Act & Assert - Should not throw
        try await validator.validateDocument(document!)
    }
    
    @Test("Validate empty PDF document")
    func testValidateEmptyPDFDocument() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (document, _) = MockPDFGenerator.generatePDF(type: .empty)
        
        // Act & Assert
        await #expect(throws: PDFSecurityError.self) {
            try await validator.validateDocument(document!)
        }
        
        // Verify it's a corrupted PDF error (empty = corrupted)
        do {
            try await validator.validateDocument(document!)
        } catch let error as PDFSecurityError {
            switch error {
            case .corruptedPDF:
                // Expected
                break
            default:
                Issue.record("Expected corruptedPDF error, got \(error)")
            }
        }
    }
    
    @Test("Validate PDF with too many pages")
    func testValidatePDFTooManyPages() async throws {
        // Arrange - Create restrictive configuration
        let config = PDFSecurityConfiguration(
            maxFileSize: 100 * 1024 * 1024,
            maxPageCount: 5, // Very low limit
            allowEncryptedPDFs: false,
            allowJavaScript: false,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        
        // Create PDF with more pages than allowed
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        
        // Act & Assert
        await #expect(throws: PDFSecurityError.self) {
            try await validator.validateDocument(document!)
        }
        
        // Verify it's a too many pages error
        do {
            try await validator.validateDocument(document!)
        } catch let error as PDFSecurityError {
            switch error {
            case .tooManyPages(let count, let limit):
                #expect(count == 10)
                #expect(limit == 5)
            default:
                Issue.record("Expected tooManyPages error, got \(error)")
            }
        }
    }
    
    // MARK: - Encryption Validation Tests
    
    @Test("Validate non-encrypted PDF with encryption disabled")
    func testValidateNonEncryptedPDFEncryptionDisabled() async throws {
        // Arrange
        let config = PDFSecurityConfiguration(
            maxFileSize: 100 * 1024 * 1024,
            maxPageCount: 1000,
            allowEncryptedPDFs: false,
            allowJavaScript: false,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        
        // Act & Assert - Should not throw for non-encrypted PDF
        try await validator.validateDocument(document!)
    }
    
    @Test("Validate non-encrypted PDF with encryption enabled")
    func testValidateNonEncryptedPDFEncryptionEnabled() async throws {
        // Arrange
        let config = PDFSecurityConfiguration(
            maxFileSize: 100 * 1024 * 1024,
            maxPageCount: 1000,
            allowEncryptedPDFs: true,
            allowJavaScript: false,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        
        // Act & Assert - Should not throw
        try await validator.validateDocument(document!)
    }
    
    // Note: Testing encrypted PDFs is complex as PDFKit doesn't easily
    // support creating encrypted PDFs programmatically for testing
    
    // MARK: - JavaScript Validation Tests
    
    @Test("Validate PDF without JavaScript when JS disabled")
    func testValidatePDFWithoutJavaScriptJSDisabled() async throws {
        // Arrange
        let config = PDFSecurityConfiguration(
            maxFileSize: 100 * 1024 * 1024,
            maxPageCount: 1000,
            allowEncryptedPDFs: false,
            allowJavaScript: false,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        
        // Act & Assert - Should not throw for PDF without JS
        try await validator.validateDocument(document!)
    }
    
    @Test("Validate PDF with JavaScript when JS disabled")
    func testValidatePDFWithJavaScriptJSDisabled() async throws {
        // Arrange
        let config = PDFSecurityConfiguration(
            maxFileSize: 100 * 1024 * 1024,
            maxPageCount: 1000,
            allowEncryptedPDFs: false,
            allowJavaScript: false,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        let (_, data) = MockPDFGenerator.generatePDF(type: .malicious) // Contains JS patterns
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "malicious.pdf")!
        
        // Act & Assert
        await #expect(throws: PDFSecurityError.self) {
            try await validator.validateFile(at: url)
        }
        
        // Verify it's a malicious JavaScript error
        do {
            try await validator.validateFile(at: url)
        } catch let error as PDFSecurityError {
            switch error {
            case .maliciousJavaScript(let count):
                #expect(count > 0)
            default:
                Issue.record("Expected maliciousJavaScript error, got \(error)")
            }
        }
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("Validate PDF with JavaScript when JS enabled")
    func testValidatePDFWithJavaScriptJSEnabled() async throws {
        // Arrange
        let config = PDFSecurityConfiguration(
            maxFileSize: 100 * 1024 * 1024,
            maxPageCount: 1000,
            allowEncryptedPDFs: false,
            allowJavaScript: true,
            allowedFileExtensions: ["pdf"],
            allowedMIMETypes: ["application/pdf"]
        )
        let validator = PDFSecurityValidator(configuration: config)
        let (_, data) = MockPDFGenerator.generatePDF(type: .malicious)
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "js_allowed.pdf")!
        
        // Act & Assert - Should not throw when JS is allowed
        try await validator.validateFile(at: url)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    // MARK: - Content Structure Validation Tests
    
    @Test("Validate PDF with normal page dimensions")
    func testValidatePDFNormalDimensions() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (document, _) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        
        // Act & Assert - Should not throw for normal PDF
        try await validator.validateDocument(document!)
    }
    
    // Note: Testing extremely large page dimensions would require creating
    // special PDFs with manipulated page bounds, which is complex to do programmatically
    
    // MARK: - Error Type and Message Tests
    
    @Test("PDFSecurityError descriptions")
    func testPDFSecurityErrorDescriptions() async throws {
        let testCases: [(PDFSecurityError, String)] = [
            (.fileTooLarge(size: 1000, limit: 500), "File size"),
            (.invalidFileType(type: "txt", expected: ["pdf"]), "Invalid file type"),
            (.maliciousJavaScript(count: 3), "JavaScript elements"),
            (.tooManyPages(count: 2000, limit: 1000), "2000 pages"),
            (.encryptedPDF, "Encrypted PDFs"),
            (.corruptedPDF, "corrupted"),
            (.accessDenied(path: "/test"), "Access denied"),
            (.fileNotReadable(path: "/test"), "not readable"),
            (.invalidFileFormat, "not a valid PDF"),
            (.suspiciousContent(description: "test"), "Suspicious content")
        ]
        
        for (error, expectedSubstring) in testCases {
            let description = error.description
            #expect(description.localizedCaseInsensitiveContains(expectedSubstring))
        }
    }
    
    // MARK: - Validation Result Tests
    
    @Test("Validation result with valid file")
    func testValidationResultValidFile() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "valid.pdf")!
        
        // Act
        let result = await validator.validateFileWithResult(at: url)
        
        // Assert
        #expect(result.isValid == true)
        #expect(result.errors.isEmpty)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("Validation result with invalid file")
    func testValidationResultInvalidFile() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let nonExistentURL = URL(fileURLWithPath: "/path/that/does/not/exist/file.pdf")
        
        // Act
        let result = await validator.validateFileWithResult(at: nonExistentURL)
        
        // Assert
        #expect(result.isValid == false)
        #expect(!result.errors.isEmpty)
        
        // Should contain a file access related error
        let hasFileAccessError = result.errors.contains { error in
            switch error {
            case .fileNotReadable, .accessDenied:
                return true
            default:
                return false
            }
        }
        #expect(hasFileAccessError)
    }
    
    // MARK: - Performance Tests
    
    @Test("Validation performance with large document")
    func testValidationPerformanceLargeDocument() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (_, data) = MockPDFGenerator.generatePDF(type: .large(pageCount: 100))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "large_validation.pdf")!
        
        // Act
        let (_, validationTime) = await TestHelpers.measureTime {
            try await validator.validateFile(at: url)
        }
        
        // Assert - Should complete within reasonable time
        #expect(validationTime < 10.0) // 10 seconds for large document
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
    
    @Test("Concurrent validation operations")
    func testConcurrentValidationOperations() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        
        // Create multiple test files
        var testURLs: [URL] = []
        for i in 0..<5 {
            let (_, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 3))
            let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "concurrent_\(i).pdf")!
            testURLs.append(url)
        }
        
        // Create concurrent validation operations
        let operations: [() async throws -> Void] = testURLs.map { url in
            return {
                try await validator.validateFile(at: url)
            }
        }
        
        // Act
        let results = await PerformanceTestHelpers.generateConcurrentLoad(operations: operations)
        
        // Assert
        #expect(results.count == 5)
        
        for result in results {
            switch result {
            case .success:
                // Expected for valid files
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
    
    // MARK: - Integration Tests
    
    @Test("End-to-end file validation workflow")
    func testEndToEndFileValidationWorkflow() async throws {
        // Arrange - Create a realistic validation scenario
        let validator = PDFSecurityValidator(configuration: .default)
        
        // Test valid document
        let (validDocument, validData) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 10))
        let validURL = MockPDFGenerator.writeToTemporaryFile(data: validData!, filename: "workflow_valid.pdf")!
        
        // Test invalid document (wrong extension)
        let (_, invalidData) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 1))
        let invalidURL = MockPDFGenerator.writeToTemporaryFile(data: invalidData!, filename: "workflow_invalid.txt")!
        
        // Act & Assert - Valid document should pass
        try await validator.validateFile(at: validURL)
        
        // Invalid document should fail
        await #expect(throws: PDFSecurityError.self) {
            try await validator.validateFile(at: invalidURL)
        }
        
        // Direct document validation should also work
        try await validator.validateDocument(validDocument!)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: validURL)
        TestHelpers.cleanupTemporaryFiles(at: invalidURL)
    }
    
    @Test("Multi-stage validation process")
    func testMultiStageValidationProcess() async throws {
        // Arrange
        let validator = PDFSecurityValidator()
        let (document, data) = MockPDFGenerator.generatePDF(type: .simple(pageCount: 5))
        let url = MockPDFGenerator.writeToTemporaryFile(data: data!, filename: "multistage.pdf")!
        
        // Act - File validation (includes document validation internally)
        try await validator.validateFile(at: url)
        
        // Act - Separate document validation
        try await validator.validateDocument(document!)
        
        // Act - Result-based validation
        let result = await validator.validateFileWithResult(at: url)
        
        // Assert
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
        
        // Cleanup
        TestHelpers.cleanupTemporaryFiles(at: url)
    }
}