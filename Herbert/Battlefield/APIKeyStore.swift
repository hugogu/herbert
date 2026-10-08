import Foundation
import Security

@MainActor
protocol APIKeyStore {
    func hasKey(for provider: UUID) throws -> Bool
    func key(for provider: UUID) throws -> String?
    func setKey(_ value: String?, for provider: UUID) throws
}

struct KeychainError: Error, LocalizedError {
    let status: OSStatus
    var errorDescription: String? { "Keychain \(status)" }
}

struct KeychainAPIKeyStore: APIKeyStore {
    private func query(_ provider: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "info.hugogu.Herbert.Battlefield",
            kSecAttrAccount as String: provider.uuidString,
            kSecAttrSynchronizable as String: false,
        ]
    }

    func hasKey(for provider: UUID) throws -> Bool {
        let status = SecItemCopyMatching(query(provider) as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
        return status == errSecSuccess
    }

    func key(for provider: UUID) throws -> String? {
        var query = query(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainError(status: status)
        }
        return value
    }

    func setKey(_ value: String?, for provider: UUID) throws {
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(query(provider) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
            return
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(provider) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(provider)
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw KeychainError(status: added) }
        } else if status != errSecSuccess {
            throw KeychainError(status: status)
        }
    }
}

#if DEBUG
    @MainActor
    final class TestAPIKeyStore: APIKeyStore {
        private var keys: [UUID: String] = [:]
        func hasKey(for provider: UUID) throws -> Bool { keys[provider] != nil }
        func key(for provider: UUID) throws -> String? { keys[provider] }
        func setKey(_ value: String?, for provider: UUID) throws { keys[provider] = value }
    }
#endif
