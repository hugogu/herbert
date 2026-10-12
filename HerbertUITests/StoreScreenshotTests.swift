import XCTest

/// Captures App Store product page screenshots from the original-only edition.
/// `scripts/capture_store_screenshots.sh` runs it once per device and language; ordinary UI runs skip it.
final class StoreScreenshotTests: XCTestCase {
    private struct Labels {
        let back: String
        let turbo: String
        let dismissKeyboard: String
        let tabs: [String: String]
    }

    private static let labels = [
        "en": Labels(
            back: "Back", turbo: "Turbo", dismissKeyboard: "Dismiss keyboard",
            tabs: ["关卡": "Problems", "手册": "Guide", "记录": "Progress", "AI Battlefield": "AI Battlefield"]),
        "zh-Hans": Labels(
            back: "返回", turbo: "极速", dismissKeyboard: "收起键盘",
            tabs: ["关卡": "关卡", "手册": "手册", "记录": "记录", "AI Battlefield": "AI Battlefield"]),
        "ja": Labels(
            back: "戻る", turbo: "高速", dismissKeyboard: "キーボードを閉じる",
            tabs: ["关卡": "問題", "手册": "ガイド", "记录": "記録", "AI Battlefield": "AI Battlefield"]),
    ]

    /// Reference programs for L01–L07, solved in order so the library and progress screens show real play.
    private static let firstLessons = [
        (10001, "s"), (10006, "rsslsslss"), (10012, "a:ssssr\naaaa"),
        (10074, "a(N):sa(N-1)\na(6)ra(10)ra(6)ra(10)"), (10075, "a(N,P):Pa(N-1,P)\nb:a(6,srsl)r\nbbbb"),
        (10076, "a(X):Xla(Xss)\na(ss)"), (10051, "a(N,X):XrXlXrrXrXlXrra(N-1,Xs)\nq(P):PPPP\nq(a(3,ss)r)"),
    ]

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        #if !APP_STORE
            throw XCTSkip("Store screenshots use the original-only App Store edition.")
        #else
            let environment = ProcessInfo.processInfo.environment
            try XCTSkipUnless(
                environment["HERBERT_CAPTURE_STORE_SCREENSHOTS"] == "1", "Run scripts/capture_store_screenshots.sh.")
            let language = environment["HERBERT_SCREENSHOT_LANGUAGE"] ?? "en"
            let text = try XCTUnwrap(Self.labels[language], "Unsupported screenshot language \(language)")
            let app = launch(language: language)

