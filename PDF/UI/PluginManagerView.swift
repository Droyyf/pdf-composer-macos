import SwiftUI
import PDFKit

/// Main plugin management interface with brutalist design
struct PluginManagerView: View {
    @StateObject private var pluginManager = PluginManager()
    @State private var selectedPlugin: PluginMetadata?
    @State private var showingPluginDetails = false
    @State private var showingPluginSettings = false
    @State private var showingPluginInstaller = false
    @State private var isRefreshing = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with brutal texture
                BrutalistBackgroundView()
                
                VStack(spacing: 0) {
                    // Header
                    pluginManagerHeader
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                    
                    // Main content
                    HStack(spacing: 20) {
                        // Plugin list sidebar
                        pluginListSidebar
                            .frame(width: geometry.size.width * 0.4)
                        
                        // Plugin details/content area
                        pluginContentArea
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            Task {
                await pluginManager.scanForPlugins()
            }
        }
        .sheet(isPresented: $showingPluginDetails) {
            if let plugin = selectedPlugin {
                PluginDetailView(plugin: plugin, pluginManager: pluginManager)
            }
        }
        .sheet(isPresented: $showingPluginSettings) {
            if let plugin = selectedPlugin {
                PluginSettingsView(plugin: plugin, pluginManager: pluginManager)
            }
        }
        .sheet(isPresented: $showingPluginInstaller) {
            PluginInstallerView(pluginManager: pluginManager)
        }
    }
    
    // MARK: - Header
    
    private var pluginManagerHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                BrutalistText("PLUGIN MANAGER", style: .headline)
                    .foregroundColor(.primary)
                
