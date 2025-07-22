import Foundation
import SwiftUI
import PDFKit
import AppKit

/// Enhanced export service with cloud storage integration
@MainActor
final class ExportService: ObservableObject {
    static let shared = ExportService()
    
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0.0
    @Published var exportStatus: String = ""
    @Published var showCloudPicker: Bool = false
    @Published var showCloudUploadProgress: Bool = false
    
    private let cloudManager = CloudStorageManager.shared
    private var currentExportTask: Task<Void, Never>?
    
    enum ExportDestination {
        case local(URL)
        case cloud(CloudUploadRequest, CloudAccount)
    }
    
    enum ExportFormat: String, CaseIterable, Codable {
        case pdf = "pdf"
        case png = "png"
        case jpeg = "jpeg"
        case webp = "webp"
        
        var displayName: String {
            switch self {
            case .pdf: return "PDF"
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .webp: return "WebP"
            }
        }
        
        var fileExtension: String {
            return rawValue
        }
        
        var mimeType: String {
            switch self {
            case .pdf: return "application/pdf"
            case .png: return "image/png"
            case .jpeg: return "image/jpeg"
            case .webp: return "image/webp"
            }
        }
    }
    
    private init() {}
    
    // MARK: - Export Methods
    
    /// Export composed PDF with destination choice
    func exportComposedPDF(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        format: ExportFormat,
        composition: CompositionMode = .centerCitation,
        showDestinationPicker: Bool = true
    ) {
        // Cancel any existing export
        cancelExport()
        
        if showDestinationPicker {
            showExportDestinationPicker(
                citationPages: citationPages,
                coverPage: coverPage,
                format: format,
                composition: composition
            )
        } else {
            // Default to local export
            showLocalSavePanel(
                citationPages: citationPages,
                coverPage: coverPage,
                format: format,
                composition: composition
            )
        }
    }
    
