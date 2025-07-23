import SwiftUI

// MARK: - Options Section Model
struct OptionsSection: Identifiable {
    let id = UUID()
    let title: String
    let iconName: String
    let items: [OptionsItem]
}

struct OptionsItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String?
    let iconName: String
    let action: OptionsAction
    let isEnabled: Bool
}

enum OptionsAction {
    case toggle(Binding<Bool>)
    case navigation(() -> Void)
    case picker(selection: Binding<String>, options: [String])
    case stepper(value: Binding<Double>, range: ClosedRange<Double>, step: Double)
    case button(() -> Void)
}

// MARK: - Options Menu View
struct OptionsMenuView: View {
    @ObservedObject var settingsStore = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var animateOnAppear = false
    @State private var showingCloudAuth = false
    @State private var showingPluginManager = false
    @State private var showingAbout = false
    
    // Closure to handle dismissal when not presented as a modal
    var onDismiss: (() -> Void)? = nil
    
    // Local state for immediate UI updates
    @State private var selectedCloudProvider = "None"
    @State private var cacheSize: Double = 100.0
    @State private var thumbnailQuality: Double = 0.8
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background with brutalist styling
                Color.black
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 0) {
                    // Header section
                    headerSection(geo: geo)
                        .frame(height: geo.size.height * 0.15)
                    
                    // Options content
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: DesignTokens.gridLarge) {
                            ForEach(createOptionsSections(), id: \.id) { section in
                                OptionsSectionView(section: section, geo: geo)
                            }
                            
                            // Footer spacing
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 40)
                        }
                        .padding(.horizontal, DesignTokens.gridLarge)
                        .padding(.top, DesignTokens.gridLarge)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                // Heavy grain overlay
                optionsHeavyGrainOverlay(geo: geo)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .scaleEffect(animateOnAppear ? 1.0 : 0.95)
        .opacity(animateOnAppear ? 1.0 : 0.0)
        .onAppear {
            // Load current settings
            selectedCloudProvider = settingsStore.settings.defaultCloudProvider ?? "None"
            cacheSize = Double(settingsStore.settings.thumbnailCacheSize)
            thumbnailQuality = settingsStore.settings.thumbnailQuality
            
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) {
                animateOnAppear = true
            }
        }
        .sheet(isPresented: $showingCloudAuth) {
            CloudAuthenticationView()
        }
        .sheet(isPresented: $showingPluginManager) {
            PluginManagerView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private func headerSection(geo: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            DesignTokens.brutalistPrimary
                .ignoresSafeArea(.all, edges: .top)
            
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OPTIONS")
                        .font(.custom("Helvetica Black Original", size: min(geo.size.width * 0.12, 48)))
                        .tracking(-2)
                        .foregroundColor(DesignTokens.brutalistBlack)
                        .padding(.top, 8)
                    
                    Text("SYSTEM SETTINGS")
                        .font(.custom("HelveticaNeue-Bold", size: min(geo.size.width * 0.025, 14)))
                        .tracking(1)
                        .foregroundColor(DesignTokens.brutalistBlack.opacity(0.7))
                }
                
                Spacer()
                
                // Close button
                Button(action: { 
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.brutalistBlack.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.brutalistBlack)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .animation(.spring(duration: 0.3, bounce: 0.7), value: animateOnAppear)
            }
            .padding(.horizontal, DesignTokens.gridLarge)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Options Sections Creation
    private func createOptionsSections() -> [OptionsSection] {
        return [
            // Cloud Storage Section
            OptionsSection(
                title: "CLOUD STORAGE",
                iconName: "icloud",
                items: [
                    OptionsItem(
                        title: "Cloud Provider",
                        description: "Select your preferred cloud storage service",
                        iconName: "cloud",
                        action: .picker(
                            selection: $selectedCloudProvider,
                            options: ["None", "Google Drive", "OneDrive", "Dropbox", "iCloud Drive"]
                        ),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Auto Upload",
                        description: "Automatically upload exported PDFs to cloud",
                        iconName: "arrow.up.to.line.compact",
                        action: .toggle($settingsStore.settings.autoUploadEnabled),
                        isEnabled: selectedCloudProvider != "None"
                    ),
                    OptionsItem(
                        title: "Cloud Authentication",
                        description: "Manage cloud service connections",
                        iconName: "key",
                        action: .button { showingCloudAuth = true },
                        isEnabled: true
                    )
                ]
            ),
            
            // Plugins Section
            OptionsSection(
                title: "PLUGINS",
                iconName: "puzzlepiece.extension",
                items: [
                    OptionsItem(
                        title: "Plugin Manager",
                        description: "Install and manage PDF processing plugins",
                        iconName: "square.3.layers.3d",
                        action: .button { showingPluginManager = true },
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Plugin Updates",
                        description: "Automatically check for plugin updates",
                        iconName: "arrow.triangle.2.circlepath",
                        action: .toggle($settingsStore.settings.autoUpdatePlugins),
                        isEnabled: true
                    )
                ]
            ),
            
            // Export Settings Section
            OptionsSection(
                title: "EXPORT SETTINGS",
                iconName: "square.and.arrow.up",
                items: [
                    OptionsItem(
                        title: "Default Format",
                        description: "Choose the default export format for compositions",
                        iconName: "doc.badge.gearshape",
                        action: .picker(
                            selection: $settingsStore.settings.defaultExportFormat,
                            options: ["PDF", "PNG", "JPEG", "WebP"]
                        ),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Image Quality",
                        description: "Set the quality for image exports (0.1 - 1.0)",
                        iconName: "photo",
                        action: .stepper(
                            value: $settingsStore.settings.exportImageQuality,
                            range: 0.1...1.0,
                            step: 0.1
                        ),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Optimize for Web",
                        description: "Compress exports for faster web loading",
                        iconName: "globe",
                        action: .toggle($settingsStore.settings.optimizeForWeb),
                        isEnabled: true
                    )
                ]
            ),
            
            // Performance Section
            OptionsSection(
                title: "PERFORMANCE",
                iconName: "speedometer",
                items: [
                    OptionsItem(
                        title: "Memory Cache Size",
                        description: "Thumbnail cache size in MB (50-500)",
                        iconName: "memorychip",
                        action: .stepper(
                            value: $cacheSize,
                            range: 50...500,
                            step: 25
                        ),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Thumbnail Quality",
                        description: "Balance between quality and performance",
                        iconName: "photo.badge.checkmark",
                        action: .stepper(
                            value: $thumbnailQuality,
                            range: 0.3...1.0,
                            step: 0.1
                        ),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Background Processing",
                        description: "Process thumbnails in background for better UI responsiveness",
                        iconName: "cpu",
                        action: .toggle($settingsStore.settings.backgroundProcessing),
                        isEnabled: true
                    )
                ]
            ),
            
            // Interface Section
            OptionsSection(
                title: "INTERFACE",
                iconName: "paintbrush",
                items: [
                    OptionsItem(
                        title: "Dark Mode",
                        description: "Use dark theme throughout the application",
                        iconName: "moon",
                        action: .toggle($settingsStore.settings.darkMode),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Animation Effects",
                        description: "Enable smooth animations and transitions",
                        iconName: "wand.and.stars",
                        action: .toggle($settingsStore.settings.animationsEnabled),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Noise Intensity",
                        description: "Adjust the background texture intensity",
                        iconName: "waveform",
                        action: .stepper(
                            value: $settingsStore.settings.noiseIntensity,
                            range: 0.1...1.0,
                            step: 0.1
                        ),
                        isEnabled: true
                    )
                ]
            ),
            
            // Debug Section (conditionally shown)
            OptionsSection(
                title: "DEBUG",
                iconName: "ant",
                items: [
                    OptionsItem(
                        title: "Debug Logging",
                        description: "Enable detailed logging for troubleshooting",
                        iconName: "doc.text.magnifyingglass",
                        action: .toggle($settingsStore.settings.debugLogging),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Performance Metrics",
                        description: "Show performance overlay in the interface",
                        iconName: "chart.line.uptrend.xyaxis",
                        action: .toggle($settingsStore.settings.showPerformanceMetrics),
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Clear Cache",
                        description: "Clear all cached thumbnails and temporary files",
                        iconName: "trash",
                        action: .button { clearCache() },
                        isEnabled: true
                    )
                ]
            ),
            
            // About Section
            OptionsSection(
                title: "ABOUT",
                iconName: "info.circle",
                items: [
                    OptionsItem(
                        title: "App Information",
                        description: "Version, credits, and licensing information",
                        iconName: "info.square",
                        action: .button { showingAbout = true },
                        isEnabled: true
                    ),
                    OptionsItem(
                        title: "Check for Updates",
                        description: "Check for application updates",
                        iconName: "arrow.down.circle",
                        action: .button { checkForUpdates() },
                        isEnabled: true
                    )
                ]
            )
        ]
    }
    
    // MARK: - Actions
    private func clearCache() {
        // Implementation would clear thumbnail cache
        print("Clearing cache...")
    }
    
    private func checkForUpdates() {
        // Implementation would check for app updates
        print("Checking for updates...")
    }
    
    // MARK: - Texture Overlay
    @ViewBuilder
    private func optionsHeavyGrainOverlay(geo: GeometryProxy) -> some View {
        Canvas { context, size in
            context.opacity = 1.0
            
            // Combined procedural texture effects for options screen
            context.blendMode = .overlay
            context.opacity = 0.4
            
            // Fine grain pattern
            let grainSize: CGFloat = 1.5
            for x in stride(from: 0, to: size.width, by: grainSize) {
                for y in stride(from: 0, to: size.height, by: grainSize) {
                    let intensity = CGFloat.random(in: 0.2...0.8)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: grainSize, height: grainSize)),
                        with: .color(.white.opacity(intensity * 0.1))
                    )
                }
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }
}

