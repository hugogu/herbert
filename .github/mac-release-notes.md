Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. No Xcode is needed. Requires **macOS 14 or later**; the same app
supports **Apple Silicon and Intel**.

This open-source preview includes **50 original lessons + 1,769 archived community
problems**, automatic English/Chinese/Japanese UI, Modern and Classic boards,
movement trails, grid dots, and local progress with JSON backup import/export.

**Updated in 0.3.1 — Herbert Benchmark:** AI Providers now lives inside Battlefield,
leaving four main tabs. Mac setup uses two columns; shared rules render as Markdown.
Progress is a compact, width-adaptive table whose model columns rank by target-coverage
and code-length scores, then token consumption. Headers show tokens/cache rates and
corner error indicators. Inspect every submission and try it on the game board with
Back to match; personal drafts and shortest solutions are preserved. Best Effort ends
when the first AI finishes its entire puzzle schedule and cancels the remaining calls.
Old match histories keep their original scoring. README includes refreshed English app
captures and the Herbert Benchmark methodology.
AI is optional and requires your own API key/credits. Keys stay in Keychain; settings
and history stay local. Streaming estimates and cancellation cannot guarantee final
provider billing. See [setup and scoring](https://github.com/hugogu/herbert/blob/main/docs/ai-battlefield.md)
and [privacy](https://github.com/hugogu/herbert/blob/main/PRIVACY.md).

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
0.3.1 将 AI 配置合入 Battlefield，手机端保留四个主 Tab。比赛进度按目标覆盖和代码长度评分、按 Token 打破同分；表头整合用量，答案可跳到棋盘试运行并返回。Best Effort 首个 AI 完成整套题目即结束全场。新增 Herbert Benchmark 说明及英文截图；旧历史保留原计分。AI 使用自己的 API 额度，密钥保存在钥匙串中。

See the [changelog](https://github.com/hugogu/herbert/blob/main/CHANGELOG.md) for changes
and the [README](https://github.com/hugogu/herbert#readme) for screenshots and controls.
