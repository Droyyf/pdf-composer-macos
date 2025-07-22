import Foundation
import Intents
import PDFKit
import AppKit

@available(macOS 11.0, *)
class BatchProcessIntentHandler: NSObject, BatchProcessIntentHandling {
    
    private let pdfService = PDFService()
    
    // MARK: - Intent Handling
    
    func handle(intent: BatchProcessIntent, completion: @escaping (BatchProcessIntentResponse) -> Void) {
        Task {
            await handleIntent(intent: intent, completion: completion)
        }
    }
    
    private func handleIntent(intent: BatchProcessIntent, completion: @escaping (BatchProcessIntentResponse) -> Void) async {
        guard let pdfFiles = intent.pdfFiles, !pdfFiles.isEmpty else {
            let response = BatchProcessIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No PDF files provided"
            completion(response)
            return
        }
        
        guard let operations = intent.operations, !operations.isEmpty else {
            let response = BatchProcessIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No operations specified"
            completion(response)
            return
        }
        
        do {
            let outputDirectory = try determineOutputDirectory(from: intent)
            let maxPPI = intent.maxPPI?.intValue ?? 300
            let processOperations = mapProcessOperations(from: operations)
            
            var processedFiles: [INFile] = []
            var totalSizeSaved: Int64 = 0
            var filesProcessed = 0
            
            // Process each file
            for file in pdfFiles {
                guard let fileURL = file.fileURL else {
                    continue
                }
                
                let hasAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                do {
                    let originalSize = try getFileSize(at: fileURL)
                    let processedURL = try await processFile(
                        url: fileURL,
                        operations: processOperations,
                        maxPPI: maxPPI,
                        outputDirectory: outputDirectory
                    )
                    
                    let newSize = try getFileSize(at: processedURL)
                    let sizeSaved = max(0, originalSize - newSize)
                    totalSizeSaved += sizeSaved
                    
                    let processedFile = INFile(
                        fileURL: processedURL,
                        filename: processedURL.lastPathComponent,
                        typeIdentifier: "com.adobe.pdf"
                    )
                    processedFiles.append(processedFile)
                    filesProcessed += 1
                    
                } catch {
                    // Log error but continue processing other files
                    print("Failed to process \(fileURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
            
            // Create successful response
            let response = BatchProcessIntentResponse(code: .success, userActivity: nil)
            response.processedFiles = processedFiles
            response.filesProcessed = NSNumber(value: filesProcessed)
            response.totalSizeSaved = formatFileSize(totalSizeSaved)
            
            completion(response)
            
        } catch {
            let response = BatchProcessIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "Failed to process files: \(error.localizedDescription)"
            completion(response)
        }
    }
    
    // MARK: - File Processing
    
    private func processFile(
        url: URL,
        operations: Set<ProcessOperationType>,
        maxPPI: Int,
        outputDirectory: URL
    ) async throws -> URL {
        
        let document = try await pdfService.open(url: url)
        var processedDocument = document
        
        // Apply operations
        if operations.contains(.optimize) || operations.contains(.downsample) {
            processedDocument = try await optimizeDocument(
                document: processedDocument,
                maxPPI: CGFloat(maxPPI)
            )
        }
        
        if operations.contains(.stripMetadata) {
            processedDocument = try stripMetadata(from: processedDocument)
        }
        
        if operations.contains(.validateSecurity) {
            try validateSecurity(of: processedDocument)
        }
        
        // Create output URL
        let originalName = url.deletingPathExtension().lastPathComponent
        let outputURL = createUniqueOutputURL(
            baseName: "\(originalName)_processed",
            directory: outputDirectory,
            extension: "pdf"
        )
        
        // Export processed document
        try await pdfService.export(document: processedDocument, format: .pdf, url: outputURL)
        
        return outputURL
    }
    
    private func optimizeDocument(document: PDFDocument, maxPPI: CGFloat) async throws -> PDFDocument {
        let optimizedDocument = PDFDocument()
        
        // Process each page
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            // Create optimized page representation
            let pageData = page.dataRepresentation
            
            if let pageImage = createImageFromPage(page),
               let optimizedImage = Composer.downsampleIfNeeded(
                image: pageImage,
                maxPPI: maxPPI,
                pageSize: page.bounds(for: .mediaBox).size
               ),
               let optimizedPage = try await createPageFromImage(optimizedImage) {
                optimizedDocument.insert(optimizedPage, at: pageIndex)
            } else {
                // Fallback to original page if optimization fails
                optimizedDocument.insert(page, at: pageIndex)
            }
        }
        
        return optimizedDocument
    }
    
    private func createImageFromPage(_ page: PDFPage) -> NSImage? {
        let bounds = page.bounds(for: .mediaBox)
        return page.thumbnail(of: bounds.size, for: .mediaBox)
    }
    
    private func createPageFromImage(_ image: NSImage) async throws -> PDFPage? {
        return try await Composer.imageToPDFPage(image: image, mode: .export)
    }
    
    private func stripMetadata(from document: PDFDocument) throws -> PDFDocument {
        // Create new document without metadata
        let newDocument = PDFDocument()
        
        // Copy pages without metadata
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex) {
                newDocument.insert(page, at: pageIndex)
            }
        }
        
        // Remove document-level metadata
        newDocument.documentAttributes = [:]
        
        return newDocument
    }
    
