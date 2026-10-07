import XCTest

final class HerbertUITests: XCTestCase {
    @MainActor
    private func launch(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + (reset ? ["--reset-progress"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["continue-problem"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func openFirst(_ app: XCUIApplication) {
        app.buttons["continue-problem"].activate()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSolveOriginalProblemAndRestoreDraftAfterRelaunch() {
        let app = launch()
        openFirst(app)
        let code = app.textViews["code-editor"]
        code.activate()
        code.typeText("ssss")
        app.buttons["run-program"].activate()
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
        code.activate()
        code.typeText("z")
        app.buttons["run-program"].activate()
        XCTAssertTrue(app.staticTexts["game-status"].displayedText.contains("未定义"))
        app.buttons["reset-program"].activate()
        XCTAssertTrue(app.staticTexts["game-status"].displayedText.contains("观察棋盘"))
    }

    @MainActor
    func testCommandKeysInsertAtCaretAndSingleStepCompletes() {
        let app = launch()
        openFirst(app)
        for _ in 0..<4 { app.buttons["insert-s"].activate() }
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "ssss")
        for _ in 0..<4 { app.buttons["step-program"].activate() }
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 5))
    }
}

extension XCUIElement {
    fileprivate var displayedText: String { (value as? String) ?? label }
    fileprivate func activate() {
        #if os(macOS)
            click()
        #else
            tap()
        #endif
    }
}
