import XCTest

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
                let progress = app.descendants(matching: .any)["section-记录"].firstMatch
                XCTAssertTrue(progress.waitForExistence(timeout: 5))
                progress.click()
            #else
                app.tabBars.buttons["Progress"].tap()
            #endif
            let link = app.buttons["cloud-leaderboard"]
            if !link.isHittable { app.swipeUp() }
            XCTAssertTrue(link.waitForExistence(timeout: 5))
            #if os(macOS)
                link.click()
            #else
                link.tap()
            #endif
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
            app.terminate()
        #else
            throw XCTSkip("Cloud UI is available only in the App Store target.")
        #endif
    }
    @MainActor
    func testLeaderboardIsANavigablePageAndUnconfiguredBuildStaysOffline() throws {
        #if APP_STORE
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing", "--reset-progress", "-AppleLanguages", "(en)"]
            app.launch()
            #if os(macOS)
                if !app.windows.firstMatch.waitForExistence(timeout: 3) { app.typeKey("n", modifierFlags: .command) }
                XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 8))
            #endif
            let progress = app.descendants(matching: .any)["section-记录"].firstMatch
            #if os(macOS)
                XCTAssertTrue(progress.waitForExistence(timeout: 5))
                progress.click()
            #else
                app.tabBars.buttons["Progress"].tap()
            #endif
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
            let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
            attachment.name = "cloud-leaderboard-unconfigured-en"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        #else
            throw XCTSkip("Cloud UI is available only in the App Store target.")
        #endif
    }
}
