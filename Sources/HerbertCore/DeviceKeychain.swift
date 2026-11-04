import Foundation
import Security

protocol KeychainBackend {
    func read(_ query: [String: Any]) -> (OSStatus, Data?)
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus
    func add(_ query: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

private struct SystemKeychain: KeychainBackend {
    func read(_ query: [String: Any]) -> (OSStatus, Data?) {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        return (status, value as? Data)
    }
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }
    func add(_ query: [String: Any]) -> OSStatus { SecItemAdd(query as CFDictionary, nil) }
    func delete(_ query: [String: Any]) -> OSStatus { SecItemDelete(query as CFDictionary) }
}

/// Prefer device-bound credentials. Ad-hoc macOS apps without the required entitlement
/// use the non-synchronizing login Keychain; legacy items migrate only after a protected copy succeeds.
public struct DeviceKeychain {
    private let service: String
    private let account: String
    private let backend: any KeychainBackend
    public init(service: String, account: String) {
        self.init(service: service, account: account, backend: SystemKeychain())
    }
    init(service: String, account: String, backend: any KeychainBackend) {
        self.service = service
        self.account = account
        self.backend = backend
    }
    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account, kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: false,
        ]
    }
    #if os(macOS)
        private var legacyQuery: [String: Any] {
            var query = query
            query[kSecUseDataProtectionKeychain as String] = false
            return query
        }
    #endif
    private func check(_ status: OSStatus, allowingMissing: Bool = false) throws {
        guard status == errSecSuccess || (allowingMissing && status == errSecItemNotFound) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
    private func save(_ data: Data, query: [String: Any], deviceOnly: Bool) -> OSStatus {
        var attributes: [String: Any] = [kSecValueData as String: data]
        if deviceOnly {
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }
        let status = backend.update(query, attributes: attributes)
        return status == errSecItemNotFound
            ? backend.add(query.merging(attributes) { _, new in new }) : status
    }
    public func read() throws -> Data? {
        let (status, data) = backend.read(query)
        if status == errSecSuccess { return data }
        #if os(macOS)
            if status != errSecMissingEntitlement { try check(status, allowingMissing: true) }
            let (legacyStatus, legacyData) = backend.read(legacyQuery)
            try check(legacyStatus, allowingMissing: true)
            if let legacyData {
                // Migration is best effort; a signing/authorization failure must not hide a readable key.
                if save(legacyData, query: query, deviceOnly: true) == errSecSuccess {
                    try? check(backend.delete(legacyQuery), allowingMissing: true)
                }
                return legacyData
            }
        #else
            try check(status, allowingMissing: true)
        #endif
        return nil
    }
    public func write(_ data: Data?) throws {
        let status = data.map { save($0, query: query, deviceOnly: true) } ?? backend.delete(query)
        #if os(macOS)
            if status == errSecMissingEntitlement {
                if let data {
                    try check(save(data, query: legacyQuery, deviceOnly: false))
                } else {
                    try check(backend.delete(legacyQuery), allowingMissing: true)
                }
                return
            }
        #endif
        try check(status, allowingMissing: data == nil)
        #if os(macOS)
            try check(backend.delete(legacyQuery), allowingMissing: true)
        #endif
    }
}
