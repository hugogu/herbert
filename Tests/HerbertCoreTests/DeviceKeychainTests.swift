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
        func testFailedMigrationKeepsLegacyReadableUntilProtectedWriteSucceeds() throws {
            let backend = FakeKeychain()
            let original = Data("legacy".utf8)
            backend.legacy = original
            backend.addStatus = errSecAuthFailed
            let store = DeviceKeychain(service: "test", account: "test", backend: backend)
            XCTAssertEqual(try store.read(), original)
            XCTAssertFalse(backend.deletedLegacy)
            XCTAssertNil(backend.protected)
            backend.addStatus = errSecSuccess
            XCTAssertEqual(try store.read(), original)
            XCTAssertTrue(backend.deletedLegacy)
            XCTAssertEqual(backend.protected, original)
        }
        func testAdHocBuildCanCreateReadUpdateAndDeleteKeys() throws {
            for readStatus in [errSecItemNotFound, errSecMissingEntitlement] {
                let backend = FakeKeychain()
                backend.protectedReadStatus = readStatus
                backend.addStatus = errSecMissingEntitlement
                backend.deleteStatus = errSecMissingEntitlement
                let store = DeviceKeychain(service: "test", account: "test", backend: backend)
                XCTAssertNil(try store.read())
                let first = Data("first".utf8)
                let second = Data("second".utf8)
                try store.write(first)
                XCTAssertEqual(backend.added?[kSecUseDataProtectionKeychain as String] as? Bool, false)
                XCTAssertEqual(backend.added?[kSecAttrSynchronizable as String] as? Bool, false)
                XCTAssertEqual(try store.read(), first)
                try store.write(second)
                XCTAssertEqual(try store.read(), second)
                try store.write(nil)
                XCTAssertNil(try store.read())
            }
        }
        func testMissingEntitlementOnUpdateUsesExistingLegacyKey() throws {
            let backend = FakeKeychain()
            backend.legacy = Data("old".utf8)
            backend.updateStatus = errSecMissingEntitlement
            let store = DeviceKeychain(service: "test", account: "test", backend: backend)
            let value = Data("new".utf8)
            try store.write(value)
            XCTAssertEqual(backend.legacy, value)
            XCTAssertEqual(try store.read(), value)
            XCTAssertFalse(backend.deletedLegacy)
        }
        func testOrdinaryAuthorizationErrorsNeverDowngradeWritesOrReads() throws {
            let backend = FakeKeychain()
            backend.legacy = Data("old".utf8)
            backend.addStatus = errSecAuthFailed
            let store = DeviceKeychain(service: "test", account: "test", backend: backend)
            XCTAssertThrowsError(try store.write(Data("new".utf8)))
            XCTAssertEqual(backend.legacy, Data("old".utf8))
            backend.protectedReadStatus = errSecAuthFailed
            XCTAssertThrowsError(try store.read())
        }
        func testLegacyWriteErrorsAreReportedAndDoNotDeleteExistingKeys() throws {
            let backend = FakeKeychain()
            backend.legacy = Data("old".utf8)
            backend.updateStatus = errSecMissingEntitlement
            backend.legacyWriteStatus = errSecAuthFailed
            let store = DeviceKeychain(service: "test", account: "test", backend: backend)
            XCTAssertThrowsError(try store.write(Data("new".utf8)))
            XCTAssertEqual(backend.legacy, Data("old".utf8))
            XCTAssertFalse(backend.deletedLegacy)
        }
    #endif
}
private final class FakeKeychain: KeychainBackend {
    var added: [String: Any]?
    var legacy: Data?
    var protected: Data?
    var protectedReadStatus: OSStatus = errSecItemNotFound
    var updateStatus: OSStatus = errSecItemNotFound
    var addStatus: OSStatus = errSecSuccess
    var deleteStatus: OSStatus = errSecSuccess
    var legacyWriteStatus: OSStatus = errSecSuccess
    var deletedLegacy = false
    private func isProtected(_ query: [String: Any]) -> Bool {
        query[kSecUseDataProtectionKeychain as String] as? Bool == true
    }
    func read(_ query: [String: Any]) -> (OSStatus, Data?) {
        if isProtected(query) {
            if let protected { return (errSecSuccess, protected) }
            return (protectedReadStatus, nil)
        }
        return legacy.map { (errSecSuccess, $0) } ?? (errSecItemNotFound, nil)
    }
    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        if isProtected(query) {
            guard protected != nil else { return updateStatus }
            protected = attributes[kSecValueData as String] as? Data
        } else {
            guard legacyWriteStatus == errSecSuccess else { return legacyWriteStatus }
            guard legacy != nil else { return errSecItemNotFound }
            legacy = attributes[kSecValueData as String] as? Data
        }
        return errSecSuccess
    }
    func add(_ query: [String: Any]) -> OSStatus {
        added = query
        let status = isProtected(query) ? addStatus : legacyWriteStatus
        if status == errSecSuccess {
            if isProtected(query) {
                protected = query[kSecValueData as String] as? Data
            } else {
                legacy = query[kSecValueData as String] as? Data
            }
        }
        return status
    }
    func delete(_ query: [String: Any]) -> OSStatus {
        if isProtected(query) {
            if deleteStatus == errSecSuccess { protected = nil }
            return deleteStatus
        }
        deletedLegacy = true
        legacy = nil
        return errSecSuccess
    }
}
