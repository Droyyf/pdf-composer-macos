import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: - Batch Processing View Model
@MainActor
class BatchProcessingViewModel: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var outputDirectory: URL?
    @Published var processingOptions = BatchProcessingOptions()
    @Published var isProcessing = false
    @Published var currentSession: UUID?
    @Published var overallProgress: Double = 0.0
    @Published var currentJob: BatchJob?
    @Published var completedJobs: [BatchJob] = []
    @Published var failedJobs: [BatchJob] = []
    @Published var processingResult: BatchProcessingResult?
    @Published var errorMessage: String?
    @Published var showFileImporter = false
    @Published var showDirectoryPicker = false
    
    private var batchProcessor: BatchProcessor?
    private var processingTask: Task<Void, Never>?
    
    init(pdfService: PDFService) {
        self.batchProcessor = BatchProcessor(pdfService: pdfService)
    }
    
    func addFiles(_ urls: [URL]) {
        // Filter for PDF files and avoid duplicates
        let pdfUrls = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        let uniqueUrls = pdfUrls.filter { newUrl in
            !selectedFiles.contains { existingUrl in
                existingUrl.path == newUrl.path
            }
        }
        
        selectedFiles.append(contentsOf: uniqueUrls)
    }
    
    func removeFile(at index: Int) {
        guard index < selectedFiles.count else { return }
        selectedFiles.remove(at: index)
    }
    
    func clearFiles() {
        selectedFiles.removeAll()
    }
    
    func setOutputDirectory(_ url: URL) {
        outputDirectory = url
    }
    
    func startBatchProcessing() {
        guard let batchProcessor = batchProcessor,
              let outputDirectory = outputDirectory,
              !selectedFiles.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        currentSession = UUID()
        overallProgress = 0.0
        completedJobs.removeAll()
        failedJobs.removeAll()
        processingResult = nil
        
        processingTask = Task { [weak self] in
            do {
                let stream = batchProcessor.processBatch(
                    inputURLs: selectedFiles,
                    outputDirectory: outputDirectory,
                    options: processingOptions
                )
                
                for try await update in stream {
                    await MainActor.run { [weak self] in
                        self?.handleProcessingUpdate(update)
                    }
                }
                
            } catch {
                await MainActor.run { [weak self] in
                    self?.handleProcessingError(error)
                }
            }
        }
    }
    
    func cancelProcessing() {
        guard let sessionId = currentSession,
              let batchProcessor = batchProcessor else { return }
        
        processingTask?.cancel()
        
        Task {
            await batchProcessor.cancelBatch(sessionId: sessionId)
            await MainActor.run { [weak self] in
                self?.resetProcessingState()
            }
        }
    }
    
    private func handleProcessingUpdate(_ update: BatchProcessingUpdate) {
        overallProgress = update.overallProgress
        currentJob = update.currentJob
        completedJobs = update.completedJobs
        failedJobs = update.failedJobs
        
        if let result = update.result {
            processingResult = result
            resetProcessingState()
        }
    }
    
    private func handleProcessingError(_ error: Error) {
        errorMessage = error.localizedDescription
        resetProcessingState()
    }
    
    private func resetProcessingState() {
        isProcessing = false
        currentSession = nil
        overallProgress = 0.0
        currentJob = nil
    }
}

// MARK: - Main Batch Processing View
struct BatchProcessingView: View {
    @StateObject private var viewModel: BatchProcessingViewModel
    @State private var showToast = false
    @State private var toastMessage = ""
    
    init(pdfService: PDFService) {
        self._viewModel = StateObject(wrappedValue: BatchProcessingViewModel(pdfService: pdfService))
    }
    