    /// Show destination picker (local vs cloud)
    private func showExportDestinationPicker(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        format: ExportFormat,
        composition: CompositionMode
    ) {
        // For now, show both options via alert
        let alert = NSAlert()
        alert.messageText = "Choose Export Destination"
        alert.informativeText = "Where would you like to save your exported files?"
        alert.addButton(withTitle: "Local Folder")
        
        if !cloudManager.connectedAccounts.isEmpty {
            alert.addButton(withTitle: "Cloud Storage")
        }
        
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            // Local export
            showLocalSavePanel(
                citationPages: citationPages,
                coverPage: coverPage,
                format: format,
                composition: composition
            )
            
        case .alertSecondButtonReturn:
            // Cloud export (only if accounts exist)
            if !cloudManager.connectedAccounts.isEmpty {
                exportToCloud(
                    citationPages: citationPages,
                    coverPage: coverPage,
                    format: format,
                    composition: composition
                )
            }
            
        default:
            // Cancel - do nothing
            break
        }
    }
    
    /// Show local save panel for export
    private func showLocalSavePanel(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        format: ExportFormat,
        composition: CompositionMode
    ) {
        let savePanel = NSSavePanel()
        savePanel.title = "Choose Export Location"
        savePanel.message = "Select a folder to save your exported files"
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = true
        savePanel.nameFieldStringValue = "PDF_Export_\(Date().timeIntervalSince1970)"
        
        switch format {
        case .pdf:
            savePanel.allowedContentTypes = [.pdf]
        case .png:
            savePanel.allowedContentTypes = [.png]
        case .jpeg:
            savePanel.allowedContentTypes = [.jpeg]
        case .webp:
            savePanel.allowedContentTypes = [.init(filenameExtension: "webp")!]
        }
        
        savePanel.begin { [weak self] result in
            if result == .OK, let url = savePanel.url {
                self?.performLocalExport(
                    citationPages: citationPages,
                    coverPage: coverPage,
                    format: format,
                    composition: composition,
                    destinationURL: url
                )
            }
        }
    }
    
    /// Export to cloud storage
    private func exportToCloud(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        format: ExportFormat,
        composition: CompositionMode
    ) {
        // First, export to temporary local file
        let tempURL = createTempFileURL(format: format)
        
        currentExportTask = Task {
            do {
                // Export to temp file
                try await performExportToFile(
                    citationPages: citationPages,
                    coverPage: coverPage,
                    format: format,
                    composition: composition,
                    destinationURL: tempURL
                )
                
                // Show cloud picker
                await showCloudStoragePicker(tempFileURL: tempURL)
                
            } catch {
                await showExportError("Export failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Show cloud storage picker
    private func showCloudStoragePicker(tempFileURL: URL) async {
        showCloudPicker = true
        
        // The CloudStoragePickerView will handle the upload
        // This is a simplified approach - in a real implementation,
        // you'd want to set up proper callbacks or use a coordinator
    }
    
    /// Perform local export
    private func performLocalExport(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        format: ExportFormat,
        composition: CompositionMode,
        destinationURL: URL
    ) {
        currentExportTask = Task {
            do {
                try await performExportToFile(
                    citationPages: citationPages,
                    coverPage: coverPage,
                    format: format,
                    composition: composition,
                    destinationURL: destinationURL
                )
                
                await showExportSuccess("Export completed successfully")
                
            } catch {
                await showExportError("Export failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Core export functionality
    private func performExportToFile(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        format: ExportFormat,
        composition: CompositionMode,
        destinationURL: URL
    ) async throws {
        isExporting = true
        exportProgress = 0.0
        exportStatus = "Starting export..."
        
        defer {
            isExporting = false
            exportProgress = 0.0
            exportStatus = ""
        }
        
        let totalPages = citationPages.count + (coverPage != nil ? 1 : 0)
        var currentPage = 0
        
        switch format {
        case .pdf:
            try await exportToPDF(
                citationPages: citationPages,
                coverPage: coverPage,
                composition: composition,
                destinationURL: destinationURL,
                progressHandler: { progress, status in
                    Task { @MainActor in
                        self.exportProgress = progress
                        self.exportStatus = status
                    }
                }
            )
            
        case .png, .jpeg, .webp:
            try await exportToImageFormat(
                citationPages: citationPages,
                coverPage: coverPage,
                format: format,
                composition: composition,
                destinationURL: destinationURL,
                progressHandler: { progress, status in
                    Task { @MainActor in
                        self.exportProgress = progress
                        self.exportStatus = status
                    }
                }
            )
        }
    }
    
    /// Export to PDF format
    private func exportToPDF(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        composition: CompositionMode,
        destinationURL: URL,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        let composer = Composer()
        
        progressHandler(0.1, "Preparing PDF composition...")
        
        let composedPDF = try await composer.composePages(
            citationPages: citationPages.map { ($0, 0) }, // Simplified - use actual page indices if needed
            coverPage: coverPage.map { ($0, 0) },
            mode: composition
        )
        
        progressHandler(0.8, "Saving PDF...")
        
        composedPDF.write(to: destinationURL)
        
        progressHandler(1.0, "Export completed")
    }
    
    /// Export to image formats
    private func exportToImageFormat(
        citationPages: [PDFPage],
        coverPage: PDFPage?,
        format: ExportFormat,
        composition: CompositionMode,
        destinationURL: URL,
        progressHandler: @escaping (Double, String) -> Void
    ) async throws {
        progressHandler(0.1, "Preparing image export...")
        
        let composer = Composer()
        
        // First compose to PDF
        let composedPDF = try await composer.composePages(
            citationPages: citationPages.map { ($0, 0) },
            coverPage: coverPage.map { ($0, 0) },
            mode: composition
        )
        
        progressHandler(0.5, "Converting to \(format.displayName)...")
        
        // Extract pages as images
        var images: [NSImage] = []
        
        for pageIndex in 0..<composedPDF.pageCount {
            guard let page = composedPDF.page(at: pageIndex) else { continue }
            
            let pageRect = page.bounds(for: .mediaBox)
            let image = page.thumbnail(of: pageRect.size, for: .mediaBox)
            images.append(image)
            
            let progress = 0.5 + (Double(pageIndex + 1) / Double(composedPDF.pageCount)) * 0.3
            progressHandler(progress, "Converting page \(pageIndex + 1) of \(composedPDF.pageCount)...")
        }
        
        progressHandler(0.9, "Saving \(format.displayName) files...")
        
        // Save images based on format
        let baseURL = destinationURL.deletingPathExtension()
        let directory = baseURL.deletingLastPathComponent()
        let baseName = baseURL.lastPathComponent
        
        for (index, image) in images.enumerated() {
            let filename = images.count == 1 ? baseName : "\(baseName)_page_\(index + 1)"
            let fileURL = directory.appendingPathComponent(filename).appendingPathExtension(format.fileExtension)
            
            try await saveImage(image, to: fileURL, format: format)
        }
        
        progressHandler(1.0, "Export completed")
    }
    
    /// Save image to file in specified format
    private func saveImage(_ image: NSImage, to url: URL, format: ExportFormat) async throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ExportError.imageConversionFailed
        }
        
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        bitmapRep.size = image.size
        
        let data: Data?
        
        switch format {
        case .png:
            data = bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        case .webp:
            // WebP support would require additional framework
            throw ExportError.unsupportedFormat
        case .pdf:
            throw ExportError.invalidOperation
        }
        
        guard let imageData = data else {
            throw ExportError.imageConversionFailed
        }
        
        try imageData.write(to: url)
    }
    
    // MARK: - Cloud Upload Methods
    
    /// Upload file to cloud storage
    func uploadToCloud(request: CloudUploadRequest, account: CloudAccount) {
        showCloudUploadProgress = true
        
        currentExportTask = Task {
            do {
                let uploadedFile = try await cloudManager.upload(request: request, to: account)
                await showExportSuccess("Uploaded to \(account.provider.displayName) successfully")
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: request.localFileURL)
                
            } catch {
                await showExportError("Upload failed: \(error.localizedDescription)")
            }
            
            showCloudUploadProgress = false
            showCloudPicker = false
        }
    }
    
    // MARK: - Utility Methods
    
    private func createTempFileURL(format: ExportFormat) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "temp_export_\(UUID().uuidString).\(format.fileExtension)"
        return tempDir.appendingPathComponent(filename)
    }
    
    func cancelExport() {
        currentExportTask?.cancel()
        currentExportTask = nil
        isExporting = false
        exportProgress = 0.0
        exportStatus = ""
    }
    
    private func showExportSuccess(_ message: String) async {
        exportStatus = message
        // You might want to show a toast or notification here
        print("✅ Export: \(message)")
    }
    
    private func showExportError(_ message: String) async {
        exportStatus = message
        // You might want to show an error alert here
        print("❌ Export Error: \(message)")
    }
}

// MARK: - Export Errors

enum ExportError: Error, LocalizedError {
    case imageConversionFailed
    case unsupportedFormat
    case invalidOperation
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image"
        case .unsupportedFormat:
            return "Unsupported export format"
        case .invalidOperation:
            return "Invalid export operation"
        case .fileWriteFailed:
            return "Failed to write file"
        }
    }
}

// MARK: - Composition Mode

enum CompositionMode: String, CaseIterable {
    case centerCitation = "center_citation"
    case leftAlign = "left_align"
    case rightAlign = "right_align"
    case fullPage = "full_page"
    
    var displayName: String {
        switch self {
        case .centerCitation:
            return "Center Citation"
        case .leftAlign:
            return "Left Aligned"
        case .rightAlign:
            return "Right Aligned"
        case .fullPage:
            return "Full Page"
        }
    }
}