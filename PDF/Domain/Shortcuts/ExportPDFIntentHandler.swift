import Foundation
import Intents
import PDFKit
import AppKit

@available(macOS 11.0, *)
class ExportPDFIntentHandler: NSObject, ExportPDFIntentHandling {
    
    private let pdfService = PDFService()
    
    // MARK: - Intent Handling
    
    func handle(intent: ExportPDFIntent, completion: @escaping (ExportPDFIntentResponse) -> Void) {
        Task {
            await handleIntent(intent: intent, completion: completion)
        }
    }
    
    private func handleIntent(intent: ExportPDFIntent, completion: @escaping (ExportPDFIntentResponse) -> Void) async {
        guard let pdfFile = intent.pdfFile,
              let pdfURL = pdfFile.fileURL else {
            let response = ExportPDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No PDF file provided"
            completion(response)
            return
        }
        
        guard let exportFormat = intent.format else {
            let response = ExportPDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No export format specified"
            completion(response)
            return
        }
        
        do {
            // Access the source file
            let hasAccess = pdfURL.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    pdfURL.stopAccessingSecurityScopedResource()
                }
            }
            
            let document = try await pdfService.open(url: pdfURL)
            
            // Determine output directory
            let outputDirectory = try determineOutputDirectory(from: intent)
            
            // Generate output file name
            let outputFileName = generateOutputFileName(
                from: intent.outputFileName,
                originalURL: pdfURL,
                format: exportFormat
            )
            
            // Create output URL
            let outputURL = createUniqueOutputURL(
                fileName: outputFileName,
                directory: outputDirectory
            )
            
            // Get quality setting
            let quality = intent.quality?.doubleValue ?? 0.9
            
            // Export based on format
            try await exportDocument(
                document: document,
                format: exportFormat,
                url: outputURL,
                quality: CGFloat(quality)
            )
            
            // Get file size for response
            let fileSize = try getFileSize(at: outputURL)
            
            // Create successful response
            let response = ExportPDFIntentResponse(code: .success, userActivity: nil)
            response.exportedFile = INFile(
                fileURL: outputURL,
                filename: outputURL.lastPathComponent,
                typeIdentifier: getTypeIdentifier(for: exportFormat)
            )
            response.fileSize = formatFileSize(fileSize)
            