    private func validateSecurity(of document: PDFDocument) throws {
        // Check if document is encrypted
        if document.isEncrypted {
            throw ProcessingError.documentEncrypted
        }
        
        // Check for permissions
        if !document.allowsCopying || !document.allowsPrinting {
            throw ProcessingError.restrictedPermissions
        }
        
        // Additional security validations can be added here
    }
    
    // MARK: - Parameter Resolution
    
    func resolvePdfFiles(for intent: BatchProcessIntent, with completion: @escaping ([INFileResolutionResult]) -> Void) {
        guard let pdfFiles = intent.pdfFiles, !pdfFiles.isEmpty else {
            completion([INFileResolutionResult.needsValue()])
            return
        }
        
        var results: [INFileResolutionResult] = []
        for file in pdfFiles {
            if let fileURL = file.fileURL, fileURL.pathExtension.lowercased() == "pdf" {
                results.append(INFileResolutionResult.success(with: file))
            } else {
                results.append(INFileResolutionResult.unsupported(forReason: .invalidFormat))
            }
        }
        
        completion(results)
    }
    
    func resolveOperations(for intent: BatchProcessIntent, with completion: @escaping ([ProcessOperationResolutionResult]) -> Void) {
        guard let operations = intent.operations, !operations.isEmpty else {
            completion([ProcessOperationResolutionResult.needsValue()])
            return
        }
        
        let results = operations.map { ProcessOperationResolutionResult.success(with: $0) }
        completion(results)
    }
    
    func resolveMaxPPI(for intent: BatchProcessIntent, with completion: @escaping (INIntegerResolutionResult) -> Void) {
        if let maxPPI = intent.maxPPI {
            let value = maxPPI.intValue
            if value >= 72 && value <= 600 {
                completion(INIntegerResolutionResult.success(with: value))
            } else {
                completion(INIntegerResolutionResult.outOfRange())
            }
        } else {
            completion(INIntegerResolutionResult.success(with: 300))
        }
    }
    
    func resolveOutputDirectory(for intent: BatchProcessIntent, with completion: @escaping (INFileResolutionResult) -> Void) {
        if let directory = intent.outputDirectory {
            completion(INFileResolutionResult.success(with: directory))
        } else {
            completion(INFileResolutionResult.notRequired())
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapProcessOperations(from operations: [ProcessOperation]) -> Set<ProcessOperationType> {
        var result: Set<ProcessOperationType> = []
        
        for operation in operations {
            switch operation {
            case .optimize:
                result.insert(.optimize)
            case .downsample:
                result.insert(.downsample)
            case .stripMetadata:
                result.insert(.stripMetadata)
            case .validateSecurity:
                result.insert(.validateSecurity)
            @unknown default:
                break
            }
        }
        
        return result
    }
    
    private func determineOutputDirectory(from intent: BatchProcessIntent) throws -> URL {
        if let directory = intent.outputDirectory,
           let directoryURL = directory.fileURL {
            return directoryURL
        }
        
        // Default to Documents directory
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private func createUniqueOutputURL(baseName: String, directory: URL, extension ext: String) -> URL {
        var outputURL = directory.appendingPathComponent("\(baseName).\(ext)")
        var counter = 1
        
        while FileManager.default.fileExists(atPath: outputURL.path) {
            outputURL = directory.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }
        
        return outputURL
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // MARK: - Confirmation
    
    func confirm(intent: BatchProcessIntent, completion: @escaping (BatchProcessIntentResponse) -> Void) {
        guard let pdfFiles = intent.pdfFiles, !pdfFiles.isEmpty else {
            let response = BatchProcessIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No PDF files provided"
            completion(response)
            return
        }
        
        guard let operations = intent.operations, !operations.isEmpty else {
            let response = BatchProcessIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No operations specified"
            completion(response)
            return
        }
        
        // Validate file count
        if pdfFiles.count > 50 {
            let response = BatchProcessIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "Too many files. Maximum 50 files can be processed at once."
            completion(response)
            return
        }
        
        let response = BatchProcessIntentResponse(code: .ready, userActivity: nil)
        completion(response)
    }
}

// MARK: - Supporting Types

enum ProcessOperationType {
    case optimize
    case downsample
    case stripMetadata
    case validateSecurity
}

enum ProcessingError: LocalizedError {
    case documentEncrypted
    case restrictedPermissions
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .documentEncrypted:
            return "Document is encrypted and cannot be processed"
        case .restrictedPermissions:
            return "Document has restricted permissions"
        case .unsupportedFormat:
            return "Unsupported file format"
        }
    }
}