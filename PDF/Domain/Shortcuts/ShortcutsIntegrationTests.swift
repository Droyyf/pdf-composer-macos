import Foundation
import PDFKit
import XCTest

/// Integration tests for Shortcuts functionality
/// These tests validate the core functionality without requiring the full Shortcuts app
@available(macOS 11.0, *)
class ShortcutsIntegrationTests {
    
    private let integration = ShortcutsIntegration.shared
    
    // MARK: - Setup Validation Tests
    
    func testShortcutsAvailability() {
        XCTAssertTrue(ShortcutsIntegration.isShortcutsAvailable, "Shortcuts should be available on macOS 11.0+")
    }
    
    func testIntentHandlerValidation() {
        let isValid = integration.validateIntentHandlers()
        XCTAssertTrue(isValid, "All required intent handler classes should be available")
    }
    
    // MARK: - Utility Function Tests
    
    func testFileUtilities() {
        do {
            // Test directory access
            let documentsDir = try SharedUtilities.getStandardDirectory(.documents)
            XCTAssertTrue(FileManager.default.fileExists(atPath: documentsDir.path), "Documents directory should exist")
            
            // Test unique URL generation
            let uniqueURL = SharedUtilities.createUniqueURL(
                baseName: "test",
                directory: documentsDir,
                pathExtension: "pdf"
            )
            XCTAssertEqual(uniqueURL.pathExtension, "pdf", "Generated URL should have correct extension")
            
            // Test file size formatting
            let sizeString = SharedUtilities.formatFileSize(1024 * 1024) // 1MB
            XCTAssertFalse(sizeString.isEmpty, "File size should be formatted as string")
            
        } catch {
            XCTFail("Utility functions should work without errors: \(error)")
        }
    }
    
    func testTimestampedFilenameGeneration() {
        let filename = SharedUtilities.generateTimestampedFilename(prefix: "Test", extension: "pdf")
        XCTAssertTrue(filename.contains("Test_"), "Filename should contain prefix")
        XCTAssertTrue(filename.hasSuffix(".pdf"), "Filename should have correct extension")
    }
    
    // MARK: - Progress Tracking Tests
    
    func testProgressTracker() {
        let tracker = SharedUtilities.ProgressTracker(total: 10)
        
        XCTAssertEqual(tracker.current, 0, "Initial progress should be 0")
        XCTAssertEqual(tracker.progress, 0.0, "Initial progress percentage should be 0")
        XCTAssertFalse(tracker.isComplete, "Should not be complete initially")
        
        // Test progress increments
        for i in 1...5 {
            tracker.increment()
            XCTAssertEqual(tracker.current, i, "Current count should increment correctly")
        }
        
        XCTAssertEqual(tracker.progress, 0.5, "Progress should be 50% after 5 increments", accuracy: 0.01)
        XCTAssertFalse(tracker.isComplete, "Should not be complete at 50%")
        
        // Complete the progress
        for _ in 6...10 {
            tracker.increment()
        }
        
        XCTAssertTrue(tracker.isComplete, "Should be complete after all increments")
        XCTAssertEqual(tracker.progress, 1.0, "Progress should be 100% when complete", accuracy: 0.01)
    }
    
    // MARK: - Error Handling Tests
    
    func testValidationErrors() {
        // Test file validation with non-existent file
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non-existent.pdf")
        
        XCTAssertThrowsError(try SharedUtilities.validatePDFFile(at: nonExistentURL)) { error in
            XCTAssertTrue(error is SharedUtilities.ValidationError, "Should throw ValidationError")
        }
        
        // Test image validation with non-existent file  
        let nonExistentImageURL = URL(fileURLWithPath: "/tmp/non-existent.png")
        
        XCTAssertThrowsError(try SharedUtilities.validateImageFile(at: nonExistentImageURL)) { error in
            XCTAssertTrue(error is SharedUtilities.ValidationError, "Should throw ValidationError")
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testAutoreleaseFunctionality() {
        var testValue: String?
        
        do {
            testValue = try SharedUtilities.withAutorelease {
                return "Test Value"
            }
        } catch {
            XCTFail("Autorelease block should not throw: \(error)")
        }
        
        XCTAssertEqual(testValue, "Test Value", "Autorelease should return correct value")
    }
    
    func testAsyncAutoreleaseFunctionality() async {
        var testValue: String?
        
        do {
            testValue = try await SharedUtilities.withAutorelease {
                return "Async Test Value"
            }
        } catch {
            XCTFail("Async autorelease block should not throw: \(error)")
        }
        
        XCTAssertEqual(testValue, "Async Test Value", "Async autorelease should return correct value")
    }
    
    // MARK: - Integration Test Helpers
    
    /// Run all integration tests
    static func runAllTests() async {
        print("Starting Shortcuts Integration Tests...")
        
        let tests = ShortcutsIntegrationTests()
        
        // Run synchronous tests
        tests.testShortcutsAvailability()
        tests.testIntentHandlerValidation()
        tests.testFileUtilities()
        tests.testTimestampedFilenameGeneration()
        tests.testProgressTracker()
        tests.testValidationErrors()
        tests.testAutoreleaseFunctionality()
        
        // Run asynchronous tests
        await tests.testAsyncAutoreleaseFunctionality()
        
        print("Shortcuts Integration Tests completed successfully!")
    }
}

/// Extension for running tests in the main app
@available(macOS 11.0, *)
extension ShortcutsIntegration {
    
    /// Run integration tests to validate the setup
    func runIntegrationTests() async {
        await ShortcutsIntegrationTests.runAllTests()
    }
}