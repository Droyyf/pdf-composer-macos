import Foundation

// MARK: - Cloud Provider

enum CloudProvider: String, CaseIterable, Codable {
    case googleDrive = "googledrive"
    case oneDrive = "onedrive"
    case dropbox = "dropbox"
    
    var displayName: String {
        switch self {
        case .googleDrive:
            return "Google Drive"
        case .oneDrive:
            return "Microsoft OneDrive"
        case .dropbox:
            return "Dropbox"
        }
    }
    
    var iconName: String {
        switch self {
        case .googleDrive:
            return "globe"
        case .oneDrive:
            return "cloud.fill"
        case .dropbox:
            return "cloud.drizzle.fill"
        }
    }
    
    var authURL: String {
        switch self {
        case .googleDrive:
            return "https://accounts.google.com/o/oauth2/v2/auth"
        case .oneDrive:
            return "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
        case .dropbox:
            return "https://www.dropbox.com/oauth2/authorize"
        }
    }
    
    var tokenURL: String {
        switch self {
        case .googleDrive:
            return "https://oauth2.googleapis.com/token"
        case .oneDrive:
            return "https://login.microsoftonline.com/common/oauth2/v2.0/token"
        case .dropbox:
            return "https://api.dropboxapi.com/oauth2/token"
        }
    }
    
    var apiBaseURL: String {
        switch self {
        case .googleDrive:
            return "https://www.googleapis.com/drive/v3"
        case .oneDrive:
            return "https://graph.microsoft.com/v1.0"
        case .dropbox:
            return "https://api.dropboxapi.com/2"
        }
    }
    
    var scope: String {
        switch self {
        case .googleDrive:
            return "https://www.googleapis.com/auth/drive.file"
        case .oneDrive:
            return "files.readwrite"
        case .dropbox:
            return "files.content.write"
        }
    }
}

// MARK: - OAuth Models

struct OAuthConfiguration {
    let clientId: String
    let clientSecret: String
    let redirectURI: String
    let scope: String
    
    static func `for`(_ provider: CloudProvider) -> OAuthConfiguration {
        // In a real app, these would be stored securely or configured via build settings
        switch provider {
        case .googleDrive:
            return OAuthConfiguration(
                clientId: "YOUR_GOOGLE_CLIENT_ID",
                clientSecret: "YOUR_GOOGLE_CLIENT_SECRET",
                redirectURI: "com.almostbrutal.pdf://oauth/google",
                scope: provider.scope
            )
        case .oneDrive:
            return OAuthConfiguration(
                clientId: "YOUR_MICROSOFT_CLIENT_ID",
                clientSecret: "YOUR_MICROSOFT_CLIENT_SECRET",
                redirectURI: "com.almostbrutal.pdf://oauth/microsoft",
                scope: provider.scope
            )
        case .dropbox:
            return OAuthConfiguration(
                clientId: "YOUR_DROPBOX_CLIENT_ID",
                clientSecret: "YOUR_DROPBOX_CLIENT_SECRET",
                redirectURI: "com.almostbrutal.pdf://oauth/dropbox",
                scope: provider.scope
            )
        }
    }
}

struct OAuthToken: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresIn: Int?
    let scope: String?
    let issuedAt: Date
    
    var isExpired: Bool {
        guard let expiresIn = expiresIn else { return false }
        return Date().timeIntervalSince(issuedAt) >= TimeInterval(expiresIn)
    }
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case scope
        case issuedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        issuedAt = try container.decodeIfPresent(Date.self, forKey: .issuedAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encodeIfPresent(expiresIn, forKey: .expiresIn)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encode(issuedAt, forKey: .issuedAt)
    }
}

// MARK: - Account Models

struct CloudAccount: Codable, Identifiable {
    let id: String
    let email: String
    let displayName: String
    let provider: CloudProvider
    let avatarURL: String?
    let isActive: Bool
    let connectedAt: Date
    let lastSync: Date?
    
