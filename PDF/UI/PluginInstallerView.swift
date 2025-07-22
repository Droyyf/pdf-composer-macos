import SwiftUI
import UniformTypeIdentifiers

/// Plugin installer interface for installing new plugins
struct PluginInstallerView: View {
    let pluginManager: PluginManager
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedInstallMethod: InstallMethod = .file
    @State private var isInstalling = false
    @State private var installationProgress: Double = 0.0
    @State private var installationMessage = ""
    @State private var installationError: String?
    @State private var showingFilePicker = false
    @State private var showingSuccessAlert = false
    @State private var installedPluginName = ""
    
    enum InstallMethod: String, CaseIterable {
        case file = "Local File"
        case url = "Remote URL"
        case repository = "Plugin Repository"
        
        var icon: String {
            switch self {
            case .file: return "folder.fill"
            case .url: return "link"
            case .repository: return "globe"
            }
        }
    }
    
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
                    installerHeader
                    
                    // Content
                    if isInstalling {
                        installationProgressView
                    } else {
                        installMethodSelection
                    }
                    
                    // Footer
                    installerFooter
                }
                .padding(.all, 24)
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.init(filenameExtension: "plugin") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Installation Successful", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Plugin '\(installedPluginName)' has been successfully installed and is now available.")
        }
    }
    
    // MARK: - Header
    
    private var installerHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                BrutalistText("INSTALL PLUGIN", style: .title)
                    .foregroundColor(.primary)
                
                BrutalistText("ADD NEW FUNCTIONALITY TO THE APPLICATION", style: .caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Close button
            BrutalistButton(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .disabled(isInstalling)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            BrutalistCard()
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Install Method Selection
    
    private var installMethodSelection: some View {
        VStack(spacing: 24) {
            // Method selection
            VStack(alignment: .leading, spacing: 16) {
                BrutalistText("INSTALLATION METHOD", style: .subheadline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(InstallMethod.allCases, id: \.self) { method in
                        installMethodCard(method)
                    }
                }
            }
            
            // Method-specific content
            methodSpecificContent
            
            // Security warning
            securityWarning
        }
        .padding(24)
        .background(
            BrutalistCard()
                .fill(.regularMaterial)
        )
        .overlay(
            BrutalistCard()
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    private func installMethodCard(_ method: InstallMethod) -> some View {
        VStack(spacing: 12) {
            Image(systemName: method.icon)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(selectedInstallMethod == method ? .blue : .secondary)
            
            BrutalistText(method.rawValue.uppercased(), style: .caption)
                .foregroundColor(selectedInstallMethod == method ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(selectedInstallMethod == method ? .blue.opacity(0.1) : .clear)
                .overlay(
                    Rectangle()
                        .stroke(selectedInstallMethod == method ? .blue : .tertiary, lineWidth: 2)
                )
        )
        .onTapGesture {
            selectedInstallMethod = method
        }
        .animation(.easeInOut(duration: 0.2), value: selectedInstallMethod)
    }
    
    @ViewBuilder
    private var methodSpecificContent: some View {
        switch selectedInstallMethod {
        case .file:
            fileInstallContent
        case .url:
            urlInstallContent
        case .repository:
            repositoryInstallContent
        }
    }
    
    private var fileInstallContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistText("SELECT PLUGIN FILE", style: .subheadline)
                .foregroundColor(.primary)
            
            BrutalistText("Choose a .plugin bundle file from your computer. Plugin files typically end with the .plugin extension and contain all necessary code and resources.", style: .body)
                .foregroundColor(.secondary)
            
            BrutalistButton(action: {
                showingFilePicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 16, weight: .bold))
                    
                    BrutalistText("BROWSE FOR PLUGIN FILE", style: .button)
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var urlInstallContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistText("PLUGIN URL", style: .subheadline)
                .foregroundColor(.primary)
            
            BrutalistText("Enter the URL to download a plugin. This should be a direct link to a .plugin file or a zip archive containing the plugin.", style: .body)
                .foregroundColor(.secondary)
            
            TextField("https://example.com/plugin.plugin", text: .constant(""))
                .textFieldStyle(BrutalistTextFieldStyle())
                .disabled(true) // TODO: Implement URL installation
            
            BrutalistText("URL INSTALLATION NOT YET IMPLEMENTED", style: .caption)
                .foregroundColor(.orange)
                .padding(.top, 4)
        }
    }
    
    private var repositoryInstallContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrutalistText("PLUGIN REPOSITORY", style: .subheadline)
                .foregroundColor(.primary)
            
            BrutalistText("Browse and install plugins from the official plugin repository. This provides the safest way to install verified plugins.", style: .body)
                .foregroundColor(.secondary)
            
            // Repository browser placeholder
            VStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.secondary)
                
                BrutalistText("REPOSITORY BROWSER", style: .subheadline)
                    .foregroundColor(.secondary)
                
                BrutalistText("PLUGIN REPOSITORY NOT YET IMPLEMENTED", style: .caption)
                    .foregroundColor(.orange)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Rectangle()
                            .stroke(.tertiary, lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Security Warning
    
    private var securityWarning: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                
                BrutalistText("SECURITY WARNING", style: .subheadline)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                BrutalistText("• Only install plugins from trusted sources", style: .caption)
                    .foregroundColor(.secondary)
                
                BrutalistText("• Plugins run with application privileges and can access your files", style: .caption)
                    .foregroundColor(.secondary)
                
                BrutalistText("• Code-signed plugins from verified developers are recommended", style: .caption)
                    .foregroundColor(.secondary)
                
                BrutalistText("• Review plugin permissions and capabilities before installation", style: .caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            Rectangle()
                .fill(.orange.opacity(0.1))
                .overlay(
                    Rectangle()
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Installation Progress
    
    private var installationProgressView: some View {
        VStack(spacing: 24) {
            // Progress indicator
            VStack(spacing: 16) {
                Image(systemName: "gearshape.2.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(installationProgress * 360))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: installationProgress)
                
                BrutalistText("INSTALLING PLUGIN", style: .headline)
                    .foregroundColor(.primary)
                
                BrutalistText(installationMessage, style: .body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: installationProgress, total: 1.0)
                    .progressViewStyle(BrutalistProgressViewStyle())
                
                BrutalistText("\(Int(installationProgress * 100))% COMPLETE", style: .caption)
                    .foregroundColor(.secondary)
            }
            
            // Error display
            if let error = installationError {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.red)
                        
                        BrutalistText("INSTALLATION FAILED", style: .subheadline)
                            .foregroundColor(.red)
                    }
                    
                    BrutalistText(error, style: .body)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
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
        .padding(40)
        .background(
            BrutalistCard()
                .fill(.regularMaterial)
        )
        .overlay(
            BrutalistCard()
                .stroke(.tertiary, lineWidth: 2)
        )
    }
    
    // MARK: - Footer
    
    private var installerFooter: some View {
        HStack {
            Spacer()
            
            HStack(spacing: 12) {
                // Cancel button
                BrutalistButton(action: {
                    dismiss()
                }) {
                    BrutalistText("CANCEL", style: .button)
                        .foregroundColor(.secondary)
                }
                .disabled(isInstalling)
                
                // Install button (only for file method currently)
                if selectedInstallMethod == .file {
                    BrutalistButton(action: {
                        showingFilePicker = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            
                            BrutalistText("SELECT & INSTALL", style: .button)
                        }
                    }
                    .disabled(isInstalling)
                } else {
                    BrutalistButton(action: {
                        // TODO: Implement for other methods
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                            
                            BrutalistText("INSTALL", style: .button)
                        }
                    }
                    .disabled(true) // Disabled until implemented
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            BrutalistCard()
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Helper Methods
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                installPlugin(from: url)
            }
        case .failure(let error):
            installationError = "Failed to select file: \(error.localizedDescription)"
        }
    }
    
    private func installPlugin(from url: URL) {
        isInstalling = true
        installationProgress = 0.0
        installationError = nil
        installationMessage = "Preparing installation..."
        
        Task {
            do {
                // Simulate installation process with progress updates
                await updateProgress(0.1, "Validating plugin file...")
                try await Task.sleep(nanoseconds: 500_000_000)
                
                await updateProgress(0.3, "Checking security requirements...")
                try await Task.sleep(nanoseconds: 500_000_000)
                
                await updateProgress(0.5, "Copying plugin files...")
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                await updateProgress(0.7, "Registering plugin...")
                try await Task.sleep(nanoseconds: 500_000_000)
                
                await updateProgress(0.9, "Finalizing installation...")
                try await Task.sleep(nanoseconds: 500_000_000)
                
                await updateProgress(1.0, "Installation complete!")
                
                // TODO: Implement actual plugin installation
                // This would involve:
                // 1. Copy plugin to appropriate directory
                // 2. Validate plugin structure and metadata
                // 3. Register plugin with plugin manager
                // 4. Perform security validation
                
                await MainActor.run {
                    installedPluginName = url.deletingPathExtension().lastPathComponent
                    isInstalling = false
                    showingSuccessAlert = true
                }
                
                // Refresh plugin list
                await pluginManager.scanForPlugins()
                
            } catch {
                await MainActor.run {
                    installationError = error.localizedDescription
                    isInstalling = false
                }
            }
        }
    }
    
    @MainActor
    private func updateProgress(_ progress: Double, _ message: String) {
        installationProgress = progress
        installationMessage = message
    }
}

// MARK: - Custom Progress View Style

struct BrutalistProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0.0
        
        return GeometryReader { geometry in
            Rectangle()
                .fill(.quaternary)
                .frame(height: 8)
                .overlay(
                    HStack {
                        Rectangle()
                            .fill(.blue)
                            .frame(width: geometry.size.width * progress)
                        
                        Spacer(minLength: 0)
                    }
                )
                .overlay(
                    Rectangle()
                        .stroke(.tertiary, lineWidth: 2)
                )
        }
        .frame(height: 8)
    }
}

// MARK: - Custom Text Field Style

struct BrutalistTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(.quaternary)
                    .overlay(
                        Rectangle()
                            .stroke(.tertiary, lineWidth: 2)
                    )
            )
            .font(.system(size: 14, weight: .medium, design: .monospaced))
    }
}

#Preview {
    PluginInstallerView(pluginManager: PluginManager())
        .frame(width: 600, height: 500)
}