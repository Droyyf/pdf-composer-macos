import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct CardItem: Identifiable {
    var id = UUID()
    var imageName: String
    var title: String
    var action: () -> Void
}

// MARK: - Poster Configuration
struct PosterConfiguration {
    let subElements: [(String?, String?, String?)]
    let rightText: String
    let rightSymbols: [String]
    
    static let main = PosterConfiguration(
        subElements: [
            ("globe", "BCR.", nil),
            (nil, "—", nil),
            ("plus.circle.fill", "SPHERE", "sun.max.fill")
        ],
        rightText: "HATE VS LOVE.",
        rightSymbols: ["number.square", "globe.americas.fill", "cylinder.split.1x2.fill"]
    )
}

// MARK: - Layout Configuration
struct LayoutConfiguration {
    let titleFontSize: CGFloat
    let titleTracking: CGFloat
    let titleLineSpacing: CGFloat
    let subElementFontSize: CGFloat
    let rightTextFontSize: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let titleOffset: CGFloat
    
    static func responsive(for geometry: GeometryProxy) -> LayoutConfiguration {
        return LayoutConfiguration(
            titleFontSize: min(geometry.size.width * 0.35, geometry.size.height * 0.3),
            titleTracking: min(geometry.size.width * -0.02, -10),
            titleLineSpacing: min(geometry.size.width * -0.05, -20),
            subElementFontSize: min(geometry.size.width * 0.025, 18),
            rightTextFontSize: min(geometry.size.width * 0.065, 35),
            horizontalPadding: geometry.size.width * 0.05,
            verticalPadding: geometry.size.height * 0.02,
            titleOffset: geometry.size.height * 0.02
        )
    }
}

// MARK: - Main Menu View
struct MainMenuView: View {
    @ObservedObject var viewModel: AppShellViewModel
    @State private var showFileImporter = false
    @State private var animateLogo = false
    @State private var loadError: String? = nil
    @State private var showCloudPopover = false
    @StateObject private var cloudManager = CloudStorageManager.shared
    
    // Configuration
    private let posterConfig = PosterConfiguration.main

