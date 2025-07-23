import Foundation
import PDFKit
import AppKit
import SwiftUI

// MARK: - Plugin Metadata

/// Semantic version structure for plugin compatibility
struct PluginVersion: Codable, Comparable, CustomStringConvertible, Hashable {
    let major: Int
    let minor: Int
    let patch: Int
    
    init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    init?(from string: String) {
        let components = string.split(separator: ".").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }
        self.major = components[0]
        self.minor = components[1]
        self.patch = components.count > 2 ? components[2] : 0
    }
    
    var description: String {
        return "\(major).\(minor).\(patch)"
    }
    
    static func < (lhs: PluginVersion, rhs: PluginVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
    
    /// Check if this version is compatible with a required version range
    func isCompatible(with requirement: PluginVersionRequirement) -> Bool {
        return self >= requirement.minimum && (requirement.maximum == nil || self <= requirement.maximum!)
    }
}

/// Version requirement for host app compatibility
struct PluginVersionRequirement: Codable, Hashable {
    let minimum: PluginVersion
    let maximum: PluginVersion?
    
    init(minimum: PluginVersion, maximum: PluginVersion? = nil) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

/// Plugin capability flags
struct PluginCapabilities: Codable, OptionSet, Hashable {
    let rawValue: UInt32
    
    static let pdfProcessing = PluginCapabilities(rawValue: 1 << 0)
    static let imageExport = PluginCapabilities(rawValue: 1 << 1)
    static let batchProcessing = PluginCapabilities(rawValue: 1 << 2)
    static let userInterface = PluginCapabilities(rawValue: 1 << 3)
    static let fileSystemAccess = PluginCapabilities(rawValue: 1 << 4)
    static let networkAccess = PluginCapabilities(rawValue: 1 << 5)
    
    var description: String {
        var capabilities: [String] = []
        if contains(.pdfProcessing) { capabilities.append("PDF Processing") }
        if contains(.imageExport) { capabilities.append("Image Export") }
        if contains(.batchProcessing) { capabilities.append("Batch Processing") }
        if contains(.userInterface) { capabilities.append("User Interface") }
        if contains(.fileSystemAccess) { capabilities.append("File System Access") }
        if contains(.networkAccess) { capabilities.append("Network Access") }
        return capabilities.joined(separator: ", ")
    }
}

/// Plugin metadata structure
struct PluginMetadata: Codable {
    let identifier: String
    let name: String
    let version: PluginVersion
    let author: String
    let description: String
    let website: URL?
    let supportEmail: String?
    
    // Compatibility and requirements
    let hostVersionRequirement: PluginVersionRequirement
    let swiftVersion: String
    let minimumMacOSVersion: String
    
    // Capabilities and permissions
    let capabilities: PluginCapabilities
    let requiredEntitlements: [String]
    
    // Security and integrity
    let codeSigningIdentity: String?
    let teamIdentifier: String?
    let bundleIdentifier: String
    let checksumSHA256: String?
    
    // UI Integration
    let displayName: String
    let iconName: String?
    let menuItems: [PluginMenuItem]
    let settingsSchema: PluginSettingsSchema?
    
    // Validation
    func validate() throws {
        guard !identifier.isEmpty else {
            throw PluginError.invalidMetadata("Plugin identifier cannot be empty")
        }
        
        guard !name.isEmpty else {
            throw PluginError.invalidMetadata("Plugin name cannot be empty")
        }
        
        guard !bundleIdentifier.isEmpty else {
            throw PluginError.invalidMetadata("Bundle identifier cannot be empty")
        }
        
        // Validate bundle identifier format
        let bundlePattern = #"^[a-zA-Z][a-zA-Z0-9\-]*(\.[a-zA-Z][a-zA-Z0-9\-]*)+$"#
        guard bundleIdentifier.range(of: bundlePattern, options: .regularExpression) != nil else {
            throw PluginError.invalidMetadata("Invalid bundle identifier format")
        }
    }
}

/// Plugin menu item definition
struct PluginMenuItem: Codable {
    let title: String
    let action: String
    let keyEquivalent: String?
    let modifierMask: Int?
    let submenu: [PluginMenuItem]?
    let separator: Bool
    
