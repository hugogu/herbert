import XCTest

@testable import HerbertCore

final class LocalizationTests: XCTestCase {
    func testPreferredLanguageMatchingAndEnglishFallback() {
        XCTAssertEqual(HerbertStrings.text("运行", language: "en-GB"), "Run")
        XCTAssertEqual(HerbertStrings.text("运行", language: "zh-CN"), "运行")
        XCTAssertEqual(HerbertStrings.text("运行", language: "zh-hans"), "运行")
        XCTAssertEqual(HerbertStrings.text("运行", language: "ja-JP"), "実行")
        XCTAssertEqual(HerbertStrings.text("运行", language: "fr-FR"), "Run")
    }

    func testCompactImportExportLabels() {
        for (language, export, importLabel) in [
            ("en", "Export", "Import"), ("zh-Hans", "导出", "导入"), ("ja", "書き出す", "読み込む"),
        ] {
            XCTAssertEqual(HerbertStrings.text("导出", language: language), export)
            XCTAssertEqual(HerbertStrings.text("导入", language: language), importLabel)
        }
    }

    func testFormattedInterpreterAndBoardMessagesInEveryLanguage() {
        for language in ["en", "zh-Hans", "ja"] {
            let error = HerbertStrings.text("过程 %@ 需要 %ld 个参数，收到了 %ld 个。", language: language, arguments: ["q", 2, 1])
            XCTAssertTrue(error.contains("q"))
            XCTAssertTrue(error.contains("2"))
            XCTAssertTrue(error.contains("1"))
            XCTAssertFalse(error.contains("%@"))
            let board = HerbertStrings.text(
                "%@；网格点%@；轨迹%@；%ld 段路径", language: language, arguments: ["Classic", "on", "on", 4])
            XCTAssertTrue(board.contains("4"))
            XCTAssertFalse(board.contains("%ld"))
        }
    }
}
