import XCTest

@testable import HerbertCore

final class AppVersionTests: XCTestCase {
    func testShowsTheMarketingVersionAndBuild() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.1.0", "CFBundleVersion": "15"])
        XCTAssertEqual(version?.marketing, "1.1.0")
        XCTAssertEqual(version?.build, "15")
        XCTAssertEqual(version?.description, "1.1.0 (15)")
    }

    func testOmitsAMissingOrEmptyBuild() {
        XCTAssertEqual(AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.1.0"])?.description, "1.1.0")
        XCTAssertEqual(
            AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.1.0", "CFBundleVersion": ""])?.description,
            "1.1.0")
    }

    func testNeedsAMarketingVersion() {
        XCTAssertNil(AppVersion(infoDictionary: nil))
        XCTAssertNil(AppVersion(infoDictionary: ["CFBundleVersion": "15"]))
        XCTAssertNil(AppVersion(infoDictionary: ["CFBundleShortVersionString": "", "CFBundleVersion": "15"]))
    }

    func testVersionLabelInEveryLanguage() {
        for (language, label) in [
            ("en", "Version 1.1.0 (15)"), ("zh-Hans", "版本 1.1.0 (15)"), ("ja", "バージョン 1.1.0 (15)"),
        ] {
            XCTAssertEqual(HerbertStrings.text("版本 %@", language: language, arguments: ["1.1.0 (15)"]), label)
        }
    }
}
