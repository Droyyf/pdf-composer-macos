import Foundation
import PDFKit
import UniformTypeIdentifiers

// MARK: - Security Error Types

enum PDFSecurityError: LocalizedError, CustomStringConvertible {
    case fileTooLarge(size: Int, limit: Int)
    case invalidFileType(type: String, expected: [String])
    case maliciousJavaScript(count: Int)
    case tooManyPages(count: Int, limit: Int)
    case encryptedPDF
    case corruptedPDF
    case accessDenied(path: String)
    case fileNotReadable(path: String)
    case invalidFileFormat
    case suspiciousContent(description: String)
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let size, let limit):
            return "File size (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))) exceeds security limit (\(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)))"
        case .invalidFileType(let type, let expected):
            return "Invalid file type '\(type)'. Expected: \(expected.joined(separator: ", "))"
        case .maliciousJavaScript(let count):
            return "PDF contains \(count) JavaScript elements which are not allowed for security reasons"
        case .tooManyPages(let count, let limit):
            return "PDF has \(count) pages, exceeding the security limit of \(limit) pages"
        case .encryptedPDF:
            return "Encrypted PDFs are not supported for security reasons"
        case .corruptedPDF:
            return "PDF appears to be corrupted or malformed"
        case .accessDenied(let path):
            return "Access denied to file: \(path)"
        case .fileNotReadable(let path):
            return "File is not readable: \(path)"
        case .invalidFileFormat:
            return "File format is not a valid PDF"
        case .suspiciousContent(let description):
            return "Suspicious content detected: \(description)"
        }
    }
    
    var description: String {
        return errorDescription ?? "Unknown security error"
    }
}

// MARK: - Security Configuration

struct PDFSecurityConfiguration {
    /// Maximum file size in bytes (default: 100MB)
    let maxFileSize: Int
    /// Maximum number of pages allowed (default: 1000)
    let maxPageCount: Int
    /// Whether to allow encrypted PDFs (default: false)
    let allowEncryptedPDFs: Bool
    /// Whether to allow JavaScript in PDFs (default: false)
    let allowJavaScript: Bool
    /// List of allowed file extensions
    let allowedFileExtensions: [String]
    /// List of allowed MIME types
    let allowedMIMETypes: [String]
    
    static let `default` = PDFSecurityConfiguration(
        maxFileSize: 100 * 1024 * 1024, // 100MB
        maxPageCount: 1000,
        allowEncryptedPDFs: false,
        allowJavaScript: false,
        allowedFileExtensions: ["pdf"],
        allowedMIMETypes: ["application/pdf"]
    )
    
    static let strict = PDFSecurityConfiguration(
        maxFileSize: 50 * 1024 * 1024, // 50MB
        maxPageCount: 500,
        allowEncryptedPDFs: false,
        allowJavaScript: false,
        allowedFileExtensions: ["pdf"],
        allowedMIMETypes: ["application/pdf"]
    )
}

// MARK: - PDF Security Validator

