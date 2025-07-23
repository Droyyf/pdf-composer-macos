import Foundation
import Security
import OSLog
import CryptoKit

/// Security validator for plugins that performs code signing verification,
/// integrity checks, and security policy enforcement
class PluginSecurityValidator {
    
    private let logger = Logger(subsystem: "com.almostbrutal.pdf", category: "PluginSecurity")
    private let fileManager = FileManager.default
    
    // Security configuration
    private let requireCodeSigning: Bool
    private let trustedTeamIds: Set<String>
    private let allowedCapabilities: PluginCapabilities
    
    init(requireCodeSigning: Bool = true) {
        self.requireCodeSigning = requireCodeSigning
        
        // Configure trusted team identifiers (in production, load from configuration)
        self.trustedTeamIds = Set([
            "TEAM_ID_1", // Add actual team IDs for trusted developers
            "TEAM_ID_2"
        ])
        
        // Define allowed capabilities for plugins
        self.allowedCapabilities = [
            .pdfProcessing,
            .imageExport,
            .batchProcessing,
            .userInterface
        ]
    }
    
    // MARK: - Plugin Bundle Validation
    
    /// Perform comprehensive security validation of a plugin bundle
    func validatePluginBundle(_ bundleURL: URL, metadata: PluginMetadata) async throws {
        logger.info("Starting security validation for plugin: \(metadata.identifier)")
        
        // 1. Basic bundle structure validation
        try validateBundleStructure(bundleURL)
        
        // 2. Code signing verification
        if requireCodeSigning {
            try validateCodeSigning(bundleURL, metadata: metadata)
        }
        
        // 3. Capability and entitlement validation
        try validateCapabilities(metadata)
        
        // 4. Integrity verification (checksums, etc.)
        try await validateIntegrity(bundleURL, metadata: metadata)
        
        // 5. Content security analysis
        try await performContentSecurityAnalysis(bundleURL)
        
        // 6. Metadata security validation
        try validateMetadataSecurity(metadata)
        
        logger.info("Security validation completed successfully for plugin: \(metadata.identifier)")
    }
    
    // MARK: - Bundle Structure Validation
    
    private func validateBundleStructure(_ bundleURL: URL) throws {
        guard fileManager.fileExists(atPath: bundleURL.path) else {
            throw PluginError.securityViolation("Plugin bundle does not exist")
        }
        
        // Check for required bundle structure
        let contentsURL = bundleURL.appendingPathComponent("Contents")
        guard fileManager.fileExists(atPath: contentsURL.path) else {
            throw PluginError.securityViolation("Invalid bundle structure: Contents directory missing")
        }
        
        // Validate Info.plist
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        guard fileManager.fileExists(atPath: infoPlistURL.path) else {
            throw PluginError.securityViolation("Invalid bundle structure: Info.plist missing")
        }
        
        // Validate metadata.json
        let metadataURL = contentsURL.appendingPathComponent("metadata.json")
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw PluginError.securityViolation("Invalid bundle structure: metadata.json missing")
        }
        
