import Security
import XCTest

@testable import HerbertCore

final class DeviceKeychainTests: XCTestCase {
    func testProtectedWritesAreDeviceOnlyAndNeverSynchronize() throws {
        let backend = FakeKeychain()
        try DeviceKeychain(service: "test", account: "test", backend: backend).write(Data("test".utf8))
        let item = try XCTUnwrap(backend.added)
        XCTAssertEqual(item[kSecUseDataProtectionKeychain as String] as? Bool, true)
        XCTAssertEqual(item[kSecAttrSynchronizable as String] as? Bool, false)
        XCTAssertEqual(
            item[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }
    #if os(macOS)
        func testLegacyCredentialsMigrateOnlyAfterSuccessfulProtectedWrite() throws {
            let backend = FakeKeychain()
            backend.legacy = Data("legacy".utf8)
            backend.addStatus = errSecAuthFailed
            let store = DeviceKeychain(service: "test", account: "test", backend: backend)
            XCTAssertThrowsError(try store.read())
            XCTAssertFalse(backend.deletedLegacy)
            backend.addStatus = errSecSuccess
            XCTAssertEqual(try store.read(), backend.legacy)
            XCTAssertTrue(backend.deletedLegacy)
        }
    #endif
}
private final class FakeKeychain: KeychainBackend {
    var added: [String: Any]?
    var legacy: Data?
    var addStatus: OSStatus = errSecSuccess
    var deletedLegacy = false
    func read(_ query: [String: Any]) -> (OSStatus, Data?) {
        if query[kSecUseDataProtectionKeychain as String] as? Bool == false, let legacy {
            return (errSecSuccess, legacy)
        }
        return (errSecItemNotFound, nil)
    }
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus { errSecItemNotFound }
    func add(_ query: [String: Any]) -> OSStatus {
        added = query
        return addStatus
    }
    func delete(_ query: [String: Any]) -> OSStatus {
        if query[kSecUseDataProtectionKeychain as String] as? Bool == false { deletedLegacy = true }
        return errSecSuccess
    }
}
