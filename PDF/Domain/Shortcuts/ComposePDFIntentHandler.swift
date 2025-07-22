import Foundation
import Intents
import PDFKit
import AppKit

@available(macOS 11.0, *)
class ComposePDFIntentHandler: NSObject, ComposePDFIntentHandling {
    
    private let pdfService = PDFService()
    
    // MARK: - Intent Handling
    
    func handle(intent: ComposePDFIntent, completion: @escaping (ComposePDFIntentResponse) -> Void) {
        Task {
            await handleIntent(intent: intent, completion: completion)
        }
    }
    
    private func handleIntent(intent: ComposePDFIntent, completion: @escaping (ComposePDFIntentResponse) -> Void) async {
        guard let pdfFiles = intent.pdfFiles, !pdfFiles.isEmpty else {
            let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No PDF files provided"
            completion(response)
            return
        }
        
        do {
            // Load PDF documents and extract pages
            var allPages: [PDFPage] = []
            
            for file in pdfFiles {
                guard let fileURL = file.fileURL else {
                    let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
                    response.errorMessage = "Invalid file URL for PDF file"
                    completion(response)
                    return
                }
                
                // Start accessing security-scoped resource
                let hasAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                let document = try await pdfService.open(url: fileURL)
                
                // Extract all pages from the document
                for pageIndex in 0..<document.pageCount {
                    if let page = document.page(at: pageIndex) {
                        allPages.append(page)
                    }
                }
            }
            
            // Handle cover image if provided
            var coverImage: NSImage?
            if let coverFile = intent.coverImage,
               let coverURL = coverFile.fileURL {
                let hasAccess = coverURL.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        coverURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                coverImage = NSImage(contentsOf: coverURL)
                if coverImage == nil {
                    let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
                    response.errorMessage = "Failed to load cover image"
                    completion(response)
                    return
                }
            }
            
            // Determine cover placement
            let coverPlacement = mapCoverPlacement(from: intent.coverPlacement)
            
            // Compose the PDF
            let composedDocument = try await Composer.merge(
                pages: allPages,
                cover: coverImage,
                coverPlacement: coverPlacement,
                mode: .export
            )
            
            // Generate output file name
            let outputFileName = intent.outputFileName ?? generateDefaultFileName()
            let outputURL = try createOutputURL(fileName: outputFileName)
            
            // Export the composed PDF
            try await pdfService.export(document: composedDocument, format: .pdf, url: outputURL)
            
            // Create successful response
            let response = ComposePDFIntentResponse(code: .success, userActivity: nil)
            response.resultFile = INFile(fileURL: outputURL, filename: outputFileName, typeIdentifier: "com.adobe.pdf")
            response.pageCount = NSNumber(value: composedDocument.pageCount)
            
            completion(response)
            
        } catch let error as CompositionError {
            let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = error.localizedDescription
            completion(response)
        } catch {
            let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "Failed to compose PDF: \(error.localizedDescription)"
            completion(response)
        }
    }
    
    // MARK: - Parameter Validation
    
    func resolvePdfFiles(for intent: ComposePDFIntent, with completion: @escaping ([INFileResolutionResult]) -> Void) {
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
    
    func resolveCoverImage(for intent: ComposePDFIntent, with completion: @escaping (INFileResolutionResult) -> Void) {
        guard let coverImage = intent.coverImage else {
            completion(INFileResolutionResult.notRequired())
            return
        }
        
        guard let fileURL = coverImage.fileURL else {
            completion(INFileResolutionResult.needsValue())
            return
        }
        
        let supportedExtensions = ["png", "jpg", "jpeg", "tiff", "tif", "gif", "bmp", "webp"]
        let fileExtension = fileURL.pathExtension.lowercased()
        
        if supportedExtensions.contains(fileExtension) {
            completion(INFileResolutionResult.success(with: coverImage))
        } else {
            completion(INFileResolutionResult.unsupported(forReason: .invalidFormat))
        }
    }
    
    func resolveCoverPlacement(for intent: ComposePDFIntent, with completion: @escaping (CoverPlacementResolutionResult) -> Void) {
        if let coverPlacement = intent.coverPlacement {
            completion(CoverPlacementResolutionResult.success(with: coverPlacement))
        } else {
            // Default to center placement
            completion(CoverPlacementResolutionResult.success(with: .center))
        }
    }
    
    func resolveOutputFileName(for intent: ComposePDFIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let fileName = intent.outputFileName, !fileName.isEmpty {
            completion(INStringResolutionResult.success(with: fileName))
        } else {
            let defaultName = generateDefaultFileName()
            completion(INStringResolutionResult.success(with: defaultName))
        }
    }
    
    // MARK: - Helper Methods
    
    private func mapCoverPlacement(from intentPlacement: CoverPlacement?) -> PDF.CoverPlacement {
        switch intentPlacement {
        case .topLeft:
            return .topLeft
        case .top:
            return .top
        case .topRight:
            return .topRight
        case .left:
            return .left
        case .center, .none:
            return .center
        case .right:
            return .right
        case .bottomLeft:
            return .bottomLeft
        case .bottom:
            return .bottom
        case .bottomRight:
            return .bottomRight
        @unknown default:
            return .center
        }
    }
    
    private func generateDefaultFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Composed_PDF_\(formatter.string(from: Date())).pdf"
    }
    
    private func createOutputURL(fileName: String) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var outputURL = documentsURL.appendingPathComponent(fileName)
        
        // Ensure .pdf extension
        if outputURL.pathExtension.lowercased() != "pdf" {
            outputURL = outputURL.appendingPathExtension("pdf")
        }
        
        // Handle duplicate names
        var counter = 1
        let baseURL = outputURL
        while FileManager.default.fileExists(atPath: outputURL.path) {
            let nameWithoutExtension = baseURL.deletingPathExtension().lastPathComponent
            let newName = "\(nameWithoutExtension)_\(counter).pdf"
            outputURL = baseURL.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }
        
        return outputURL
    }
    
    // MARK: - Confirmation
    
    func confirm(intent: ComposePDFIntent, completion: @escaping (ComposePDFIntentResponse) -> Void) {
        guard let pdfFiles = intent.pdfFiles, !pdfFiles.isEmpty else {
            let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "No PDF files provided"
            completion(response)
            return
        }
        
        // Perform basic validation
        var totalPageCount = 0
        for file in pdfFiles {
            guard let fileURL = file.fileURL, fileURL.pathExtension.lowercased() == "pdf" else {
                let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
                response.errorMessage = "One or more files are not valid PDF files"
                completion(response)
                return
            }
            
            // Quick page count estimation (this is an approximation)
            if let pdfDoc = PDFDocument(url: fileURL) {
                totalPageCount += pdfDoc.pageCount
            }
        }
        
        // Check if total page count is reasonable
        if totalPageCount > Composer.maxPageCount {
            let response = ComposePDFIntentResponse(code: .failure, userActivity: nil)
            response.errorMessage = "Total page count (\(totalPageCount)) exceeds the maximum limit of \(Composer.maxPageCount)"
            completion(response)
            return
        }
        
        // All validations passed
        let response = ComposePDFIntentResponse(code: .ready, userActivity: nil)
        completion(response)
    }
}