// MARK: - Options Section View
struct OptionsSectionView: View {
    let section: OptionsSection
    let geo: GeometryProxy
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.grid) {
            // Section header
            Button(action: { 
                withAnimation(.spring(duration: 0.4, bounce: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: section.iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(DesignTokens.brutalistPrimary)
                        .frame(width: 24)
                    
                    Text(section.title)
                        .font(.custom("HelveticaNeue-Bold", size: 16))
                        .tracking(1)
                        .foregroundColor(DesignTokens.brutalistPrimary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignTokens.brutalistPrimary.opacity(0.7))
                }
                .padding(.horizontal, DesignTokens.grid)
                .padding(.vertical, DesignTokens.grid)
                .background(
                    ZStack {
                        DesignTokens.brutalistGray
                        
                        // Brutalist border
                        UnevenRoundedRectangle(
                            cornerRadii: [
                                .topLeading: 8,
                                .bottomLeading: 0,
                                .bottomTrailing: 8,
                                .topTrailing: 0
                            ],
                            style: .continuous
                        )
                        .strokeBorder(DesignTokens.brutalistPrimary, lineWidth: 2)
                    }
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: [
                            .topLeading: 8,
                            .bottomLeading: 0,
                            .bottomTrailing: 8,
                            .topTrailing: 0
                        ],
                        style: .continuous
                    )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Section items
            if isExpanded {
                VStack(spacing: DesignTokens.grid) {
                    ForEach(section.items, id: \.id) { item in
                        OptionsItemView(item: item, geo: geo)
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
    }
}

// MARK: - Options Item View
struct OptionsItemView: View {
    let item: OptionsItem
    let geo: GeometryProxy
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.grid) {
            // Icon
            Image(systemName: item.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(item.isEnabled ?
                    DesignTokens.brutalistSecondary : DesignTokens.brutalistSecondary.opacity(0.4))
                .frame(width: 20)
                .padding(.top, 2)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("HelveticaNeue-Bold", size: 14))
                    .foregroundColor(item.isEnabled ?
                        DesignTokens.brutalistWhite : DesignTokens.brutalistWhite.opacity(0.4))
                
                if let description = item.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(item.isEnabled ?
                            DesignTokens.brutalistSecondary.opacity(0.8) : DesignTokens.brutalistSecondary.opacity(0.3))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Action control
            actionControlView
                .disabled(!item.isEnabled)
        }
        .padding(DesignTokens.grid)
        .background(
            ZStack {
                Color.black.opacity(isHovered ? 0.3 : 0.1)
                
                UnevenRoundedRectangle(
                    cornerRadii: [
                        .topLeading: 0,
                        .bottomLeading: 12,
                        .bottomTrailing: 0,
                        .topTrailing: 12
                    ],
                    style: .continuous
                )
                .strokeBorder(
                    DesignTokens.brutalistSecondary.opacity(isHovered ? 0.3 : 0.1),
                    lineWidth: 1
                )
            }
        )
        .clipShape(
            UnevenRoundedRectangle(
                cornerRadii: [
                    .topLeading: 0,
                    .bottomLeading: 12,
                    .bottomTrailing: 0,
                    .topTrailing: 12
                ],
                style: .continuous
            )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    @ViewBuilder
    private var actionControlView: some View {
        switch item.action {
        case .toggle(let binding):
            Toggle("", isOn: binding)
                .toggleStyle(.brutalist)
                
        case .navigation(let action):
            Button(action: action) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DesignTokens.brutalistPrimary)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .picker(let selection, let options):
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: 120)
            
        case .stepper(let value, let range, let step):
            HStack(spacing: 8) {
                Text(String(format: "%.1f", value.wrappedValue))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(DesignTokens.brutalistSecondary)
                    .frame(width: 35)
                
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
                    .frame(width: 60)
            }
            
        case .button(let action):
            Button(action: action) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignTokens.brutalistPrimary)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}


// MARK: - Placeholder Views for Sheets
struct CloudAuthenticationView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("CLOUD AUTHENTICATION")
                .font(.custom("Helvetica Black Original", size: 24))
                .foregroundColor(DesignTokens.brutalistPrimary)
            
            Text("Connect your cloud storage accounts")
                .font(.system(size: 16))
                .foregroundColor(DesignTokens.brutalistSecondary)
            
            // Placeholder content
            VStack(spacing: 12) {
                cloudServiceButton(name: "Google Drive", iconName: "globe", connected: false)
                cloudServiceButton(name: "OneDrive", iconName: "folder", connected: true)
                cloudServiceButton(name: "Dropbox", iconName: "icloud", connected: false)
            }
            
            Spacer()
            
            Button("Close") { dismiss() }
                .padding()
                .background(DesignTokens.brutalistPrimary)
                .foregroundColor(DesignTokens.brutalistBlack)
                .cornerRadius(8)
        }
        .padding()
        .frame(width: 400, height: 500)
        .background(Color.black)
    }
    
    private func cloudServiceButton(name: String, iconName: String, connected: Bool) -> some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(DesignTokens.brutalistPrimary)
            
            Text(name)
                .foregroundColor(DesignTokens.brutalistWhite)
            
            Spacer()
            
            Text(connected ? "Connected" : "Connect")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(connected ? DesignTokens.brutalistPrimary.opacity(0.3) : DesignTokens.brutalistGray)
                .foregroundColor(connected ? DesignTokens.brutalistPrimary : DesignTokens.brutalistSecondary)
                .cornerRadius(12)
        }
        .padding()
        .background(DesignTokens.brutalistGray.opacity(0.3))
        .cornerRadius(8)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ABOUT PDF COMPOSER")
                .font(.custom("Helvetica Black Original", size: 24))
                .foregroundColor(DesignTokens.brutalistPrimary)
            
            Text("Version 1.0.0")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(DesignTokens.brutalistSecondary)
            
            Text("A brutalist PDF composition tool for macOS")
                .font(.system(size: 14))
                .foregroundColor(DesignTokens.brutalistSecondary.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button("Close") { dismiss() }
                .padding()
                .background(DesignTokens.brutalistPrimary)
                .foregroundColor(DesignTokens.brutalistBlack)
                .cornerRadius(8)
        }
        .padding()
        .frame(width: 400, height: 300)
        .background(Color.black)
    }
}

#Preview {
    OptionsMenuView(onDismiss: nil)
        .frame(width: 800, height: 800)
        .preferredColorScheme(.dark)
}