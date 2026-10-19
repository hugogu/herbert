import Foundation
import HerbertCore
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
    private func credentials(_ provider: UUID) -> DeviceKeychain {
        DeviceKeychain(service: "info.hugogu.Herbert.Battlefield", account: provider.uuidString)
    }
    func hasKey(for provider: UUID) throws -> Bool { try key(for: provider) != nil }
    func key(for provider: UUID) throws -> String? {
        guard let data = try credentials(provider).read() else { return nil }
        guard let value = String(data: data, encoding: .utf8) else { throw KeychainError(status: errSecDecode) }
        return value
    }
    func setKey(_ value: String?, for provider: UUID) throws {
        try credentials(provider).write(value.flatMap { $0.isEmpty ? nil : Data($0.utf8) })
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
