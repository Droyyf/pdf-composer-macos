import Foundation
import PDFKit
import AppKit
import OSLog
import Security

/// Main plugin management actor that handles plugin lifecycle, security, and execution
@MainActor
final class PluginManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var loadedPlugins: [String: LoadedPlugin] = [:]
    @Published var availablePlugins: [PluginMetadata] = []
    @Published var pluginErrors: [String: PluginError] = [:]
    @Published var isScanning: Bool = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.almostbrutal.pdf", category: "PluginManager")
    private let fileManager = FileManager.default
    private let securityValidator: PluginSecurityValidator
    private let resourceManager: PluginResourceManagerImpl
    private let sandboxManager: PluginSandboxManager
    
    // Plugin directories
    private let pluginSearchPaths: [URL]
    private let hostVersion = PluginVersion(1, 0, 0) // Current app version
    
    // Execution limits
    private let maxExecutionTime: TimeInterval = 30.0
    private let maxMemoryUsage: UInt64 = 100 * 1024 * 1024 // 100MB
    
    // Plugin communication
    private var messageHandlers: [String: (PluginMessage) async throws -> PluginMessage?] = [:]
    
    // MARK: - Initialization
    
    init() {
        // Set up plugin search paths
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appPluginsDir = appSupport.appendingPathComponent("AlmostBrutal/Plugins", isDirectory: true)
        
        let bundlePluginsDir = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns", isDirectory: true)
        let systemPluginsDir = URL(fileURLWithPath: "/Library/Application Support/AlmostBrutal/Plugins")
        
        self.pluginSearchPaths = [appPluginsDir, bundlePluginsDir, systemPluginsDir]
        
        // Initialize components
        self.securityValidator = PluginSecurityValidator()
        self.resourceManager = PluginResourceManagerImpl()
        self.sandboxManager = PluginSandboxManager()
        
        // Create plugin directories if needed
        for path in pluginSearchPaths {
            try? fileManager.createDirectory(at: path, withIntermediateDirectories: true)
        }
        
        // Set up message handlers
        setupMessageHandlers()
        
        logger.info("PluginManager initialized with search paths: \(self.pluginSearchPaths)")
    }
    
    // MARK: - Plugin Discovery
    
    /// Scan all plugin directories and load available plugins
    func scanForPlugins() async {
        isScanning = true
        logger.info("Starting plugin discovery scan")
        
        var discoveredPlugins: [PluginMetadata] = []
        var errors: [String: PluginError] = [:]
        
        for searchPath in pluginSearchPaths {
            do {
                let plugins = try await scanDirectory(searchPath)
                discoveredPlugins.append(contentsOf: plugins)
                logger.info("Found \(plugins.count) plugins in \(searchPath.path)")
            } catch {
                logger.error("Failed to scan directory \(searchPath.path): \(error)")
                errors[searchPath.path] = .executionError("Failed to scan directory: \(error.localizedDescription)")
            }
        }
        
        // Update published properties
        availablePlugins = discoveredPlugins
        pluginErrors.merge(errors) { _, new in new }
        isScanning = false
        
        logger.info("Plugin discovery completed. Found \(discoveredPlugins.count) plugins")
    }
    
    private func scanDirectory(_ directory: URL) async throws -> [PluginMetadata] {
        guard fileManager.fileExists(atPath: directory.path) else {
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        var plugins: [PluginMetadata] = []
        
        for item in contents {
            // Look for .plugin bundles
            if item.pathExtension == "plugin" {
                do {
                    let metadata = try await loadPluginMetadata(from: item)
                    plugins.append(metadata)
                } catch let error as PluginError {
                    logger.warning("Failed to load plugin metadata from \(item.path): \(error)")
                    pluginErrors[item.path] = error
                } catch {
                    logger.warning("Unexpected error loading plugin metadata from \(item.path): \(error)")
                    pluginErrors[item.path] = .executionError(error.localizedDescription)
                }
            }
        }
        
        return plugins
    }
    
    private func loadPluginMetadata(from bundleURL: URL) async throws -> PluginMetadata {
        let metadataURL = bundleURL.appendingPathComponent("Contents/metadata.json")
        
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw PluginError.invalidMetadata("metadata.json not found in plugin bundle")
        }
        
        let data = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(PluginMetadata.self, from: data)
        
        // Validate metadata
        try metadata.validate()
        
        // Check version compatibility
        guard metadata.hostVersionRequirement.minimum <= hostVersion else {
            throw PluginError.incompatibleVersion(required: metadata.hostVersionRequirement, found: hostVersion)
        }
        
        if let maxVersion = metadata.hostVersionRequirement.maximum,
           hostVersion > maxVersion {
            throw PluginError.incompatibleVersion(required: metadata.hostVersionRequirement, found: hostVersion)
        }
        
        return metadata
    }
    
    // MARK: - Plugin Loading
    
    /// Load a plugin by its identifier
    func loadPlugin(_ identifier: String) async throws {
        guard let metadata = availablePlugins.first(where: { $0.identifier == identifier }) else {
            throw PluginError.invalidMetadata("Plugin with identifier '\(identifier)' not found")
        }
        
        // Check if already loaded
        if loadedPlugins[identifier] != nil {
            logger.info("Plugin \(identifier) is already loaded")
            return
        }
        
        logger.info("Loading plugin: \(identifier)")
        
        do {
            // Find plugin bundle
            guard let bundleURL = findPluginBundle(for: metadata) else {
                throw PluginError.executionError("Plugin bundle not found")
            }
            
            // Security validation
            try await securityValidator.validatePluginBundle(bundleURL, metadata: metadata)
            
            // Create sandbox environment
            let sandbox = try sandboxManager.createSandbox(for: metadata)
            
            // Load the plugin bundle
            guard let bundle = Bundle(url: bundleURL) else {
                throw PluginError.executionError("Failed to create bundle from URL")
            }
            
            // Load the principal class
            try bundle.loadAndReturnError()
            
            guard let principalClassName = bundle.infoDictionary?["NSPrincipalClass"] as? String,
                  let principalClass = bundle.classNamed(principalClassName) as? NSObject.Type else {
                throw PluginError.executionError("Principal class not found")
            }
            
            // Instantiate the plugin
            guard let plugin = principalClass.init() as? PDFPlugin else {
                throw PluginError.executionError("Principal class doesn't conform to PDFPlugin")
            }
            
            // Create plugin context
            let context = PluginContext(
                hostVersion: hostVersion,
                sandboxContainer: sandbox.containerURL,
                temporaryDirectory: sandbox.temporaryDirectory,
                configurationDirectory: getConfigurationDirectory(for: identifier),
                logger: PluginLoggerImpl(pluginId: identifier),
                resourceManager: resourceManager
            )
            
            // Initialize the plugin
            try await plugin.initialize(context: context)
            
            // Create loaded plugin wrapper
            let loadedPlugin = LoadedPlugin(
                metadata: metadata,
                plugin: plugin,
                bundle: bundle,
                sandbox: sandbox,
                context: context,
                loadTime: Date()
            )
            
            // Store loaded plugin
            loadedPlugins[identifier] = loadedPlugin
            
            // Remove any previous errors
            pluginErrors.removeValue(forKey: identifier)
            
            logger.info("Successfully loaded plugin: \(identifier)")
            
        } catch {
            logger.error("Failed to load plugin \(identifier): \(error)")
            
            if let pluginError = error as? PluginError {
                pluginErrors[identifier] = pluginError
                throw pluginError
            } else {
                let wrappedError = PluginError.executionError(error.localizedDescription)
                pluginErrors[identifier] = wrappedError
                throw wrappedError
            }
        }
    }
    
    /// Unload a plugin by its identifier
    func unloadPlugin(_ identifier: String) async {
        guard let loadedPlugin = loadedPlugins[identifier] else {
            logger.info("Plugin \(identifier) is not loaded")
            return
        }
        
        logger.info("Unloading plugin: \(identifier)")
        
        do {
            // Deinitialize the plugin
            await loadedPlugin.plugin.deinitialize()
            
            // Clean up sandbox
            sandboxManager.cleanupSandbox(loadedPlugin.sandbox)
            
            // Clean up resources
            resourceManager.cleanupResources(for: identifier)
            
            // Remove from loaded plugins
            loadedPlugins.removeValue(forKey: identifier)
            
            logger.info("Successfully unloaded plugin: \(identifier)")
            
        } catch {
            logger.error("Error during plugin unload \(identifier): \(error)")
        }
    }
    
    // MARK: - Plugin Execution
    
    /// Execute a plugin action safely with timeout and resource limits
    func executePluginAction(_ pluginId: String, action: String, parameters: [String: Any]) async throws -> PluginExecutionResult {
        guard let loadedPlugin = loadedPlugins[pluginId] else {
            throw PluginError.executionError("Plugin \(pluginId) is not loaded")
        }
        
        let startTime = Date()
        
        return try await withThrowingTimeout(maxExecutionTime) {
            // Check resource limits before execution
            try self.resourceManager.checkResourceLimits()
            
            // Create plugin request
            let request = PluginRequest(
                id: UUID(),
                action: action,
                parameters: parameters.compactMapValues { value in
                    // Only wrap values that are already Codable
                    if let codableValue = value as? any Codable {
                        return AnyCodable(codableValue)
                    }
                    return nil
                },
                timestamp: Date()
            )
            
            let message = PluginMessage.request(request)
            
            // Execute in sandbox
            let response = try await self.sandboxManager.executeInSandbox(loadedPlugin.sandbox) {
                return try await loadedPlugin.plugin.handleMessage(message)
            }
            
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Process response
            if let responseMessage = response,
               case .response(let pluginResponse) = responseMessage {
                return PluginExecutionResult(
                    success: pluginResponse.success,
                    result: pluginResponse.result,
                    error: pluginResponse.error.map { PluginError.executionError($0) },
                    executionTime: executionTime,
                    resourcesUsed: [:] // TODO: Collect actual resource usage
                )
            } else {
                return PluginExecutionResult(
                    success: false,
                    result: nil,
                    error: .communicationFailure("No valid response received"),
                    executionTime: executionTime,
                    resourcesUsed: [:]
                )
            }
        }
    }
    
    // MARK: - Plugin Information
    
    /// Get list of plugins supporting PDF processing
    func getPDFProcessingPlugins() -> [PluginMetadata] {
        return availablePlugins.filter { $0.capabilities.contains(.pdfProcessing) }
    }
    
    /// Get list of plugins supporting export formats
    func getExportFormatPlugins() -> [PluginMetadata] {
        return availablePlugins.filter { $0.capabilities.contains(.imageExport) }
    }
    
    /// Check if a plugin is loaded
    func isPluginLoaded(_ identifier: String) -> Bool {
        return loadedPlugins[identifier] != nil
    }
    
    /// Get plugin configuration schema
    func getPluginConfiguration(_ identifier: String) -> PluginSettingsSchema? {
        return loadedPlugins[identifier]?.plugin.getConfigurationSchema()
    }
    
    // MARK: - Helper Methods
    
    private func findPluginBundle(for metadata: PluginMetadata) -> URL? {
        let bundleName = "\(metadata.identifier).plugin"
        
        for searchPath in pluginSearchPaths {
            let bundleURL = searchPath.appendingPathComponent(bundleName)
            if fileManager.fileExists(atPath: bundleURL.path) {
                return bundleURL
            }
        }
        
        return nil
    }
    
    private func getConfigurationDirectory(for pluginId: String) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("AlmostBrutal/PluginConfigs/\(pluginId)", isDirectory: true)
        try? fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir
    }
    
    private func setupMessageHandlers() {
        // Set up built-in message handlers
        messageHandlers["ping"] = { message in
            return PluginMessage.response(PluginResponse(
                requestId: UUID(),
                success: true,
                result: ["status": AnyCodable("pong")],
                error: nil,
                timestamp: Date()
            ))
        }
        
        messageHandlers["getHostInfo"] = { message in
            return PluginMessage.response(PluginResponse(
                requestId: UUID(),
                success: true,
                result: [
                    "version": AnyCodable(self.hostVersion.description as String),
                    "build": AnyCodable((Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "unknown")
                ],
                error: nil,
                timestamp: Date()
            ))
        }
    }
}

