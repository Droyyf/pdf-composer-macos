import SwiftUI

/// Detailed plugin information view
struct PluginDetailView: View {
    let plugin: PluginMetadata
    let pluginManager: PluginManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black
                    .overlay(
                        BrutalistTexture()
                            .opacity(0.2)
                            .blendMode(.overlay)
                    )
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    detailHeader
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            pluginOverview
                            capabilitiesSection
                            requirementsSection
                            menuItemsSection
                            securitySection
                        }
                        .padding(.all, 24)
                    }
                    
                    // Footer
                    detailFooter
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            PluginSettingsView(plugin: plugin, pluginManager: pluginManager)
        }
    }
    
    // MARK: - Header
    
    private var detailHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // Plugin icon placeholder
                    pluginIcon
                    
                    VStack(alignment: .leading, spacing: 4) {
                        BrutalistText(plugin.displayName.uppercased(), style: .title)
                            .foregroundColor(.primary)
                        
                        BrutalistText("VERSION \(plugin.version.description)", style: .subheadline)
                            .foregroundColor(.secondary)
                        
                        BrutalistText("BY \(plugin.author.uppercased())", style: .caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Status indicator
                pluginStatusBanner
            }
            
            Spacer()
            
            // Close button
            BrutalistButton(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .padding(.all, 24)
        .background(
            BrutalistCard()
                .fill(.ultraThinMaterial)
        )
    }
    
    private var pluginIcon: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 64, height: 64)
            .overlay(
                if let iconName = plugin.iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.secondary)
                }
            )
            .overlay(
                Rectangle()
                    .stroke(.tertiary, lineWidth: 2)
            )
    }
    
    private var pluginStatusBanner: some View {
        HStack(spacing: 8) {
            statusIndicator
            
            BrutalistText(statusText, style: .caption)
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Rectangle()
                        .fill(statusColor.opacity(0.1))
                        .overlay(
                            Rectangle()
                                .stroke(statusColor.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 12, height: 12)
    }
    
    private var statusColor: Color {
        if pluginManager.pluginErrors.keys.contains(plugin.identifier) {
            return .red
        } else if pluginManager.isPluginLoaded(plugin.identifier) {
            return .green
        } else {
            return .orange
        }
    }
    
    private var statusText: String {
        if pluginManager.pluginErrors.keys.contains(plugin.identifier) {
            return "ERROR - PLUGIN FAILED TO LOAD"
        } else if pluginManager.isPluginLoaded(plugin.identifier) {
            return "LOADED AND ACTIVE"
        } else {
            return "AVAILABLE - NOT LOADED"
        }
    }
    
    // MARK: - Content Sections
    
    private var pluginOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("OVERVIEW")
            
            VStack(alignment: .leading, spacing: 12) {
                BrutalistText(plugin.description, style: .body)
                    .foregroundColor(.primary)
                
                // Links
                if plugin.website != nil || plugin.supportEmail != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        if let website = plugin.website {
                            linkRow("Website", website.absoluteString)
                        }
                        
                        if let email = plugin.supportEmail {
                            linkRow("Support", "mailto:\(email)")
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            BrutalistCard()
                .fill(.regularMaterial)
        )
        .overlay(
            BrutalistCard()
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("CAPABILITIES")
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150))
            ], spacing: 12) {
                if plugin.capabilities.contains(.pdfProcessing) {
                    capabilityCard("PDF Processing", "doc.text.fill", .blue)
                }
                if plugin.capabilities.contains(.imageExport) {
                    capabilityCard("Image Export", "photo.fill", .purple)
                }
                if plugin.capabilities.contains(.batchProcessing) {
                    capabilityCard("Batch Processing", "square.grid.3x3.fill", .orange)
                }
                if plugin.capabilities.contains(.userInterface) {
                    capabilityCard("User Interface", "window.shade.closed", .green)
                }
                if plugin.capabilities.contains(.fileSystemAccess) {
                    capabilityCard("File System", "folder.fill", .red)
                }
                if plugin.capabilities.contains(.networkAccess) {
                    capabilityCard("Network Access", "network", .yellow)
                }
            }
        }
        .padding(20)
        .background(
            BrutalistCard()
                .fill(.regularMaterial)
        )
        .overlay(
            BrutalistCard()
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("REQUIREMENTS")
            
            VStack(alignment: .leading, spacing: 12) {
                requirementRow("Host Version", "\(plugin.hostVersionRequirement.minimum.description)+")
                requirementRow("Swift Version", plugin.swiftVersion)
                requirementRow("macOS Version", "\(plugin.minimumMacOSVersion)+")
                requirementRow("Bundle ID", plugin.bundleIdentifier)
                
                if !plugin.requiredEntitlements.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        BrutalistText("REQUIRED ENTITLEMENTS:", style: .caption)
                            .foregroundColor(.secondary)
                        
                        ForEach(plugin.requiredEntitlements, id: \.self) { entitlement in
                            BrutalistText("• \(entitlement)", style: .caption)
                                .foregroundColor(.primary)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            BrutalistCard()
                .fill(.regularMaterial)
        )
        .overlay(
            BrutalistCard()
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    private var menuItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("MENU INTEGRATION")
            
            if plugin.menuItems.isEmpty {
                BrutalistText("NO MENU ITEMS", style: .body)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plugin.menuItems.indices, id: \.self) { index in
                        menuItemView(plugin.menuItems[index])
                    }
                }
            }
        }
        .padding(20)
        .background(
            BrutalistCard()
                .fill(.regularMaterial)
        )
        .overlay(
            BrutalistCard()
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("SECURITY")
            
            VStack(alignment: .leading, spacing: 12) {
                if let teamId = plugin.teamIdentifier {
                    securityRow("Team ID", teamId, .green)
                } else {
                    securityRow("Team ID", "NOT SPECIFIED", .orange)
                }
                
                if let codeSigningIdentity = plugin.codeSigningIdentity {
                    securityRow("Code Signing", codeSigningIdentity, .green)
                } else {
                    securityRow("Code Signing", "NOT SPECIFIED", .orange)
                }
                
                if let checksum = plugin.checksumSHA256 {
                    securityRow("Checksum", String(checksum.prefix(16)) + "...", .green)
                } else {
                    securityRow("Checksum", "NOT PROVIDED", .orange)
                }
                
                // Security risk assessment
                securityRiskAssessment
            }
        }
        .padding(20)
        .background(
            BrutalistCard()
                .fill(.regularMaterial)
        )
        .overlay(
            BrutalistCard()
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    private var securityRiskAssessment: some View {
        VStack(alignment: .leading, spacing: 8) {
            BrutalistText("RISK ASSESSMENT:", style: .caption)
                .foregroundColor(.secondary)
            
            let riskLevel = calculateRiskLevel()
            HStack {
                Circle()
                    .fill(riskLevel.color)
                    .frame(width: 8, height: 8)
                
                BrutalistText(riskLevel.text, style: .caption)
                    .foregroundColor(riskLevel.color)
            }
        }
    }
    
    // MARK: - Footer
    
    private var detailFooter: some View {
        HStack {
            // Info buttons
            HStack(spacing: 12) {
                if pluginManager.getPluginConfiguration(plugin.identifier) != nil {
                    BrutalistButton(action: {
                        showingSettings = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .bold))
                            BrutalistText("SETTINGS", style: .button)
                        }
                    }
                    .disabled(!pluginManager.isPluginLoaded(plugin.identifier))
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                // Load/Unload button
                pluginActionButton
            }
        }
        .padding(.all, 24)
        .background(
            BrutalistCard()
                .fill(.ultraThinMaterial)
        )
    }
    
    private var pluginActionButton: some View {
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
            HStack(spacing: 8) {
                Image(systemName: isLoaded ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isLoaded ? .red : .green)
                
                BrutalistText(isLoaded ? "UNLOAD PLUGIN" : "LOAD PLUGIN", style: .button)
            }
        }
        .disabled(hasError)
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(_ title: String) -> some View {
        BrutalistText(title, style: .subheadline)
            .foregroundColor(.primary)
            .padding(.bottom, 8)
    }
    
    private func linkRow(_ label: String, _ url: String) -> some View {
        HStack {
            BrutalistText("\(label):", style: .caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Link(url, destination: URL(string: url) ?? URL(string: "about:blank")!)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.blue)
        }
    }
    
    private func capabilityCard(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            BrutalistText(title.uppercased(), style: .caption)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(color.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    private func requirementRow(_ label: String, _ value: String) -> some View {
        HStack {
            BrutalistText("\(label):", style: .caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            BrutalistText(value, style: .caption)
                .foregroundColor(.primary)
                .font(.system(.caption, design: .monospaced))
        }
    }
    
    private func menuItemView(_ item: PluginMenuItem) -> some View {
        HStack(spacing: 8) {
            if item.separator {
                Rectangle()
                    .fill(.tertiary)
                    .frame(height: 1)
            } else {
                BrutalistText("• \(item.title)", style: .caption)
                    .foregroundColor(.primary)
                
                if let keyEquivalent = item.keyEquivalent {
                    Spacer()
                    BrutalistText("⌘\(keyEquivalent)", style: .caption)
                        .foregroundColor(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
    }
    
    private func securityRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            BrutalistText("\(label):", style: .caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            BrutalistText(value, style: .caption)
                .foregroundColor(color)
                .font(.system(.caption, design: .monospaced))
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateRiskLevel() -> (text: String, color: Color) {
        var riskScore = 0
        
        // Check for dangerous capabilities
        if plugin.capabilities.contains(.fileSystemAccess) { riskScore += 2 }
        if plugin.capabilities.contains(.networkAccess) { riskScore += 2 }
        
        // Check for missing security features
        if plugin.teamIdentifier == nil { riskScore += 1 }
        if plugin.codeSigningIdentity == nil { riskScore += 1 }
        if plugin.checksumSHA256 == nil { riskScore += 1 }
        
        switch riskScore {
        case 0...1:
            return ("LOW RISK", .green)
        case 2...3:
            return ("MEDIUM RISK", .orange)
        default:
            return ("HIGH RISK", .red)
        }
    }
}

#Preview {
    PluginDetailView(
        plugin: PluginMetadata(
            identifier: "com.example.testplugin",
            name: "Test Plugin",
            version: PluginVersion(1, 0, 0),
            author: "Test Author",
            description: "A comprehensive test plugin for demonstration purposes. This plugin provides PDF processing capabilities with advanced export options and batch processing support.",
            website: URL(string: "https://example.com"),
            supportEmail: "support@example.com",
            hostVersionRequirement: PluginVersionRequirement(minimum: PluginVersion(1, 0, 0)),
            swiftVersion: "5.9",
            minimumMacOSVersion: "14.0",
            capabilities: [.pdfProcessing, .imageExport, .batchProcessing],
            requiredEntitlements: [
                "com.apple.security.files.user-selected.read-write",
                "com.apple.security.network.client"
            ],
            codeSigningIdentity: "Developer ID Application: Test Developer",
            teamIdentifier: "ABC123DEF4",
            bundleIdentifier: "com.example.testplugin",
            checksumSHA256: "a1b2c3d4e5f6789012345678901234567890abcdef",
            displayName: "Test Plugin",
            iconName: nil,
            menuItems: [
                PluginMenuItem(title: "Process PDF", action: "processPDF", keyEquivalent: "p"),
                PluginMenuItem(title: "Export Options", action: "showExportOptions", submenu: [
                    PluginMenuItem(title: "Export as PNG", action: "exportPNG"),
                    PluginMenuItem(title: "Export as JPEG", action: "exportJPEG")
                ])
            ],
            settingsSchema: nil
        ),
        pluginManager: PluginManager()
    )
    .frame(width: 800, height: 600)
}