    var body: some View {
        GeometryReader { geo in
            let layout = LayoutConfiguration.responsive(for: geo)
            let responsiveLayout = DesignTokens.layoutConfiguration(for: geo)
            
            VStack(spacing: 0) {
                // Title area - 40% of height, styled like the "FIGHT" poster
                titleSection(layout: layout, responsiveLayout: responsiveLayout, geo: geo)
                    .frame(height: geo.size.height * 0.4)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Cards section - 60% of height
                cardsSection(layout: layout, responsiveLayout: responsiveLayout, geo: geo)
                    .frame(height: geo.size.height * 0.6)
                    .frame(maxWidth: .infinity)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            logDebug("MainMenuView appeared with FIGHT poster style")
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.pdf], allowsMultipleSelection: false, onCompletion: handleFileImportResult)
        .alert(item: Binding<IdentifiableString?>(
            get: { loadError.map { IdentifiableString(value: $0) } },
            set: { loadError = $0?.value }
        )) { errorAlert in
            Alert(
                title: Text("Unable to Load PDF"),
                message: Text(errorAlert.value),
                dismissButton: .default(Text("OK")) {
                    // Clear error state
                    loadError = nil
                }
            )
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func cloudSignInArea(layout: LayoutConfiguration, geo: GeometryProxy) -> some View {
        Button(action: {
            withAnimation(DesignTokens.cardTapAnimation) {
                showCloudPopover.toggle()
            }
        }) {
            HStack(spacing: max(geo.size.width * 0.008, 6)) {
                // Cloud status indicator
                ZStack {
                    // Brutalist background shape with asymmetric corners
                    UnevenRoundedRectangle(
                        cornerRadii: [
                            .topLeading: 2,
                            .bottomLeading: 0,
                            .bottomTrailing: 8,
                            .topTrailing: 0
                        ],
                        style: .continuous
                    )
                    .fill(DesignTokens.brutalistBlack.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: [
                                .topLeading: 2,
                                .bottomLeading: 0,
                                .bottomTrailing: 8,
                                .topTrailing: 0
                            ],
                            style: .continuous
                        )
                        .strokeBorder(DesignTokens.brutalistBlack.opacity(0.25), lineWidth: 1.5)
                    )
                    
                    // Cloud icon
                    Image(systemName: cloudManager.connectedAccounts.isEmpty ? "cloud" : "cloud.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignTokens.brutalistBlack.opacity(0.7))
                }
                
                // Connection status text with brutalist typography
                VStack(alignment: .leading, spacing: 0) {
                    Text(cloudConnectionStatusText)
                        .font(.custom("HelveticaNeue-Bold", size: max(layout.subElementFontSize * 0.7, 10)))
                        .tracking(0.5)
                        .foregroundColor(DesignTokens.brutalistBlack.opacity(0.8))
                        .lineLimit(1)
                    
                    if !cloudManager.connectedAccounts.isEmpty {
                        Text("\(cloudManager.connectedAccounts.count) connected")
                            .font(.custom("HelveticaNeue-Medium", size: max(layout.subElementFontSize * 0.6, 8)))
                            .tracking(0.3)
                            .foregroundColor(DesignTokens.brutalistBlack.opacity(0.6))
                            .lineLimit(1)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Cloud Storage")
        .accessibilityHint("Tap to manage cloud storage connections")
        .popover(isPresented: $showCloudPopover, arrowEdge: .bottom) {
            cloudSignInPopover()
        }
    }
    
    @ViewBuilder
    private func cloudSignInPopover() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with brutalist styling
            VStack(alignment: .leading, spacing: 8) {
                Text("CLOUD STORAGE")
                    .font(.custom("HelveticaNeue-Bold", size: 16))
                    .tracking(1.2)
                    .foregroundColor(DesignTokens.brutalistBlack)
                
                Text("Connect your cloud accounts")
                    .font(.custom("HelveticaNeue-Medium", size: 12))
                    .tracking(0.3)
                    .foregroundColor(DesignTokens.brutalistBlack.opacity(0.7))
            }
            
            Divider()
                .background(DesignTokens.brutalistBlack.opacity(0.2))
            
            // Provider list
            VStack(spacing: 12) {
                ForEach(CloudProvider.allCases, id: \.self) { provider in
                    cloudProviderRow(provider: provider)
                }
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(DesignTokens.brutalistPrimary.opacity(0.95))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(DesignTokens.brutalistBlack.opacity(0.15), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func cloudProviderRow(provider: CloudProvider) -> some View {
        let connectedAccount = cloudManager.accounts(for: provider).first
        let isConnected = connectedAccount != nil
        
        HStack(spacing: 12) {
            // Provider icon with brutalist styling
            ZStack {
                UnevenRoundedRectangle(
                    cornerRadii: [
                        .topLeading: 0,
                        .bottomLeading: 6,
                        .bottomTrailing: 0,
                        .topTrailing: 4
                    ],
                    style: .continuous
                )
                .fill(isConnected ? DesignTokens.brutalistBlack.opacity(0.15) : DesignTokens.brutalistBlack.opacity(0.08))
                .frame(width: 32, height: 32)
                .overlay(
                    UnevenRoundedRectangle(
                        cornerRadii: [
                            .topLeading: 0,
                            .bottomLeading: 6,
                            .bottomTrailing: 0,
                            .topTrailing: 4
                        ],
                        style: .continuous
                    )
                    .strokeBorder(DesignTokens.brutalistBlack.opacity(0.2), lineWidth: 1)
                )
                
                Image(systemName: provider.iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignTokens.brutalistBlack.opacity(0.8))
            }
            
            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(.custom("HelveticaNeue-Bold", size: 13))
                    .tracking(0.3)
                    .foregroundColor(DesignTokens.brutalistBlack)
                
                if let account = connectedAccount {
                    Text(account.email)
                        .font(.custom("HelveticaNeue-Medium", size: 11))
                        .tracking(0.2)
                        .foregroundColor(DesignTokens.brutalistBlack.opacity(0.6))
                        .lineLimit(1)
                } else {
                    Text("Not connected")
                        .font(.custom("HelveticaNeue-Medium", size: 11))
                        .tracking(0.2)
                        .foregroundColor(DesignTokens.brutalistBlack.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Action button
            Button(action: {
                Task {
                    if isConnected, let account = connectedAccount {
                        try? await cloudManager.signOut(account: account)
                    } else {
                        try? await cloudManager.authenticate(provider: provider)
                    }
                }
            }) {
                ZStack {
                    UnevenRoundedRectangle(
                        cornerRadii: [
                            .topLeading: 2,
                            .bottomLeading: 0,
                            .bottomTrailing: 6,
                            .topTrailing: 0
                        ],
                        style: .continuous
                    )
                    .fill(isConnected ? DesignTokens.brutalistBlack.opacity(0.15) : DesignTokens.brutalistBlack.opacity(0.1))
                    .frame(width: 60, height: 24)
                    .overlay(
                        UnevenRoundedRectangle(
                            cornerRadii: [
                                .topLeading: 2,
                                .bottomLeading: 0,
                                .bottomTrailing: 6,
                                .topTrailing: 0
                            ],
                            style: .continuous
                        )
                        .strokeBorder(DesignTokens.brutalistBlack.opacity(0.25), lineWidth: 1)
                    )
                    
                    Text(isConnected ? "SIGN OUT" : "CONNECT")
                        .font(.custom("HelveticaNeue-Bold", size: 9))
                        .tracking(0.8)
                        .foregroundColor(DesignTokens.brutalistBlack.opacity(0.8))
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(cloudManager.isAuthenticating)
        }
    }
    
    private var cloudConnectionStatusText: String {
        if cloudManager.isAuthenticating {
            return "CONNECTING..."
        } else if cloudManager.connectedAccounts.isEmpty {
            return "CLOUD"
        } else {
            return "CONNECTED"
        }
    }
    
    @ViewBuilder
    private func titleSection(layout: LayoutConfiguration, responsiveLayout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        ZStack(alignment: .bottomLeading) {
            DesignTokens.brutalistPrimary
                .edgesIgnoringSafeArea(.top)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                // Title row with cloud sign-in area
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PDF")
                            .font(.custom("Helvetica Black Original", size: layout.titleFontSize))
                            .tracking(layout.titleTracking)
                            .lineSpacing(layout.titleLineSpacing)
                            .foregroundColor(DesignTokens.brutalistBlack)
                            .accessibilityLabel("PDF Application")
                            .accessibilityAddTraits(.isHeader)
                    }
                    .padding(.leading, layout.horizontalPadding)
                    .offset(y: layout.titleOffset)
                    
                    Spacer()
                    
                    // Cloud sign-in area - positioned in upper right of title area
                    cloudSignInArea(layout: layout, geo: geo)
                        .padding(.trailing, layout.horizontalPadding)
                        .padding(.top, max(layout.verticalPadding, 8))
                }

                posterSubElementsView(layout: layout, geo: geo)
                    .padding(.horizontal, layout.horizontalPadding)
                    .padding(.bottom, layout.verticalPadding)
                    .accessibilityHidden(true) // Decorative elements
            }
            
            // Options button positioned in bottom right of title area
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button(action: {
                        withAnimation(DesignTokens.cardTapAnimation) {
                            viewModel.selectedAppScene = .options
                        }
                    }) {
                        ZStack {
                            // Brutalist background shape
                            UnevenRoundedRectangle(
                                cornerRadii: [
                                    .topLeading: 4,
                                    .bottomLeading: 0,
                                    .bottomTrailing: 0,
                                    .topTrailing: 8
                                ],
                                style: .continuous
                            )
                            .fill(DesignTokens.brutalistBlack.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay(
                                UnevenRoundedRectangle(
                                    cornerRadii: [
                                        .topLeading: 4,
                                        .bottomLeading: 0,
                                        .bottomTrailing: 0,
                                        .topTrailing: 8
                                    ],
                                    style: .continuous
                                )
                                .strokeBorder(DesignTokens.brutalistBlack.opacity(0.25), lineWidth: 1.5)
                            )
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DesignTokens.brutalistBlack.opacity(0.7))
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Open Options")
                    .accessibilityHint("Opens the options and settings menu")
                }
                .padding(.horizontal, layout.horizontalPadding)
                .padding(.bottom, max(layout.verticalPadding, 8))
            }
        }
    }
    
    @ViewBuilder
    private func posterSubElementsView(layout: LayoutConfiguration, geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: geo.size.width * 0.02) {
            ForEach(0..<posterConfig.subElements.count, id: \.self) { index in
                HStack(spacing: geo.size.width * 0.01) {
                    if let icon1 = posterConfig.subElements[index].0 {
                        Image(systemName: icon1)
                            .font(.system(size: layout.subElementFontSize, weight: .semibold))
                            .foregroundColor(DesignTokens.brutalistBlack)
                    }
                    if let text = posterConfig.subElements[index].1 {
                        Text(text)
                            .font(.custom("HelveticaNeue-Bold", size: layout.subElementFontSize))
                            .tracking(1)
                            .foregroundColor(DesignTokens.brutalistBlack)
                    }
                    if let icon2 = posterConfig.subElements[index].2 {
                        Image(systemName: icon2)
                            .font(.system(size: layout.subElementFontSize, weight: .semibold))
                            .foregroundColor(DesignTokens.brutalistBlack)
                    }
                }
            }
            Spacer()
            Text(posterConfig.rightText)
                .font(.custom("Circus Ace DEMO", size: layout.rightTextFontSize))
                .tracking(2)
                .foregroundColor(DesignTokens.brutalistBlack)
        }
    }
    
    @ViewBuilder
    private func cardsSection(layout: LayoutConfiguration, responsiveLayout: ResponsiveLayout, geo: GeometryProxy) -> some View {

        ZStack(alignment: .top) {
            Color.black
                .edgesIgnoringSafeArea(.bottom)

            // FIGHT poster decorative elements
            BrutalistDecorations(scale: min(geo.size.width * 0.0025, 1.2))
                .allowsHitTesting(false)
                .frame(width: geo.size.width, height: geo.size.height * 0.6)
                .offset(y: -20)

            // Fixed layout configuration - 1 card top, 2 cards in bottom row
            VStack(spacing: max(geo.size.height * 0.02, 12)) {
                // Main card - Open PDF (always on top, takes more height)
                MenuCardView(
                    imageName: "poster_image_panel_1",
                    title: "OPEN PDF",
                    iconName: "doc.viewfinder",
                    action: {
                        withAnimation(DesignTokens.cardTapAnimation) {
                            showFileImporter = true
                        }
                    },
                    height: max(geo.size.height * 0.24, 120),
                    geo: geo
                )
                .frame(maxWidth: .infinity)

                // Two smaller cards side by side
                HStack(spacing: max(geo.size.width * 0.02, 12)) {
                    secondaryCard1(responsiveLayout: responsiveLayout, geo: geo)
                        .frame(maxWidth: .infinity)
                    
                    secondaryCard2(responsiveLayout: responsiveLayout, geo: geo)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, max(geo.size.width * 0.04, 16))
            .padding(.top, max(geo.size.height * 0.02, 12))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                setError("No file was selected. Please try selecting a PDF file again.")
                return
            }
            
            loadPDF(from: url)
            
        case .failure(let error):
            let errorMessage = formatFileAccessError(error)
            setError(errorMessage)
        }
    }
    
    private func loadPDF(from url: URL) {
        Task {
            do {
                logDebug("Starting PDF import from: \(url.absoluteString)")
                try await viewModel.loadPDF(from: url)
                logDebug("PDF import completed successfully")
                
                // Provide user feedback on success
                await MainActor.run {
                    // Could add a success toast here if needed
                }
            } catch let error as NSError {
                let detailedMessage = formatPDFLoadError(error)
                logDebug("PDF import failed: \(detailedMessage)")
                await MainActor.run {
                    setError(detailedMessage)
                }
            } catch {
                let genericMessage = "An unexpected error occurred while loading the PDF. Please try again."
                logDebug("PDF import failed with unexpected error: \(error)")
                await MainActor.run {
                    setError(genericMessage)
                }
            }
        }
    }
    
    private func formatFileAccessError(_ error: Error) -> String {
        if error.localizedDescription.contains("cancelled") {
            return "File selection was cancelled."
        } else if error.localizedDescription.contains("permission") {
            return "Permission denied. Please ensure you have access to this file."
        } else {
            return "Failed to access the selected file. Please try again."
        }
    }
    
    private func formatPDFLoadError(_ error: NSError) -> String {
        switch error.code {
        case 1: // File not found
            return "The PDF file could not be found. It may have been moved or deleted."
        case 2: // Invalid file format
            return "This file is not a valid PDF or is corrupted. Please select a different file."
        case 3: // Permission denied
            return "Cannot open this PDF. It may be password-protected or restricted."
        default:
            return "Failed to load PDF: \(error.localizedDescription)"
        }
    }
    
    private func setError(_ message: String) {
        withAnimation(DesignTokens.errorAnimation) {
            loadError = message
        }
    }
    
    private func logDebug(_ message: String) {
        #if DEBUG
        print("[MainMenuView] \(message)")
        #endif
    }
    
    @ViewBuilder
    private func secondaryCard1(responsiveLayout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        MenuCardView(
            imageName: "poster_image_panel_2",
            title: "BATCH PROCESS",
            iconName: "square.3.layers.3d",
            action: {
                withAnimation(DesignTokens.cardTapAnimation) {
                    viewModel.selectedAppScene = .batchProcessing
                }
            },
            enableHover: true, // Always enabled since it doesn't require a loaded PDF
            height: max(geo.size.height * 0.2, 100),
            geo: geo
        )
    }
    
    @ViewBuilder
    private func secondaryCard2(responsiveLayout: ResponsiveLayout, geo: GeometryProxy) -> some View {
        MenuCardView(
            imageName: "poster_image_panel_3",
            title: "SELECT PAGES",
            iconName: "square.grid.2x2",
            action: {
                // Only perform action if PDF is loaded
                guard viewModel.pdfDocument != nil else { return }
                withAnimation(DesignTokens.cardTapAnimation) {
                    viewModel.showPreview = false
                    viewModel.selectedAppScene = .main
                }
            },
            enableHover: viewModel.pdfDocument != nil,
            height: max(geo.size.height * 0.2, 100),
            geo: geo
        )
    }
    
}

// MARK: - Debug Utilities
#if DEBUG
extension MainMenuView {
    /// Creates a sample PDF for testing purposes
    static func createSamplePDF() -> Data {
        let pdfData = NSMutableData()
        let pdfConsumer = CGDataConsumer(data: pdfData)!
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        guard let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        // Page 1
        pdfContext.beginPage(mediaBox: &mediaBox)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let text = "This is a test PDF document"
        let textRect = CGRect(x: 72, y: 396, width: 468, height: 100)
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString as CFAttributedString)
        let line = CTTypesetterCreateLine(typesetter, CFRange(location: 0, length: attributedString.length))

        pdfContext.textPosition = CGPoint(x: textRect.midX, y: textRect.midY)
        CTLineDraw(line, pdfContext)

        // Page 2
        pdfContext.endPage()
        pdfContext.beginPage(mediaBox: &mediaBox)

        pdfContext.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        pdfContext.setLineWidth(2)
        let rect = CGRect(x: 100, y: 100, width: 412, height: 300)
        pdfContext.stroke(rect)

        let text2 = "Page 2 - Sample Content"
        let attributes2: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString2 = NSAttributedString(string: text2, attributes: attributes2)
        let typesetter2 = CTTypesetterCreateWithAttributedString(attributedString2 as CFAttributedString)
        let line2 = CTTypesetterCreateLine(typesetter2, CFRange(location: 0, length: attributedString2.length))

        pdfContext.textPosition = CGPoint(x: rect.midX, y: rect.midY)
        CTLineDraw(line2, pdfContext)

        pdfContext.endPage()
        return pdfData as Data
    }
}
#endif

#Preview {
    // Create a dummy viewModel for the preview
    let previewViewModel = AppShellViewModel()
    // Optionally, load a sample PDF for previews where it's relevant
    // if let samplePDFURL = Bundle.main.url(forResource: "sample", withExtension: "pdf") {
    //     Task { try? await previewViewModel.loadPDF(from: samplePDFURL) }
    // }

    return MainMenuView(viewModel: previewViewModel)
        .frame(width: 800, height: 800) // Ensure preview size is square like the app window
        .preferredColorScheme(.dark)
        .environmentObject(AppBackgroundModel()) // If your previews need this
}
