#if os(macOS)
import Foundation
import Security

/// Thin Keychain wrapper used to persist sensitive credentials on macOS.
/// iOS continues to use UserDefaults for these values (see AppState).
///
/// Uses the data-protection keychain (`kSecUseDataProtectionKeychain: true`)
/// rather than the legacy login keychain. The data-protection keychain is
/// keyed to the app's sandbox container by bundle id, not to the signing
/// identity, so ad-hoc rebuilds don't trigger "allow access" prompts each
/// run. This matches iOS keychain semantics.
enum KeychainStorage {
    private static let service = "com.actual.accounts.mac"

    private static func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    static func read(_ key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, for key: String) {
        guard !value.isEmpty else {
            delete(key)
            return
        }
        let data = Data(value.utf8)
        let query = baseQuery(key: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete(_ key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
    }
}
#endif
