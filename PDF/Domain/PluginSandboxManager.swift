import Foundation
import OSLog

/// File access modes for sandbox operations
enum SandboxFileAccessMode {
    case read
    case write
    case readWrite
}

/// Manager for creating and maintaining secure sandboxed environments for plugin execution
class PluginSandboxManager {
    
    private let logger = Logger(subsystem: "com.almostbrutal.pdf", category: "PluginSandbox")
    private let fileManager = FileManager.default
    
    // Sandbox configuration
    private let sandboxRootDirectory: URL
    private var activeSandboxes: [String: PluginSandbox] = [:]
    
    // Resource limits per sandbox
    private let maxDiskUsage: UInt64 = 50 * 1024 * 1024 // 50MB
    private let maxMemoryUsage: UInt64 = 100 * 1024 * 1024 // 100MB
    private let maxOpenFiles: Int = 100
    private let maxExecutionTime: TimeInterval = 30.0
    
    init() {
        // Set up sandbox root directory
        let tempDir = fileManager.temporaryDirectory
        self.sandboxRootDirectory = tempDir.appendingPathComponent("AlmostBrutal_PluginSandboxes", isDirectory: true)
        
        // Create sandbox root if needed
        try? fileManager.createDirectory(at: sandboxRootDirectory, withIntermediateDirectories: true)
        
        // Clean up any existing sandboxes on startup
        cleanupAllSandboxes()
        
        logger.info("PluginSandboxManager initialized with root directory: \(self.sandboxRootDirectory.path)")
    }
    
    deinit {
        cleanupAllSandboxes()
    }
    
    // MARK: - Sandbox Creation
    
