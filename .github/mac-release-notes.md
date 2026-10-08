Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. No Xcode is needed. Requires **macOS 14 or later**; the same app
supports **Apple Silicon and Intel**.

This open-source preview includes **50 original lessons + 1,769 archived community
problems**, automatic English/Chinese/Japanese UI, Modern and Classic boards,
movement trails, grid dots, and local progress with JSON backup import/export.

**Signing:** this preview is ad-hoc signed and has not been notarized by Apple.
If macOS blocks the first launch, follow [Apple's instructions](https://support.apple.com/en-us/102445)
for **System Settings → Privacy & Security → Open Anyway** after trying to open it.
Developer ID signing and notarization remain future release work.

**Integrity:** download the accompanying `.sha256` file into the same directory and run:

```sh
shasum -a 256 -c Herbert-macOS-universal.dmg.sha256
```

GitHub Actions builds both architectures, checks the signature, sandbox and bundled
catalogs, mounts the DMG read-only to verify it, and publishes it only after the tests
and Mac/iOS builds pass. iPhone/iPad runtime testing is still pending.

Code and the 50 original lessons are MIT licensed. Archived community content has
separate, unconfirmed redistribution rights; it is not relicensed under MIT.
See [NOTICE.md](https://github.com/hugogu/herbert/blob/main/NOTICE.md).
The App Store scheme contains only the originals; this DMG is the open-source edition.

中文：下载下方 DMG，打开后将 Herbert 拖到“应用程序”。支持 macOS 14+ 的 Apple Silicon
与 Intel Mac，无需 Xcode。此预览版尚未经过 Apple 公证；如首次启动被阻止，可按上方
Apple 指引在“系统设置 → 隐私与安全”中确认打开。含 50 道原创题和 1,769 道社区题。

See the [changelog](https://github.com/hugogu/herbert/blob/main/CHANGELOG.md) for changes
and the [README](https://github.com/hugogu/herbert#readme) for screenshots and controls.
