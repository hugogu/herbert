# Contributing to Herbert

Welcome! You can contribute code, documentation, translations, accessibility improvements,
or reports from real devices. Small, focused changes are easiest to review.

## Set up

1. Fork and clone the repository.
2. Open `Herbert.xcodeproj` in Xcode 16+ with Swift 6 and select the Herbert scheme.
3. Run on your Mac, or select your own signing team for an iPhone/iPad.
4. Create a branch for your change. Do not commit personal signing settings or save files.

There are no external package dependencies. `HerbertCore` is a standalone local Swift
package; `HerbertBattlefield` contains the UI-independent AI client, judge and competition engine.
UI and original lessons support English, Simplified Chinese and Japanese.
Use `HerbertAppStore` to test the original-only edition. Personal signing can go in
ignored `Config/Local.xcconfig`; generation keeps it intact.

## Before opening a pull request

```sh
scripts/check.sh
```

This checks Swift formatting and runs Python importer unit tests and Swift core/integration
tests. Format edited Swift files with `xcrun swift-format format -i path/to/File.swift`.
Add unit tests and an integration case for new behavior, particularly parser semantics,
execution limits, persistence, or backup merging. Keep UI code out of HerbertCore.

For UI changes, also build both targets and run the relevant native UI flow:

```sh
xcodebuild -project Herbert.xcodeproj -scheme Herbert \
  -destination 'platform=macOS' CODE_SIGN_IDENTITY=- test
xcodebuild -project Herbert.xcodeproj -scheme Herbert \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Mac UI tests require an interactive desktop and may request macOS automation permission.
They use a separate temporary save file. Let them run without switching focus to another
app. Report your actual device/runtime and checks; compilation alone is not a device test.
CI runs checks and unsigned Mac/iOS builds, not interactive UI tests.

If you add or remove app source files, regenerate the project and commit its diff:

```sh
python3 scripts/generate_project.py
```

## Refresh screenshots

```sh
scripts/capture_screenshots.sh en
scripts/capture_screenshots.sh zh-Hans
scripts/capture_screenshots.sh en store
scripts/capture_screenshots.sh zh-Hans store
```

The opt-in XCTest captures the library, full puzzle screens, and their actual board
elements. It explicitly sets the app language and exports nine unmodified PNG attachments
for the community gallery or eleven for the original course. English images go to
`docs/screenshots/en/`, Chinese to `docs/screenshots/`, with course images in `course/`.
English is the default when no argument is supplied. Keep each README's images in its own language.
Review each image before committing it. See [screenshot provenance](docs/screenshots/README.md).

## AI Battlefield

Use deterministic `AIClient` fixtures for engine tests and URLProtocol fixtures for HTTP
integration tests. Exercise streamed usage, retries, cancellation and shared/per-model
budgets without paid requests. Native `BattlefieldUITests` use isolated local files and
in-memory keys; no real provider key is needed. Never commit API keys, provider error
bodies, personal history or an unlabelled model benchmark. Keep API keys in Keychain
and preserve the disclosure before sending puzzles to a provider.

See [protocol, scoring and storage](docs/ai-battlefield.md) and [privacy](PRIVACY.md).

## Problem data and H compatibility

The original curriculum lives in `scripts/generate_original_problems.py`. Regenerate after
edits and run `scripts/check.sh`; the real engine replays all 50 test-only references.
Keep stable IDs 10001–10050, goals, two progressive hints, and all three translations.
New original content must be independently designed and explicitly contributed under MIT.
Do not put community JSON or reference programs in HerbertCore application resources.
Audit each final store `.app` with `scripts/check_app_store_bundle.py`. See
[the curriculum](docs/original-course.md) and [device instructions](docs/app-store.md).

Preserve the original 25 × 25 geometry, IDs, titles, authors, byte limits, and source metadata.
Do not silently simplify a puzzle. Explain behavior differences with a minimal H program
and an original problem ID when possible. See [rules](docs/rules.md) and
[third-party content notices](NOTICE.md).

The importer is a maintenance tool, not an app startup requirement:

```sh
python3 scripts/import_problems.py --workers 2
```

It contacts a legacy HTTP server. Keep concurrency low, retain bounded retries, and inspect
the manifest for missing IDs or failures. Avoid an unrelated full catalog refresh in a
code PR. New original puzzles need an explicit license from their author.

## Pull requests

Describe the problem, resulting behavior, and checks performed. Include before/after
screenshots for visible changes, and say what remains untested. Use focused commits
with a short imperative subject, such as `fix(core): preserve targets after a blocked move`.
Never include credentials, personal progress, build outputs, local absolute paths, or
IDE user settings. No CLA is required: original code contributions are accepted under MIT.
Do not submit third-party content without its applicable permissions and attribution.

## Places to start

Look for `good first issue` and `help wanted`. Translation improvements, better accessibility
labels, reproducible compatibility cases, and real iPhone/iPad test reports are useful.
Ask in an issue before large architectural changes or new dependencies.

Please follow our [code of conduct](CODE_OF_CONDUCT.md). Report vulnerabilities through
the private channel described in [SECURITY.md](SECURITY.md).

## Translations

Edit `Sources/HerbertCore/Resources/{en,zh-Hans,ja}.lproj/Localizable.strings`. The app
and core bundle use the same files so diagnostics and UI stay consistent. Keep keys
and printf placeholders identical across languages. Use `LocalizedStringKey` for
SwiftUI helper labels and `HerbertStrings.text` for dynamic strings and core errors.
Run `scripts/check.sh`; native UI tests also exercise language matching via AppleLanguages.
Original problem titles, authors, and H programs are not translated.
