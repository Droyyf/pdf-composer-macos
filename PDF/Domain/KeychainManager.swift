import Foundation
import Security

/// Secure keychain-based storage for OAuth tokens and sensitive data
final class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    private let serviceName = "com.almostbrutal.pdf.cloudstorage"
    
    enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case invalidData
        case duplicateItem
        case unexpectedError(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Item not found in keychain"
            case .invalidData:
                return "Invalid data format"
            case .duplicateItem:
                return "Item already exists in keychain"
            case .unexpectedError(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    // MARK: - Token Storage
    
    /// Store OAuth token securely in keychain
    func storeToken(_ token: String, for account: String, provider: CloudProvider) throws {
        let key = tokenKey(for: account, provider: provider)
        let data = token.data(using: .utf8) ?? Data()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    /// Retrieve OAuth token from keychain
    func retrieveToken(for account: String, provider: CloudProvider) throws -> String {
        let key = tokenKey(for: account, provider: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedError(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return token
    }
    
    /// Delete OAuth token from keychain
    func deleteToken(for account: String, provider: CloudProvider) throws {
        let key = tokenKey(for: account, provider: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    // MARK: - Account Data Storage
    
    /// Store account information securely
    func storeAccountData<T: Codable>(_ data: T, for account: String, provider: CloudProvider) throws {
        let key = accountDataKey(for: account, provider: provider)
        let jsonData = try JSONEncoder().encode(data)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: jsonData
        ]
        
        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    /// Retrieve account information from keychain
    func retrieveAccountData<T: Codable>(_ type: T.Type, for account: String, provider: CloudProvider) throws -> T {
        let key = accountDataKey(for: account, provider: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedError(status)
        }
        
        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
    /// Delete account data from keychain
    func deleteAccountData(for account: String, provider: CloudProvider) throws {
        let key = accountDataKey(for: account, provider: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedError(status)
        }
    }
    
    /// List all stored accounts for a provider
    func listAccounts(for provider: CloudProvider) throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw KeychainError.unexpectedError(status)
        }
        
        guard let items = result as? [[String: Any]] else {
            return []
        }
        
        let providerPrefix = "token_\(provider.rawValue)_"
        var accounts: [String] = []
        
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String,
               account.hasPrefix(providerPrefix) {
                let accountId = String(account.dropFirst(providerPrefix.count))
                accounts.append(accountId)
            }
        }
        
        return Array(Set(accounts)) // Remove duplicates
    }
    
    // MARK: - Private Helpers
    
    private func tokenKey(for account: String, provider: CloudProvider) -> String {
        return "token_\(provider.rawValue)_\(account)"
    }
    
    private func accountDataKey(for account: String, provider: CloudProvider) -> String {
        return "account_\(provider.rawValue)_\(account)"
    }
}