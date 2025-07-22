import Foundation
import PDFKit
import AppKit
import Darwin

// MARK: - Batch Processing Models
struct BatchJob: Identifiable, Codable {
    let id = UUID()
    let inputURL: URL
    let outputURL: URL
    let processingOptions: BatchProcessingOptions
    var status: BatchJobStatus = .pending
    var progress: Double = 0.0
    var error: String?
    var startTime: Date?
    var endTime: Date?
    var outputFileSize: Int64?
    
    var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
}

enum BatchJobStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

struct BatchProcessingOptions: Codable {
    var outputFormat: ExportFormat = .pdf
    var compressionQuality: Double = 0.9
    var downsampleImages: Bool = true
    var maxImageDPI: Double = 300
    var stripMetadata: Bool = true
    var optimizeForWeb: Bool = false
    var addWatermark: Bool = false
    var watermarkText: String = ""
}

struct BatchProcessingResult: Identifiable {
    let id = UUID()
    let totalJobs: Int
    let completedJobs: Int
    let failedJobs: Int
    let cancelledJobs: Int
    let totalProcessingTime: TimeInterval
    let totalInputSize: Int64
    let totalOutputSize: Int64
    let jobs: [BatchJob]
    
    var successRate: Double {
        guard totalJobs > 0 else { return 0.0 }
        return Double(completedJobs) / Double(totalJobs)
    }
    
    var averageCompressionRatio: Double {
        guard totalInputSize > 0 else { return 1.0 }
        return Double(totalOutputSize) / Double(totalInputSize)
    }
}

// MARK: - Batch Processing Errors
enum BatchProcessingError: LocalizedError, Equatable {
    case invalidInputFile(url: URL, reason: String)
    case outputDirectoryNotWritable(url: URL)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case memoryLimitExceeded
    case operationCancelled
    case concurrencyLimitExceeded(limit: Int)
    case processingFailed(url: URL, underlyingError: String)
    case batchSizeTooLarge(size: Int, limit: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidInputFile(let url, let reason):
            return "Invalid input file '\(url.lastPathComponent)': \(reason)"
        case .outputDirectoryNotWritable(let url):
            return "Cannot write to output directory: \(url.path)"
        case .insufficientDiskSpace(let required, let available):
            return "Insufficient disk space. Required: \(ByteCountFormatter.string(fromByteCount: required, countStyle: .file)), Available: \(ByteCountFormatter.string(fromByteCount: available, countStyle: .file))"
        case .memoryLimitExceeded:
            return "Processing cancelled due to memory constraints"
        case .operationCancelled:
            return "Batch processing operation was cancelled"
        case .concurrencyLimitExceeded(let limit):
            return "Too many concurrent operations. Limit: \(limit)"
        case .processingFailed(let url, let error):
            return "Failed to process '\(url.lastPathComponent)': \(error)"
        case .batchSizeTooLarge(let size, let limit):
            return "Batch size (\(size)) exceeds limit (\(limit))"
        }
    }
}