            completion(response)
            
        } catch {
            let response = ExportPDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "Failed to export PDF: \(error.localizedDescription)"
            completion(response)
        }
    }
    
    // MARK: - Export Methods
    
    private func exportDocument(
        document: PDFDocument,
        format: ExportFormat,
        url: URL,
        quality: CGFloat
    ) async throws {
        switch format {
        case .pdf:
            try await pdfService.export(document: document, format: .pdf, url: url, quality: quality)
            
        case .png:
            try await pdfService.export(document: document, format: .png, url: url, quality: quality)
            
        case .jpeg:
            try await exportAsJPEG(document: document, url: url, quality: quality)
            
        case .webp:
            try await exportAsWebP(document: document, url: url, quality: quality)
            
        @unknown default:
            throw ExportError.unsupportedFormat
        }
    }
    
    private func exportAsJPEG(document: PDFDocument, url: URL, quality: CGFloat) async throws {
        guard let page = document.page(at: 0) else {
            throw ExportError.noPages
        }
        
        let image = page.thumbnail(of: CGSize(width: 2480, height: 3508), for: .mediaBox)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ExportError.imageConversionFailed
        }
        
        let compressionFactor = NSNumber(value: Float(1.0 - quality))
        guard let jpegData = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionFactor]
        ) else {
            throw ExportError.imageEncodingFailed
        }
        
        try jpegData.write(to: url)
    }
    
    private func exportAsWebP(document: PDFDocument, url: URL, quality: CGFloat) async throws {
        // WebP export would require additional frameworks or libraries
        // For now, we'll fall back to PNG export
        try await pdfService.export(document: document, format: .png, url: url, quality: quality)
    }
    
    // MARK: - Parameter Resolution
    
    func resolvePdfFile(for intent: ExportPDFIntent, with completion: @escaping (INFileResolutionResult) -> Void) {
        guard let pdfFile = intent.pdfFile else {
            completion(INFileResolutionResult.needsValue())
            return
        }
        
        guard let fileURL = pdfFile.fileURL,
              fileURL.pathExtension.lowercased() == "pdf" else {
            completion(INFileResolutionResult.unsupported(forReason: .invalidFormat))
            return
        }
        
        completion(INFileResolutionResult.success(with: pdfFile))
    }
    
    func resolveFormat(for intent: ExportPDFIntent, with completion: @escaping (ExportFormatResolutionResult) -> Void) {
        guard let format = intent.format else {
            completion(ExportFormatResolutionResult.needsValue())
            return
        }
        
        completion(ExportFormatResolutionResult.success(with: format))
    }
    
    func resolveDestination(for intent: ExportPDFIntent, with completion: @escaping (ExportDestinationResolutionResult) -> Void) {
        if let destination = intent.destination {
            completion(ExportDestinationResolutionResult.success(with: destination))
        } else {
            completion(ExportDestinationResolutionResult.success(with: .documents))
        }
    }
    
    func resolveCustomDirectory(for intent: ExportPDFIntent, with completion: @escaping (INFileResolutionResult) -> Void) {
        if intent.destination == .custom {
            guard let customDirectory = intent.customDirectory else {
                completion(INFileResolutionResult.needsValue())
                return
            }
            completion(INFileResolutionResult.success(with: customDirectory))
        } else {
            completion(INFileResolutionResult.notRequired())
        }
    }
    
    func resolveQuality(for intent: ExportPDFIntent, with completion: @escaping (INDoubleResolutionResult) -> Void) {
        if let quality = intent.quality {
            let value = quality.doubleValue
            if value >= 0.1 && value <= 1.0 {
                completion(INDoubleResolutionResult.success(with: value))
            } else {
                completion(INDoubleResolutionResult.outOfRange())
            }
        } else {
            completion(INDoubleResolutionResult.success(with: 0.9))
        }
    }
    
    func resolveOutputFileName(for intent: ExportPDFIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let fileName = intent.outputFileName, !fileName.isEmpty {
            completion(INStringResolutionResult.success(with: fileName))
        } else {
            completion(INStringResolutionResult.notRequired())
        }
    }
    
    // MARK: - Helper Methods
    
    private func determineOutputDirectory(from intent: ExportPDFIntent) throws -> URL {
        let destination = intent.destination ?? .documents
        
        switch destination {
        case .files:
            // Use iCloud Documents for Files app integration
            if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
                return iCloudURL
            }
            fallthrough
            
        case .documents:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            
        case .desktop:
            return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            
        case .custom:
            guard let customDirectory = intent.customDirectory,
                  let customURL = customDirectory.fileURL else {
                throw ExportError.invalidDestination
            }
            return customURL
            
        @unknown default:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
    }
    
    private func generateOutputFileName(
        from customName: String?,
        originalURL: URL,
        format: ExportFormat
    ) -> String {
        let baseName: String
        
        if let customName = customName, !customName.isEmpty {
            baseName = customName
        } else {
            baseName = originalURL.deletingPathExtension().lastPathComponent
        }
        
        let fileExtension = getFileExtension(for: format)
        return "\(baseName).\(fileExtension)"
    }
    
    private func getFileExtension(for format: ExportFormat) -> String {
        switch format {
        case .pdf:
            return "pdf"
        case .png:
            return "png"
        case .jpeg:
            return "jpg"
        case .webp:
            return "webp"
        @unknown default:
            return "pdf"
        }
    }
    
    private func getTypeIdentifier(for format: ExportFormat) -> String {
        switch format {
        case .pdf:
            return "com.adobe.pdf"
        case .png:
            return "public.png"
        case .jpeg:
            return "public.jpeg"
        case .webp:
            return "org.webmproject.webp"
        @unknown default:
            return "com.adobe.pdf"
        }
    }
    
    private func createUniqueOutputURL(fileName: String, directory: URL) -> URL {
        var outputURL = directory.appendingPathComponent(fileName)
        var counter = 1
        let baseURL = outputURL
        
        while FileManager.default.fileExists(atPath: outputURL.path) {
            let nameWithoutExtension = baseURL.deletingPathExtension().lastPathComponent
            let fileExtension = baseURL.pathExtension
            let newName = "\(nameWithoutExtension)_\(counter).\(fileExtension)"
            outputURL = baseURL.deletingLastPathComponent().appendingPathComponent(newName)
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
    
    func confirm(intent: ExportPDFIntent, completion: @escaping (ExportPDFIntentResponse) -> Void) {
        guard let pdfFile = intent.pdfFile,
              let pdfURL = pdfFile.fileURL else {
            let response = ExportPDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No PDF file provided"
            completion(response)
            return
        }
        
        guard let exportFormat = intent.format else {
            let response = ExportPDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No export format specified"
            completion(response)
            return
        }
        
        // Validate PDF file accessibility
        let hasAccess = pdfURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }
        
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            let response = ExportPDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "PDF file does not exist or is not accessible"
            completion(response)
            return
        }
        
        // Validate custom directory if specified
        if intent.destination == .custom {
            guard let customDirectory = intent.customDirectory,
                  let customURL = customDirectory.fileURL,
                  FileManager.default.fileExists(atPath: customURL.path) else {
                let response = ExportPDFIntentResponse(code: .failure, userActivity: nil)
                response.errorMessage = "Custom directory does not exist or is not accessible"
                completion(response)
                return
            }
        }
        
        let response = ExportPDFIntentResponse(code: .ready, userActivity: nil)
        completion(response)
    }
}

// MARK: - Supporting Types

enum ExportError: LocalizedError {
    case unsupportedFormat
    case noPages
    case imageConversionFailed
    case imageEncodingFailed
    case invalidDestination
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported export format"
        case .noPages:
            return "PDF has no pages to export"
        case .imageConversionFailed:
            return "Failed to convert PDF to image"
        case .imageEncodingFailed:
            return "Failed to encode image"
        case .invalidDestination:
            return "Invalid export destination"
        }
    }
}