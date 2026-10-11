import XCTest

final class CloudUITests: XCTestCase {
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
