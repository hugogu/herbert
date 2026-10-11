import ImageIO
import XCTest

#if os(macOS)
    import AppKit
#endif

final class HerbertUITests: XCTestCase {
    @MainActor
    private func launch(reset: Bool = true, language: String = "zh-Hans", shortWindow: Bool = false) -> XCUIApplication
    {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments =
            ["--ui-testing", "-AppleLanguages", "(\(language))"] + (reset ? ["--reset-progress"] : [])
            + (shortWindow ? ["--ui-testing-short-window"] : [])
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
    func testOverLimitProgramRunsWithoutSavingAcceptedProgress() {
        let app = launch(language: "en")
        openFirst(app)
        let editor = app.textViews["code-editor"]
        editor.activateControl()
        editor.typeText("ss")
        app.buttons["run-program"].activateControl()
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "trial only", "trial only")
            ).firstMatch.exists)
        app.terminate()
        let restored = launch(reset: false, language: "en")
        #if os(macOS)
            XCTAssertTrue(restored.staticTexts["sidebar-progress"].displayedText.hasPrefix("0 /"))
        #endif
        openFirst(restored)
        XCTAssertEqual(restored.textViews["code-editor"].value as? String, "ss")
        // The first puzzle remains unsolved, even though trial execution lit its target.
        restored.buttons["run-program"].activateControl()
        XCTAssertTrue(restored.staticTexts["completion-title"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            restored.staticTexts.matching(
                NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", "trial only", "trial only")
            ).firstMatch.exists)
        restored.terminate()
    }

    @MainActor
    func testCopyProblemPromptIncludesSharedRulesExamplesAndBoardWithoutChangingDraft() throws {
        let app = launch(language: "en")
        openFirst(app)
        app.buttons["insert-r"].activateControl()
        app.buttons["problem-details"].activateControl()
        let copy = app.buttons["copy-ai-prompt"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        try assertButtonInk(copy, white: true)
        copy.activateControl()
        XCTAssertTrue(copy.label.contains("copied"))
        #if os(macOS)
            let prompt = NSPasteboard.general.string(forType: .string) ?? ""
            XCTAssertTrue(prompt.hasPrefix("# Herbert H programming challenge"))
            XCTAssertTrue(prompt.contains("## Worked example 2"))
            XCTAssertTrue(prompt.contains("## Puzzle to solve\n\nPuzzle L01 (ID 10001), byte limit: 1."))
            XCTAssertTrue(prompt.contains("24: ........................."))
            XCTAssertTrue(
                prompt.hasSuffix(
                    "Return one complete fenced h block, with definitions first and an execution line last."))
        #endif
        app.buttons["close-problem-details"].activateControl()
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "r")
        app.terminate()
    }

    @MainActor
    func testProgressActionsHaveCompactLabelsAndVisibleColors() throws {
        let app = launch(language: "en")
        #if os(macOS)
            app.descendants(matching: .any)["section-我的"].firstMatch.activateControl()
        #else
            app.buttons["My"].activateControl()
        #endif
        let export = app.buttons["export-backup"]
        let importButton = app.buttons["import-backup"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        XCTAssertEqual(export.label, "Export")
        XCTAssertEqual(importButton.label, "Import")
        try assertButtonInk(export, white: true)
        try assertButtonInk(importButton, white: false)
        capture(app, name: "progress-actions")
        app.terminate()
    }

    @MainActor
    private func assertButtonInk(_ button: XCUIElement, white: Bool) throws {
        XCUIApplication().activate()
        let source = try XCTUnwrap(CGImageSourceCreateWithData(button.screenshot().pngRepresentation as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var inkPixels = 0
        // Ignore the native border, corners and shadow; inspect the label's interior.
        for y in (image.height / 3)..<(image.height * 2 / 3) {
            for x in (image.width / 5)..<(image.width * 4 / 5) {
                let offset = (y * image.width + x) * 4
                let r = Int(pixels[offset])
                let g = Int(pixels[offset + 1])
                let b = Int(pixels[offset + 2])
                if white ? (r > 235 && g > 235 && b > 235) : (g > r + 35 && g > b + 8 && g < 170) {
                    inkPixels += 1
                }
            }
        }
        XCTAssertGreaterThan(inkPixels, 20, "Button text and icon must remain visible in the action color")
    }

    @MainActor
    func testShortHeightKeepsNavigationAndPlaygroundVisible() {
        let app = launch(language: "en", shortWindow: true)
        #if os(macOS)
            let window = app.windows.firstMatch
            let origin = window.coordinate(withNormalizedOffset: .zero)
            let frame = window.frame
            origin.withOffset(CGVector(dx: frame.width - 2, dy: frame.height - 2))
                .click(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 930, dy: 428)))
            XCTAssertLessThan(window.frame.height, 460)
        #else
            XCUIDevice.shared.orientation = .landscapeLeft
            defer { XCUIDevice.shared.orientation = .portrait }
        #endif
        for section in ["手册", "记录", "AI Battlefield", "关卡"] {
            let navigation = app.descendants(matching: .any)["section-\(section)"].firstMatch
            #if os(macOS)
                XCTAssertTrue(navigation.isHittable, "All sidebar destinations fit without scrolling")
                navigation.activateControl()
            #else
                if navigation.exists { navigation.activateControl() }
            #endif
        }
        #if os(macOS)
            let brand = app.staticTexts["sidebar-brand"].frame
            XCTAssertLessThan(brand.minY - window.frame.minY, 90)
            let footer = app.descendants(matching: .any)["sidebar-progress"].firstMatch.frame
            XCTAssertLessThan(footer.height, 24)
        #endif
        openFirst(app)
        let board = app.descendants(matching: .any)["game-board"].firstMatch
        let editor = app.textViews["code-editor"]
        XCTAssertTrue(board.isHittable)
        XCTAssertTrue(editor.isHittable)
        XCTAssertLessThan(board.frame.minX, editor.frame.minX)
        XCTAssertLessThan(abs(board.frame.minY - editor.frame.minY), 60)
        #if os(macOS)
            XCTAssertTrue(window.frame.contains(board.frame), "The entire board is visible on entry")
            XCTAssertTrue(window.frame.contains(editor.frame), "The editor is visible on entry")
            XCTAssertTrue(app.buttons["run-program"].isHittable)
        #endif
        let size = app.staticTexts["game-program-size"]
        XCTAssertGreaterThan(size.frame.minY, board.frame.maxY)
        XCTAssertFalse(app.staticTexts["lesson-objective"].exists)
        capture(app, name: "compact-playground")
        app.buttons["problem-details"].activateControl()
        XCTAssertTrue(app.staticTexts["problem-credit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["lesson-objective"].exists)
        app.buttons["reveal-hint"].activateControl()
        XCTAssertTrue(app.staticTexts["lesson-hint-1"].exists)
        app.buttons["close-problem-details"].activateControl()
        XCTAssertTrue(app.staticTexts["problem-credit"].waitForNonExistence(timeout: 5))
        app.buttons["problem-details"].activateControl()
        XCTAssertTrue(app.staticTexts["problem-credit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["lesson-hint-1"].exists)
        app.buttons["close-problem-details"].activateControl()
        app.buttons["insert-s"].activateControl()
        app.buttons["step-program"].activateControl()
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 5))
        capture(app, name: "compact-completed")
        #if os(macOS)
            let short = window.frame
            let start = window.coordinate(withNormalizedOffset: .zero)
            start.withOffset(CGVector(dx: short.width - 2, dy: short.height - 2))
                .click(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 1238, dy: 848)))
        #else
            XCUIDevice.shared.orientation = .portrait
        #endif
        XCTAssertTrue(app.staticTexts["lesson-objective"].waitForExistence(timeout: 5))
        XCTAssertLessThan(size.frame.minY, board.frame.minY, "Statistics return above the board in a tall layout")
        XCTAssertEqual(editor.value as? String, "s", "Resizing preserves the program")
        app.terminate()
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
    func testKeyboardDismissAndCommandKeysFollowTheReflowedIPadEditor() throws {
        #if os(iOS)
            try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "The reflow happens on iPad.")
            // The landscape keyboard switches the lesson to its compact layout while editing.
            XCUIDevice.shared.orientation = .landscapeLeft
            defer { XCUIDevice.shared.orientation = .portrait }
            let app = launch(language: "en")
            openFirst(app)
            let editor = app.textViews["code-editor"]
            editor.activateControl()
            editor.typeText("s")
            let dismiss = app.buttons["Dismiss keyboard"]
            dismiss.waitForStableFrame()
            dismiss.activateControl()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            app.buttons["insert-s"].activateControl()
            XCTAssertEqual(editor.value as? String, "ss")
            app.terminate()
        #else
            throw XCTSkip("Only iPhone and iPad show a software keyboard.")
        #endif
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
    func testGuideShowsTheAppVersion() {
        let app = launch(language: "en")
        let section = app.descendants(matching: .any)["section-手册"].firstMatch
        if section.exists { section.activateControl() } else { app.tabBars.buttons["Guide"].activateControl() }
        let version = app.staticTexts["app-version"]
        XCTAssertTrue(version.waitForExistence(timeout: 5))
        XCTAssertNotNil(
            version.displayedText.range(of: #"^Version \d+\.\d+\.\d+ \(\d+\)$"#, options: .regularExpression),
            version.displayedText)
        app.terminate()
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
                XCTAssertEqual(
                    app.staticTexts["game-program-size"].displayedText, "0 / 19 B",
                    "The puzzle limit remains independent of Best")
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
    func testThreeDStyleCanBeChosenTurnedAndTiltedAndPersists() throws {
        var app = launch(language: "en")
        openProblem(10074, in: app)
        selectThreeD(in: app)
        var board = app.descendants(matching: .any)["game-board"].firstMatch
        XCTAssertTrue(board.label.contains("3D; grid dots on; trail on; 0"), board.debugDescription)
        XCTAssertEqual(board.value as? String, "View 0°, tilt 56°")
        let amber = try countPixels(in: board) { red, green, blue in
            red > 200 && (120...190).contains(green) && blue < 110
        }
        XCTAssertGreaterThan(amber, 300, "The glowing discs are part of the picture")
        app.buttons["camera-rotate-right"].activateControl()
        XCTAssertEqual(board.value as? String, "View 90°, tilt 56°")
        app.buttons["camera-rotate-left"].activateControl()
        app.buttons["camera-rotate-left"].activateControl()
        XCTAssertEqual(board.value as? String, "View 270°, tilt 56°")
        app.buttons["camera-tilt"].activateControl()
        XCTAssertEqual(board.value as? String, "View 270°, tilt 76°")
        capture(app, name: "three-d-turned")
        app.buttons["reset-board-view"].activateControl()
        XCTAssertEqual(board.value as? String, "View 0°, tilt 56°")
        app.terminate()
        app = launch(reset: false, language: "en")
        openFirst(app)
        board = app.descendants(matching: .any)["game-board"].firstMatch
        XCTAssertTrue(board.label.contains("3D; grid dots on; trail on; 0"), "The style is remembered")
        app.terminate()
    }

    @MainActor
    func testThreeDBoardOrbitsWithADragAndKeepsVerticalSwipesForThePage() throws {
        let app = launch(language: "en")
        openProblem(10074, in: app)
        selectThreeD(in: app)
        let board = app.descendants(matching: .any)["game-board"].firstMatch
        XCTAssertEqual(board.value as? String, "View 0°, tilt 56°")
        #if os(macOS)
            board.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).click(
                forDuration: 0.1, thenDragTo: board.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
            XCTAssertNotEqual(board.value as? String, "View 0°, tilt 56°", "Dragging turns the board")
        #else
            board.swipeLeft()
            let turned = try XCTUnwrap(board.value as? String)
            XCTAssertNotEqual(turned, "View 0°, tilt 56°", "Dragging sideways turns the board")
            XCTAssertTrue(turned.hasSuffix("tilt 56°"), "Sideways drags never tilt")
            let before = board.frame.minY
            // Start in the visible upper part of the board, clear of the pinned run controls.
            board.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.3)).press(
                forDuration: 0.05, thenDragTo: board.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.02)))
            XCTAssertEqual((board.value as? String)?.hasSuffix("tilt 56°"), true, "Vertical drags never tilt")
            if app.windows.firstMatch.frame.width < 600 {
                XCTAssertLessThan(board.frame.minY, before, "A vertical swipe over the board scrolls the page")
            }
        #endif
        app.terminate()
    }

    @MainActor
    func testThreeDBoardGetsMoreRoomThanTheFlatStyles() throws {
        let app = launch(language: "en")
        openProblem(10074, in: app)
        let flat = app.descendants(matching: .any)["game-board"].firstMatch.frame
        selectThreeD(in: app)
        let deep = app.descendants(matching: .any)["game-board"].firstMatch.frame
        XCTAssertGreaterThanOrEqual(deep.width, flat.width - 1)
        if app.windows.firstMatch.frame.width < 600 {
            XCTAssertGreaterThan(deep.height, flat.height * 1.1, "A foreshortened board needs a taller phone panel")
        } else {
            // Beside the editor the panel follows its column: no taller than the board can use, never cramped.
            XCTAssertGreaterThanOrEqual(deep.height, 340)
        }
        app.terminate()
    }

    @MainActor
    func testThreeDStageEnlargesTheBoardAndRunsTheProgram() throws {
        let app = launch(language: "en")
        openFirst(app)
        selectThreeD(in: app)
        app.textViews["code-editor"].activateControl()
        app.textViews["code-editor"].typeText("s")
        let inline = app.descendants(matching: .any)["game-board"].firstMatch.frame
        app.buttons["enlarge-board"].activateControl()
        XCTAssertTrue(app.buttons["close-stage"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.textViews["code-editor"].exists, "The page behind the stage is out of reach")
        let stage = app.descendants(matching: .any)["game-board"].firstMatch.frame
        XCTAssertGreaterThan(
            stage.width * stage.height, inline.width * inline.height * 1.3, "The stage is for a bigger board")
        for identifier in [
            "camera-rotate-left", "camera-rotate-right", "camera-tilt", "camera-zoom-in", "camera-zoom-out",
            "camera-follow", "camera-focus", "camera-reset",
        ] {
            XCTAssertTrue(app.buttons[identifier].exists, identifier)
        }
        capture(app, name: "three-d-stage")
        app.buttons["camera-follow"].activateControl()
        app.buttons["camera-zoom-in"].activateControl()
        XCTAssertEqual(app.staticTexts["stage-program"].displayedText, "s")
        app.buttons["stage-run-program"].activateControl()
        XCTAssertTrue(
            app.descendants(matching: .any)["stage-completion"].waitForExistence(timeout: 8), app.debugDescription)
        capture(app, name: "three-d-stage-complete")
        app.buttons["close-stage"].activateControl()
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textViews["code-editor"].exists)
        app.terminate()
    }

    @MainActor
    func testThreeDBoardGuideNamesDiscsAndHoles() throws {
        let app = launch(language: "en")
        openProblem(10074, in: app)
        selectThreeD(in: app)
        let legend = app.buttons["board-legend"]
        #if os(iOS)
            // On a phone the legend sits below the fold, under the pinned run controls.
            if app.windows.firstMatch.frame.width < 600 { app.swipeUp() }
        #endif
        legend.activateControl()
        // Match any element type: iOS exposes sheet text differently from a Mac popover.
        let targetHelp = app.descendants(matching: .any)["board-target-help"].firstMatch
        XCTAssertTrue(targetHelp.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(targetHelp.displayedText.contains("glowing disc"), targetHelp.debugDescription)
        let trapHelp = app.descendants(matching: .any)["board-trap-help"].firstMatch
        XCTAssertTrue(trapHelp.displayedText.contains("Herbert stays on the trap"), trapHelp.debugDescription)
        capture(app, name: "three-d-guide")
        app.buttons["close-board-legend"].activateControl()
        app.terminate()
    }

    @MainActor
    func testCaptureThreeDScreenshots() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["HERBERT_CAPTURE_SCREENSHOTS"] == "1",
            "Run scripts/capture_screenshots.sh to refresh the documentation images.")
        let app = launch(language: ProcessInfo.processInfo.environment["HERBERT_SCREENSHOT_LANGUAGE"] ?? "en")
        openProblem(10096, in: app)
        selectThreeD(in: app)
        app.textViews["code-editor"].activateControl()
        app.textViews["code-editor"].typeText("a(X):sa(X-1)\na(3)")
        for _ in 0..<3 { app.buttons["step-program"].activateControl() }
        let board = app.descendants(matching: .any)["game-board"].firstMatch
        #if os(iOS)
            // Bring the whole board between the navigation bar and the pinned run controls.
            let window = app.windows.firstMatch.frame
            for _ in 0..<3 where board.frame.minY < 150 || board.frame.maxY > window.height - 170 {
                let delta = board.frame.minY - 160
                let start = CGVector(dx: 0.5, dy: 0.7)
                app.coordinate(withNormalizedOffset: start).press(
                    forDuration: 0.05,
                    thenDragTo: app.coordinate(
                        withNormalizedOffset: CGVector(dx: 0.5, dy: start.dy - delta / window.height)))
            }
        #endif
        capture(app, name: "three-d-board")
        app.activate()
        let image = XCTAttachment(screenshot: board.screenshot())
        image.name = "readme-three-d-board-only"
        image.lifetime = .keepAlways
        add(image)
        app.buttons["enlarge-board"].activateControl()
        XCTAssertTrue(app.buttons["close-stage"].waitForExistence(timeout: 5))
        capture(app, name: "three-d-stage-capture")
        app.terminate()
    }

    @MainActor
    private func selectThreeD(in app: XCUIApplication) {
        app.buttons["board-options"].activateControl()
        selectBoardStyle("threeD", in: app)
        app.buttons["close-board-options"].activateControl()
        XCTAssertTrue(app.popovers.firstMatch.waitForNonExistence(timeout: 5))
    }

    @MainActor
    private func countPixels(in element: XCUIElement, matching predicate: (UInt8, UInt8, UInt8) -> Bool) throws -> Int {
        let data = element.screenshot().pngRepresentation as CFData
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = try XCTUnwrap(
            CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        var count = 0
        for index in stride(from: 0, to: image.width * image.height * 4, by: 4)
        where predicate(pixels[index], pixels[index + 1], pixels[index + 2]) { count += 1 }
        return count
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
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "50 PROBLEMS")
            XCTAssertFalse(app.buttons["filter-community"].exists)
        #else
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "1,819 PROBLEMS")
            app.buttons["filter-originals"].activateControl()
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "50 PROBLEMS")
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
    func testRedesignedCurriculumProgramsComplete() {
        let app = launch(language: "en")
        for (id, source) in [
            (10074, "a(N):sa(N-1)\na(6)ra(10)ra(6)ra(10)"),
            (10075, "a(N,P):Pa(N-1,P)\nb:a(6,srsl)r\nbbbb"),
            (10076, "a(X):Xla(Xss)\na(ss)"),
            (10051, "a(N,X):XrXlXrrXrXlXrra(N-1,Xs)\nq(P):PPPP\nq(a(3,ss)r)"),
            (10052, "b(N):sb(N-1)\nq(P):PPPP\nw:q(b(6)r)\nwrb(11)lw"),
            (
                10078,
                "b(N):sb(N-1)\nq(P):PPPP\na(N):b(24)rq(b(2)r)rb(N)rrr\na(6)a(9)a(6)a(9)"
            ),
            (
                10084,
                "b(N):sb(N-1)\nq(P):PPPP\nd(N):srsld(N-1)\nw:q(d(2)r)\ne:wrb(6)l\n"
                    + "a(N):eeelb(18)rb(6)a(N-1)\nlb(8)lb(6)rra(3)"
            ),
            (
                10097,
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
    func testExpertCourseProgramsComplete() {
        for (id, source) in [
            (
                10108,
                "b(N):sb(N-1)\nq(X):XXXX\nc(W,H,T):b(W)Tb(H)Tb(W)Tb(H)T\n"
                    + "a(N,W,H,T,U):c(W,H,T)b(2)Tb(2)Ua(N-1,H-2,W-2,U,T)Ub(2)Ub(2)rr\nq(a(3,8,6,r,l)r)"
            ),
            (
                10117,
                "q(X):XXXX\nd(N,T,U):sTsUd(N-1,T,U)\ne(N,T,U):TsUse(N-1,T,U)\nc:q(sr)\nw:q(srslr)\n"
                    + "a(N,D,T,U,P,Q):Pd(D,T,U)Ta(N-1,D-1,U,T,Q,P)rra(N-2,D-2,T,U,P,Q)Trre(D,T,U)rr\n"
                    + "q(a(4,4,r,l,c,w)r)"
            ),
        ] {
            let app = launch(language: "en")
            #if !APP_STORE
                app.buttons["filter-originals"].activateControl()
            #endif
            XCTAssertEqual(app.staticTexts["catalog-count"].displayedText, "50 PROBLEMS")
            openProblem(id, in: app)
            XCTAssertTrue(app.staticTexts["lesson-objective"].exists)
            app.buttons["reveal-hint"].activateControl()
            XCTAssertTrue(app.staticTexts["lesson-hint-1"].exists)
            #if os(iOS)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    let page = app.scrollViews.containing(.textView, identifier: "code-editor").firstMatch
                    let top = app.navigationBars.firstMatch.frame.maxY + 16
                    for _ in 0..<4 where app.buttons["Dismiss keyboard"].frame.minY > top + 10 {
                        let distance = min(app.buttons["Dismiss keyboard"].frame.minY - top, page.frame.height * 0.6)
                        let start = page.coordinate(withNormalizedOffset: .zero).withOffset(
                            CGVector(dx: 6, dy: page.frame.height * 0.85))
                        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)))
                    }
                }
            #endif
            let editor = app.textViews["code-editor"]
            editor.activateControl()
            editor.typeText(source)
            #if os(iOS)
                let dismiss = app.buttons["Dismiss keyboard"]
                dismiss.waitForStableFrame()
                dismiss.activateControl()
                XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
            #endif
            app.buttons["Turbo"].activateControl()
            app.buttons["run-program"].activateControl()
            XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 15), "Problem \(id)")
            app.terminate()
        }
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
            (10051, "rose"), (10052, "lanterns"), (10085, "rosette"), (10091, "seal"), (10096, "mosaic"),
            (10097, "cathedral"),
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
            if id == 10096 {
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
    /// Static text puts its content in `value` on macOS and in `label` on iOS, where `value` can be empty.
    fileprivate var displayedText: String { (value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? label }
    fileprivate func activateControl() {
        #if os(macOS)
            XCUIApplication().activate()
            click()
        #else
            tap()
        #endif
    }
}