// MARK: - Batch Processor Actor
actor BatchProcessor {
    // MARK: - Configuration
    private let maxConcurrentJobs = 4 // Prevent resource exhaustion
    private let maxBatchSize = 100 // Maximum files per batch
    private let memoryWarningThreshold: Int64 = 1_000_000_000 // 1GB
    private let minDiskSpaceRequired: Int64 = 100_000_000 // 100MB
    
    // MARK: - Dependencies
    private let pdfService: PDFService
    private let fileManager = FileManager.default
    
    // MARK: - State
    private var activeBatches: [UUID: BatchProcessingSession] = [:]
    private var memoryMonitor = MemoryMonitor()
    
    // MARK: - Initialization
    init(pdfService: PDFService) {
        self.pdfService = pdfService
    }
    
    // MARK: - Public Interface
    func processBatch(
        inputURLs: [URL],
        outputDirectory: URL,
        options: BatchProcessingOptions = BatchProcessingOptions()
    ) -> AsyncThrowingStream<BatchProcessingUpdate, Error> {
        return AsyncThrowingStream { continuation in
            let sessionId = UUID()
            
            Task { [weak self] in
                do {
                    guard let self = self else {
                        continuation.finish(throwing: BatchProcessingError.operationCancelled)
                        return
                    }
                    
                    // Validate batch
                    try await self.validateBatch(inputURLs: inputURLs, outputDirectory: outputDirectory, options: options)
                    
                    // Create batch session
                    let session = BatchProcessingSession(
                        id: sessionId,
                        inputURLs: inputURLs,
                        outputDirectory: outputDirectory,
                        options: options,
                        continuation: continuation
                    )
                    
                    self.activeBatches[sessionId] = session
                    
                    // Process batch
                    await self.processSession(session)
                    
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func cancelBatch(sessionId: UUID) async {
        guard let session = activeBatches[sessionId] else { return }
        
        await session.cancel()
        activeBatches.removeValue(forKey: sessionId)
    }
    
    func getActiveSessionIds() async -> [UUID] {
        return Array(activeBatches.keys)
    }
    
    // MARK: - Batch Validation
    private func validateBatch(
        inputURLs: [URL],
        outputDirectory: URL,
        options: BatchProcessingOptions
    ) throws {
        // Check batch size
        guard inputURLs.count <= maxBatchSize else {
            throw BatchProcessingError.batchSizeTooLarge(size: inputURLs.count, limit: maxBatchSize)
        }
        
        // Validate input files
        for url in inputURLs {
            guard fileManager.fileExists(atPath: url.path) else {
                throw BatchProcessingError.invalidInputFile(url: url, reason: "File does not exist")
            }
            
            guard url.pathExtension.lowercased() == "pdf" else {
                throw BatchProcessingError.invalidInputFile(url: url, reason: "Not a PDF file")
            }
        }
        
        // Check output directory
        guard fileManager.fileExists(atPath: outputDirectory.path) else {
            throw BatchProcessingError.outputDirectoryNotWritable(url: outputDirectory)
        }
        
        // Check disk space
        let totalInputSize = try estimateInputSize(urls: inputURLs)
        let availableSpace = try getAvailableDiskSpace(at: outputDirectory)
        let estimatedOutputSize = Int64(Double(totalInputSize) * 1.2) // 20% buffer
        
        guard availableSpace >= estimatedOutputSize + minDiskSpaceRequired else {
            throw BatchProcessingError.insufficientDiskSpace(
                required: estimatedOutputSize + minDiskSpaceRequired,
                available: availableSpace
            )
        }
    }
    
    // MARK: - Batch Processing
    private func processSession(_ session: BatchProcessingSession) async {
        let startTime = Date()
        var jobs: [BatchJob] = []
        
        // Create jobs
        for (index, inputURL) in session.inputURLs.enumerated() {
            let outputFileName = generateOutputFileName(
                inputURL: inputURL,
                index: index,
                options: session.options
            )
            let outputURL = session.outputDirectory.appendingPathComponent(outputFileName)
            
            let job = BatchJob(
                inputURL: inputURL,
                outputURL: outputURL,
                processingOptions: session.options
            )
            jobs.append(job)
        }
        
        // Send initial update
        let initialUpdate = BatchProcessingUpdate(
            sessionId: session.id,
            overallProgress: 0.0,
            currentJob: nil,
            completedJobs: [],
            failedJobs: [],
            status: .processing
        )
        session.sendUpdate(initialUpdate)
        
        // Process jobs with concurrency control
        await withTaskGroup(of: BatchJob.self) { group in
            var pendingJobs = jobs
            var processingJobs: [BatchJob] = []
            var completedJobs: [BatchJob] = []
            var failedJobs: [BatchJob] = []
            
            // Start initial batch of concurrent jobs
            while processingJobs.count < maxConcurrentJobs && !pendingJobs.isEmpty {
                let job = pendingJobs.removeFirst()
                processingJobs.append(job)
                
                group.addTask { [weak self] in
                    await self?.processJob(job, session: session) ?? job
                }
            }
            
            // Process remaining jobs as others complete
            for await completedJob in group {
                // Remove from processing
                if let index = processingJobs.firstIndex(where: { $0.id == completedJob.id }) {
                    processingJobs.remove(at: index)
                }
                
                // Categorize result
                switch completedJob.status {
                case .completed:
                    completedJobs.append(completedJob)
                case .failed, .cancelled:
                    failedJobs.append(completedJob)
                default:
                    break
                }
                
                // Send progress update
                let totalJobs = jobs.count
                let processedJobs = completedJobs.count + failedJobs.count
                let overallProgress = Double(processedJobs) / Double(totalJobs)
                
                let update = BatchProcessingUpdate(
                    sessionId: session.id,
                    overallProgress: overallProgress,
                    currentJob: processingJobs.first,
                    completedJobs: completedJobs,
                    failedJobs: failedJobs,
                    status: .processing
                )
                session.sendUpdate(update)
                
                // Start next job if available
                if !pendingJobs.isEmpty {
                    let nextJob = pendingJobs.removeFirst()
                    processingJobs.append(nextJob)
                    
                    group.addTask { [weak self] in
                        await self?.processJob(nextJob, session: session) ?? nextJob
                    }
                }
            }
            
            // Send final result
            let endTime = Date()
            let result = BatchProcessingResult(
                totalJobs: jobs.count,
                completedJobs: completedJobs.count,
                failedJobs: failedJobs.count,
                cancelledJobs: jobs.filter { $0.status == .cancelled }.count,
                totalProcessingTime: endTime.timeIntervalSince(startTime),
                totalInputSize: try? estimateInputSize(urls: session.inputURLs) ?? 0,
                totalOutputSize: calculateOutputSize(jobs: completedJobs),
                jobs: completedJobs + failedJobs
            )
            
            let finalUpdate = BatchProcessingUpdate(
                sessionId: session.id,
                overallProgress: 1.0,
                currentJob: nil,
                completedJobs: completedJobs,
                failedJobs: failedJobs,
                status: .completed,
                result: result
            )
            session.sendUpdate(finalUpdate)
            session.finish()
        }
        
        // Clean up session
        activeBatches.removeValue(forKey: session.id)
    }
    
    // MARK: - Job Processing
    private func processJob(_ job: BatchJob, session: BatchProcessingSession) async -> BatchJob {
        var updatedJob = job
        updatedJob.status = .processing
        updatedJob.startTime = Date()
        
        do {
            // Check for cancellation
            try Task.checkCancellation()
            
            // Monitor memory usage
            if await memoryMonitor.getCurrentUsage() > memoryWarningThreshold {
                // Wait for memory to be available or cancel
                try await memoryMonitor.waitForMemoryAvailable(threshold: memoryWarningThreshold)
            }
            
            updatedJob.progress = 0.1
            
            // Load PDF document
            let document = try await pdfService.open(url: job.inputURL)
            
            updatedJob.progress = 0.3
            try Task.checkCancellation()
            
            // Apply processing options
            let processedDocument = try await applyProcessingOptions(
                document: document,
                options: job.processingOptions,
                progressCallback: { progress in
                    Task {
                        updatedJob.progress = 0.3 + (progress * 0.6)
                    }
                }
            )
            
            updatedJob.progress = 0.9
            try Task.checkCancellation()
            
            // Export document
            try await exportDocument(
                processedDocument,
                to: job.outputURL,
                format: job.processingOptions.outputFormat,
                quality: job.processingOptions.compressionQuality
            )
            
            // Calculate output file size
            if let attributes = try? fileManager.attributesOfItem(atPath: job.outputURL.path),
               let fileSize = attributes[.size] as? Int64 {
                updatedJob.outputFileSize = fileSize
            }
            
            updatedJob.progress = 1.0
            updatedJob.status = .completed
            updatedJob.endTime = Date()
            
        } catch is CancellationError {
            updatedJob.status = .cancelled
            updatedJob.error = "Processing was cancelled"
            updatedJob.endTime = Date()
        } catch {
            updatedJob.status = .failed
            updatedJob.error = error.localizedDescription
            updatedJob.endTime = Date()
        }
        
        return updatedJob
    }
    
    // MARK: - Processing Options
    private func applyProcessingOptions(
        document: PDFDocument,
        options: BatchProcessingOptions,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> PDFDocument {
        let processedDocument = PDFDocument()
        let pageCount = document.pageCount
        
        for i in 0..<pageCount {
            try Task.checkCancellation()
            
            guard let page = document.page(at: i) else { continue }
            
            var processedPage = page
            
            // Apply downsampling if enabled
            if options.downsampleImages {
                processedPage = try await downsamplePageImages(page, maxDPI: options.maxImageDPI)
            }
            
            // Strip metadata if enabled
            if options.stripMetadata {
                processedPage = stripPageMetadata(processedPage)
            }
            
            processedDocument.insert(processedPage, at: i)
            
            // Update progress
            let progress = Double(i + 1) / Double(pageCount)
            progressCallback(progress)
        }
        
        return processedDocument
    }
    
    // MARK: - Helper Methods
    private func generateOutputFileName(inputURL: URL, index: Int, options: BatchProcessingOptions) -> String {
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = options.outputFormat.rawValue.lowercased()
        return "\(baseName)_processed_\(timestamp)_\(index).\(fileExtension)"
    }
    
    private func estimateInputSize(urls: [URL]) throws -> Int64 {
        var totalSize: Int64 = 0
        for url in urls {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                totalSize += fileSize
            }
        }
        return totalSize
    }
    
    private func getAvailableDiskSpace(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfFileSystem(forPath: url.path)
        return attributes[.systemFreeSize] as? Int64 ?? 0
    }
    
    private func calculateOutputSize(jobs: [BatchJob]) -> Int64 {
        return jobs.compactMap { $0.outputFileSize }.reduce(0, +)
    }
    
    private func exportDocument(_ document: PDFDocument, to url: URL, format: ExportFormat, quality: Double) async throws {
        try await pdfService.export(document: document, format: format, url: url, quality: CGFloat(quality))
    }
    
    private func downsamplePageImages(_ page: PDFPage, maxDPI: Double) async throws -> PDFPage {
        // This is a simplified implementation - in a real app, you'd implement proper image downsampling
        return page
    }
    
    private func stripPageMetadata(_ page: PDFPage) -> PDFPage {
        // This is a simplified implementation - in a real app, you'd implement proper metadata stripping
        return page
    }
}

// MARK: - Supporting Classes
private class BatchProcessingSession {
    let id: UUID
    let inputURLs: [URL]
    let outputDirectory: URL
    let options: BatchProcessingOptions
    private let continuation: AsyncThrowingStream<BatchProcessingUpdate, Error>.Continuation
    private var isCancelled = false
    
    init(
        id: UUID,
        inputURLs: [URL],
        outputDirectory: URL,
        options: BatchProcessingOptions,
        continuation: AsyncThrowingStream<BatchProcessingUpdate, Error>.Continuation
    ) {
        self.id = id
        self.inputURLs = inputURLs
        self.outputDirectory = outputDirectory
        self.options = options
        self.continuation = continuation
    }
    
    func sendUpdate(_ update: BatchProcessingUpdate) {
        guard !isCancelled else { return }
        continuation.yield(update)
    }
    
    func cancel() {
        isCancelled = true
        continuation.finish(throwing: BatchProcessingError.operationCancelled)
    }
    
    func finish() {
        guard !isCancelled else { return }
        continuation.finish()
    }
}

struct BatchProcessingUpdate {
    let sessionId: UUID
    let overallProgress: Double
    let currentJob: BatchJob?
    let completedJobs: [BatchJob]
    let failedJobs: [BatchJob]
    let status: BatchProcessingStatus
    let result: BatchProcessingResult?
    
    init(
        sessionId: UUID,
        overallProgress: Double,
        currentJob: BatchJob?,
        completedJobs: [BatchJob],
        failedJobs: [BatchJob],
        status: BatchProcessingStatus,
        result: BatchProcessingResult? = nil
    ) {
        self.sessionId = sessionId
        self.overallProgress = overallProgress
        self.currentJob = currentJob
        self.completedJobs = completedJobs
        self.failedJobs = failedJobs
        self.status = status
        self.result = result
    }
}

enum BatchProcessingStatus {
    case idle
    case processing
    case completed
    case cancelled
    case failed
}

// MARK: - Memory Monitor
private actor MemoryMonitor {
    private let checkInterval: TimeInterval = 1.0
    
    func getCurrentUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    func waitForMemoryAvailable(threshold: Int64, timeout: TimeInterval = 30.0) async throws {
        let startTime = Date()
        
        while getCurrentUsage() > threshold {
            try Task.checkCancellation()
            
            if Date().timeIntervalSince(startTime) > timeout {
                throw BatchProcessingError.memoryLimitExceeded
            }
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
    }
}