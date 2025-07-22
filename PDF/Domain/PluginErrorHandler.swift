import Foundation
import OSLog
import SwiftUI

/// Comprehensive error handling system for plugin failures with recovery mechanisms
@MainActor
class PluginErrorHandler: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeErrors: [PluginErrorReport] = []
    @Published var errorHistory: [PluginErrorReport] = []
    @Published var showingErrorDetails = false
    @Published var selectedError: PluginErrorReport?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.almostbrutal.pdf", category: "PluginErrorHandler")
    private let maxErrorHistory = 100
    private let maxActiveErrors = 10
    private weak var pluginManager: PluginManager?
    
    // Error recovery strategies
    private let recoveryStrategies: [PluginError: RecoveryStrategy] = [
        .incompatibleVersion(required: PluginVersionRequirement(minimum: PluginVersion(0, 0, 0)), found: PluginVersion(0, 0, 0)): .updatePlugin,
        .missingCapability(.pdfProcessing): .reinstallPlugin,
        .securityViolation(""): .blockPlugin,
        .resourceLimitExceeded(""): .restartPlugin,
        .sandboxViolation(""): .blockPlugin,
        .codeSigningFailure(""): .blockPlugin
    ]
    
    init(pluginManager: PluginManager?) {
        self.pluginManager = pluginManager
        setupErrorMonitoring()
    }
    
    // MARK: - Error Reporting
    
    /// Report a plugin error with automatic recovery attempt
    func reportError(_ error: Error, for pluginId: String, context: PluginErrorContext = .unknown, severity: PluginErrorSeverity = .error) {
        let errorReport = PluginErrorReport(
            id: UUID(),
            pluginId: pluginId,
            error: error,
            context: context,
            severity: severity,
            timestamp: Date(),
            recoveryAttempts: [],
            resolved: false
        )
        
        logger.error("Plugin error reported for \(pluginId): \(error.localizedDescription)")
        
        // Add to active errors
        addActiveError(errorReport)
        
        // Add to error history
        addToErrorHistory(errorReport)
        
        // Attempt automatic recovery if appropriate
        if severity != .warning {
            attemptRecovery(for: errorReport)
        }
        
        // Send analytics/telemetry (in production)
        sendErrorTelemetry(errorReport)
    }
    
    /// Report multiple errors from a plugin operation
    func reportErrors(_ errors: [Error], for pluginId: String, context: PluginErrorContext = .unknown) {
        for error in errors {
            let severity: PluginErrorSeverity = errors.count > 5 ? .critical : .error
            reportError(error, for: pluginId, context: context, severity: severity)
        }
    }
    
    /// Clear errors for a specific plugin
    func clearErrors(for pluginId: String) {
        activeErrors.removeAll { $0.pluginId == pluginId }
        logger.info("Cleared errors for plugin: \(pluginId)")
    }
    
    /// Clear all active errors
    func clearAllErrors() {
        activeErrors.removeAll()
        logger.info("Cleared all active plugin errors")
    }
    
    /// Mark an error as resolved
    func markErrorResolved(_ errorId: UUID) {
        if let index = activeErrors.firstIndex(where: { $0.id == errorId }) {
            activeErrors[index].resolved = true
            activeErrors[index].resolvedAt = Date()
            
            // Move to history if resolved
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.activeErrors.removeAll { $0.id == errorId }
            }
        }
        
        if let index = errorHistory.firstIndex(where: { $0.id == errorId }) {
            errorHistory[index].resolved = true
            errorHistory[index].resolvedAt = Date()
        }
    }
    
    // MARK: - Error Recovery
    
    /// Attempt automatic recovery for an error
    private func attemptRecovery(for errorReport: PluginErrorReport) {
        guard let pluginError = errorReport.error as? PluginError else {
            // Try generic recovery strategies for non-plugin errors
            attemptGenericRecovery(for: errorReport)
            return
        }
        
        let strategy = determineRecoveryStrategy(for: pluginError, errorReport: errorReport)
        
        Task {
            do {
                let success = try await executeRecoveryStrategy(strategy, for: errorReport)
                
                await MainActor.run {
                    let recoveryAttempt = RecoveryAttempt(
                        strategy: strategy,
                        timestamp: Date(),
                        success: success,
                        details: success ? "Recovery successful" : "Recovery failed"
                    )
                    
                    self.updateErrorWithRecoveryAttempt(errorReport.id, attempt: recoveryAttempt)
                    
                    if success {
                        self.markErrorResolved(errorReport.id)
                        self.logger.info("Successfully recovered from error \(errorReport.id) for plugin \(errorReport.pluginId)")
                    } else {
                        self.logger.warning("Recovery attempt failed for error \(errorReport.id) for plugin \(errorReport.pluginId)")
                    }
                }
            } catch {
                await MainActor.run {
                    let recoveryAttempt = RecoveryAttempt(
                        strategy: strategy,
                        timestamp: Date(),
                        success: false,
                        details: "Recovery error: \(error.localizedDescription)"
                    )
                    
                    self.updateErrorWithRecoveryAttempt(errorReport.id, attempt: recoveryAttempt)
                    self.logger.error("Recovery attempt threw error for \(errorReport.pluginId): \(error)")
                }
            }
        }
    }
    
    /// Determine the best recovery strategy for an error
    private func determineRecoveryStrategy(for error: PluginError, errorReport: PluginErrorReport) -> RecoveryStrategy {
        // Check for specific strategy mappings
        for (errorPattern, strategy) in recoveryStrategies {
            if errorMatches(error, pattern: errorPattern) {
                return strategy
            }
        }
        
        // Determine strategy based on error type
        switch error {
        case .incompatibleVersion:
            return .updatePlugin
        case .missingCapability:
            return .reinstallPlugin
        case .securityViolation, .sandboxViolation, .codeSigningFailure:
            return .blockPlugin
        case .resourceLimitExceeded:
            return errorReport.context == .execution ? .restartPlugin : .reduceResources
        case .initializationFailed:
            return errorReport.recoveryAttempts.isEmpty ? .restartPlugin : .reinstallPlugin
        case .executionError:
            return .restartPlugin
        case .communicationFailure:
            return .restartCommunication
        default:
            return .restartPlugin
        }
    }
    
    /// Execute a recovery strategy
    private func executeRecoveryStrategy(_ strategy: RecoveryStrategy, for errorReport: PluginErrorReport) async throws -> Bool {
        guard let pluginManager = pluginManager else {
            throw PluginError.executionError("Plugin manager not available")
        }
        
        switch strategy {
        case .restartPlugin:
            return try await restartPlugin(errorReport.pluginId, pluginManager: pluginManager)
            
        case .reinstallPlugin:
            return try await reinstallPlugin(errorReport.pluginId, pluginManager: pluginManager)
            
        case .updatePlugin:
            return try await updatePlugin(errorReport.pluginId, pluginManager: pluginManager)
            
        case .blockPlugin:
            return try await blockPlugin(errorReport.pluginId, pluginManager: pluginManager)
            
        case .reduceResources:
            return try await reducePluginResources(errorReport.pluginId, pluginManager: pluginManager)
            
        case .restartCommunication:
            return try await restartPluginCommunication(errorReport.pluginId, pluginManager: pluginManager)
            
        case .ignore:
            return true
            
        case .userIntervention:
            await requestUserIntervention(for: errorReport)
            return false
        }
    }
    
    // MARK: - Recovery Strategy Implementations
    
    private func restartPlugin(_ pluginId: String, pluginManager: PluginManager) async throws -> Bool {
        logger.info("Attempting to restart plugin: \(pluginId)")
        
        // Unload the plugin
        await pluginManager.unloadPlugin(pluginId)
        
        // Wait a moment for cleanup
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Reload the plugin
        try await pluginManager.loadPlugin(pluginId)
        
        return pluginManager.isPluginLoaded(pluginId)
    }
    
    private func reinstallPlugin(_ pluginId: String, pluginManager: PluginManager) async throws -> Bool {
        logger.info("Attempting to reinstall plugin: \(pluginId)")
        
        // This would involve:
        // 1. Finding the original plugin bundle
        // 2. Re-validating and re-installing it
        // 3. Loading the fresh installation
        
        // For now, just restart - full reinstallation would be more complex
        return try await restartPlugin(pluginId, pluginManager: pluginManager)
    }
    
    private func updatePlugin(_ pluginId: String, pluginManager: PluginManager) async throws -> Bool {
        logger.info("Plugin update required for: \(pluginId)")
        
        // This would involve checking for plugin updates
        // For now, mark for user attention
        await requestUserIntervention(for: PluginErrorReport(
            id: UUID(),
            pluginId: pluginId,
            error: PluginError.incompatibleVersion(required: PluginVersionRequirement(minimum: PluginVersion(1, 0, 0)), found: PluginVersion(0, 9, 0)),
            context: .loading,
            severity: .warning,
            timestamp: Date(),
            recoveryAttempts: [],
            resolved: false
        ))
        
        return false
    }
    
    private func blockPlugin(_ pluginId: String, pluginManager: PluginManager) async throws -> Bool {
        logger.warning("Blocking plugin due to security concerns: \(pluginId)")
        
        // Unload the plugin
        await pluginManager.unloadPlugin(pluginId)
        
        // TODO: Add plugin to blocked list
        
        return true
    }
    
    private func reducePluginResources(_ pluginId: String, pluginManager: PluginManager) async throws -> Bool {
        logger.info("Attempting to reduce resource usage for plugin: \(pluginId)")
        
        // This would involve:
        // 1. Clearing plugin caches
        // 2. Reducing memory allocations
        // 3. Limiting concurrent operations
        
        // For now, restart the plugin to clear resources
        return try await restartPlugin(pluginId, pluginManager: pluginManager)
    }
    
    private func restartPluginCommunication(_ pluginId: String, pluginManager: PluginManager) async throws -> Bool {
        logger.info("Attempting to restart communication for plugin: \(pluginId)")
        
        // Reset communication channels
        // For now, restart the plugin
        return try await restartPlugin(pluginId, pluginManager: pluginManager)
    }
    
    private func requestUserIntervention(for errorReport: PluginErrorReport) async {
        logger.info("Requesting user intervention for plugin error: \(errorReport.id)")
        
        await MainActor.run {
            self.selectedError = errorReport
            self.showingErrorDetails = true
        }
    }
    
    // MARK: - Error Matching and Generic Recovery
    
    private func errorMatches(_ error: PluginError, pattern: PluginError) -> Bool {
        // Simple pattern matching - in production this could be more sophisticated
        switch (error, pattern) {
        case (.incompatibleVersion, .incompatibleVersion):
            return true
        case (.securityViolation, .securityViolation):
            return true
        case (.resourceLimitExceeded, .resourceLimitExceeded):
            return true
        default:
            return false
        }
    }
    
    private func attemptGenericRecovery(for errorReport: PluginErrorReport) {
        // Generic recovery strategies for non-plugin errors
        let strategy: RecoveryStrategy
        
        if errorReport.error.localizedDescription.lowercased().contains("memory") {
            strategy = .reduceResources
        } else if errorReport.error.localizedDescription.lowercased().contains("network") {
            strategy = .restartCommunication
        } else {
            strategy = .restartPlugin
        }
        
        Task {
            _ = try? await executeRecoveryStrategy(strategy, for: errorReport)
        }
    }
    
    // MARK: - Error Management
    
    private func addActiveError(_ errorReport: PluginErrorReport) {
        // Remove oldest errors if we have too many
        while activeErrors.count >= maxActiveErrors {
            if let oldestError = activeErrors.min(by: { $0.timestamp < $1.timestamp }) {
                activeErrors.removeAll { $0.id == oldestError.id }
            }
        }
        
        activeErrors.append(errorReport)
    }
    
    private func addToErrorHistory(_ errorReport: PluginErrorReport) {
        errorHistory.append(errorReport)
        
        // Keep history size manageable
        while errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst()
        }
    }
    
    private func updateErrorWithRecoveryAttempt(_ errorId: UUID, attempt: RecoveryAttempt) {
        if let index = activeErrors.firstIndex(where: { $0.id == errorId }) {
            activeErrors[index].recoveryAttempts.append(attempt)
        }
        
        if let index = errorHistory.firstIndex(where: { $0.id == errorId }) {
            errorHistory[index].recoveryAttempts.append(attempt)
        }
    }
    
    // MARK: - Error Monitoring Setup
    
    private func setupErrorMonitoring() {
        // Monitor system resources
        startResourceMonitoring()
        
        // Monitor plugin health
        startPluginHealthMonitoring()
    }
    
    private func startResourceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.checkSystemResources()
            }
        }
    }
    
    private func startPluginHealthMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task {
                await self.performPluginHealthCheck()
            }
        }
    }
    
    private func checkSystemResources() async {
        // Check memory usage
        let memoryUsage = getMemoryUsage()
        if memoryUsage > 0.9 { // 90% memory usage
            reportError(
                PluginError.resourceLimitExceeded("System memory usage critical: \(Int(memoryUsage * 100))%"),
                for: "system",
                context: .system,
                severity: .warning
            )
        }
    }
    
    private func performPluginHealthCheck() async {
        guard let pluginManager = pluginManager else { return }
        
        for pluginId in pluginManager.loadedPlugins.keys {
            // Perform basic health check
            do {
                _ = try await pluginManager.executePluginAction(pluginId, action: "ping", parameters: [:])
            } catch {
                reportError(error, for: pluginId, context: .healthCheck, severity: .warning)
            }
        }
    }
    
    // MARK: - Utility Methods
    
    private func getMemoryUsage() -> Double {
        let task = mach_task_self_
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(task, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kr == KERN_SUCCESS else { return 0.0 }
        
        // Return as percentage of available memory (simplified)
        return min(Double(info.resident_size) / (1024 * 1024 * 1024 * 8), 1.0) // Assume 8GB system memory
    }
    
    private func sendErrorTelemetry(_ errorReport: PluginErrorReport) {
        // In production, this would send error telemetry to analytics service
        // For privacy, only send anonymized error patterns, not sensitive data
        logger.debug("Would send error telemetry for pattern: \(type(of: errorReport.error))")
    }
}