            for (id, source) in Self.firstLessons {
                open(id, in: app)
                enter(source, in: app, text: text)
                runTurbo(in: app, text: text)
                XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 20), "Lesson \(id)")
                if id != 10051 { back(in: app, text: text) }
            }
            showBoardAndCode(in: app)
            capture(app, "play")

            back(in: app, text: text)
            capture(app, "course")

            // L18 with its first hint: the partial program follows the hint's 11- and 8-step folds.
            // Type before revealing the hint, which would push the iPad editor under the keyboard.
            open(10085, in: app)
            enter("a(X):sa(X-1)\na(11)ra(8)", in: app, text: text)
            scrollToTop(in: app)
            app.buttons["reveal-hint"].storeTap()
            XCTAssertTrue(app.staticTexts["lesson-hint-1"].waitForExistence(timeout: 5))
            runTurbo(in: app, text: text)
            sleep(2)
            XCTAssertFalse(app.staticTexts["completion-title"].exists)
            capture(app, "hints")
            back(in: app, text: text)

            show("手册", in: app, text: text)
            capture(app, "guide")

            show("AI Battlefield", in: app, text: text)
            reveal("chooseBattlefieldProblems", in: app).storeTap()
            app.buttons["clearBattlefieldProblems"].storeTap()
            for id in [10001, 10006, 10012] {
                app.descendants(matching: .any)["problemChoice-\(id)"].firstMatch.storeTap()
            }
            app.buttons["closeBattlefieldSheet"].storeTap()
            reveal("startBattlefield", in: app).storeTap()
            XCTAssertTrue(app.buttons["shareBattlefield"].waitForExistence(timeout: 60), "Match did not finish")
            let score = app.staticTexts["score-fixture-1"]
            XCTAssertTrue([score.label, score.value as? String].contains("80%"), score.debugDescription)
            capture(app, "battlefield")

            show("记录", in: app, text: text)
            XCTAssertTrue(app.buttons["export-backup"].waitForExistence(timeout: 5))
            capture(app, "progress")
            app.terminate()
        #endif
    }

    @MainActor
    private func launch(language: String) -> XCUIApplication {
        continueAfterFailure = false
        #if os(iOS)
            // iPad screenshots are landscape so the board and editor sit side by side.
            XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
        #endif
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--reset-progress", "--battlefield-fixture", "--battlefield-showcase",
            "-AppleLanguages", "(\(language))",
        ]
        app.launch()
        app.activate()
        #if os(macOS)
            if !app.windows.firstMatch.waitForExistence(timeout: 3) {
                app.typeKey("n", modifierFlags: .command)
                XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
            }
            // 1680 × 1050 points shows a whole lesson; its Retina capture scales to the 2880 × 1800 store size.
            let window = app.windows.firstMatch
            let origin = window.coordinate(withNormalizedOffset: .zero)
            let frame = window.frame
            origin.withOffset(CGVector(dx: frame.width - 2, dy: frame.height - 2))
                .click(forDuration: 0.2, thenDragTo: origin.withOffset(CGVector(dx: 1678, dy: 1048)))
            XCTAssertEqual(window.frame.width, 1680, accuracy: 1)
            XCTAssertEqual(window.frame.height, 1050, accuracy: 1)
        #endif
        XCTAssertTrue(app.buttons["continue-problem"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func open(_ id: Int, in app: XCUIApplication) {
        let search = app.textFields["problem-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.storeTap()
        // Return closes the iOS keyboard so it cannot cover the search result.
        search.typeText("\(id)\n")
        let problem = app.buttons["problem-\(id)"]
        XCTAssertTrue(problem.waitForExistence(timeout: 5))
        problem.storeTap()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func enter(_ source: String, in app: XCUIApplication, text: Labels) {
        let editor = app.textViews["code-editor"]
        #if os(iOS)
            let dismiss = app.buttons[text.dismissKeyboard]
            if UIDevice.current.userInterfaceIdiom == .phone {
                // The keyboard and pinned Run controls cover the lower screen; keep the editor header at the top.
                let top = app.navigationBars.firstMatch.frame.maxY + 16
                drag(gamePage(in: app), by: dismiss.frame.minY - top)
            }
        #endif
        editor.storeTap()
        editor.typeText(source)
        #if os(iOS)
            // The iPad keyboard reflows the lesson; tap once the editor header settles.
            dismiss.waitForStableFrame()
            dismiss.storeTap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "The keyboard covers the capture")
        #endif
    }

    @MainActor
    private func runTurbo(in app: XCUIApplication, text: Labels) {
        app.buttons[text.turbo].storeTap()
        app.buttons["run-program"].storeTap()
    }

    @MainActor
    private func back(in app: XCUIApplication, text: Labels) {
        // iOS names the back button after the previous screen; the Mac toolbar uses a localized Back.
        let back = app.buttons.matching(NSPredicate(format: "label IN %@", [text.back, "Herbert"])).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), app.navigationBars.firstMatch.debugDescription)
        back.storeTap()
        let clear = app.buttons["clear-search"]
        if clear.waitForExistence(timeout: 5) { clear.storeTap() }
        XCTAssertTrue(app.buttons["continue-problem"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func show(_ section: String, in app: XCUIApplication, text: Labels) {
        let sidebar = app.descendants(matching: .any)["section-\(section)"].firstMatch
        if sidebar.exists {
            sidebar.storeTap()
        } else {
            app.tabBars.buttons[text.tabs[section] ?? section].storeTap()
        }
    }

    @MainActor
    private func reveal(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let element = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<8 where !element.isHittable {
            #if os(macOS)
                app.scrollViews.containing(.any, identifier: id).firstMatch.scroll(byDeltaX: 0, deltaY: -400)
            #else
                app.swipeUp()
            #endif
        }
        return element
    }

    /// Shows the lesson from its title, as a player first sees it.
    @MainActor
    private func scrollToTop(in app: XCUIApplication) {
        let page = gamePage(in: app)
        #if os(macOS)
            page.scroll(byDeltaX: 0, deltaY: 2000)
        #else
            for _ in 0..<2 { drag(page, by: -page.frame.height * 0.6) }
        #endif
    }

    /// The innermost scroll view holding the editor; iPad also exposes an enclosing full-window scroll view.
    @MainActor
    private func gamePage(in app: XCUIApplication) -> XCUIElement {
        let pages = app.scrollViews.containing(.textView, identifier: "code-editor").allElementsBoundByIndex
        return pages.min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
            ?? app.scrollViews.firstMatch
    }

    /// Phones cannot fit the lesson, board and editor at once; show the solved board with its program.
    @MainActor
    private func showBoardAndCode(in app: XCUIApplication) {
        #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .phone {
                let page = gamePage(in: app)
                let board = app.descendants(matching: .any)["game-board"].firstMatch
                let top = app.navigationBars.firstMatch.frame.maxY + 76
                for _ in 0..<3 where abs(board.frame.minY - top) > 4 { drag(page, by: board.frame.minY - top) }
                return
            }
        #endif
        scrollToTop(in: app)
    }

    #if os(iOS)
        /// Drags inside the page margin because the board handles its own pan gestures.
        @MainActor
        private func drag(_ page: XCUIElement, by distance: CGFloat) {
            let start = page.coordinate(withNormalizedOffset: .zero).withOffset(
                CGVector(dx: 6, dy: page.frame.height * (distance > 0 ? 0.85 : 0.15)))
            start.press(
                forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)), withVelocity: .slow,
                thenHoldForDuration: 0.5)
        }
    #endif

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        #if os(iOS)
            let screenshot = XCUIScreen.main.screenshot()
        #else
            app.activate()
            let screenshot = app.windows.firstMatch.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "store-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

extension XCUIElement {
    @MainActor
    fileprivate func storeTap() {
        #if os(macOS)
            XCUIApplication().activate()
            click()
        #else
            tap()
        #endif
    }
}