actor PDFSecurityValidator {
    private let configuration: PDFSecurityConfiguration
    
    init(configuration: PDFSecurityConfiguration = .default) {
        self.configuration = configuration
    }
    
    /// Validates a file URL for security compliance before PDF processing
    func validateFile(at url: URL) async throws {
        // 1. Basic file access validation
        try await validateFileAccess(url)
        
        // 2. File size validation
        try await validateFileSize(url)
        
        // 3. File type validation
        try await validateFileType(url)
        
        // 4. Content validation (requires PDF parsing)
        try await validatePDFContent(url)
    }
    
    /// Validates an already loaded PDF document for security compliance
    func validateDocument(_ document: PDFDocument) async throws {
        // 1. Page count validation
        try validatePageCount(document)
        
        // 2. Encryption validation
        try validateEncryption(document)
        
        // 3. JavaScript validation
        try await validateJavaScriptContent(document)
        
        // 4. Content structure validation
        try await validateContentStructure(document)
    }
    
    // MARK: - File Access Validation
    
    private func validateFileAccess(_ url: URL) async throws {
        let fileManager = FileManager.default
        
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw PDFSecurityError.fileNotReadable(path: url.path)
        }
        
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw PDFSecurityError.accessDenied(path: url.path)
        }
    }
    
    private func validateFileSize(_ url: URL) async throws {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = resourceValues.fileSize else {
                throw PDFSecurityError.fileNotReadable(path: url.path)
            }
            
            if fileSize > configuration.maxFileSize {
                throw PDFSecurityError.fileTooLarge(size: fileSize, limit: configuration.maxFileSize)
            }
        } catch let error as PDFSecurityError {
            throw error
        } catch {
            throw PDFSecurityError.fileNotReadable(path: url.path)
        }
    }
    
    private func validateFileType(_ url: URL) async throws {
        // Check file extension
        let fileExtension = url.pathExtension.lowercased()
        guard configuration.allowedFileExtensions.contains(fileExtension) else {
            throw PDFSecurityError.invalidFileType(
                type: fileExtension,
                expected: configuration.allowedFileExtensions
            )
        }
        
        // Check MIME type using UTType
        if #available(macOS 11.0, *) {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
                if let contentType = resourceValues.contentType {
                    let mimeType = contentType.preferredMIMEType ?? "unknown"
                    guard configuration.allowedMIMETypes.contains(mimeType) else {
                        throw PDFSecurityError.invalidFileType(
                            type: mimeType,
                            expected: configuration.allowedMIMETypes
                        )
                    }
                }
            } catch let error as PDFSecurityError {
                throw error
            } catch {
                // If we can't determine content type, continue with other validations
                print("Warning: Could not determine content type for \(url.path)")
            }
        }
    }
    
    // MARK: - PDF Content Validation
    
    private func validatePDFContent(_ url: URL) async throws {
        // Try to create a PDFDocument to validate the file format
        guard let document = PDFDocument(url: url) else {
            throw PDFSecurityError.invalidFileFormat
        }
        
        // Validate the document
        try await validateDocument(document)
    }
    
    private func validatePageCount(_ document: PDFDocument) throws {
        let pageCount = document.pageCount
        
        if pageCount == 0 {
            throw PDFSecurityError.corruptedPDF
        }
        
        if pageCount > configuration.maxPageCount {
            throw PDFSecurityError.tooManyPages(count: pageCount, limit: configuration.maxPageCount)
        }
    }
    
    private func validateEncryption(_ document: PDFDocument) throws {
        if !configuration.allowEncryptedPDFs && document.isEncrypted {
            throw PDFSecurityError.encryptedPDF
        }
    }
    
    private func validateJavaScriptContent(_ document: PDFDocument) async throws {
        guard !configuration.allowJavaScript else { return }
        
        // Scan PDF for JavaScript content using simpler pattern matching
        let javascriptCount = await Task.detached(priority: .userInitiated) {
            var jsCount = 0
            
            // Check if document contains any JavaScript-like patterns by examining the raw data
            if let documentURL = document.documentURL,
               let data = try? Data(contentsOf: documentURL) {
                let dataString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) ?? ""
                
                // Look for common JavaScript patterns in PDF
                let jsPatterns = ["/JS", "/JavaScript", "app.", "this.print", "eval(", "document."]
                for pattern in jsPatterns {
                    if dataString.contains(pattern) {
                        jsCount += 1
                        break // Found JavaScript content
                    }
                }
            }
            
            return jsCount
        }.value
        
        if javascriptCount > 0 {
            throw PDFSecurityError.maliciousJavaScript(count: javascriptCount)
        }
    }
    
    private func validateContentStructure(_ document: PDFDocument) async throws {
        // Perform basic content structure validation
        try await Task.detached(priority: .userInitiated) {
            // Check for suspicious patterns in PDF structure
            for pageIndex in 0..<min(document.pageCount, 10) { // Check first 10 pages
                guard let page = document.page(at: pageIndex) else { continue }
                
                // Check for extremely large page bounds (potential memory bomb)
                let bounds = page.bounds(for: .mediaBox)
                let maxDimension: CGFloat = 50000 // 50,000 points (roughly 694 inches at 72 DPI)
                
                if bounds.width > maxDimension || bounds.height > maxDimension {
                    throw PDFSecurityError.suspiciousContent(
                        description: "Page \(pageIndex + 1) has unusually large dimensions (\(bounds.width) x \(bounds.height))"
                    )
                }
            }
        }.value
    }
}

// MARK: - Security Validation Result

struct PDFSecurityValidationResult {
    let isValid: Bool
    let errors: [PDFSecurityError]
    let warnings: [String]
    
    static let valid = PDFSecurityValidationResult(isValid: true, errors: [], warnings: [])
    
    init(isValid: Bool, errors: [PDFSecurityError], warnings: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

// MARK: - Convenience Extensions

extension PDFSecurityValidator {
    /// Validates a file and returns a result with all errors collected
    func validateFileWithResult(at url: URL) async -> PDFSecurityValidationResult {
        do {
            try await validateFile(at: url)
            return .valid
        } catch let error as PDFSecurityError {
            return PDFSecurityValidationResult(isValid: false, errors: [error])
        } catch {
            return PDFSecurityValidationResult(
                isValid: false,
                errors: [PDFSecurityError.suspiciousContent(description: error.localizedDescription)]
            )
        }
    }
}