import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()
    
    private let tokenKey = "com.brainfood.auth.token"
    private let userKey = "com.brainfood.auth.user"
    
    private init() {}
    
    func saveToken(_ token: String) -> Bool {
        return save(token, forKey: tokenKey)
    }
    
    func getToken() -> String? {
        return get(forKey: tokenKey)
    }
    
    func deleteToken() -> Bool {
        return delete(forKey: tokenKey)
    }
    
    func saveUser(_ user: User) -> Bool {
        if let data = try? JSONEncoder().encode(user) {
            return save(data, forKey: userKey)
        }
        return false
    }
    
    func getUser() -> User? {
        guard let data = getData(forKey: userKey) else { return nil }
        return try? JSONDecoder().decode(User.self, from: data)
    }
    
    func deleteUser() -> Bool {
        return delete(forKey: userKey)
    }
    
    func clearAll() {
        deleteToken()
        deleteUser()
    }
    
    // MARK: - Private Keychain Methods
    
    private func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(data, forKey: key)
    }
    
    private func save(_ data: Data, forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func get(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        }
        return nil
    }
    
    private func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

