import ImageIO
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
        #if os(macOS)
            if !app.windows.firstMatch.waitForExistence(timeout: 3) {
                app.typeKey("n", modifierFlags: .command)
                XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
            }
            if let display = ProcessInfo.processInfo.environment["HERBERT_TEST_DISPLAY"] {
                app.menuBars.menuBarItems.matching(
                    NSPredicate(format: "title IN %@", ["Window", "窗口", "ウインドウ"])
                ).firstMatch.click()
                let move = app.menuBars.menuItems.matching(
                    NSPredicate(format: "title ENDSWITH %@", display)
                ).firstMatch
                if move.waitForExistence(timeout: 3) {
                    // Cache the menu frame: macOS changes the item's identity while hovering it.
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
        XCTAssertTrue(app.buttons["continue-problem"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func openFirst(_ app: XCUIApplication) {
        app.buttons["continue-problem"].activateControl()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSolveFirstLessonAndRestoreDraftAfterRelaunch() {
        let app = launch()
        openFirst(app)
        let code = app.textViews["code-editor"]
        code.activateControl()
        code.typeText("s")
        app.buttons["run-program"].activateControl()
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        openFirst(app)
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "s")
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
        app.buttons["insert-s"].activateControl()
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "s")
        app.buttons["step-program"].activateControl()
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
    func testBoardGuideExplainsWallsAndTrapsInEveryLanguageAndStyle() {
        for (language, wall, trap) in [
            ("en", "stays put", "Herbert stays on the trap"),
            ("zh-Hans", "留在原地", "不会回到起点"),
            ("ja", "その場に留まり", "スタート地点には戻らず"),
        ] {
            let app = launch(language: language)
            openFirst(app)
            XCTAssertFalse(app.buttons["original-best-reference"].exists, "Original lessons have no site reference")
            for style in language == "en" ? ["modern", "classic"] : ["modern"] {
                app.buttons["board-options"].activateControl()
                selectBoardStyle(style, in: app)
                app.buttons["close-board-options"].activateControl()
                app.buttons["board-legend"].activateControl()
                XCTAssertTrue(app.staticTexts["board-wall-help"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.staticTexts["board-wall-help"].displayedText.contains(wall))
                XCTAssertTrue(app.staticTexts["board-trap-help"].displayedText.contains(trap))
                XCTAssertTrue(app.staticTexts["board-target-help"].exists)
                capture(app, name: "board-guide-\(language)-\(style)")
                app.buttons["close-board-legend"].activateControl()
                XCTAssertTrue(app.buttons["insert-s"].isEnabled)
            }
            app.terminate()
        }
    }

    @MainActor
    func testCommunityReferenceLengthMissingRecordAndLocalizedHelp() throws {
        #if APP_STORE
            throw XCTSkip("The App Store edition excludes community problems and their site records.")
        #else
            for (language, explanation, missing, back) in [
                ("en", "Best column", "No record", "Back"),
                ("zh-Hans", "Best 栏", "暂无记录", "返回"),
                ("ja", "Best 欄", "記録なし", "戻る"),
            ] {
                let app = launch(language: language)
                openProblem(3, in: app)
                XCTAssertTrue(app.buttons["original-best-reference"].label.hasSuffix(": 8 B"))
                XCTAssertTrue(app.staticTexts["0 / 19 B"].exists, "The puzzle limit remains independent of Best")
                app.buttons["original-best-reference"].activateControl()
                XCTAssertTrue(app.staticTexts["original-best-explanation"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.staticTexts["original-best-explanation"].displayedText.contains(explanation))
                app.buttons["close-original-best-info"].activateControl()
                app.buttons[back].activateControl()
                app.buttons["clear-search"].activateControl()
                openProblem(290, in: app)
                XCTAssertTrue(app.buttons["original-best-reference"].label.hasSuffix(": " + missing))
                if language == "en" {
                    app.buttons[back].activateControl()
                    app.buttons["clear-search"].activateControl()
                    openProblem(27, in: app)
                    XCTAssertTrue(app.buttons["original-best-reference"].label.hasSuffix(": 14 B"))
                    capture(app, name: "community-reference")
                    app.buttons["board-legend"].activateControl()
                    XCTAssertTrue(app.staticTexts["board-trap-help"].waitForExistence(timeout: 5))
                    #if os(macOS)
                        XCTAssertTrue(app.popovers.firstMatch.waitForExistence(timeout: 5))
                        capture(app, name: "community-board-guide", element: app.popovers.firstMatch)
                    #else
                        capture(app, name: "community-board-guide")
                    #endif
                    app.buttons["close-board-legend"].activateControl()
                }
                app.terminate()
            }
        #endif
    }

    @MainActor
    func testBoardSettingsPersistAndTrailCanBeHiddenWithoutLosingMoves() {
        var app = launch(language: "en")
        openProblem(10012, in: app)
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
        selectBoardStyle("classic", in: app)
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
    func testAdjacentWallCellsRenderWithoutSeamsInBothStyles() throws {
        let app = launch(language: "en")
        openProblem(10006, in: app)
        for style in ["modern", "classic"] {
            app.buttons["board-options"].activateControl()
            selectBoardStyle(style, in: app)
            app.buttons["close-board-options"].activateControl()
            XCTAssertTrue(app.popovers.firstMatch.waitForNonExistence(timeout: 5))
            let board = app.descendants(matching: .any)["game-board"].firstMatch
            let data = board.screenshot().pngRepresentation as CFData
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            let context = try XCTUnwrap(
                CGContext(
                    data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                    bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
            // L02 has three horizontal walls centered in its focused 7 × 7 region.
            let cell = Double(min(image.width, image.height)) / 7
            let y = image.height / 2
            // Sample away from a grid dot, which is faintly visible beneath Modern opacity.
            let center = (y * image.width + Int(Double(image.width) / 2 + cell * 0.25)) * 4
            XCTAssertLessThan(pixels[center], 128, "Wall center must be dark")
            for offset in [-0.51, -0.5, -0.49, 0.49, 0.5, 0.51] {
                let x = Int(Double(image.width) / 2 + offset * cell)
                let index = (y * image.width + x) * 4
                for channel in 0..<3 {
                    XCTAssertLessThanOrEqual(
                        abs(Int(pixels[index + channel]) - Int(pixels[center + channel])), 3,
                        "\(style) seam at \(offset) cells")
                }
            }
        }
        app.terminate()
    }

    @MainActor
    private func openProblem(_ id: Int, in app: XCUIApplication) {
        let search = app.textFields["problem-search"]
        search.activateControl()
        search.typeText(id < 10000 ? String(format: "%04d", id) : String(id))
        let problem = app.buttons["problem-\(id)"]
        XCTAssertTrue(problem.waitForExistence(timeout: 5))
        problem.activateControl()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCurriculumHintsAndCatalogEdition() {
        let app = launch(language: "en")
        #if APP_STORE
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "30 PROBLEMS")
            XCTAssertFalse(app.buttons["filter-community"].exists)
        #else
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "1,799 PROBLEMS")
            app.buttons["filter-originals"].activateControl()
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "30 PROBLEMS")
            app.buttons["filter-community"].activateControl()
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "1,769 PROBLEMS")
            app.buttons["filter-all"].activateControl()
        #endif
        openFirst(app)
        XCTAssertTrue(app.staticTexts["lesson-objective"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["lesson-hint-1"].exists)
        app.buttons["reveal-hint"].activateControl()
        XCTAssertTrue(app.staticTexts["lesson-hint-1"].exists)
        XCTAssertFalse(app.staticTexts["lesson-hint-2"].exists)
        app.buttons["reveal-hint"].activateControl()
        XCTAssertTrue(app.staticTexts["lesson-hint-2"].exists)
        XCTAssertFalse(app.buttons["reveal-hint"].exists)
        app.buttons["insert-s"].activateControl()
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "s")
        #if os(macOS)
            app.scrollViews.containing(.textView, identifier: "code-editor").firstMatch.scroll(
                byDeltaX: 0, deltaY: -500)
        #else
            app.scrollViews.containing(.textView, identifier: "code-editor").firstMatch.swipeUp()
        #endif
        app.buttons["step-program"].activateControl()
        XCTAssertTrue(app.buttons["next-problem"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["next-problem"].activateControl()
        XCTAssertTrue(app.staticTexts["Around the block"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["lesson-hint-1"].exists)
        app.terminate()
    }

    @MainActor
    func testAdvancedWallCountingAndRecursiveCompositionComplete() {
        let app = launch(language: "en")
        for (id, source) in [
            (10051, "a(N,X):XrXlXrrXrXlXrra(N-1,Xs)\nq(P):PPPP\nq(a(3,ss)r)"),
            (10052, "b(N):sb(N-1)\nq(P):PPPP\nw:q(b(6)r)\nwrb(11)lw"),
            (10031, "b(N):sb(N-1)\na(N,T):b(24)Tb(3)Ta(N-1,rrT)\nra(6,r)"),
            (
                10050,
                "b(N):sb(N-1)\nq(X):XXXX\nd(W):q(b(W)r)\n"
                    + "a(N,D,T):d(D)b(D)Ta(N-1,D-2,rrT)rra(N-1,D-2,T)Trrb(D)rr\nq(a(3,6,r)r)"
            ),
        ] {
            openProblem(id, in: app)
            app.textViews["code-editor"].activateControl()
            app.textViews["code-editor"].typeText(source)
            #if os(macOS)
                app.scrollViews.containing(.textView, identifier: "code-editor").firstMatch.scroll(
                    byDeltaX: 0, deltaY: -800)
            #else
                app.scrollViews.containing(.textView, identifier: "code-editor").firstMatch.swipeUp()
            #endif
            app.buttons["Turbo"].activateControl()
            app.buttons["run-program"].activateControl()
            XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 10), "L\(id - 10000)")
            let board = app.descendants(matching: .any)["game-board"].firstMatch
            XCTAssertTrue(board.label.contains("trail on"), board.label)
            app.buttons["Back"].activateControl()
            app.buttons["clear-search"].activateControl()
        }
        app.terminate()
    }

    @MainActor
    func testCaptureOriginalCourseScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["HERBERT_CAPTURE_SCREENSHOTS"] == "1")
        let language = ProcessInfo.processInfo.environment["HERBERT_SCREENSHOT_LANGUAGE"] ?? "en"
        XCTAssertTrue(["en", "zh-Hans"].contains(language))
        let app = launch(language: language)
        XCTAssertTrue(app.staticTexts[language == "en" ? "Explore problems" : "探索关卡"].exists)
        #if os(macOS)
            if app.windows.firstMatch.frame.height < 1000 {
                app.menuBars.menuBarItems.matching(
                    NSPredicate(format: "title IN %@", ["Window", "窗口", "ウインドウ"])
                ).firstMatch.click()
                app.menuBars.menuItems["performZoom:"].click()
            }
            let window = app.windows.firstMatch
            let origin = window.coordinate(withNormalizedOffset: .zero)
            window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5)).withOffset(
                CGVector(dx: -1, dy: 0)
            ).click(
                forDuration: 0.2,
                thenDragTo: origin.withOffset(CGVector(dx: 1239, dy: window.frame.height / 2)))
            window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(
                CGVector(dx: 0, dy: -1)
            ).click(
                forDuration: 0.2,
                thenDragTo: origin.withOffset(CGVector(dx: window.frame.width / 2, dy: 1079)))
            XCTAssertLessThanOrEqual(window.frame.width, 1800)
            XCTAssertGreaterThanOrEqual(window.frame.height, 1000)
        #endif
        capture(app, name: "course-library")
        for (id, name) in [
            (10051, "rose"), (10052, "lanterns"), (10038, "rosette"), (10044, "seal"), (10049, "mosaic"),
            (10050, "cathedral"),
        ] {
            openProblem(id, in: app)
            capture(app, name: "course-\(name)")
            app.activate()
            let board = app.descendants(matching: .any)["game-board"].firstMatch
            #if os(macOS)
                XCTAssertTrue(app.windows.firstMatch.frame.contains(board.frame))
            #endif
            let image = XCTAttachment(screenshot: board.screenshot())
            image.name = "readme-course-\(name)-board"
            image.lifetime = .keepAlways
            add(image)
            if id == 10049 {
                app.textViews["code-editor"].activateControl()
                app.textViews["code-editor"].typeText("a(X):sa(X-1)\na(3)")
                for _ in 0..<3 { app.buttons["step-program"].activateControl() }
                app.buttons["board-options"].activateControl()
                selectBoardStyle("classic", in: app)
                app.buttons["close-board-options"].activateControl()
                XCTAssertTrue(app.popovers.firstMatch.waitForNonExistence(timeout: 5))
                capture(app, name: "course-mosaic-classic")
                let classic = XCTAttachment(screenshot: board.screenshot())
                classic.name = "readme-course-mosaic-classic-board"
                classic.lifetime = .keepAlways
                add(classic)
                app.buttons["board-options"].activateControl()
                selectBoardStyle("modern", in: app)
                app.buttons["close-board-options"].activateControl()
                XCTAssertTrue(app.popovers.firstMatch.waitForNonExistence(timeout: 5))
            }
            app.buttons[language == "en" ? "Back" : "返回"].activateControl()
            app.buttons["clear-search"].activateControl()
        }
    }

    @MainActor
    func testCaptureReadmeScreenshots() throws {
        #if APP_STORE
            throw XCTSkip("Community gallery is excluded from the App Store edition.")
        #else
            try XCTSkipUnless(
                ProcessInfo.processInfo.environment["HERBERT_CAPTURE_SCREENSHOTS"] == "1",
                "Run scripts/capture_screenshots.sh to refresh the documentation images.")
            let language = ProcessInfo.processInfo.environment["HERBERT_SCREENSHOT_LANGUAGE"] ?? "en"
            XCTAssertTrue(["en", "zh-Hans"].contains(language), "Unsupported screenshot language")
            let app = launch(language: language)
            XCTAssertTrue(app.staticTexts[language == "en" ? "Explore problems" : "探索关卡"].exists)
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
                    code.typeText("a(X):sa(X-1)\na(4)")
                }
                capture(app, name: name)
                let board = app.descendants(matching: .any)["game-board"].firstMatch
                XCTAssertTrue(board.exists)
                app.activate()
                let image = XCTAttachment(screenshot: board.screenshot())
                image.name = "readme-\(name)-board"
                image.lifetime = .keepAlways
                add(image)
                if id == 37 {
                    for _ in 0..<4 { app.buttons["step-program"].activateControl() }
                    app.buttons["board-options"].activateControl()
                    selectBoardStyle("classic", in: app)
                    app.buttons["close-board-options"].activateControl()
                    XCTAssertTrue(app.popovers.firstMatch.waitForNonExistence(timeout: 5))
                    app.textViews["code-editor"].activateControl()
                    capture(app, name: "flower-classic")
                    app.activate()
                    let classic = XCTAttachment(screenshot: board.screenshot())
                    classic.name = "readme-flower-classic-board"
                    classic.lifetime = .keepAlways
                    add(classic)
                    app.buttons["board-options"].activateControl()
                    selectBoardStyle("modern", in: app)
                    app.buttons["close-board-options"].activateControl()
                }
                app.buttons[language == "en" ? "Back" : "返回"].activateControl()
                XCTAssertTrue(search.waitForExistence(timeout: 5))
                app.buttons["clear-search"].activateControl()
            }
        #endif
    }

    @MainActor
    private func selectBoardStyle(_ style: String, in app: XCUIApplication) {
        #if os(macOS)
            app.radioButtons["board-style-\(style)"].activateControl()
        #else
            app.buttons["board-style-\(style)"].activateControl()
        #endif
    }

    @MainActor
    private func boardToggle(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.switches[id]
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String, element: XCUIElement? = nil) {
        guard ProcessInfo.processInfo.environment["HERBERT_CAPTURE_SCREENSHOTS"] == "1" else { return }
        app.activate()
        let image = XCTAttachment(screenshot: (element ?? app.windows.firstMatch).screenshot())
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
