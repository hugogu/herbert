import XCTest

final class HerbertUITests: XCTestCase {
    @MainActor
    private func launch(reset: Bool = true, language: String = "zh-Hans") -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments =
            ["--ui-testing", "-AppleLanguages", "(\(language))"] + (reset ? ["--reset-progress"] : [])
        app.launch()
        app.activate()
        XCTAssertTrue(app.buttons["continue-problem"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func openFirst(_ app: XCUIApplication) {
        app.buttons["continue-problem"].activateControl()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSolveOriginalProblemAndRestoreDraftAfterRelaunch() {
        let app = launch()
        openFirst(app)
        let code = app.textViews["code-editor"]
        code.activateControl()
        code.typeText("ssss")
        app.buttons["run-program"].activateControl()
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        openFirst(app)
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "ssss")
    }

    @MainActor
    func testSyntaxErrorsAppearInlineAndResetWorks() {
        let app = launch()
        openFirst(app)
        let code = app.textViews["code-editor"]
        code.activateControl()
        code.typeText("z")
        app.buttons["run-program"].activateControl()
        XCTAssertTrue(app.staticTexts["game-status"].displayedText.contains("未定义"))
        app.buttons["reset-program"].activateControl()
        XCTAssertTrue(app.staticTexts["game-status"].displayedText.contains("观察棋盘"))
    }

    @MainActor
    func testCommandKeysInsertAtCaretAndSingleStepCompletes() {
        let app = launch()
        openFirst(app)
        for _ in 0..<4 { app.buttons["insert-s"].activateControl() }
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "ssss")
        for _ in 0..<4 { app.buttons["step-program"].activateControl() }
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAutomaticEnglishAndJapaneseLocalization() {
        for (language, title, error, guideTitle) in [
            ("en", "Explore problems", "Procedure z is not defined.", "Game guide"),
            ("ja", "問題を探す", "手続き z が定義されていません。", "遊び方ガイド"),
        ] {
            let app = launch(language: language)
            XCTAssertTrue(app.staticTexts[title].exists)
            openFirst(app)
            app.textViews["code-editor"].activateControl()
            app.textViews["code-editor"].typeText("z")
            app.buttons["run-program"].activateControl()
            XCTAssertEqual(app.staticTexts["game-status"].displayedText, error)
            app.buttons[language == "en" ? "Game rules" : "ゲームのルール"].activateControl()
            XCTAssertTrue(app.staticTexts[guideTitle].waitForExistence(timeout: 5))
            capture(app, name: "localization-\(language)")
            app.terminate()
        }
    }

    @MainActor
    func testBoardSettingsPersistAndTrailCanBeHiddenWithoutLosingMoves() {
        var app = launch(language: "en")
        openFirst(app)
        let code = app.textViews["code-editor"]
        code.activateControl()
        code.typeText("ssss")
        app.buttons["step-program"].activateControl()
        var board = app.descendants(matching: .any)["game-board"].firstMatch
        XCTAssertTrue(board.label.contains("Modern; grid dots on; trail on; 1"), board.debugDescription)
        capture(app, name: "modern-trail")
        app.buttons["board-options"].activateControl()
        XCTAssertTrue(boardToggle("show-trail", in: app).waitForExistence(timeout: 5))
        boardToggle("show-trail", in: app).activateControl()
        boardToggle("show-grid-dots", in: app).activateControl()
        #if os(macOS)
            app.radioButtons["Classic"].activateControl()
        #else
            app.buttons["Classic"].activateControl()
        #endif
        app.buttons["close-board-options"].activateControl()
        for _ in 0..<3 { app.buttons["step-program"].activateControl() }
        XCTAssertTrue(board.label.contains("Classic; grid dots off; trail off; 0"), board.debugDescription)
        app.buttons["board-options"].activateControl()
        boardToggle("show-trail", in: app).activateControl()
        capture(app, name: "board-settings")
        app.buttons["close-board-options"].activateControl()
        XCTAssertTrue(board.label.contains("Classic; grid dots off; trail on; 4"), board.debugDescription)
        capture(app, name: "classic-trail")
        app.buttons["reset-program"].activateControl()
        XCTAssertTrue(board.label.contains("trail on; 0"), board.debugDescription)
        app.terminate()
        app = launch(reset: false, language: "en")
        openFirst(app)
        board = app.descendants(matching: .any)["game-board"].firstMatch
        XCTAssertTrue(board.label.contains("Classic; grid dots off; trail on; 0"), board.debugDescription)
        app.terminate()
    }

    @MainActor
    func testCaptureReadmeScreenshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["HERBERT_CAPTURE_SCREENSHOTS"] == "1",
            "Run scripts/capture_screenshots.sh to refresh the documentation images.")
        let app = launch()
        capture(app, name: "library")
        for (id, name) in [(37, "flower"), (27, "shuriken"), (361, "butterfly")] {
            let search = app.textFields["problem-search"]
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.activateControl()
            search.typeText(String(format: "%04d", id))
            let problem = app.buttons["problem-\(id)"]
            XCTAssertTrue(problem.waitForExistence(timeout: 5))
            problem.activateControl()
            XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
            if id == 37 {
                let code = app.textViews["code-editor"]
                code.activateControl()
                code.typeText("a(4)\na(X):sa(X-1)")
            }
            capture(app, name: name)
            let board = app.descendants(matching: .any)["game-board"].firstMatch
            XCTAssertTrue(board.exists)
            app.activate()
            let image = XCTAttachment(screenshot: board.screenshot())
            image.name = "readme-\(name)-board"
            image.lifetime = .keepAlways
            add(image)
            app.buttons["返回"].activateControl()
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            app.buttons["clear-search"].activateControl()
        }
    }

    @MainActor
    private func boardToggle(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.switches[id]
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        app.activate()
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        image.name = "readme-\(name)"
        image.lifetime = .keepAlways
        add(image)
    }
}

extension XCUIElement {
    fileprivate var displayedText: String { (value as? String) ?? label }
    fileprivate func activateControl() {
        #if os(macOS)
            XCUIApplication().activate()
            click()
        #else
            tap()
        #endif
    }
}
