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

/// Device-bound credentials. Legacy macOS items migrate only after a protected copy succeeds.
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
    public func read() throws -> Data? {
        let (status, data) = backend.read(query)
        if status == errSecSuccess { return data }
        try check(status, allowingMissing: true)
        #if os(macOS)
            let (legacyStatus, legacyData) = backend.read(legacyQuery)
            try check(legacyStatus, allowingMissing: true)
            if let legacyData {
                try write(legacyData)
                return legacyData
            }
        #endif
        return nil
    }
    public func write(_ data: Data?) throws {
        if let data {
            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            ]
            let status = backend.update(query, attributes: attributes)
            if status == errSecItemNotFound {
                try check(backend.add(query.merging(attributes) { _, new in new }))
            } else {
                try check(status)
            }
        } else {
            try check(backend.delete(query), allowingMissing: true)
        }
        #if os(macOS)
            try check(backend.delete(legacyQuery), allowingMissing: true)
        #endif
    }
}