    init(title: String, action: String, keyEquivalent: String? = nil, modifierMask: Int? = nil, submenu: [PluginMenuItem]? = nil, separator: Bool = false) {
        self.title = title
        self.action = action
        self.keyEquivalent = keyEquivalent
        self.modifierMask = modifierMask
        self.submenu = submenu
        self.separator = separator
    }
    
    static func separator() -> PluginMenuItem {
        return PluginMenuItem(title: "", action: "", separator: true)
    }
}

/// Plugin settings schema for configuration UI
struct PluginSettingsSchema: Codable {
    let settings: [PluginSetting]
    
    struct PluginSetting: Codable {
        let key: String
        let title: String
        let description: String?
        let type: SettingType
        let defaultValue: SettingValue
        let validation: SettingValidation?
        
        enum SettingType: String, Codable {
            case string, integer, double, boolean, url, color, file, directory
        }
        
        enum SettingValue: Codable {
            case string(String)
            case integer(Int)
            case double(Double)
            case boolean(Bool)
            case url(URL)
            case color(String) // Hex color
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .string(value)
                } else if let value = try? container.decode(Int.self) {
                    self = .integer(value)
                } else if let value = try? container.decode(Double.self) {
                    self = .double(value)
                } else if let value = try? container.decode(Bool.self) {
                    self = .boolean(value)
                } else {
                    throw DecodingError.typeMismatch(SettingValue.self, 
                        DecodingError.Context(codingPath: decoder.codingPath, 
                                            debugDescription: "Unknown setting value type"))
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .string(let value):
                    try container.encode(value)
                case .integer(let value):
                    try container.encode(value)
                case .double(let value):
                    try container.encode(value)
                case .boolean(let value):
                    try container.encode(value)
                case .url(let value):
                    try container.encode(value.absoluteString)
                case .color(let value):
                    try container.encode(value)
                }
            }
        }
        
        struct SettingValidation: Codable {
            let required: Bool?
            let minLength: Int?
            let maxLength: Int?
            let minValue: Double?
            let maxValue: Double?
            let pattern: String?
            let allowedValues: [SettingValue]?
        }
    }
}

// MARK: - Plugin Communication

/// Message types for plugin communication
enum PluginMessage: Codable {
    case request(PluginRequest)
    case response(PluginResponse)
    case notification(PluginNotification)
    case error(PluginError)
}

struct PluginRequest: Codable {
    let id: UUID
    let action: String
    let parameters: [String: AnyCodable]
    let timestamp: Date
}

struct PluginResponse: Codable {
    let requestId: UUID
    let success: Bool
    let result: [String: AnyCodable]?
    let error: String?
    let timestamp: Date
}

struct PluginNotification: Codable {
    let event: String
    let data: [String: AnyCodable]
    let timestamp: Date
}

/// Type-erased Codable wrapper for heterogeneous data
struct AnyCodable: Codable {
    let value: Any
    
