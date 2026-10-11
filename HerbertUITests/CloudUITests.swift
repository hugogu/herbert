import XCTest

#if os(macOS)
    import AppKit
#endif

final class CloudUITests: XCTestCase {
    @MainActor
    func testAccountActionsAndNicknameEditor() throws {
        #if APP_STORE
            let app = XCUIApplication()
            app.launchArguments = [
                "--ui-testing", "--reset-progress", "--ui-testing-cloud-account", "-AppleLanguages", "(en)",
            ]
            app.launch()
            #if os(macOS)
                if !app.windows.firstMatch.waitForExistence(timeout: 3) { app.typeKey("n", modifierFlags: .command) }
                XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
                prepareWindow(app)
                let progress = app.descendants(matching: .any)["section-我的"].firstMatch
                XCTAssertTrue(progress.waitForExistence(timeout: 5))
                progress.click()
            #else
                app.tabBars.buttons["My"].tap()
            #endif
            XCTAssertTrue(app.buttons["export-backup"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["import-backup"].exists)
            selectAccount(app)
            let upload = app.buttons["cloud-upload"]
            XCTAssertTrue(upload.waitForExistence(timeout: 5))
            XCTAssertTrue(upload.isEnabled)
            let account = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            account.name = "cloud-account-actions-en"
            account.lifetime = .keepAlways
            add(account)
            let edit = app.buttons["cloud-edit-name"]
            XCTAssertTrue(edit.isHittable)
            #if os(macOS)
                edit.click()
            #else
                edit.tap()
            #endif
            let field = app.textFields["cloud-name-field"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            XCTAssertEqual(field.value as? String, "Learner preview")
            XCTAssertTrue(app.buttons["cloud-save-name"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["cloud-save-name"].isEnabled)
            let editor = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            editor.name = "cloud-nickname-editor-en"
            editor.lifetime = .keepAlways
            add(editor)
            activate(app.buttons["Cancel"])
            activate(app.buttons["cloud-leaderboard"])
            XCTAssertTrue(
                app.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", "80 points", "80 points"))
                    .firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(
                app.staticTexts.matching(
                    NSPredicate(format: "value == %@ OR label == %@", "Solved 1/30", "Solved 1/30")
                ).firstMatch.exists)
            app.terminate()
        #else
            throw XCTSkip("Cloud UI is available only in the App Store target.")
        #endif
    }
    @MainActor
    func testLeaderboardIsANavigablePageAndUnconfiguredBuildStaysOffline() throws {
        #if APP_STORE
            let app = XCUIApplication()
            app.launchArguments = [
                "--ui-testing", "--reset-progress", "--ui-testing-cloud-offline", "-AppleLanguages", "(en)",
            ]
            app.launch()
            #if os(macOS)
                if !app.windows.firstMatch.waitForExistence(timeout: 3) { app.typeKey("n", modifierFlags: .command) }
                XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
            #endif
            prepareWindow(app)
            let progress = app.descendants(matching: .any)["section-我的"].firstMatch
            #if os(macOS)
                XCTAssertTrue(progress.waitForExistence(timeout: 5))
                progress.click()
            #else
                app.tabBars.buttons["My"].tap()
            #endif
            selectAccount(app)
            let link = app.buttons["cloud-leaderboard"]
            if !link.isHittable { app.swipeUp() }
            XCTAssertTrue(link.waitForExistence(timeout: 5))
            #if os(macOS)
                link.click()
            #else
                link.tap()
            #endif
            XCTAssertTrue(app.descendants(matching: .any)["cloud-unconfigured"].firstMatch.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["cloud-upload"].exists)
            app.terminate()
        #else
            throw XCTSkip("Cloud UI is available only in the App Store target.")
        #endif
    }
    @MainActor
    private func prepareWindow(_ app: XCUIApplication) {
        app.activate()
        #if os(macOS)
            if let display = ProcessInfo.processInfo.environment["HERBERT_TEST_DISPLAY"] {
                app.menuBars.menuBarItems.matching(NSPredicate(format: "title IN %@", ["Window", "窗口", "ウインドウ"]))
                    .firstMatch.click()
                let move = app.menuBars.menuItems.matching(NSPredicate(format: "title ENDSWITH %@", display)).firstMatch
                if move.waitForExistence(timeout: 3) {
                    let frame = move.frame
                    let window = app.windows.firstMatch
                    let origin = window.frame.origin
                    window.coordinate(withNormalizedOffset: .zero).withOffset(
                        CGVector(dx: frame.midX - origin.x, dy: frame.midY - origin.y)
                    ).click()
                } else {
                    app.typeKey(.escape, modifierFlags: [])
                }
            }
        #endif
    }

    @MainActor
    private func selectAccount(_ app: XCUIApplication) {
        #if os(macOS)
            let account = app.radioButtons["Account"]
            XCTAssertTrue(account.waitForExistence(timeout: 5))
            account.click()
        #else
            app.segmentedControls.buttons["Account"].tap()
        #endif
    }

    @MainActor
    func testFinishedAnswerUploadAndProblemRankingNavigation() throws {
        #if APP_STORE
            let app = XCUIApplication()
            app.launchArguments = [
                "--ui-testing", "--reset-progress", "--ui-testing-cloud-account", "-AppleLanguages", "(en)",
            ]
            app.launch()
            #if os(macOS)
                if !app.windows.firstMatch.waitForExistence(timeout: 3) { app.typeKey("n", modifierFlags: .command) }
            #endif
            prepareWindow(app)
            let first = app.buttons["continue-problem"]
            XCTAssertTrue(first.waitForExistence(timeout: 10))
            activate(first)
            XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["cloud-upload-answer"].exists)
            activate(app.buttons["insert-s"])
            activate(app.buttons["run-program"])
            XCTAssertTrue(app.buttons["cloud-upload-answer"].waitForExistence(timeout: 8))
            let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            attachment.name = "cloud-answer-upload-en"
            attachment.lifetime = .keepAlways
            add(attachment)
            // Editing invalidates the executed snapshot and hides its upload action.
            activate(app.buttons["insert-r"])
            XCTAssertTrue(app.buttons["cloud-upload-answer"].waitForNonExistence(timeout: 5))
            activate(app.buttons["cloud-problem-ranking"])
            XCTAssertTrue(
                app.descendants(matching: .any)["cloud-ranking-scope"].firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(
                app.staticTexts.matching(
                    NSPredicate(
                        format: "value CONTAINS %@ OR label CONTAINS %@", "L01 · First light", "L01 · First light")
                ).firstMatch.exists)
            XCTAssertTrue(
                app.staticTexts.matching(NSPredicate(format: "value == %@ OR label == %@", "80 points", "80 points"))
                    .firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(
                app.staticTexts.matching(
                    NSPredicate(format: "value == %@ OR label == %@", "Lit 1/1 · 1 B", "Lit 1/1 · 1 B")
                ).firstMatch.exists)
            app.terminate()
        #else
            throw XCTSkip("Cloud UI is available only in the App Store target.")
        #endif
    }

    @MainActor
    private func activate(_ element: XCUIElement) {
        #if os(macOS)
            element.click()
        #else
            element.tap()
        #endif
    }

}
