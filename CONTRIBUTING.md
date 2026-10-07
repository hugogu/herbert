# Contributing to Herbert

Welcome! You can contribute code, documentation, translations, accessibility improvements,
or reports from real devices. Small, focused changes are easiest to review.

## Set up

1. Fork and clone the repository.
2. Open `Herbert.xcodeproj` in Xcode 16+ with Swift 6 and select the Herbert scheme.
3. Run on your Mac, or select your own signing team for an iPhone/iPad.
4. Create a branch for your change. Do not commit personal signing settings or save files.

There are no external package dependencies. `HerbertCore` is a standalone local Swift
package. The current interface is Simplified Chinese; English localization is welcome.

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
scripts/capture_screenshots.sh
```

The opt-in XCTest captures the library, three full puzzle screens, and their actual board
elements. It exports unmodified PNG attachments into `docs/screenshots/`. Review each
image before committing it. See [screenshot provenance](docs/screenshots/README.md).

## Problem data and H compatibility

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

Look for `good first issue` and `help wanted`. English localization, better accessibility
labels, reproducible compatibility cases, and real iPhone/iPad test reports are useful.
Ask in an issue before large architectural changes or new dependencies.

Please follow our [code of conduct](CODE_OF_CONDUCT.md). Report vulnerabilities through
the private channel described in [SECURITY.md](SECURITY.md).