                BrutalistText("\(pluginManager.availablePlugins.count) PLUGINS AVAILABLE", style: .caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Refresh button
                BrutalistButton(action: {
                    Task {
                        isRefreshing = true
                        await pluginManager.scanForPlugins()
                        isRefreshing = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRefreshing)
                        
                        BrutalistText("REFRESH", style: .button)
                    }
                }
                .disabled(pluginManager.isScanning)
                
                // Install plugin button
                BrutalistButton(action: {
                    showingPluginInstaller = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.square.fill")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        
                        BrutalistText("INSTALL", style: .button)
                    }
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Plugin List Sidebar
    
    private var pluginListSidebar: some View {
        VStack(spacing: 0) {
            // Sidebar header
            HStack {
                BrutalistText("AVAILABLE PLUGINS", style: .subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if pluginManager.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Rectangle()
                            .stroke(.secondary, lineWidth: 1)
                            .offset(y: 1)
                    )
            )
            
            // Plugin list
            if pluginManager.availablePlugins.isEmpty && !pluginManager.isScanning {
                emptyPluginListView
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(pluginManager.availablePlugins, id: \.identifier) { plugin in
                            PluginListItemView(
                                plugin: plugin,
                                isSelected: selectedPlugin?.identifier == plugin.identifier,
                                isLoaded: pluginManager.isPluginLoaded(plugin.identifier),
                                hasError: pluginManager.pluginErrors.keys.contains(plugin.identifier)
                            )
                            .onTapGesture {
                                selectedPlugin = plugin
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .stroke(.secondary, lineWidth: 2)
        )
    }
    
    private var emptyPluginListView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                BrutalistText("NO PLUGINS FOUND", style: .headline)
                    .foregroundColor(.primary)
                
                BrutalistText("INSTALL PLUGINS TO EXTEND FUNCTIONALITY", style: .caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            BrutalistButton(action: {
                showingPluginInstaller = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    
                    BrutalistText("INSTALL PLUGINS", style: .button)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
    
    // MARK: - Plugin Content Area
    
    private var pluginContentArea: some View {
        VStack(spacing: 0) {
            if let plugin = selectedPlugin {
                selectedPluginView(plugin)
            } else {
                noSelectionView
            }
        }
        .background(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            UnevenRoundedRectangle(cornerRadii: [.topLeading: 8, .bottomLeading: 2, .bottomTrailing: 8, .topTrailing: 2], style: .continuous)
                .stroke(.secondary, lineWidth: 2)
        )
    }
    
    private func selectedPluginView(_ plugin: PluginMetadata) -> some View {
        VStack(spacing: 0) {
            // Plugin header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        BrutalistText(plugin.displayName.uppercased(), style: .headline)
                            .foregroundColor(.primary)
                        
                        // Status indicator
                        pluginStatusIndicator(plugin)
                    }
                    
                    BrutalistText("VERSION \(plugin.version.description)", style: .caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Settings button
                    BrutalistButton(action: {
                        showingPluginSettings = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12, weight: .bold))
                            BrutalistText("SETTINGS", style: .caption)
                        }
                    }
                    .disabled(!pluginManager.isPluginLoaded(plugin.identifier))
                    
                    // Load/Unload button
                    pluginActionButton(plugin)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Rectangle()
                            .stroke(.secondary, lineWidth: 1)
                            .offset(y: 1)
                    )
            )
            
            // Plugin content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        BrutalistText("DESCRIPTION", style: .subheadline)
                            .foregroundColor(.primary)
                        
                        BrutalistText(plugin.description, style: .body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Capabilities
                    VStack(alignment: .leading, spacing: 8) {
                        BrutalistText("CAPABILITIES", style: .subheadline)
                            .foregroundColor(.primary)
                        
                        capabilitiesView(plugin.capabilities)
                    }
                    
                    // Author and info
                    VStack(alignment: .leading, spacing: 8) {
                        BrutalistText("INFORMATION", style: .subheadline)
                            .foregroundColor(.primary)
                        
                        pluginInfoGrid(plugin)
                    }
                    
                    // Error display if any
                    if let error = pluginManager.pluginErrors[plugin.identifier] {
                        VStack(alignment: .leading, spacing: 8) {
                            BrutalistText("ERROR", style: .subheadline)
                                .foregroundColor(.red)
                            
                            BrutalistText(error.localizedDescription, style: .body)
                                .foregroundColor(.red)
                                .padding(12)
                                .background(
                                    Rectangle()
                                        .fill(.red.opacity(0.1))
                                        .overlay(
                                            Rectangle()
                                                .stroke(.red.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                BrutalistText("SELECT A PLUGIN", style: .headline)
                    .foregroundColor(.secondary)
                
                BrutalistText("CHOOSE A PLUGIN FROM THE LIST TO VIEW DETAILS", style: .caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Views
    
    private func pluginStatusIndicator(_ plugin: PluginMetadata) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(pluginStatusColor(plugin))
                .frame(width: 8, height: 8)
            
            BrutalistText(pluginStatusText(plugin), style: .caption)
                .foregroundColor(pluginStatusColor(plugin))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(pluginStatusColor(plugin).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(pluginStatusColor(plugin).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func pluginStatusColor(_ plugin: PluginMetadata) -> Color {
        if pluginManager.pluginErrors.keys.contains(plugin.identifier) {
            return .red
        } else if pluginManager.isPluginLoaded(plugin.identifier) {
            return .green
        } else {
            return .orange
        }
    }
    
    private func pluginStatusText(_ plugin: PluginMetadata) -> String {
        if pluginManager.pluginErrors.keys.contains(plugin.identifier) {
            return "ERROR"
        } else if pluginManager.isPluginLoaded(plugin.identifier) {
            return "LOADED"
        } else {
            return "UNLOADED"
        }
    }
    
    private func pluginActionButton(_ plugin: PluginMetadata) -> some View {
        let isLoaded = pluginManager.isPluginLoaded(plugin.identifier)
        let hasError = pluginManager.pluginErrors.keys.contains(plugin.identifier)
        
        return BrutalistButton(action: {
            Task {
                if isLoaded {
                    await pluginManager.unloadPlugin(plugin.identifier)
                } else {
                    try? await pluginManager.loadPlugin(plugin.identifier)
                }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isLoaded ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isLoaded ? .red : .green)
                
                BrutalistText(isLoaded ? "UNLOAD" : "LOAD", style: .button)
            }
        }
        .disabled(hasError)
    }
    
    private func capabilitiesView(_ capabilities: PluginCapabilities) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 120))
        ], spacing: 8) {
            if capabilities.contains(.pdfProcessing) {
                capabilityChip("PDF Processing", color: .blue)
            }
            if capabilities.contains(.imageExport) {
                capabilityChip("Image Export", color: .purple)
            }
            if capabilities.contains(.batchProcessing) {
                capabilityChip("Batch Processing", color: .orange)
            }
            if capabilities.contains(.userInterface) {
                capabilityChip("User Interface", color: .green)
            }
            if capabilities.contains(.fileSystemAccess) {
                capabilityChip("File System", color: .red)
            }
            if capabilities.contains(.networkAccess) {
                capabilityChip("Network Access", color: .yellow)
            }
        }
    }
    
    private func capabilityChip(_ title: String, color: Color) -> some View {
        BrutalistText(title.uppercased(), style: .caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(color.opacity(0.5), lineWidth: 1)
                    )
            )
            .foregroundColor(color)
    }
    
    private func pluginInfoGrid(_ plugin: PluginMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            infoRow("AUTHOR", plugin.author)
            infoRow("BUNDLE ID", plugin.bundleIdentifier)
            
            if let website = plugin.website {
                infoRow("WEBSITE", website.absoluteString)
            }
            
            if let email = plugin.supportEmail {
                infoRow("SUPPORT", email)
            }
            
            infoRow("MIN HOST VERSION", plugin.hostVersionRequirement.minimum.description)
            
            if let maxVersion = plugin.hostVersionRequirement.maximum {
                infoRow("MAX HOST VERSION", maxVersion.description)
            }
        }
    }
    
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            BrutalistText("\(label):", style: .caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            BrutalistText(value, style: .caption)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Plugin List Item View

struct PluginListItemView: View {
    let plugin: PluginMetadata
    let isSelected: Bool
    let isLoaded: Bool
    let hasError: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIndicator
            
            // Plugin info
            VStack(alignment: .leading, spacing: 2) {
                BrutalistText(plugin.displayName, style: .body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                BrutalistText("v\(plugin.version.description)", style: .caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Capabilities indicator
            if plugin.capabilities.contains(.pdfProcessing) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            if plugin.capabilities.contains(.imageExport) {
                Image(systemName: "photo.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.purple)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(isSelected ? .quaternary : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(isSelected ? .primary : Color.clear, lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }
    
    private var statusColor: Color {
        if hasError {
            return .red
        } else if isLoaded {
            return .green
        } else {
            return .orange
        }
    }
}

// MARK: - Background View

private struct BrutalistBackgroundView: View {
    var body: some View {
        Color.black
            .overlay(
                BrutalistTexture()
                    .opacity(0.3)
                    .blendMode(.overlay)
            )
            .ignoresSafeArea()
    }
}

#Preview {
    PluginManagerView()
        .frame(width: 1000, height: 700)
}