// MARK: - Supporting Types

/// Wrapper for a loaded plugin with its context
struct LoadedPlugin {
    let metadata: PluginMetadata
    let plugin: PDFPlugin
    let bundle: Bundle
    let sandbox: PluginSandbox
    let context: PluginContext
    let loadTime: Date
}

/// Plugin sandbox environment
struct PluginSandbox {
    let identifier: String
    let containerURL: URL
    let temporaryDirectory: URL
    let allowedCapabilities: PluginCapabilities
}

// MARK: - Timeout Helper

func withThrowingTimeout<R>(_ timeout: TimeInterval, operation: @escaping () async throws -> R) async throws -> R {
    return try await withThrowingTaskGroup(of: R.self) { group in
        // Add the main operation
        group.addTask {
            try await operation()
        }
        
        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            throw PluginError.resourceLimitExceeded("Operation timed out after \(timeout) seconds")
        }
        
        // Return the first completed result and cancel the rest
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

// MARK: - Plugin Logger Implementation

private class PluginLoggerImpl: PluginLogger {
    private let pluginId: String
    private let logger: Logger
    
    init(pluginId: String) {
        self.pluginId = pluginId
        self.logger = Logger(subsystem: "com.almostbrutal.pdf.plugins", category: pluginId)
    }
    
    func debug(_ message: String, file: String = #file, line: Int = #line) {
        logger.debug("[\(self.pluginId)] \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
    }
    
    func info(_ message: String, file: String = #file, line: Int = #line) {
        logger.info("[\(self.pluginId)] \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
    }
    
    func warning(_ message: String, file: String = #file, line: Int = #line) {
        logger.warning("[\(self.pluginId)] \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
    }
    
    func error(_ message: String, file: String = #file, line: Int = #line) {
        logger.error("[\(self.pluginId)] \(message) (\(URL(fileURLWithPath: file).lastPathComponent):\(line))")
    }
}

// MARK: - Plugin Resource Manager Implementation

private class PluginResourceManagerImpl: PluginResourceManager {
    private let fileManager = FileManager.default
    private var temporaryFiles: [String: Set<URL>] = [:]
    private var resourceUsage: [String: UInt64] = [:]
    private let maxResourceUsage: UInt64 = 100 * 1024 * 1024 // 100MB per plugin
    
    func requestTemporaryFile(extension: String) throws -> URL {
        let tempDir = fileManager.temporaryDirectory
        let fileName = UUID().uuidString + "." + `extension`
        return tempDir.appendingPathComponent(fileName)
    }
    
    func requestDirectoryAccess(_ url: URL) throws -> Bool {
        // In a real implementation, this would check sandbox permissions
        return fileManager.fileExists(atPath: url.path)
    }
    
    func cleanupResources(for pluginId: String) {
        // Clean up temporary files
        if let files = temporaryFiles[pluginId] {
            for file in files {
                try? fileManager.removeItem(at: file)
            }
            temporaryFiles.removeValue(forKey: pluginId)
        }
        
        // Reset resource usage
        resourceUsage.removeValue(forKey: pluginId)
    }
    
    func checkResourceLimits() throws {
        let totalUsage = resourceUsage.values.reduce(0, +)
        if totalUsage > maxResourceUsage {
            throw PluginError.resourceLimitExceeded("Total resource usage exceeds limit")
        }
    }
}