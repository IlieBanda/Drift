import Foundation
import Security

/// Stores per-server RPC passwords in the login Keychain, keyed by ServerProfile.id.
/// Server name/host/port/username still live in UserDefaults (ServerProfile excludes
/// password from its Codable representation); only the password touches Keychain.
enum KeychainHelper {
    private static let service = "ru.iliebanda.Swarm.server"

    static func savePassword(_ password: String, forServerID id: UUID) {
        let account = id.uuidString
        guard !password.isEmpty else { deletePassword(forServerID: id); return }
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        var attributesToUpdate: [String: Any] = [kSecValueData as String: data]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        } else {
            attributesToUpdate[kSecClass as String] = kSecClassGenericPassword
            attributesToUpdate[kSecAttrService as String] = service
            attributesToUpdate[kSecAttrAccount as String] = account
            SecItemAdd(attributesToUpdate as CFDictionary, nil)
        }
    }

    static func readPassword(forServerID id: UUID) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let password = String(data: data, encoding: .utf8) else {
            return ""
        }
        return password
    }

    static func deletePassword(forServerID id: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
