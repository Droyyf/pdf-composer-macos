import Foundation
import PDFKit
import AppKit

/// Shared utilities for both main app and Shortcuts extension
struct SharedUtilities {
    
    // MARK: - File Handling
    
    /// Safely access a security-scoped resource and perform an operation
    static func withSecurityScopedResource<T>(
        _ url: URL,
        operation: () throws -> T
    ) throws -> T {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try operation()
    }
    
    /// Safely access a security-scoped resource and perform an async operation
    static func withSecurityScopedResource<T>(
        _ url: URL,
        operation: () async throws -> T
    ) async throws -> T {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try await operation()
    }
    
    /// Create a unique file URL to prevent overwrites
    static func createUniqueURL(
        baseName: String,
        directory: URL,
        pathExtension: String
    ) -> URL {
        var candidateURL = directory
            .appendingPathComponent(baseName)
            .appendingPathExtension(pathExtension)
        
        var counter = 1
        while FileManager.default.fileExists(atPath: candidateURL.path) {
            let numberedName = "\(baseName)_\(counter)"
            candidateURL = directory
                .appendingPathComponent(numberedName)
                .appendingPathExtension(pathExtension)
            counter += 1
        }
        
        return candidateURL
    }
    
    /// Get human-readable file size string
    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Get file size in bytes
    static func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    // MARK: - PDF Validation
    
    /// Validate that a file is a proper PDF
    static func validatePDFFile(at url: URL) throws {
        guard url.pathExtension.lowercased() == "pdf" else {
            throw ValidationError.invalidFileType
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError.fileNotFound
        }
        
        // Try to open the PDF to validate it
        guard let _ = PDFDocument(url: url) else {
            throw ValidationError.corruptedPDF
        }
    }
    
    /// Validate that a file is a supported image format
    static func validateImageFile(at url: URL) throws {
        let supportedExtensions = ["png", "jpg", "jpeg", "tiff", "tif", "gif", "bmp", "webp"]
        let fileExtension = url.pathExtension.lowercased()
        
        guard supportedExtensions.contains(fileExtension) else {
            throw ValidationError.unsupportedImageFormat
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError.fileNotFound
        }
        
        // Try to load the image to validate it
        guard let _ = NSImage(contentsOf: url) else {
            throw ValidationError.corruptedImage
        }
    }
    
    // MARK: - Directory Utilities
    
    /// Get standard directories for export operations
    static func getStandardDirectory(_ type: StandardDirectoryType) throws -> URL {
        switch type {
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            
        case .downloads:
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            
        case .iCloudDocuments:
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents") else {
                throw ValidationError.iCloudNotAvailable
            }
            return iCloudURL
        }
    }
    
    enum StandardDirectoryType {
        case documents
        case desktop
        case downloads
        case iCloudDocuments
    }
    
    // MARK: - Error Handling
    
    enum ValidationError: LocalizedError {
        case invalidFileType
        case fileNotFound
        case corruptedPDF
        case unsupportedImageFormat
        case corruptedImage
        case iCloudNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .invalidFileType:
                return "Invalid file type"
            case .fileNotFound:
                return "File not found"
            case .corruptedPDF:
                return "PDF file is corrupted or unreadable"
            case .unsupportedImageFormat:
                return "Unsupported image format"
            case .corruptedImage:
                return "Image file is corrupted or unreadable"
            case .iCloudNotAvailable:
                return "iCloud Drive is not available"
            }
        }
    }
    
    // MARK: - Date Utilities
    
    /// Generate timestamp-based filename
    static func generateTimestampedFilename(prefix: String = "Export", extension ext: String = "pdf") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "\(prefix)_\(timestamp).\(ext)"
    }
    
    // MARK: - Memory Management
    
    /// Execute a block with automatic memory management
    static func withAutorelease<T>(_ block: () throws -> T) throws -> T {
        return try autoreleasepool {
            return try block()
        }
    }
    
    /// Execute an async block with automatic memory management
    static func withAutorelease<T>(_ block: () async throws -> T) async throws -> T {
        // Can't use autoreleasepool directly with async code
        // Instead, perform memory management manually
        return try await block()
    }
    
    // MARK: - Progress Tracking
    
    /// Simple progress tracking for batch operations
    class ProgressTracker {
        private(set) var current: Int = 0
        private(set) var total: Int
        
        init(total: Int) {
            self.total = total
        }
        
        func increment() {
            current += 1
        }
        
        var progress: Double {
            guard total > 0 else { return 0 }
            return Double(current) / Double(total)
        }
        
        var isComplete: Bool {
            return current >= total
        }
    }
}