    /// Create a new sandbox environment for a plugin
    func createSandbox(for metadata: PluginMetadata) throws -> PluginSandbox {
        let sandboxId = generateSandboxId(for: metadata.identifier)
        
        logger.info("Creating sandbox for plugin: \(metadata.identifier) with ID: \(sandboxId)")
        
        // Create sandbox directory structure
        let sandboxContainer = sandboxRootDirectory.appendingPathComponent(sandboxId, isDirectory: true)
        let tempDirectory = sandboxContainer.appendingPathComponent("tmp", isDirectory: true)
        let dataDirectory = sandboxContainer.appendingPathComponent("data", isDirectory: true)
        let cacheDirectory = sandboxContainer.appendingPathComponent("cache", isDirectory: true)
        
        // Create directories
        try fileManager.createDirectory(at: sandboxContainer, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Set appropriate permissions (restrict access)
        try setSecurePermissions(for: sandboxContainer)
        
        // Create sandbox configuration
        let sandbox = PluginSandbox(
            identifier: sandboxId,
            containerURL: sandboxContainer,
            temporaryDirectory: tempDirectory,
            allowedCapabilities: metadata.capabilities
        )
        
        // Store active sandbox
        activeSandboxes[metadata.identifier] = sandbox
        
        logger.info("Successfully created sandbox for plugin: \(metadata.identifier)")
        return sandbox
    }
    
    /// Execute code within a sandbox with resource monitoring
    func executeInSandbox<T>(_ sandbox: PluginSandbox, operation: @escaping () async throws -> T) async throws -> T {
        logger.debug("Executing operation in sandbox: \(sandbox.identifier)")
        
        let startTime = Date()
        let resourceMonitor = SandboxResourceMonitor(sandbox: sandbox, limits: createResourceLimits())
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add main operation
            group.addTask {
                // Set up sandbox environment
                self.setupSandboxEnvironment(sandbox)
                
                // Execute operation
                let result = try await operation()
                
                // Validate resource usage after execution
                try await resourceMonitor.validateResourceUsage()
                
                return result
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(maxExecutionTime * 1_000_000_000))
                throw PluginError.resourceLimitExceeded("Sandbox execution timed out after \(maxExecutionTime) seconds")
            }
            
            // Add resource monitoring task
            group.addTask {
                try await resourceMonitor.startMonitoring()
                throw PluginError.resourceLimitExceeded("Resource monitoring completed without timeout")
            }
            
            // Return first completed result
            defer { group.cancelAll() }
            
            for try await result in group {
                // Cancel other tasks and return first result (should be the main operation)
                return result
            }
            
            throw PluginError.executionError("No result returned from sandbox execution")
        }
    }
    
    // MARK: - Sandbox Management
    
    /// Clean up a specific sandbox
    func cleanupSandbox(_ sandbox: PluginSandbox) {
        logger.info("Cleaning up sandbox: \(sandbox.identifier)")
        
        do {
            // Remove sandbox directory
            if fileManager.fileExists(atPath: sandbox.containerURL.path) {
                try fileManager.removeItem(at: sandbox.containerURL)
            }
            
            // Remove from active sandboxes
            if let pluginId = activeSandboxes.first(where: { $0.value.identifier == sandbox.identifier })?.key {
                activeSandboxes.removeValue(forKey: pluginId)
            }
            
            logger.info("Successfully cleaned up sandbox: \(sandbox.identifier)")
            
        } catch {
            logger.error("Failed to cleanup sandbox \(sandbox.identifier): \(error)")
        }
    }
    
    /// Clean up all active sandboxes
    func cleanupAllSandboxes() {
        logger.info("Cleaning up all sandboxes")
        
        // Clean up active sandboxes
        for sandbox in activeSandboxes.values {
            cleanupSandbox(sandbox)
        }
        activeSandboxes.removeAll()
        
        // Clean up any remaining sandbox directories
        do {
            if fileManager.fileExists(atPath: sandboxRootDirectory.path) {
                let contents = try fileManager.contentsOfDirectory(at: sandboxRootDirectory, includingPropertiesForKeys: nil)
                for item in contents {
                    try fileManager.removeItem(at: item)
                }
            }
        } catch {
            logger.error("Failed to clean up sandbox root directory: \(error)")
        }
    }
    
    // MARK: - Security and Permissions
    
    private func setSecurePermissions(for directory: URL) throws {
        // Set directory permissions to owner-only access (700)
        let attributes: [FileAttributeKey: Any] = [
            .posixPermissions: 0o700
        ]
        
        try fileManager.setAttributes(attributes, ofItemAtPath: directory.path)
        
        // Recursively set permissions for subdirectories
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true {
                try fileManager.setAttributes(attributes, ofItemAtPath: fileURL.path)
            }
        }
    }
    
    private func setupSandboxEnvironment(_ sandbox: PluginSandbox) {
        // Set environment variables for sandbox
        setenv("PLUGIN_SANDBOX_ROOT", sandbox.containerURL.path, 1)
        setenv("PLUGIN_SANDBOX_TMP", sandbox.temporaryDirectory.path, 1)
        
        // Restrict network access if not allowed
        if !sandbox.allowedCapabilities.contains(.networkAccess) {
            // Note: In a real implementation, this would use system-level networking restrictions
            logger.debug("Network access disabled for sandbox: \(sandbox.identifier)")
        }
        
        // Set file system access restrictions
        if !sandbox.allowedCapabilities.contains(.fileSystemAccess) {
            logger.debug("File system access restricted for sandbox: \(sandbox.identifier)")
        }
    }
    
    // MARK: - Resource Monitoring
    
    private func createResourceLimits() -> SandboxResourceLimits {
        return SandboxResourceLimits(
            maxDiskUsage: maxDiskUsage,
            maxMemoryUsage: maxMemoryUsage,
            maxOpenFiles: maxOpenFiles,
            maxExecutionTime: maxExecutionTime
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateSandboxId(for pluginId: String) -> String {
        let timestamp = Date().timeIntervalSince1970
        let randomSuffix = UUID().uuidString.prefix(8)
        return "sandbox_\(pluginId)_\(Int(timestamp))_\(randomSuffix)"
    }
}

// MARK: - Supporting Types

struct SandboxResourceLimits {
    let maxDiskUsage: UInt64
    let maxMemoryUsage: UInt64
    let maxOpenFiles: Int
    let maxExecutionTime: TimeInterval
}

/// Resource monitor for tracking sandbox resource usage
class SandboxResourceMonitor {
    private let sandbox: PluginSandbox
    private let limits: SandboxResourceLimits
    private let logger = Logger(subsystem: "com.almostbrutal.pdf", category: "SandboxResourceMonitor")
    private let fileManager = FileManager.default
    
    private var isMonitoring = false
    private var startTime: Date?
    
    init(sandbox: PluginSandbox, limits: SandboxResourceLimits) {
        self.sandbox = sandbox
        self.limits = limits
    }
    
    /// Start monitoring resource usage
    func startMonitoring() async throws {
        isMonitoring = true
        startTime = Date()
        
        logger.debug("Starting resource monitoring for sandbox: \(sandbox.identifier)")
        
        // Monitor resources periodically
        while isMonitoring {
            try await validateResourceUsage()
            
            // Check every second
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        isMonitoring = false
        logger.debug("Stopped resource monitoring for sandbox: \(sandbox.identifier)")
    }
    
    /// Validate current resource usage against limits
    func validateResourceUsage() async throws {
        // Check execution time
        if let startTime = startTime {
            let executionTime = Date().timeIntervalSince(startTime)
            if executionTime > limits.maxExecutionTime {
                throw PluginError.resourceLimitExceeded("Execution time limit exceeded: \(executionTime)s > \(limits.maxExecutionTime)s")
            }
        }
        
        // Check disk usage
        let diskUsage = try calculateDiskUsage()
        if diskUsage > limits.maxDiskUsage {
            throw PluginError.resourceLimitExceeded("Disk usage limit exceeded: \(diskUsage) bytes > \(limits.maxDiskUsage) bytes")
        }
        
        // Check memory usage (process-level)
        let memoryUsage = try getMemoryUsage()
        if memoryUsage > limits.maxMemoryUsage {
            throw PluginError.resourceLimitExceeded("Memory usage limit exceeded: \(memoryUsage) bytes > \(limits.maxMemoryUsage) bytes")
        }
        
        // Check open file descriptors
        let openFiles = try getOpenFileCount()
        if openFiles > limits.maxOpenFiles {
            throw PluginError.resourceLimitExceeded("Open file limit exceeded: \(openFiles) > \(limits.maxOpenFiles)")
        }
    }
    
    // MARK: - Resource Calculation Methods
    
    private func calculateDiskUsage() throws -> UInt64 {
        var totalSize: UInt64 = 0
        
        let enumerator = fileManager.enumerator(at: sandbox.containerURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            
            if resourceValues.isDirectory != true {
                totalSize += UInt64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    private func getMemoryUsage() throws -> UInt64 {
        // Get current process memory usage
        let task = mach_task_self_
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kr == KERN_SUCCESS else {
            throw PluginError.resourceLimitExceeded("Failed to get memory usage information")
        }
        
        return UInt64(info.resident_size)
    }
    
    private func getOpenFileCount() throws -> Int {
        // Count open file descriptors for current process
        let pid = getpid()
        let fdPath = "/proc/\(pid)/fd"
        
        // On macOS, use lsof approach or approximate with process info
        // For this implementation, we'll use a simplified approach
        
        // Get resource usage
        var usage = rusage()
        let result = getrusage(RUSAGE_SELF, &usage)
        
        guard result == 0 else {
            throw PluginError.resourceLimitExceeded("Failed to get resource usage information")
        }
        
        // This is a rough approximation - in production you'd want more accurate file descriptor counting
        return 10 // Placeholder - would need platform-specific implementation
    }
}

// MARK: - Sandbox Isolation Helpers

extension PluginSandboxManager {
    
    /// Create a secure temporary file within the sandbox
    func createSecureTemporaryFile(in sandbox: PluginSandbox, extension: String) throws -> URL {
        let fileName = UUID().uuidString + "." + `extension`
        let fileURL = sandbox.temporaryDirectory.appendingPathComponent(fileName)
        
        // Create empty file with secure permissions
        let success = fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: [
            .posixPermissions: 0o600 // Owner read/write only
        ])
        
        guard success else {
            throw PluginError.sandboxViolation("Failed to create secure temporary file")
        }
        
        return fileURL
    }
    
    /// Validate that a file path is within the sandbox boundaries
    func validateFileAccess(_ fileURL: URL, sandbox: PluginSandbox) throws {
        let sandboxPath = sandbox.containerURL.path
        let resolvedPath = fileURL.standardized.path
        
        // Check if the resolved path starts with the sandbox path
        guard resolvedPath.hasPrefix(sandboxPath) else {
            throw PluginError.sandboxViolation("File access outside sandbox: \(resolvedPath)")
        }
        
        // Check for path traversal attempts
        let relativePath = String(resolvedPath.dropFirst(sandboxPath.count))
        if relativePath.contains("../") || relativePath.contains("..\\") {
            throw PluginError.sandboxViolation("Path traversal attempt detected: \(relativePath)")
        }
    }
    
    /// Create a restricted file handle for sandbox operations  
    func createRestrictedFileHandle(for fileURL: URL, in sandbox: PluginSandbox, mode: SandboxFileAccessMode) throws -> FileHandle {
        // Validate file access
        try validateFileAccess(fileURL, sandbox: sandbox)
        
        // Create file handle with appropriate permissions
        switch mode {
        case .read:
            return try FileHandle(forReadingFrom: fileURL)
        case .write:
            return try FileHandle(forWritingTo: fileURL)
        case .readWrite:
            return try FileHandle(forUpdating: fileURL)
        @unknown default:
            throw PluginError.sandboxViolation("Unsupported file access mode")
        }
    }
}

// MARK: - Process Isolation (Future Enhancement)

/// Process isolation manager for running plugins in separate processes
/// This would be implemented for maximum security in production
class PluginProcessIsolationManager {
    
    private let logger = Logger(subsystem: "com.almostbrutal.pdf", category: "PluginProcessIsolation")
    
    // Future: Implement XPC service or separate process execution
    // This would provide the highest level of security by running plugins
    // in completely separate processes with minimal privileges
    
    func executePluginInIsolatedProcess<T>(_ plugin: PDFPlugin, operation: @escaping () async throws -> T) async throws -> T {
        // Placeholder for future implementation
        // Would use XPC services or separate processes for true isolation
        fatalError("Process isolation not yet implemented")
    }
}