// MARK: - Supporting Types

/// Plugin error report with recovery tracking
struct PluginErrorReport: Identifiable, Equatable {
    let id: UUID
    let pluginId: String
    let error: Error
    let context: PluginErrorContext
    let severity: PluginErrorSeverity
    let timestamp: Date
    var recoveryAttempts: [RecoveryAttempt]
    var resolved: Bool
    var resolvedAt: Date?
    
    static func == (lhs: PluginErrorReport, rhs: PluginErrorReport) -> Bool {
        lhs.id == rhs.id
    }
}

/// Context in which the error occurred
enum PluginErrorContext: String, CaseIterable {
    case loading = "Loading"
    case execution = "Execution"
    case communication = "Communication"
    case security = "Security"
    case resources = "Resources"
    case healthCheck = "Health Check"
    case system = "System"
    case unknown = "Unknown"
}

/// Error severity levels
enum PluginErrorSeverity: String, CaseIterable, Comparable {
    case info = "Info"
    case warning = "Warning"
    case error = "Error"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    static func < (lhs: PluginErrorSeverity, rhs: PluginErrorSeverity) -> Bool {
        let order: [PluginErrorSeverity] = [.info, .warning, .error, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

/// Recovery strategies
enum RecoveryStrategy: String, CaseIterable {
    case restartPlugin = "Restart Plugin"
    case reinstallPlugin = "Reinstall Plugin"
    case updatePlugin = "Update Plugin"
    case blockPlugin = "Block Plugin"
    case reduceResources = "Reduce Resources"
    case restartCommunication = "Restart Communication"
    case ignore = "Ignore"
    case userIntervention = "User Intervention Required"
}

/// Recovery attempt record
struct RecoveryAttempt {
    let strategy: RecoveryStrategy
    let timestamp: Date
    let success: Bool
    let details: String
}