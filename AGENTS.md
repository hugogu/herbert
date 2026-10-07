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