        // Check for suspicious files or directories
        try checkForSuspiciousContent(contentsURL)
    }
    
    private func checkForSuspiciousContent(_ contentsURL: URL) throws {
        let suspiciousPatterns = [
            "*.sh",     // Shell scripts
            "*.py",     // Python scripts
            "*.rb",     // Ruby scripts
            "*.pl",     // Perl scripts
            "*.js",     // JavaScript (unless part of web content)
            ".*rc",     // RC files
            ".DS_Store" // System files
        ]
        
        let enumerator = fileManager.enumerator(at: contentsURL, includingPropertiesForKeys: [.nameKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let fileName = fileURL.lastPathComponent
            
            // Check against suspicious patterns
            for pattern in suspiciousPatterns {
                if fileName.contains(pattern.replacingOccurrences(of: "*", with: "")) {
                    logger.warning("Found potentially suspicious file: \(fileName)")
                }
            }
            
            // Check file permissions
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let permissions = attributes[.posixPermissions] as? NSNumber,
                   permissions.intValue & 0o111 != 0 { // Executable bits set
                    logger.info("Executable file found: \(fileName)")
                }
            } catch {
                logger.warning("Could not check attributes for file: \(fileName)")
            }
        }
    }
    
    // MARK: - Code Signing Validation
    
    private func validateCodeSigning(_ bundleURL: URL, metadata: PluginMetadata) throws {
        logger.info("Validating code signing for plugin: \(metadata.identifier)")
        
        // Get security information from the bundle
        var staticCode: SecStaticCode?
        let result = SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode)
        
        guard result == errSecSuccess, let code = staticCode else {
            throw PluginError.codeSigningFailure("Failed to create static code reference: \(result)")
        }
        
        // Validate code signature with basic flags
        let validationFlags: SecCSFlags = SecCSFlags()  // Use default validation flags
        
        let validationResult = SecStaticCodeCheckValidity(code, validationFlags, nil)
        guard validationResult == errSecSuccess else {
            throw PluginError.codeSigningFailure("Code signature validation failed: \(validationResult)")
        }
        
        // Extract signing information
        try validateSigningInformation(code, metadata: metadata)
        
        logger.info("Code signing validation successful for plugin: \(metadata.identifier)")
    }
    
    private func validateSigningInformation(_ staticCode: SecStaticCode, metadata: PluginMetadata) throws {
        var signingInfo: CFDictionary?
        let infoResult = SecCodeCopySigningInformation(staticCode, SecCSFlags(), &signingInfo)
        
        guard infoResult == errSecSuccess, let info = signingInfo as? [String: Any] else {
            throw PluginError.codeSigningFailure("Failed to extract signing information")
        }
        
        // Validate team identifier if specified in metadata
        if let expectedTeamId = metadata.teamIdentifier {
            if let actualTeamId = info[kSecCodeInfoTeamIdentifier as String] as? String {
                guard actualTeamId == expectedTeamId else {
                    throw PluginError.codeSigningFailure("Team identifier mismatch: expected \(expectedTeamId), got \(actualTeamId)")
                }
                
                // Check if team is trusted
                guard trustedTeamIds.contains(actualTeamId) else {
                    throw PluginError.securityViolation("Plugin team identifier '\(actualTeamId)' is not trusted")
                }
            } else {
                throw PluginError.codeSigningFailure("Team identifier not found in signing information")
            }
        }
        
        // Validate signing identity if specified
        if let expectedIdentity = metadata.codeSigningIdentity {
            if let actualIdentity = info[kSecCodeInfoIdentifier as String] as? String {
                guard actualIdentity == expectedIdentity else {
                    throw PluginError.codeSigningFailure("Code signing identity mismatch: expected \(expectedIdentity), got \(actualIdentity)")
                }
            } else {
                throw PluginError.codeSigningFailure("Code signing identity not found in signing information")
            }
        }
        
        // Validate entitlements
        if let entitlements = info[kSecCodeInfoEntitlements as String] as? [String: Any] {
            try validateEntitlements(entitlements, requiredEntitlements: metadata.requiredEntitlements)
        }
    }
    
    private func validateEntitlements(_ entitlements: [String: Any], requiredEntitlements: [String]) throws {
        for requiredEntitlement in requiredEntitlements {
            guard entitlements.keys.contains(requiredEntitlement) else {
                throw PluginError.securityViolation("Required entitlement missing: \(requiredEntitlement)")
            }
        }
        
        // Check for dangerous entitlements
        let dangerousEntitlements = [
            "com.apple.security.cs.allow-jit",
            "com.apple.security.cs.allow-unsigned-executable-memory",
            "com.apple.security.cs.disable-library-validation"
        ]
        
        for dangerous in dangerousEntitlements {
            if entitlements.keys.contains(dangerous) {
                logger.warning("Plugin contains potentially dangerous entitlement: \(dangerous)")
            }
        }
    }
    
    // MARK: - Capability Validation
    
    private func validateCapabilities(_ metadata: PluginMetadata) throws {
        // Check if requested capabilities are allowed
        let requestedCapabilities = metadata.capabilities
        let disallowedCapabilities = requestedCapabilities.subtracting(allowedCapabilities)
        
        guard disallowedCapabilities.isEmpty else {
            throw PluginError.securityViolation("Plugin requests disallowed capabilities: \(disallowedCapabilities.description)")
        }
        
        // Validate capability combinations
        if requestedCapabilities.contains(.networkAccess) && requestedCapabilities.contains(.fileSystemAccess) {
            logger.warning("Plugin requests both network and file system access - increased security risk")
        }
    }
    
    // MARK: - Integrity Validation
    
    private func validateIntegrity(_ bundleURL: URL, metadata: PluginMetadata) async throws {
        // Verify checksum if provided
        if let expectedChecksum = metadata.checksumSHA256 {
            try await validateChecksum(bundleURL, expectedChecksum: expectedChecksum)
        }
        
        // Additional integrity checks
        try validateFileIntegrity(bundleURL)
    }
    
    private func validateChecksum(_ bundleURL: URL, expectedChecksum: String) async throws {
        let checksum = try await calculateBundleChecksum(bundleURL)
        
        guard checksum.lowercased() == expectedChecksum.lowercased() else {
            throw PluginError.securityViolation("Bundle checksum mismatch: expected \(expectedChecksum), calculated \(checksum)")
        }
        
        logger.info("Bundle checksum validation successful")
    }
    
    private func calculateBundleChecksum(_ bundleURL: URL) async throws -> String {
        return try await Task.detached {
            var hasher = SHA256()
            
            let enumerator = self.fileManager.enumerator(at: bundleURL, includingPropertiesForKeys: [.isRegularFileKey])
            
            var files: [(URL, Date)] = []
            
            // Collect all files with modification dates for consistent ordering
            while let fileURL = enumerator?.nextObject() as? URL {
                let attributes = try self.fileManager.attributesOfItem(atPath: fileURL.path)
                if let isRegularFile = attributes[.type] as? FileAttributeType,
                   isRegularFile == .typeRegular,
                   let modificationDate = attributes[.modificationDate] as? Date {
                    files.append((fileURL, modificationDate))
                }
            }
            
            // Sort files by path for consistent checksum
            files.sort { $0.0.path < $1.0.path }
            
            // Hash all files
            for (fileURL, _) in files {
                let data = try Data(contentsOf: fileURL)
                hasher.update(data: data)
                
                // Also hash the relative path to detect moved files
                let relativePath = fileURL.path.replacingOccurrences(of: bundleURL.path, with: "")
                hasher.update(data: Data(relativePath.utf8))
            }
            
            let digest = hasher.finalize()
            return digest.compactMap { String(format: "%02x", $0) }.joined()
        }.value
    }
    
    private func validateFileIntegrity(_ bundleURL: URL) throws {
        // Check for common signs of tampering
        let _ = bundleURL.appendingPathComponent("Contents/Info.plist")  // Future: validate Info.plist
        let _ = bundleURL.appendingPathComponent("Contents/metadata.json")  // Future: validate metadata
        
        // Verify file timestamps are reasonable
        let now = Date()
        let attributes = try fileManager.attributesOfItem(atPath: bundleURL.path)
        
        if let creationDate = attributes[.creationDate] as? Date {
            // Check if bundle was created in the future
            if creationDate > now.addingTimeInterval(300) { // 5 minute grace period
                throw PluginError.securityViolation("Bundle creation date is in the future")
            }
            
            // Check if bundle is extremely old (potential replay attack)
            if creationDate < now.addingTimeInterval(-365 * 24 * 3600 * 5) { // 5 years old
                logger.warning("Plugin bundle is very old, potential security risk")
            }
        }
        
        // Verify Info.plist and metadata.json are consistent
        try validateBundleConsistency(bundleURL)
    }
    
    private func validateBundleConsistency(_ bundleURL: URL) throws {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        let metadataURL = bundleURL.appendingPathComponent("Contents/metadata.json")
        
        // Load both files
        guard let infoPlist = NSDictionary(contentsOf: infoPlistURL) else {
            throw PluginError.securityViolation("Cannot read Info.plist")
        }
        
        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(PluginMetadata.self, from: metadataData)
        
        // Check bundle identifier consistency
        if let infoBundleId = infoPlist["CFBundleIdentifier"] as? String {
            guard infoBundleId == metadata.bundleIdentifier else {
                throw PluginError.securityViolation("Bundle identifier mismatch between Info.plist and metadata.json")
            }
        }
        
        // Check version consistency
        if let infoVersion = infoPlist["CFBundleShortVersionString"] as? String,
           let infoVersionParsed = PluginVersion(from: infoVersion) {
            guard infoVersionParsed == metadata.version else {
                throw PluginError.securityViolation("Version mismatch between Info.plist and metadata.json")
            }
        }
    }
    
    // MARK: - Content Security Analysis
    
    private func performContentSecurityAnalysis(_ bundleURL: URL) async throws {
        // Analyze executable code for suspicious patterns
        try await analyzeExecutableContent(bundleURL)
        
        // Check for suspicious resources
        try analyzeBundleResources(bundleURL)
    }
    
    private func analyzeExecutableContent(_ bundleURL: URL) async throws {
        let macOSDir = bundleURL.appendingPathComponent("Contents/MacOS")
        
        guard fileManager.fileExists(atPath: macOSDir.path) else {
            return // No executable content to analyze
        }
        
        let contents = try fileManager.contentsOfDirectory(at: macOSDir, includingPropertiesForKeys: [.isRegularFileKey])
        
        for fileURL in contents {
            // Read first part of file to analyze headers
            let data = try Data(contentsOf: fileURL, options: [.mappedRead]).prefix(1024)
            
            // Check for Mach-O magic numbers
            if data.count >= 4 {
                let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
                
                // Valid Mach-O magic numbers
                let validMagicNumbers: Set<UInt32> = [
                    0xfeedface, // MH_MAGIC (32-bit)
                    0xfeedfacf, // MH_MAGIC_64 (64-bit)
                    0xcafebabe, // FAT_MAGIC (universal binary)
                    0xcffaedfe, // MH_CIGAM (32-bit, byte-swapped)
                    0xcffaedfe  // MH_CIGAM_64 (64-bit, byte-swapped)
                ]
                
                guard validMagicNumbers.contains(magic) else {
                    throw PluginError.securityViolation("Invalid executable format detected")
                }
            }
        }
    }
    
    private func analyzeBundleResources(_ bundleURL: URL) throws {
        let resourcesDir = bundleURL.appendingPathComponent("Contents/Resources")
        
        guard fileManager.fileExists(atPath: resourcesDir.path) else {
            return // No resources to analyze
        }
        
        let enumerator = fileManager.enumerator(at: resourcesDir, includingPropertiesForKeys: [.fileSizeKey, .typeIdentifierKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Check file size limits
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? NSNumber {
                // Flag unusually large resource files
                if fileSize.int64Value > 100 * 1024 * 1024 { // 100MB
                    logger.warning("Large resource file detected: \(fileURL.lastPathComponent) (\(fileSize.int64Value / (1024*1024))MB)")
                }
            }
            
            // Check for suspicious file types
            let suspiciousExtensions = ["exe", "bat", "cmd", "scr", "com", "pif", "vbs", "js", "jar"]
            if suspiciousExtensions.contains(fileURL.pathExtension.lowercased()) {
                logger.warning("Suspicious resource file type: \(fileURL.lastPathComponent)")
            }
        }
    }
    
    // MARK: - Metadata Security Validation
    
    private func validateMetadataSecurity(_ metadata: PluginMetadata) throws {
        // Validate URLs for safety
        if let website = metadata.website {
            try validateURL(website)
        }
        
        // Check for suspicious patterns in text fields
        let textFields = [
            metadata.name,
            metadata.description,
            metadata.author,
            metadata.displayName
        ]
        
        for field in textFields {
            try validateTextFieldSecurity(field)
        }
        
        // Validate email address format if provided
        if let email = metadata.supportEmail {
            try validateEmailAddress(email)
        }
    }
    
    private func validateURL(_ url: URL) throws {
        guard url.scheme == "https" || url.scheme == "http" else {
            throw PluginError.securityViolation("Invalid URL scheme: \(url.scheme ?? "nil")")
        }
        
        guard let host = url.host, !host.isEmpty else {
            throw PluginError.securityViolation("Invalid URL host")
        }
        
        // Check against known malicious domains (in production, use a real blocklist)
        let suspiciousDomains = ["malware.com", "suspicious.net"]
        if suspiciousDomains.contains(host) {
            throw PluginError.securityViolation("URL host is on blocklist: \(host)")
        }
    }
    
    private func validateTextFieldSecurity(_ text: String) throws {
        // Check for script injection patterns
        let suspiciousPatterns = [
            "<script",
            "javascript:",
            "vbscript:",
            "onload=",
            "onerror=",
            "${",
            "#{",
        ]
        
        let lowercaseText = text.lowercased()
        for pattern in suspiciousPatterns {
            if lowercaseText.contains(pattern) {
                throw PluginError.securityViolation("Suspicious pattern detected in text field: \(pattern)")
            }
        }
        
        // Check for excessively long fields (potential buffer overflow)
        if text.count > 10000 {
            throw PluginError.securityViolation("Text field exceeds maximum length")
        }
    }
    
    private func validateEmailAddress(_ email: String) throws {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let range = email.range(of: emailRegex, options: .regularExpression)
        
        guard range != nil else {
            throw PluginError.securityViolation("Invalid email address format")
        }
    }
}