    var body: some View {
        ZStack {
            // Black background with grain texture
            Color.black
                .ignoresSafeArea()
                .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
            
            VStack(spacing: 0) {
                // Header
                brutalistHeader
                
                // Main content
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 24) {
                            if viewModel.isProcessing {
                                processingInterface
                            } else if let result = viewModel.processingResult {
                                resultsInterface(result: result)
                            } else {
                                setupInterface
                            }
                        }
                        .padding(24)
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
            
            // Toast notifications
            if showToast {
                toastOverlay
            }
        }
        .fileImporter(
            isPresented: $viewModel.showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .fileImporter(
            isPresented: $viewModel.showDirectoryPicker,
            allowedContentTypes: [UTType.folder],
            allowsMultipleSelection: false
        ) { result in
            handleDirectorySelection(result)
        }
    }
    
    // MARK: - Header
    private var brutalistHeader: some View {
        VStack(spacing: 0) {
            HStack {
                // Title
                BrutalistHeading(
                    text: "BATCH PROCESSOR",
                    size: 24,
                    color: Color(DesignTokens.brutalistPrimary),
                    tracking: 1.5,
                    addStroke: true
                )
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isProcessing ? Color.green : Color(DesignTokens.brutalistPrimary))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: viewModel.isProcessing)
                    
                    Text(viewModel.isProcessing ? "PROCESSING" : "READY")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Color.black.opacity(0.8)
                    .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
            )
            
            // Technical info bar
            HStack {
                BrutalistTechnicalText(
                    text: "FILES: \(viewModel.selectedFiles.count)",
                    color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                    size: 10
                )
                
                Spacer()
                
                if viewModel.isProcessing {
                    BrutalistCaption(
                        text: "\(Int(viewModel.overallProgress * 100))% COMPLETE",
                        prefix: "◆",
                        color: Color.green.opacity(0.8),
                        size: 10
                    )
                }
                
                Spacer()
                
                BrutalistTechnicalText(
                    text: "OUTPUT: \(viewModel.outputDirectory?.lastPathComponent ?? "NOT SET")",
                    color: Color(DesignTokens.brutalistPrimary).opacity(0.7),
                    size: 10
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
        }
    }
    
    // MARK: - Setup Interface
    private var setupInterface: some View {
        VStack(spacing: 32) {
            // File selection section
            fileSelectionSection
            
            // Output directory section
            outputDirectorySection
            
            // Processing options section
            processingOptionsSection
            
            // Action buttons
            actionButtons
        }
    }
    
    private var fileSelectionSection: some View {
        VStack(spacing: 16) {
            HStack {
                BrutalistTechnicalText(
                    text: "INPUT FILES",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 14,
                    addDecorators: true
                )
                Spacer()
            }
            
            if viewModel.selectedFiles.isEmpty {
                // Empty state
                Button {
                    viewModel.showFileImporter = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        
                        BrutalistHeading(
                            text: "SELECT PDF FILES",
                            size: 20,
                            color: Color(DesignTokens.brutalistPrimary),
                            addStroke: false
                        )
                        
                        Text("Drag files here or click to browse")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 2, antialiased: true)
                            .background(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .fill(Color.black.opacity(0.3))
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
            } else {
                // File list
                VStack(spacing: 8) {
                    // List header with controls
                    HStack {
                        Text("\(viewModel.selectedFiles.count) FILES SELECTED")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        
                        Spacer()
                        
                        Button("ADD MORE") {
                            viewModel.showFileImporter = true
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                        )
                        
                        Button("CLEAR ALL") {
                            viewModel.clearFiles()
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.red.opacity(0.5), lineWidth: 1)
                        )
                    }
                    
                    // File list
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.selectedFiles.enumerated()), id: \.offset) { index, url in
                            FileRowView(
                                url: url,
                                index: index + 1,
                                onRemove: {
                                    viewModel.removeFile(at: index)
                                }
                            )
                        }
                    }
                    .padding(8)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }
    
    private var outputDirectorySection: some View {
        VStack(spacing: 16) {
            HStack {
                BrutalistTechnicalText(
                    text: "OUTPUT DIRECTORY",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 14,
                    addDecorators: true
                )
                Spacer()
            }
            
            Button {
                viewModel.showDirectoryPicker = true
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.outputDirectory?.lastPathComponent ?? "SELECT OUTPUT FOLDER")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        if let outputDirectory = viewModel.outputDirectory {
                            Text(outputDirectory.path)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(DesignTokens.brutalistPrimary))
                }
                .padding(16)
                .background(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var processingOptionsSection: some View {
        VStack(spacing: 16) {
            HStack {
                BrutalistTechnicalText(
                    text: "PROCESSING OPTIONS",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 14,
                    addDecorators: true
                )
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Output format
                OptionRowView(
                    label: "OUTPUT FORMAT",
                    value: viewModel.processingOptions.outputFormat.rawValue
                ) {
                    // Format selector (simplified for now)
                    EmptyView()
                }
                
                // Quality slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("COMPRESSION QUALITY")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.processingOptions.compressionQuality * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(DesignTokens.brutalistPrimary))
                    }
                    
                    Slider(value: $viewModel.processingOptions.compressionQuality, in: 0.1...1.0)
                        .tint(Color(DesignTokens.brutalistPrimary))
                }
                
                // Toggle options
                ToggleOptionView(
                    label: "DOWNSAMPLE IMAGES",
                    isOn: $viewModel.processingOptions.downsampleImages
                )
                
                ToggleOptionView(
                    label: "STRIP METADATA",
                    isOn: $viewModel.processingOptions.stripMetadata
                )
                
                ToggleOptionView(
                    label: "OPTIMIZE FOR WEB",
                    isOn: $viewModel.processingOptions.optimizeForWeb
                )
            }
            .padding(16)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button {
                // Reset to setup
                viewModel.processingResult = nil
                viewModel.errorMessage = nil
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                    
                    Text("RESET")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                        .background(
                            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                .fill(Color.black.opacity(0.4))
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button {
                viewModel.startBatchProcessing()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                    
                    Text("START PROCESSING")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.black)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .fill(Color(DesignTokens.brutalistPrimary))
                        .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.selectedFiles.isEmpty || viewModel.outputDirectory == nil)
            .opacity(viewModel.selectedFiles.isEmpty || viewModel.outputDirectory == nil ? 0.5 : 1.0)
        }
    }
    
    // MARK: - Processing Interface
    private var processingInterface: some View {
        VStack(spacing: 24) {
            // Overall progress
            overallProgressSection
            
            // Current job
            if let currentJob = viewModel.currentJob {
                currentJobSection(job: currentJob)
            }
            
            // Job lists
            jobListsSection
            
            // Cancel button
            Button {
                viewModel.cancelProcessing()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                    
                    Text("CANCEL PROCESSING")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .fill(.red.opacity(0.8))
                        .brutalistTexture(style: .grain, intensity: 0.2, color: .white)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var overallProgressSection: some View {
        VStack(spacing: 12) {
            HStack {
                BrutalistTechnicalText(
                    text: "OVERALL PROGRESS",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 14,
                    addDecorators: true
                )
                
                Spacer()
                
                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(DesignTokens.brutalistPrimary))
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 24)
                
                Rectangle()
                    .fill(Color(DesignTokens.brutalistPrimary))
                    .frame(width: CGFloat(viewModel.overallProgress) * 300, height: 24)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.overallProgress)
            }
            .frame(width: 300)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.7), lineWidth: 2)
            )
        }
        .padding(20)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.6))
                .brutalistTexture(style: .noise, intensity: 0.2, color: .white)
        )
    }
    
    private func currentJobSection(job: BatchJob) -> some View {
        VStack(spacing: 12) {
            HStack {
                BrutalistTechnicalText(
                    text: "CURRENT JOB",
                    color: Color.green,
                    size: 12,
                    addDecorators: true
                )
                
                Spacer()
                
                Text("\(Int(job.progress * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.green)
            }
            
            HStack {
                Text(job.inputURL.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            
            // Individual progress bar
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 8)
                
                Rectangle()
                    .fill(Color.green)
                    .frame(width: CGFloat(job.progress) * 200, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: job.progress)
            }
            .frame(width: 200)
            .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .padding(16)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var jobListsSection: some View {
        HStack(spacing: 16) {
            // Completed jobs
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("COMPLETED (\(viewModel.completedJobs.count))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.completedJobs) { job in
                            JobRowView(job: job, statusColor: .green)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding(12)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Failed jobs
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text("FAILED (\(viewModel.failedJobs.count))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.failedJobs) { job in
                            JobRowView(job: job, statusColor: .red)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding(12)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Results Interface
    private func resultsInterface(result: BatchProcessingResult) -> some View {
        VStack(spacing: 24) {
            // Results summary
            resultsSummarySection(result: result)
            
            // Detailed results
            detailedResultsSection(result: result)
            
            // Action buttons
            HStack(spacing: 16) {
                Button {
                    // Open output directory
                    if let outputDirectory = viewModel.outputDirectory {
                        NSWorkspace.shared.open(outputDirectory)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 14, weight: .bold))
                        
                        Text("OPEN OUTPUT FOLDER")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                            .background(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .fill(Color.black.opacity(0.4))
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button {
                    // Start new batch
                    viewModel.processingResult = nil
                    viewModel.clearFiles()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        
                        Text("NEW BATCH")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .fill(Color(DesignTokens.brutalistPrimary))
                            .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func resultsSummarySection(result: BatchProcessingResult) -> some View {
        VStack(spacing: 16) {
            BrutalistHeading(
                text: "BATCH COMPLETE",
                size: 28,
                color: result.failedJobs > 0 ? .orange : Color.green,
                addStroke: true
            )
            
            HStack(spacing: 32) {
                StatCardView(
                    title: "SUCCESS RATE",
                    value: "\(Int(result.successRate * 100))%",
                    color: result.successRate > 0.8 ? .green : .orange
                )
                
                StatCardView(
                    title: "COMPLETED",
                    value: "\(result.completedJobs)",
                    color: .green
                )
                
                StatCardView(
                    title: "FAILED",
                    value: "\(result.failedJobs)",
                    color: .red
                )
                
                StatCardView(
                    title: "TIME",
                    value: formatDuration(result.totalProcessingTime),
                    color: Color(DesignTokens.brutalistPrimary)
                )
            }
        }
        .padding(24)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.6))
                .brutalistTexture(style: .grain, intensity: 0.3, color: .white)
        )
    }
    
    private func detailedResultsSection(result: BatchProcessingResult) -> some View {
        VStack(spacing: 16) {
            HStack {
                BrutalistTechnicalText(
                    text: "DETAILED RESULTS",
                    color: Color(DesignTokens.brutalistPrimary),
                    size: 14,
                    addDecorators: true
                )
                Spacer()
            }
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(result.jobs) { job in
                        DetailedJobRowView(job: job)
                    }
                }
            }
            .frame(maxHeight: 400)
            .padding(12)
            .background(
                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                    .fill(Color.black.opacity(0.4))
                    .overlay(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Toast Overlay
    private var toastOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Text(toastMessage)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                            .fill(Color.black.opacity(0.9))
                            .overlay(
                                UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                                    .strokeBorder(Color(DesignTokens.brutalistPrimary).opacity(0.5), lineWidth: 1)
                            )
                    )
            }
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showToast = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            viewModel.addFiles(urls)
            showToastMessage("Added \(urls.count) files")
        case .failure(let error):
            showToastMessage("Error: \(error.localizedDescription)")
        }
    }
    
    private func handleDirectorySelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                viewModel.setOutputDirectory(url)
                showToastMessage("Output directory set")
            }
        case .failure(let error):
            showToastMessage("Error: \(error.localizedDescription)")
        }
    }
    
    private func showToastMessage(_ message: String) {
        withAnimation {
            toastMessage = message
            showToast = true
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views
struct FileRowView: View {
    let url: URL
    let index: Int
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(String(format: "%02d", index))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(DesignTokens.brutalistPrimary))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(url.deletingLastPathComponent().path)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.3))
        )
    }
}

struct OptionRowView<Content: View>: View {
    let label: String
    let value: String
    let content: () -> Content
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(DesignTokens.brutalistPrimary))
            
            content()
        }
    }
}

