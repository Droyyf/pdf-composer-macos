import XCTest
@testable import PDF

/// Integration tests for cloud storage functionality
@MainActor
final class CloudStorageIntegrationTests: XCTestCase {
    
    var cloudManager: CloudStorageManager!
    var keychainManager: KeychainManager!
    var exportService: ExportService!
    
    override func setUp() async throws {
        try await super.setUp()
        cloudManager = CloudStorageManager.shared
        keychainManager = KeychainManager.shared
        exportService = ExportService.shared
    }
    
    override func tearDown() async throws {
        // Clean up any test accounts
        for account in cloudManager.connectedAccounts {
            try? await cloudManager.signOut(account: account)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Keychain Tests
    
    func testKeychainTokenStorage() throws {
        let testAccount = "test@example.com"
        let testProvider = CloudProvider.googleDrive
        let testToken = "test_access_token_12345"
        
        // Store token
        try keychainManager.storeToken(testToken, for: testAccount, provider: testProvider)
        
        // Retrieve token
        let retrievedToken = try keychainManager.retrieveToken(for: testAccount, provider: testProvider)
        XCTAssertEqual(retrievedToken, testToken)
        
        // Delete token
        try keychainManager.deleteToken(for: testAccount, provider: testProvider)
        
        // Verify deletion
        XCTAssertThrowsError(try keychainManager.retrieveToken(for: testAccount, provider: testProvider)) { error in
            XCTAssertTrue(error is KeychainManager.KeychainError)
            if let keychainError = error as? KeychainManager.KeychainError {
                XCTAssertEqual(keychainError, KeychainManager.KeychainError.itemNotFound)
            }
        }
    }
    
    func testKeychainAccountDataStorage() throws {
        let testAccount = CloudAccount(
            id: "test123",
            email: "test@example.com",
            displayName: "Test User",
            provider: .googleDrive,
            avatarURL: nil,
            isActive: true
        )
        
        // Store account data
        try keychainManager.storeAccountData(testAccount, for: testAccount.id, provider: testAccount.provider)
        
        // Retrieve account data
        let retrievedAccount = try keychainManager.retrieveAccountData(CloudAccount.self, for: testAccount.id, provider: testAccount.provider)
        
        XCTAssertEqual(retrievedAccount.id, testAccount.id)
        XCTAssertEqual(retrievedAccount.email, testAccount.email)
        XCTAssertEqual(retrievedAccount.displayName, testAccount.displayName)
        XCTAssertEqual(retrievedAccount.provider, testAccount.provider)
        XCTAssertEqual(retrievedAccount.isActive, testAccount.isActive)
        
        // Clean up
        try keychainManager.deleteAccountData(for: testAccount.id, provider: testAccount.provider)
    }
    
    // MARK: - Cloud Storage Models Tests
    
    func testCloudProviderProperties() {
        let googleDrive = CloudProvider.googleDrive
        XCTAssertEqual(googleDrive.displayName, "Google Drive")
        XCTAssertEqual(googleDrive.iconName, "globe")
        XCTAssertTrue(googleDrive.authURL.contains("accounts.google.com"))
        XCTAssertTrue(googleDrive.apiBaseURL.contains("googleapis.com"))
        
        let oneDrive = CloudProvider.oneDrive
        XCTAssertEqual(oneDrive.displayName, "Microsoft OneDrive")
        XCTAssertEqual(oneDrive.iconName, "cloud.fill")
        XCTAssertTrue(oneDrive.authURL.contains("microsoftonline.com"))
        
        let dropbox = CloudProvider.dropbox
        XCTAssertEqual(dropbox.displayName, "Dropbox")
        XCTAssertEqual(dropbox.iconName, "cloud.drizzle.fill")
        XCTAssertTrue(dropbox.authURL.contains("dropbox.com"))
    }
    
    func testOAuthTokenModel() throws {
        let tokenData = """
        {
            "access_token": "test_access_token",
            "refresh_token": "test_refresh_token",
            "token_type": "Bearer",
            "expires_in": 3600,
            "scope": "files.read"
        }
        """.data(using: .utf8)!
        
        let token = try JSONDecoder().decode(OAuthToken.self, from: tokenData)
        
        XCTAssertEqual(token.accessToken, "test_access_token")
        XCTAssertEqual(token.refreshToken, "test_refresh_token")
        XCTAssertEqual(token.tokenType, "Bearer")
        XCTAssertEqual(token.expiresIn, 3600)
        XCTAssertEqual(token.scope, "files.read")
        XCTAssertFalse(token.isExpired) // Should not be expired immediately after creation
    }
    
    func testCloudFileModel() {
        let file = CloudFile(
            id: "file123",
            name: "test.pdf",
            mimeType: "application/pdf",
            size: 1024,
            modifiedTime: Date(),
            webViewLink: "https://example.com/view",
            downloadURL: "https://example.com/download",
            parentId: "folder123"
        )
        
        XCTAssertTrue(file.isPDF)
        XCTAssertEqual(file.formattedSize, "1 KB")
    }
    
    // MARK: - Cloud Operation Progress Tests
    
    func testCloudOperationProgress() async {
        let progress = CloudOperationProgress()
        
        // Initial state
        XCTAssertFalse(progress.isActive)
        XCTAssertEqual(progress.progress, 0.0)
        XCTAssertEqual(progress.status, "")
        XCTAssertNil(progress.error)
        
        // Start operation
        progress.start(status: "Starting upload...", totalBytes: 1024)
        XCTAssertTrue(progress.isActive)
        XCTAssertEqual(progress.status, "Starting upload...")
        XCTAssertEqual(progress.totalBytes, 1024)
        
        // Update progress
        progress.update(progress: 0.5, completedBytes: 512, status: "Uploading...")
        XCTAssertEqual(progress.progress, 0.5)
        XCTAssertEqual(progress.completedBytes, 512)
        XCTAssertEqual(progress.status, "Uploading...")
        
        // Complete operation
        progress.complete(status: "Upload completed")
        XCTAssertFalse(progress.isActive)
        XCTAssertEqual(progress.progress, 1.0)
        XCTAssertEqual(progress.status, "Upload completed")
        XCTAssertEqual(progress.completedBytes, progress.totalBytes)
    }
    
    func testCloudOperationProgressError() async {
        let progress = CloudOperationProgress()
        let testError = CloudStorageError.networkError(URLError(.notConnectedToInternet))
        
        progress.start(status: "Starting...")
        progress.fail(error: testError, status: "Failed to upload")
        
        XCTAssertFalse(progress.isActive)
        XCTAssertNotNil(progress.error)
        XCTAssertEqual(progress.status, "Failed to upload")
    }
    
    // MARK: - Export Service Tests
    
    func testExportServiceInitialization() {
        let exportService = ExportService.shared
        XCTAssertFalse(exportService.isExporting)
        XCTAssertEqual(exportService.exportProgress, 0.0)
        XCTAssertEqual(exportService.exportStatus, "")
        XCTAssertFalse(exportService.showCloudPicker)
        XCTAssertFalse(exportService.showCloudUploadProgress)
    }
    
    func testExportFormats() {
        XCTAssertEqual(ExportService.ExportFormat.pdf.displayName, "PDF")
        XCTAssertEqual(ExportService.ExportFormat.pdf.fileExtension, "pdf")
        XCTAssertEqual(ExportService.ExportFormat.pdf.mimeType, "application/pdf")
        
        XCTAssertEqual(ExportService.ExportFormat.png.displayName, "PNG")
        XCTAssertEqual(ExportService.ExportFormat.png.fileExtension, "png")
        XCTAssertEqual(ExportService.ExportFormat.png.mimeType, "image/png")
        
        XCTAssertEqual(ExportService.ExportFormat.jpeg.displayName, "JPEG")
        XCTAssertEqual(ExportService.ExportFormat.jpeg.fileExtension, "jpeg")
        XCTAssertEqual(ExportService.ExportFormat.jpeg.mimeType, "image/jpeg")
        
        XCTAssertEqual(ExportService.ExportFormat.webp.displayName, "WebP")
        XCTAssertEqual(ExportService.ExportFormat.webp.fileExtension, "webp")
        XCTAssertEqual(ExportService.ExportFormat.webp.mimeType, "image/webp")
    }
    
    func testCompositionModes() {
        XCTAssertEqual(CompositionMode.centerCitation.displayName, "Center Citation")
        XCTAssertEqual(CompositionMode.leftAlign.displayName, "Left Aligned")
        XCTAssertEqual(CompositionMode.rightAlign.displayName, "Right Aligned")
        XCTAssertEqual(CompositionMode.fullPage.displayName, "Full Page")
    }
    
    // MARK: - Settings Integration Tests
    
    func testCloudSettingsIntegration() {
        let settings = SettingsStore.shared
        
        // Test default cloud settings
        XCTAssertTrue(settings.settings.cloudStorageEnabled)
        XCTAssertNil(settings.settings.defaultCloudProvider)
        XCTAssertFalse(settings.settings.autoUploadEnabled)
        XCTAssertFalse(settings.settings.cloudBackupEnabled)
        XCTAssertFalse(settings.settings.syncSettings)
        
        // Test updating cloud settings
        settings.update { settings in
            settings.cloudStorageEnabled = false
            settings.defaultCloudProvider = CloudProvider.googleDrive.rawValue
            settings.autoUploadEnabled = true
        }
        
        XCTAssertFalse(settings.settings.cloudStorageEnabled)
        XCTAssertEqual(settings.settings.defaultCloudProvider, CloudProvider.googleDrive.rawValue)
        XCTAssertTrue(settings.settings.autoUploadEnabled)
    }
    
    // MARK: - Error Handling Tests
    
    func testCloudStorageErrorTypes() {
        let errors: [CloudStorageError] = [
            .notAuthenticated,
            .tokenExpired,
            .networkError(URLError(.notConnectedToInternet)),
            .authenticationFailed("Test failure"),
            .uploadFailed("Upload error"),
            .downloadFailed("Download error"),
            .fileNotFound,
            .insufficientStorage,
            .rateLimitExceeded,
            .invalidResponse,
            .unsupportedProvider
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    func testExportErrorTypes() {
        let errors: [ExportError] = [
            .imageConversionFailed,
            .unsupportedFormat,
            .invalidOperation,
            .fileWriteFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
    
    // MARK: - Performance Tests
    
    func testKeychainPerformance() {
        let testProvider = CloudProvider.googleDrive
        
        measure {
            for i in 0..<100 {
                let account = "test\(i)@example.com"
                let token = "token_\(i)"
                
                do {
                    try keychainManager.storeToken(token, for: account, provider: testProvider)
                    let retrieved = try keychainManager.retrieveToken(for: account, provider: testProvider)
                    XCTAssertEqual(retrieved, token)
                    try keychainManager.deleteToken(for: account, provider: testProvider)
                } catch {
                    XCTFail("Keychain operation failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Mock API Client Tests
    
    func testMockAPIClientsThrowErrors() async {
        let googleClient = GoogleDriveAPIClient()
        let onedriveClient = OneDriveAPIClient()
        let dropboxClient = DropboxAPIClient()
        
        let testAccount = CloudAccount(
            id: "test",
            email: "test@example.com",
            displayName: "Test",
            provider: .googleDrive
        )
        
        // All mock clients should throw appropriate errors
        do {
            _ = try await googleClient.authenticate()
            XCTFail("Expected authentication error")
        } catch {
            XCTAssertTrue(error is CloudStorageError)
        }
        
        do {
            _ = try await onedriveClient.listFiles(for: testAccount, parentId: nil)
            XCTFail("Expected list files error")
        } catch {
            // Expected - mock implementation returns empty arrays or throws errors
        }
        
        let uploadRequest = CloudUploadRequest(
            localFileURL: URL(fileURLWithPath: "/tmp/test.pdf"),
            fileName: "test.pdf"
        )
        
        do {
            _ = try await dropboxClient.upload(request: uploadRequest, for: testAccount) { _ in }
            XCTFail("Expected upload error")
        } catch {
            XCTAssertTrue(error is CloudStorageError)
        }
    }
}

// MARK: - Test Utilities

extension CloudStorageIntegrationTests {
    
    /// Create a test PDF file for export testing
    func createTestPDFFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_export.pdf")
        
        // Create a simple PDF document
        let pdfDocument = PDFDocument()
        let page = PDFPage()
        pdfDocument.insert(page, at: 0)
        pdfDocument.write(to: testFileURL)
        
        return testFileURL
    }
    
    /// Clean up test files
    func cleanupTestFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for url in contents {
                if url.lastPathComponent.hasPrefix("test_") {
                    try fileManager.removeItem(at: url)
                }
            }
        } catch {
            print("Warning: Failed to clean up test files: \(error)")
        }
    }
}