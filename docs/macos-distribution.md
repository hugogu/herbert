# Mac DMG distribution

The open-source Mac preview supports **macOS 14+**, **Apple Silicon and Intel** in
one universal app. It bundles 30 original lessons and the 1,769-problem community
archive. The original-only `HerbertAppStore` target remains separate.

## Install

Download `Herbert-macOS-universal.dmg` from [GitHub Releases](https://github.com/hugogu/herbert/releases).
Open the image, drag `Herbert.app` to `Applications`, eject the image, then open Herbert
from Applications. No Xcode is required. Progress is saved locally in the app sandbox.
AI Battlefield is optional and uses your own provider API key and credits; keys use
Keychain and match history stays local. See [privacy](../PRIVACY.md).

**The preview is ad-hoc signed and has not been notarized by Apple.** If Gatekeeper
blocks the first launch and you trust this download, follow
[Apple's instructions](https://support.apple.com/en-us/102445): first try opening the
app, then use **System Settings → Privacy & Security → Open Anyway** for Herbert.
On managed Macs your administrator may restrict this option. The repository does
not include Developer ID credentials. Signing with Developer ID and notarization
are still required for a release that passes the normal first-launch checks.

To check download integrity, save the accompanying `.sha256` file in the same folder:

```sh
shasum -a 256 -c Herbert-macOS-universal.dmg.sha256
```

## GitHub Actions

Every successful [CI run](https://github.com/hugogu/herbert/actions/workflows/ci.yml)
uploads **Herbert-macOS-universal**, containing the DMG and its checksum. Actions
artifacts are retained for 30 days and require GitHub sign-in to download. Tagged
releases also publish both files as public Release assets for direct download.

The packaging step runs after lint, unit/integration tests, native Mac/iOS builds,
and original-only store-bundle audits. It verifies both executable architectures,
the full code signature, retained sandbox and absence of debugger entitlements,
outgoing-network entitlement for optional AI providers, exact puzzle catalogs, and absence
of test answer files. It then creates a compressed
read-only HFS+ image with an Applications shortcut, license, attribution and installation
notes. Finally it verifies and mounts the image read-only and repeats the bundle audit.

## Build locally

Run from the repository root on a Mac with Xcode:

```sh
xcodebuild -project Herbert.xcodeproj -scheme Herbert -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath .build/dmg-mac \
  ARCHS='arm64 x86_64' CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  CODE_SIGN_ENTITLEMENTS=Config/MacPreview.entitlements \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ENABLE_HARDENED_RUNTIME=YES build

python3 scripts/package_macos.py build \
  --app .build/dmg-mac/Build/Products/Release/Herbert.app \
  --output outputs/Herbert-macOS-universal.dmg

python3 scripts/package_macos.py verify outputs/Herbert-macOS-universal.dmg
```

Packaging refuses to overwrite an existing DMG or checksum. Choose a new output name
for subsequent local builds. Outputs and derived build files are ignored by Git.

## Publish a version

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
   `scripts/generate_project.py`, regenerate the project, and update the changelog.
2. Commit and push the tested changes. Use a new tag matching the app version,
   for example `v0.3.3`; the workflow rejects a mismatch.
3. Push the tag. CI builds the exact tagged source, then the release job verifies
   the downloaded artifact checksum and creates a GitHub **pre-release** with the DMG.

Release publishing has write permission only in the tagged release job, after the
read-only checks job succeeds. Pull requests and branch builds cannot publish a release.
Tags and existing releases are not overwritten automatically. If release publishing
fails after creation, inspect the release and recover its missing assets explicitly.
