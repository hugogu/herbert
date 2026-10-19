import Foundation
import Security

// Uses a unique service and the same DeviceKeychain source as the app, never user credentials.
func verifyAdHocStorage() throws {
    guard Bundle.main.bundleIdentifier == "info.hugogu.Herbert.KeychainProbe" else {
        throw NSError(
            domain: "HerbertKeychainProbe", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The probe must reuse its fixed sandbox identity"])
    }
    let service = "info.hugogu.Herbert.KeychainProbe." + UUID().uuidString
    let account = "integration-test"
    let legacy: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
        kSecAttrAccount as String: account, kSecUseDataProtectionKeychain as String: false,
        kSecAttrSynchronizable as String: false,
    ]
    var protected = legacy
    protected[kSecUseDataProtectionKeychain as String] = true
    defer {
        SecItemDelete(legacy as CFDictionary)
        SecItemDelete(protected as CFDictionary)
    }
    func require(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw NSError(domain: "HerbertKeychainProbe", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    let seed = Data("throwaway-legacy-value".utf8)
    var item = protected
    item[kSecValueData as String] = seed
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let protectedAdd = SecItemAdd(item as CFDictionary, nil)
    let protectedDelete = SecItemDelete(protected as CFDictionary)
    try require(
        protectedAdd == errSecMissingEntitlement && protectedDelete == errSecMissingEntitlement,
        "Probe must use an ad-hoc app without a data-protection entitlement")
    var old = legacy
    old[kSecValueData as String] = seed
    let seeded = SecItemAdd(old as CFDictionary, nil)
    try require(seeded == errSecSuccess, "Cannot seed isolated legacy Keychain item: \(seeded)")
    let store = DeviceKeychain(service: service, account: account)
    try require(try store.read() == seed, "Readable legacy value was lost during migration")
    let changed = Data("throwaway-updated-value".utf8)
    try store.write(changed)
    try require(try store.read() == changed, "Fallback update failed")
    try store.write(nil)
    try require(try store.read() == nil, "Fallback deletion failed")
    try store.write(seed)
    try require(try store.read() == seed, "Fallback creation failed")
    try store.write(nil)
    try require(
        SecItemCopyMatching(legacy as CFDictionary, nil) == errSecItemNotFound,
        "Probe left a legacy item behind")
    print(
        "Ad-hoc sandbox Keychain passed: protected add/delete=\(protectedAdd)/\(protectedDelete); legacy read/create/update/delete succeeded."
    )
}
do { try verifyAdHocStorage() } catch {
    FileHandle.standardError.write(Data("Keychain integration failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
