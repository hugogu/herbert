# Herbert

- SwiftUI universal app (iOS 17+, macOS 14+); `HerbertCore` is a local Swift package with no UI dependencies.
- Original rules: http://herbert.tealang.info/rule.php. Language is H, not a generic turtle language. Count letters and numeric literals (12 is one byte); punctuation is free. Preserve 25 × 25 boards, walls, traps, and original IDs/limits.
- All progress goes through `ProgressRepository`. Keep cloud credentials out of clients. Future Cloudflare D1 access must be through an authenticated Worker.
- `swift test` runs unit/integration tests. `python3 scripts/generate_project.py` regenerates the checked-in Xcode project. `scripts/check.sh` formats/lints and tests.
- Original public Flash client loads boards with POST `action=problem` to `problem.php?id=N`; a response contains a 625-character map and byte limit separated by a newline. A plain GET yields HTML. Some requests to this old HTTP server stall; use bounded retries and validate every cached response.
- This machine has Xcode but no installed iOS Simulator runtime. Build iOS without signing and exercise the native macOS app/UI tests; do not claim simulator validation without an installed runtime.
- In native Mac UI tests, SwiftUI static text can expose its content through accessibility `value` rather than `label`; assert the visible value with a label fallback.
- Under Swift 6 isolation checking, value-type `Animatable.animatableData` must be `nonisolated` when the drawing also conforms to SwiftUI `View`.
- AppKit drawing needs an RGBA bitmap context; export icons through an opaque Core Graphics context to produce RGB PNGs without alpha. Fail generation explicitly if the drawing context cannot be created.
- README screenshots must be actual app captures. `scripts/capture_screenshots.sh` runs an opt-in native UI test and exports window/board attachments; ordinary UI runs skip that capture test. Keep original problem credits and the separate content licensing notice.
- If SSH publishing stalls, pass the HTTPS repository URL directly to `git push` while retaining the saved SSH origin. `remote.<name>.url` accepts multiple values; a command-line `-c` addition can still leave a push using the configured SSH URL. Verify the published commit SHA afterward.
- Native element screenshots can include other windows that cover the app even when window screenshots look correct. Activate the app immediately before each capture and inspect every exported image, especially board-only captures.

- Native Mac Canvas can expose its descriptive state only through accessibility `label`; use that for board assertions. Rebuild in a fresh DerivedData directory if newly added Swift package localization files are absent from the embedded resource bundle.
- Match screenshot UI language to its README. The capture script defaults to English (`docs/screenshots/en/`); pass `zh-Hans` for the Chinese assets.
- macOS can restore the app without an open window. Native UI tests should open New Window with Command-N if no window appears before checking the library.
- XCTest screenshots can fail to create images on a secondary display. The optional `TEST_RUNNER_HERBERT_TEST_DISPLAY` selects a destination via the native Window menu. Cache the menu item frame and click relative to the window: the item identity changes on hover, and the application frame can be infinite. Avoid relying on restored window placement.
- `HerbertCore` bundles only the 50 MIT-original lessons; community JSON belongs in optional `HerbertCommunity`. `HerbertAppStore` must never link that module. Audit the final .app with `scripts/check_app_store_bundle.py`, including archives, rather than relying on UI filtering.
- Original lessons use stable IDs 10001–10050 and display L01–L50. Generate lessons/translations/test references with `scripts/generate_original_problems.py`; reference solutions must stay outside application resources. Preserve community IDs and existing saves.
- Personal signing belongs in ignored `Config/Local.xcconfig`, included by `Config/Signing.xcconfig`; project regeneration must not commit or erase a developer's local team selection.

- Community board symbols are `x` = wall and `*` = trap; do not infer them from their appearance. The pinned HOJ interpreter/sample judge audit is in `docs/hoj-compatibility.md`. Keep normalized command/byte fixtures aligned using the optional `scripts/check_hoj_reference.rb` without vendoring the reference source.
- Modern walls are translucent; pixel checks at cell joins should compare against a point away from the underlying grid dot. Trace wall contours with opposite winding for holes and separate diagonal components.

- Advanced course L31–L50 uses independent geometric command oracles in `scripts/advanced_course.py`. Preserve literal turn expansion in those oracles: `rrT` flips the effective turn but adds two executed instructions every recursion; simplifying it to `l` makes exact instruction-count tests wrong.
- Run native GUI and CLI UI tests sequentially: they share focus and can redirect each other's input. Xcode can rewrite shared scheme XML when a project is open; close the project and regenerate before checking generated-file consistency.