    init(id: String, email: String, displayName: String, provider: CloudProvider, avatarURL: String? = nil, isActive: Bool = true) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.provider = provider
        self.avatarURL = avatarURL
        self.isActive = isActive
        self.connectedAt = Date()
        self.lastSync = nil
    }
}

// MARK: - File Models

struct CloudFile: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String
    let size: Int64?
    let modifiedTime: Date
    let webViewLink: String?
    let downloadURL: String?
    let parentId: String?
    
    var isPDF: Bool {
        return mimeType == "application/pdf" || name.lowercased().hasSuffix(".pdf")
    }
    
    var formattedSize: String {
        guard let size = size else { return "Unknown" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct CloudFolder: Codable, Identifiable {
    let id: String
    let name: String
    let parentId: String?
    let modifiedTime: Date
    let webViewLink: String?
}

// MARK: - Upload/Download Models

struct CloudUploadRequest {
    let localFileURL: URL
    let fileName: String
    let parentFolderId: String?
    let overwrite: Bool
    
    init(localFileURL: URL, fileName: String? = nil, parentFolderId: String? = nil, overwrite: Bool = false) {
        self.localFileURL = localFileURL
        self.fileName = fileName ?? localFileURL.lastPathComponent
        self.parentFolderId = parentFolderId
        self.overwrite = overwrite
    }
}

struct CloudDownloadRequest {
    let fileId: String
    let localDestinationURL: URL
    let overwrite: Bool
    
    init(fileId: String, localDestinationURL: URL, overwrite: Bool = false) {
        self.fileId = fileId
        self.localDestinationURL = localDestinationURL
        self.overwrite = overwrite
    }
}

// MARK: - Progress Tracking

@MainActor
class CloudOperationProgress: ObservableObject {
    @Published var isActive: Bool = false
    @Published var progress: Double = 0.0
    @Published var status: String = ""
    @Published var error: Error?
    @Published var completedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    
    var formattedProgress: String {
        if totalBytes > 0 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let completed = formatter.string(fromByteCount: completedBytes)
            let total = formatter.string(fromByteCount: totalBytes)
            return "\(completed) / \(total)"
        } else {
            return "\(Int(progress * 100))%"
        }
    }
    
    func start(status: String, totalBytes: Int64 = 0) {
        self.isActive = true
        self.progress = 0.0
        self.status = status
        self.error = nil
        self.completedBytes = 0
        self.totalBytes = totalBytes
    }
    
    func update(progress: Double, completedBytes: Int64 = 0, status: String? = nil) {
        self.progress = min(1.0, max(0.0, progress))
        self.completedBytes = completedBytes
        if let status = status {
            self.status = status
        }
    }
    
    func complete(status: String = "Completed") {
        self.progress = 1.0
        self.status = status
        self.isActive = false
        self.completedBytes = self.totalBytes
    }
    
    func fail(error: Error, status: String? = nil) {
        self.error = error
        self.status = status ?? error.localizedDescription
        self.isActive = false
    }
    
    func reset() {
        self.isActive = false
        self.progress = 0.0
        self.status = ""
        self.error = nil
        self.completedBytes = 0
        self.totalBytes = 0
    }
}

// MARK: - Error Models

enum CloudStorageError: Error, LocalizedError {
    case notAuthenticated
    case tokenExpired
    case networkError(Error)
    case authenticationFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case fileNotFound
    case insufficientStorage
    case rateLimitExceeded
    case invalidResponse
    case unsupportedProvider
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with cloud storage provider"
        case .tokenExpired:
            return "Authentication token has expired"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .fileNotFound:
            return "File not found in cloud storage"
        case .insufficientStorage:
            return "Insufficient storage space"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later"
        case .invalidResponse:
            return "Invalid response from cloud storage provider"
        case .unsupportedProvider:
            return "Unsupported cloud storage provider"
        }
    }
}