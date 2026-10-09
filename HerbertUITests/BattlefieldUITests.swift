import XCTest

final class BattlefieldUITests: XCTestCase {
    @MainActor
    private func launch(
        reset: Bool = true, diagnostics: Bool = false, threeModels: Bool = false, streamErrors: Bool = false,
        specialErrors: Bool = false
    ) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments =
            ["--ui-testing", "--battlefield-fixture", "-AppleLanguages", "(en)"]
            + (reset ? ["--reset-progress"] : [])
            + (diagnostics ? ["--battlefield-diagnostics"] : [])
            + (threeModels ? ["--battlefield-three-models"] : [])
            + (streamErrors ? ["--battlefield-stream-errors"] : [])
            + (specialErrors ? ["--battlefield-special-errors"] : [])
        app.launch()
        app.activate()
        #if os(macOS)
            if !app.windows.firstMatch.waitForExistence(timeout: 3) { app.typeKey("n", modifierFlags: .command) }
            XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
            if let display = ProcessInfo.processInfo.environment["HERBERT_TEST_DISPLAY"] {
                app.menuBars.menuBarItems["Window"].click()
                let move = app.menuBars.menuItems.matching(NSPredicate(format: "title ENDSWITH %@", display)).firstMatch
                if move.exists {
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
            let window = app.windows.firstMatch
            let origin = window.coordinate(withNormalizedOffset: .zero)
            let frame = window.frame
            if abs(frame.width - 1240) > 4 || abs(frame.height - 850) > 4 {
                origin.withOffset(CGVector(dx: frame.width - 2, dy: frame.height - 2))
                    .click(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: 1238, dy: 848)))
            }
        #endif
        if app.buttons["clear-search"].exists { app.buttons["clear-search"].battlefieldTap() }
        XCTAssertTrue(app.buttons["continue-problem"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func openSection(_ name: String, in app: XCUIApplication) {
        app.descendants(matching: .any)["section-\(name == "AI 配置" ? "AI Battlefield" : name)"].firstMatch
            .battlefieldTap()
        if name == "AI 配置" { choose("AI Providers", in: app) }
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

    @MainActor
    private func choose(_ title: String, in app: XCUIApplication) {
        #if os(macOS)
            app.radioButtons[title].battlefieldTap()
        #else
            app.buttons[title].tap()
        #endif
    }

    @MainActor
    func testAddProviderDiscoversModelsAndCanBeRemoved() {
        let app = launch()
        openSection("AI 配置", in: app)
        app.buttons["addAIProvider"].battlefieldTap()
        XCTAssertTrue(app.secureTextFields["providerAPIKey"].waitForExistence(timeout: 5))
        let name = app.textFields["providerName"]
        name.battlefieldTap()
        #if os(macOS)
            name.typeKey("a", modifierFlags: .command)
        #endif
        name.typeText("Test Provider")
        app.secureTextFields["providerAPIKey"].battlefieldTap()
        app.secureTextFields["providerAPIKey"].typeText("fixture-not-a-real-key")
        app.buttons["saveAIProvider"].battlefieldTap()
        let provider = app.buttons["provider-Test Provider"]
        XCTAssertTrue(provider.waitForExistence(timeout: 10))
        provider.battlefieldTap()
        XCTAssertTrue(app.buttons["parameters-fixture-1"].waitForExistence(timeout: 5))
        app.buttons["Remove provider"].battlefieldTap()
        app.sheets.buttons["Remove provider"].battlefieldTap()
        XCTAssertTrue(app.buttons["addAIProvider"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["provider-Test Provider"].exists)
        app.terminate()
    }

    @MainActor
    func testProviderParametersPersistAndModelsRefresh() {
        var app = launch()
        openSection("AI 配置", in: app)
        XCTAssertTrue(app.buttons["addAIProvider"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["provider-Fixture Provider 1"].label.contains("Models: 1 · Default entrants: 1"))
        capture(app, "ai-providers")
        app.buttons["provider-Fixture Provider 1"].battlefieldTap()
        XCTAssertTrue(app.buttons["refreshAIModels"].waitForExistence(timeout: 5))
        app.buttons["refreshAIModels"].battlefieldTap()
        XCTAssertTrue(app.buttons["parameters-fixture-2"].waitForExistence(timeout: 5))
        app.buttons["parameters-fixture-1"].battlefieldTap()
        let reasoning = toggle("automaticReasoning", in: app)
        XCTAssertTrue(reasoning.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["modelOutputLimit"].exists)
        reasoning.battlefieldTap()
        app.buttons["saveModelParameters"].battlefieldTap()
        XCTAssertTrue(app.buttons["parameters-fixture-1"].waitForExistence(timeout: 5))
        app.terminate()
        app = launch(reset: false)
        openSection("AI 配置", in: app)
        app.buttons["provider-Fixture Provider 1"].battlefieldTap()
        app.buttons["parameters-fixture-1"].battlefieldTap()
        let restoredReasoning = toggle("automaticReasoning", in: app)
        XCTAssertTrue(restoredReasoning.waitForExistence(timeout: 5))
        XCTAssertEqual(String(describing: restoredReasoning.value ?? "missing"), "0", app.debugDescription)
        XCTAssertFalse(app.textFields["modelOutputLimit"].exists)
        app.buttons["Close"].battlefieldTap()
        capture(app, "ai-models")
        app.terminate()
    }

    @MainActor
    func testPuzzlePickerSearchBulkSelectionAndReview() {
        let app = launch()
        openSection("AI Battlefield", in: app)
        reveal("chooseBattlefieldProblems", in: app).battlefieldTap()
        let search = app.textFields["battlefieldPuzzleSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        capture(app, "ai-puzzles")
        app.buttons["clearBattlefieldProblems"].battlefieldTap()
        search.battlefieldTap()
        search.typeText("L03")
        XCTAssertTrue(app.descendants(matching: .any)["problemChoice-10012"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["problemChoice-10001"].firstMatch.exists)
        app.buttons["selectVisibleBattlefieldProblems"].battlefieldTap()
        XCTAssertTrue(
            app.staticTexts["battlefieldPuzzleSelectionCount"].value as? String == "1 puzzles selected"
                || app.staticTexts["battlefieldPuzzleSelectionCount"].label.contains("1 puzzles selected"))
        #if os(macOS)
            search.battlefieldTap()
            search.typeKey("a", modifierFlags: .command)
            search.typeKey(.delete, modifierFlags: [])
            app.radioButtons["Selected"].battlefieldTap()
        #else
            app.buttons["Clear search"].battlefieldTap()
            app.buttons["Selected"].battlefieldTap()
        #endif
        XCTAssertTrue(app.descendants(matching: .any)["problemChoice-10012"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["problemChoice-10001"].firstMatch.exists)
        app.descendants(matching: .any)["problemChoice-10012"].firstMatch.battlefieldTap()
        XCTAssertFalse(app.descendants(matching: .any)["problemChoice-10012"].firstMatch.exists)
        app.buttons["30 original puzzles"].battlefieldTap()
        XCTAssertTrue(app.descendants(matching: .any)["problemChoice-10001"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["Close"].battlefieldTap()
        XCTAssertTrue(app.buttons["chooseBattlefieldProblems"].label.contains("30 puzzles selected"))
        app.terminate()
    }

    @MainActor
    func testUnifiedMatchSettingsAndModelReasoningControls() {
        let app = launch()
        openSection("AI Battlefield", in: app)
        XCTAssertFalse(app.segmentedControls["competitionMode"].exists)
        XCTAssertFalse(app.radioButtons["Best Effort"].exists)
        let time = toggle("matchTimeLimitEnabled", in: app)
        XCTAssertTrue(time.waitForExistence(timeout: 5))
        XCTAssertEqual(String(describing: time.value ?? "missing"), "0", app.debugDescription)
        time.battlefieldTap()
        XCTAssertTrue(app.textFields["matchTimeLimit"].exists)
        let tokens = toggle("problemTokenLimitEnabled", in: app)
        tokens.battlefieldTap()
        XCTAssertTrue(app.textFields["problemTokenLimit"].exists)
        capture(app, "ai-match-settings")
        reveal("entrantParameters-fixture-1", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Model Settings"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.textFields["modelOutputLimit"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["automaticReasoning"].firstMatch.exists)
        capture(app, "ai-model-settings")
        app.buttons["Close"].battlefieldTap()
        app.terminate()
    }

    @MainActor
    func testHistoryUsesMainWindowWithThreeModelsAndResizableAnswerDetails() {
        let app = launch(threeModels: true)
        openSection("AI Battlefield", in: app)

        reveal("chooseBattlefieldProblems", in: app).battlefieldTap()
        app.buttons["clearBattlefieldProblems"].battlefieldTap()
        app.descendants(matching: .any)["problemChoice-10001"].firstMatch.battlefieldTap()
        app.buttons["Close"].battlefieldTap()
        reveal("startBattlefield", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Match complete"].waitForExistence(timeout: 15))
        choose("Match history", in: app)
        let history = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-")).firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.battlefieldTap()
        XCTAssertTrue(app.buttons["backToBattlefieldHistory"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.sheets.count, 0)
        XCTAssertFalse(app.staticTexts["battlefieldScoringHelp"].exists)
        XCTAssertFalse(app.staticTexts["battlefieldAnswerHelp"].exists)
        app.buttons["battlefieldProgressHelp"].battlefieldTap()
        XCTAssertTrue(app.staticTexts["battlefieldScoringHelp"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["battlefieldAnswerHelp"].exists)
        app.buttons["closeBattlefieldProgressHelp"].battlefieldTap()
        XCTAssertTrue(app.staticTexts["battlefieldScoringHelp"].waitForNonExistence(timeout: 5))
        #if os(macOS)
            let window = app.windows.firstMatch
            let before = window.frame
            let origin = window.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: before.width - 2, dy: before.height - 2))
                .click(
                    forDuration: 0.1,
                    thenDragTo: origin.withOffset(CGVector(dx: before.width + 178, dy: before.height + 58)))
            XCTAssertGreaterThan(window.frame.width, before.width + 100)
            XCTAssertGreaterThan(window.frame.height, before.height + 30)
            let title = app.staticTexts["Match complete"].frame
            let date = app.staticTexts["battlefieldMatchDate"].frame
            let tokens = app.descendants(matching: .any)["battlefieldMatchTokens"].firstMatch.frame
            let share = app.buttons["shareBattlefield"].frame
            XCTAssertLessThan(abs(title.midY - date.midY), 20)
            XCTAssertGreaterThan(date.minX, title.maxX)
            XCTAssertLessThan(abs(tokens.maxX - share.maxX), 4)
        #endif
        for model in 1...3 {
            XCTAssertTrue(app.buttons["answer-fixture-\(model)-10001"].isHittable)
        }
        capture(app, "ai-history")
        reveal("answer-fixture-1-10001", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Attempt 1"].waitForExistence(timeout: 5))
        #if os(macOS)
            resizeSheet(in: app)
        #endif
        closeTopSheet(in: app)
        XCTAssertEqual(app.sheets.count, 0)
        choose("Current match", in: app)
        XCTAssertFalse(app.buttons["backToBattlefieldHistory"].exists)
        choose("Match history", in: app)
        XCTAssertTrue(app.buttons["backToBattlefieldHistory"].exists)
        app.buttons["backToBattlefieldHistory"].battlefieldTap()
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["shareBattlefield"].exists)
        history.battlefieldTap()
        XCTAssertTrue(app.buttons["backToBattlefieldHistory"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.sheets.count, 0)
        app.terminate()
    }

    @MainActor
    private func closeTopSheet(in app: XCUIApplication) {
        let close = app.buttons.matching(identifier: "closeBattlefieldSheet").allElementsBoundByIndex.last {
            $0.isHittable
        }
        XCTAssertNotNil(close)
        close?.battlefieldTap()
    }

    #if os(macOS)
        @MainActor
        private func resizeSheet(in app: XCUIApplication) {
            let sheet = app.sheets.firstMatch
            let before = sheet.frame
            let origin = sheet.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: before.width - 2, dy: before.height - 2))
                .click(
                    forDuration: 0.1,
                    thenDragTo: origin.withOffset(CGVector(dx: before.width - 82, dy: before.height - 52)))
            XCTAssertLessThan(sheet.frame.width, before.width - 40)
            XCTAssertLessThan(sheet.frame.height, before.height - 20)
        }
    #endif

    @MainActor
    func testCompactSetupAndFormattedSharedPrompt() {
        let app = launch()
        openSection("AI Battlefield", in: app)

        let models = app.buttons["chooseBattlefieldModels"]
        let puzzles = app.buttons["chooseBattlefieldProblems"]
        XCTAssertTrue(models.waitForExistence(timeout: 5))
        #if os(macOS)
            XCTAssertEqual(models.frame.minY, puzzles.frame.minY, accuracy: 5)
            XCTAssertLessThan(models.frame.maxX, puzzles.frame.minX)
            XCTAssertTrue(app.buttons["startBattlefield"].isHittable, app.debugDescription)
            XCTAssertLessThan(app.radioButtons["New match"].frame.minY, models.frame.minY)
        #endif
        capture(app, "ai-new-match")
        app.buttons["View shared rules prompt"].battlefieldTap()
        XCTAssertTrue(app.staticTexts["Board and movement"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["## Board and movement"].exists)
        capture(app, "ai-rules")
        app.buttons["Close"].battlefieldTap()
        app.terminate()
    }

    @MainActor
    func testLiveReasoningTransitionsToProviderOrNetworkFailureWithoutRejection() {
        var app = launch(streamErrors: true)
        openSection("AI Battlefield", in: app)

        reveal("chooseBattlefieldProblems", in: app).battlefieldTap()
        app.buttons["clearBattlefieldProblems"].battlefieldTap()
        app.descendants(matching: .any)["problemChoice-10001"].firstMatch.battlefieldTap()
        app.buttons["Close"].battlefieldTap()
        reveal("startBattlefield", in: app).battlefieldTap()
        reveal("answer-fixture-1-10001", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Thinking…"].waitForExistence(timeout: 5), app.debugDescription)
        let reasoning = app.buttons["reasoningToggle-1"]
        XCTAssertTrue(reasoning.waitForExistence(timeout: 5))
        reasoning.battlefieldTap()
        XCTAssertTrue(app.staticTexts["Path analysis"].waitForExistence(timeout: 5))
        let timer = app.descendants(matching: .any)["attempt-time-1"].firstMatch
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        let initialTime = timer.label
        XCTAssertTrue(initialTime.hasPrefix("Elapsed "), timer.debugDescription)
        let tick = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", initialTime), object: timer)
        XCTAssertEqual(XCTWaiter.wait(for: [tick], timeout: 4), .completed)
        capture(app, "ai-thinking")
        let interruption = app.descendants(matching: .any)["answer-interrupted-1"].firstMatch
        XCTAssertTrue(interruption.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Thinking…"].exists)
        XCTAssertFalse(app.staticTexts["Rejected"].exists)
        XCTAssertTrue(app.staticTexts["AI response error"].exists)
        XCTAssertTrue(app.staticTexts["No final answer was returned."].exists)
        capture(app, "ai-stream-error")
        app.buttons["Close"].battlefieldTap()
        reveal("answer-fixture-2-10001", in: app).battlefieldTap()
        let error = app.staticTexts["answer-provider-error-1"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue((error.value as? String ?? error.label).contains("NSURLErrorDomain -1005"))
        XCTAssertFalse(app.staticTexts["Rejected"].exists)
        app.buttons["reasoningToggle-1"].battlefieldTap()
        XCTAssertTrue(app.staticTexts["Path analysis"].exists)
        capture(app, "ai-network-error")
        app.buttons["Close"].battlefieldTap()
        app.terminate()
        app = launch(reset: false, streamErrors: true)
        openSection("AI Battlefield", in: app)
        choose("Match history", in: app)
        let history = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-")).firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 10), app.debugDescription)
        history.battlefieldTap()
        reveal("answer-fixture-2-10001", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["answer-provider-error-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["answer-interrupted-1"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Thinking…"].exists)
        XCTAssertFalse(app.staticTexts["Rejected"].exists)
        app.terminate()
    }

    @MainActor
    func testLiveAnswerDialogShowsReasoningAndProviderErrorDetails() {
        let app = launch(diagnostics: true)
        openSection("AI Battlefield", in: app)

        reveal("chooseBattlefieldProblems", in: app).battlefieldTap()
        app.buttons["clearBattlefieldProblems"].battlefieldTap()
        app.descendants(matching: .any)["problemChoice-10001"].firstMatch.battlefieldTap()
        app.buttons["Close"].battlefieldTap()
        reveal("startBattlefield", in: app).battlefieldTap()
        reveal("answer-fixture-1-10001", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Attempt 1"].waitForExistence(timeout: 5))
        let disclosure = app.buttons["reasoningToggle-1"]
        XCTAssertTrue(disclosure.waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Coordinate check"].exists)
        disclosure.battlefieldTap()
        XCTAssertTrue(app.staticTexts["Coordinate check"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertFalse(app.staticTexts["### Coordinate check"].exists)
        XCTAssertTrue(app.staticTexts["Burnout"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.staticTexts["Attempt 2"].exists)
        XCTAssertFalse(app.staticTexts["Rejected"].exists)
        XCTAssertFalse(app.buttons["tryBattlefieldAnswer-1"].exists)
        _ = reveal("Coordinate check", in: app)
        capture(app, "ai-burnout")
        disclosure.battlefieldTap()
        XCTAssertFalse(app.staticTexts["Coordinate check"].exists)
        XCTAssertTrue(app.staticTexts["answer-response-1"].exists)
        app.buttons["Close"].battlefieldTap()
        reveal("answer-fixture-2-10001", in: app).battlefieldTap()
        let error = app.staticTexts["answer-provider-error-1"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue((error.value as? String ?? error.label).contains("assistant content is empty at index 2"))
        capture(app, "ai-provider-error")
        app.buttons["Close"].battlefieldTap()
        app.terminate()
    }

    @MainActor
    func testParallelMatchRetryNativeJudgingHistoryAndShareImage() {
        var app = launch()
        openSection("AI Battlefield", in: app)
        XCTAssertTrue(reveal("chooseBattlefieldProblems", in: app).label.contains("30 puzzles selected"))

        reveal("chooseBattlefieldProblems", in: app).battlefieldTap()
        app.buttons["clearBattlefieldProblems"].battlefieldTap()
        app.descendants(matching: .any)["problemChoice-10001"].firstMatch.battlefieldTap()
        app.buttons["Close"].battlefieldTap()
        reveal("startBattlefield", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Match complete"].waitForExistence(timeout: 15), app.debugDescription)
        for model in ["fixture-1", "fixture-2"] {
            let score = app.staticTexts["score-\(model)"]
            XCTAssertEqual(score.value as? String ?? score.label, "80%")
            let points = app.staticTexts["points-\(model)"]
            XCTAssertEqual(points.value as? String ?? points.label, "80 points")
        }
        XCTAssertFalse(app.staticTexts["Benchmark score"].exists)
        XCTAssertTrue(app.staticTexts["AI: 2 · Puzzles: 1"].exists)
        capture(app, "ai-battlefield")
        reveal("answer-fixture-1-10001", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Attempt 1"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(identifier: "Rejected").firstMatch.exists)
        let firstDuration = reveal("attempt-time-1", in: app).label
        XCTAssertTrue(firstDuration.hasPrefix("Elapsed "))
        #if os(macOS)
            app.sheets.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: -450)
        #else
            app.sheets.firstMatch.swipeUp()
        #endif
        XCTAssertTrue(app.staticTexts["Attempt 2"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(identifier: "Accepted").firstMatch.exists)
        let retryDuration = reveal("attempt-time-2", in: app).label
        XCTAssertTrue(retryDuration.hasPrefix("Elapsed "))
        capture(app, "ai-answer")
        reveal("tryBattlefieldAnswer-2", in: app).battlefieldTap()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "s")
        XCTAssertFalse(app.staticTexts["lesson-objective"].exists)
        XCTAssertFalse(app.staticTexts["trial-explanation"].exists)
        app.buttons["problem-details"].battlefieldTap()
        XCTAssertTrue(app.staticTexts["trial-explanation"].waitForExistence(timeout: 5))
        app.buttons["close-problem-details"].battlefieldTap()
        #if os(macOS)
            XCTAssertTrue(app.popovers.firstMatch.waitForNonExistence(timeout: 5))
        #endif
        XCTAssertTrue(app.staticTexts["trial-explanation"].waitForNonExistence(timeout: 5))
        #if os(macOS)
            XCTAssertTrue(app.buttons["run-program"].isHittable)
        #endif
        capture(app, "ai-trial")
        reveal("run-program", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["completion-title"].waitForExistence(timeout: 5))
        app.buttons["backToBattlefield"].battlefieldTap()
        XCTAssertTrue(app.buttons["shareBattlefield"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["score-fixture-1"].value as? String, "80%")
        reveal("answer-fixture-1-10001", in: app).battlefieldTap()
        reveal("tryBattlefieldAnswer-1", in: app).battlefieldTap()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "z")
        reveal("run-program", in: app).battlefieldTap()
        XCTAssertEqual(app.staticTexts["game-status"].value as? String, "Procedure z is not defined.")
        app.buttons["insert-l"].battlefieldTap()
        app.buttons["backToBattlefield"].battlefieldTap()
        // Scroll to the dashboard header before opening the export preview.
        #if os(macOS)
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: 1000)
        #else
            app.swipeDown()
        #endif
        app.buttons["shareBattlefield"].battlefieldTap()
        XCTAssertTrue(app.buttons["shareBattlefieldPNG"].waitForExistence(timeout: 10))
        capture(app, "ai-share")
        app.buttons["Close"].battlefieldTap()
        app.terminate()
        app = launch(reset: false)
        openSection("AI Battlefield", in: app)
        choose("Match history", in: app)
        let history = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-")).firstMatch
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.battlefieldTap()
        XCTAssertTrue(app.buttons["shareBattlefield"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["score-fixture-1"].value as? String, "80%")
        let restoredPoints = app.staticTexts["points-fixture-1"]
        XCTAssertEqual(restoredPoints.value as? String ?? restoredPoints.label, "80 points")
        reveal("answer-fixture-1-10001", in: app).battlefieldTap()
        XCTAssertEqual(reveal("attempt-time-1", in: app).label, firstDuration)
        XCTAssertEqual(reveal("attempt-time-2", in: app).label, retryDuration)
        reveal("tryBattlefieldAnswer-2", in: app).battlefieldTap()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "s")
        app.buttons["backToBattlefield"].battlefieldTap()
        XCTAssertTrue(app.buttons["backToBattlefieldHistory"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.sheets.count, 0)
        app.buttons["backToBattlefieldHistory"].battlefieldTap()
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        openSection("关卡", in: app)
        app.buttons["continue-problem"].battlefieldTap()
        XCTAssertTrue(app.textViews["code-editor"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textViews["code-editor"].value as? String, "")
        XCTAssertFalse(app.buttons["View my shortest solution"].exists)
        app.terminate()
    }

    @MainActor
    func testCaptureHerbertBenchmarkGallery() throws {
        guard ProcessInfo.processInfo.environment["HERBERT_CAPTURE_SCREENSHOTS"] == "1" else {
            throw XCTSkip("Opt-in README capture")
        }
        let app = launch()
        openSection("AI Battlefield", in: app)

        reveal("chooseBattlefieldProblems", in: app).battlefieldTap()
        app.buttons["clearBattlefieldProblems"].battlefieldTap()
        for id in [10001, 10006, 10012] {
            app.descendants(matching: .any)["problemChoice-\(id)"].firstMatch.battlefieldTap()
        }
        app.buttons["Close"].battlefieldTap()
        reveal("startBattlefield", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Match complete"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Live ranking"].exists)
        XCTAssertFalse(app.staticTexts["Fixture Model 1 (free)"].exists)
        XCTAssertTrue(app.staticTexts["Fixture Model 1"].exists)
        XCTAssertTrue(app.staticTexts["Solved 3/3"].exists)
        XCTAssertEqual(app.staticTexts["score-fixture-1"].value as? String, "80%")
        XCTAssertLessThan(app.staticTexts["score-fixture-1"].frame.minX, app.staticTexts["score-fixture-2"].frame.minX)
        let accepted = reveal("answer-fixture-1-10006", in: app)
        #if os(macOS)
            XCTAssertLessThanOrEqual(accepted.frame.height, 64)
        #endif
        XCTAssertTrue(app.buttons["answer-fixture-2-10006"].label.contains("Rejected"))
        #if os(macOS)
            app.scrollViews.firstMatch.scroll(byDeltaX: 0, deltaY: 1000)
        #else
            app.swipeDown()
        #endif
        capture(app, "herbert-benchmark")
        app.terminate()
    }

    @MainActor
    func testSpecialProviderFailuresRetryAdvanceAndStopOnlyDeniedEntrant() {
        let app = launch(specialErrors: true)
        openSection("AI Battlefield", in: app)
        reveal("chooseBattlefieldProblems", in: app).battlefieldTap()
        app.buttons["clearBattlefieldProblems"].battlefieldTap()
        for id in [10001, 10006] {
            app.descendants(matching: .any)["problemChoice-\(id)"].firstMatch.battlefieldTap()
        }
        app.buttons["Close"].battlefieldTap()
        reveal("startBattlefield", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Match complete"].waitForExistence(timeout: 15))
        XCTAssertTrue(reveal("answer-fixture-1-10001", in: app).label.contains("Accepted"))
        XCTAssertTrue(reveal("answer-fixture-1-10006", in: app).label.contains("Timed out"))
        XCTAssertTrue(reveal("answer-fixture-2-10001", in: app).label.contains("Access Denied"))
        XCTAssertTrue(reveal("answer-fixture-2-10006", in: app).label.contains("Stopped"))
        reveal("answer-fixture-1-10001", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Attempt 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["AI HTTP 503"].exists)
        XCTAssertFalse(app.staticTexts["Rejected"].exists)
        _ = reveal("attempt-time-2", in: app)
        XCTAssertTrue(app.staticTexts["Attempt 2"].exists)
        app.buttons["Close"].battlefieldTap()
        reveal("answer-fixture-1-10006", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Timed out"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Attempt 2"].exists)
        app.buttons["Close"].battlefieldTap()
        reveal("answer-fixture-2-10001", in: app).battlefieldTap()
        XCTAssertTrue(app.staticTexts["Access Denied"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Attempt 2"].exists)
        app.buttons["Close"].battlefieldTap()
        app.terminate()
    }

    @MainActor
    func testStopMatchSavesCancelledAnswers() {
        let app = launch()
        openSection("AI Battlefield", in: app)

        reveal("startBattlefield", in: app).battlefieldTap()
        let stop = app.buttons["stopBattlefield"]
        XCTAssertTrue(stop.waitForExistence(timeout: 5))
        stop.battlefieldTap()
        XCTAssertTrue(app.staticTexts["Stopped by user"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["stopBattlefield"].exists)
        choose("Match history", in: app)
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history-")).firstMatch
                .waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
    }

    @MainActor
    private func toggle(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        #if os(macOS)
            let checkbox = app.checkBoxes[identifier].firstMatch
            if checkbox.exists { return checkbox }
        #endif
        return app.switches[identifier].firstMatch
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        guard ProcessInfo.processInfo.environment["HERBERT_CAPTURE_SCREENSHOTS"] == "1" else { return }
        app.activate()
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        image.name = "readme-\(name)"
        image.lifetime = .keepAlways
        add(image)
    }
}

extension XCUIElement {
    @MainActor
    fileprivate func battlefieldTap() {
        #if os(macOS)
            XCUIApplication().activate()
            click()
        #else
            tap()
        #endif
    }
}