struct ToggleOptionView: View {
    let label: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color(DesignTokens.brutalistPrimary)))
                .scaleEffect(0.8)
        }
    }
}

struct JobRowView: View {
    let job: BatchJob
    let statusColor: Color
    
    var body: some View {
        HStack {
            Text(job.inputURL.lastPathComponent)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            if let duration = job.duration {
                Text(String(format: "%.1fs", duration))
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundColor(statusColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(statusColor.opacity(0.1))
        )
    }
}

struct DetailedJobRowView: View {
    let job: BatchJob
    
    private var statusColor: Color {
        switch job.status {
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(job.inputURL.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Text(job.status.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
            }
            
            if let error = job.error {
                Text(error)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundColor(.red.opacity(0.8))
                    .lineLimit(2)
            } else if let duration = job.duration {
                HStack {
                    Text("Duration: \(String(format: "%.2fs", duration))")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    if let outputSize = job.outputFileSize {
                        Text("Size: \(ByteCountFormatter.string(fromByteCount: outputSize, countStyle: .file))")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(16)
        .background(
            UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    UnevenRoundedRectangle(cornerRadii: DesignTokens.brutalCorners, style: .continuous)
                        .strokeBorder(color.opacity(0.5), lineWidth: 1)
                )
        )
    }
}