    init<T: Codable>(_ value: T) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, 
                DecodingError.Context(codingPath: decoder.codingPath, 
                                    debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let value as String:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as Bool:
            try container.encode(value)
        case let value as [String: AnyCodable]:
            try container.encode(value)
        case let value as [AnyCodable]:
            try container.encode(value)
        default:
            throw EncodingError.invalidValue(value, 
                EncodingError.Context(codingPath: encoder.codingPath, 
                                    debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Core Plugin Protocols

/// Base protocol that all plugins must conform to
protocol PDFPlugin: AnyObject {
    /// Plugin metadata
    var metadata: PluginMetadata { get }
    
    /// Initialize the plugin with host context
    func initialize(context: PluginContext) async throws
    
    /// Cleanup resources before plugin unload
    func deinitialize() async
    
    /// Handle incoming messages from host
    func handleMessage(_ message: PluginMessage) async throws -> PluginMessage?
    
    /// Get plugin configuration schema
    func getConfigurationSchema() -> PluginSettingsSchema?
    
    /// Validate plugin configuration
    func validateConfiguration(_ config: [String: Any]) throws
}

/// Protocol for PDF processing plugins
protocol PDFProcessingPlugin: PDFPlugin {
    /// Process PDF document with given parameters
    func processPDF(_ document: PDFDocument, parameters: [String: Any]) async throws -> PDFDocument
    
    /// Get supported processing actions
    func getSupportedActions() -> [String]
    
    /// Validate processing parameters
    func validateParameters(_ parameters: [String: Any], for action: String) throws
}

/// Protocol for export format plugins
protocol ExportFormatPlugin: PDFPlugin {
    /// Export PDF to custom format
    func exportPDF(_ document: PDFDocument, to url: URL, options: ExportOptions) async throws
    
    /// Get supported export formats
    func getSupportedFormats() -> [ExportFormatInfo]
    
    /// Get export options schema for a specific format
    func getExportOptionsSchema(for format: String) -> PluginSettingsSchema?
}

/// Export format information
struct ExportFormatInfo: Codable {
    let identifier: String
    let displayName: String
    let fileExtension: String
    let mimeType: String
    let supportsMultiPage: Bool
    let supportedOptions: [String]
}

/// Export options for plugins
struct ExportOptions: Codable {
    let format: String
    let quality: Double?
    let dpi: Int?
    let colorSpace: String?
    let compression: String?
    let customOptions: [String: AnyCodable]
}

/// Plugin execution context provided by host
struct PluginContext {
    let hostVersion: PluginVersion
    let sandboxContainer: URL
    let temporaryDirectory: URL
    let configurationDirectory: URL
    let logger: PluginLogger
    let resourceManager: PluginResourceManager
    
    /// Check if plugin has required capability
    func hasCapability(_ capability: PluginCapabilities) -> Bool {
        // Implementation will be in PluginManager
        return false
    }
}

/// Plugin logging interface
protocol PluginLogger {
    func debug(_ message: String, file: String, line: Int)
    func info(_ message: String, file: String, line: Int)
    func warning(_ message: String, file: String, line: Int)
    func error(_ message: String, file: String, line: Int)
}

/// Plugin resource management interface
protocol PluginResourceManager {
    /// Request temporary file access
    func requestTemporaryFile(extension: String) throws -> URL
    
    /// Request directory access with security scoping
    func requestDirectoryAccess(_ url: URL) throws -> Bool
    
    /// Clean up plugin resources
    func cleanupResources(for pluginId: String)
    
    /// Check resource usage limits
    func checkResourceLimits() throws
}

// MARK: - Plugin Errors

enum PluginError: LocalizedError, CustomStringConvertible, Codable, Hashable {
    case invalidMetadata(String)
    case incompatibleVersion(required: PluginVersionRequirement, found: PluginVersion)
    case missingCapability(PluginCapabilities)
    case initializationFailed(String)
    case executionError(String)
    case securityViolation(String)
    case resourceLimitExceeded(String)
    case invalidConfiguration(String)
    case communicationFailure(String)
    case sandboxViolation(String)
    case codeSigningFailure(String)
    case unsupportedOperation(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMetadata(let reason):
            return "Invalid plugin metadata: \(reason)"
        case .incompatibleVersion(let required, let found):
            return "Plugin version \(found) is not compatible with required version range \(required.minimum)-\(required.maximum?.description ?? "latest")"
        case .missingCapability(let capability):
            return "Plugin lacks required capability: \(capability.description)"
        case .initializationFailed(let reason):
            return "Plugin initialization failed: \(reason)"
        case .executionError(let reason):
            return "Plugin execution error: \(reason)"
        case .securityViolation(let reason):
            return "Security violation: \(reason)"
        case .resourceLimitExceeded(let reason):
            return "Resource limit exceeded: \(reason)"
        case .invalidConfiguration(let reason):
            return "Invalid plugin configuration: \(reason)"
        case .communicationFailure(let reason):
            return "Plugin communication failure: \(reason)"
        case .sandboxViolation(let reason):
            return "Sandbox violation: \(reason)"
        case .codeSigningFailure(let reason):
            return "Code signing verification failed: \(reason)"
        case .unsupportedOperation(let operation):
            return "Unsupported operation: \(operation)"
        }
    }
    
    var description: String {
        return errorDescription ?? "Unknown plugin error"
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidMetadata:
            return "Check the plugin's metadata.json file for required fields and correct formatting"
        case .incompatibleVersion:
            return "Update the plugin to a compatible version"
        case .missingCapability:
            return "Install a plugin version that includes the required capabilities"
        case .invalidConfiguration:
            return "Check plugin settings for required fields and valid values"
        default:
            return nil
        }
    }
}

/// Plugin execution result
struct PluginExecutionResult {
    let success: Bool
    let result: Any?
    let error: PluginError?
    let executionTime: TimeInterval
    let resourcesUsed: [String: Any]
}