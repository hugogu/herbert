Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. No Xcode is needed. Requires **macOS 14 or later**; the same app
supports **Apple Silicon and Intel**.

This open-source preview includes **30 original lessons + 1,769 archived community
problems**, automatic English/Chinese/Japanese UI, Modern and Classic boards,
movement trails, grid dots, and local progress with JSON backup import/export.

**Updated in 0.3.2:** Full responses now retain model reasoning, final answers,
partial streams and redacted provider error bodies, including HTTP 400 details.
Open answer dialogs update live. Retry requests preserve reasoning and avoid empty
assistant turns. Shared H prompt v3 adds coordinate rulers and two verified worked
boards, including a recursive example separate from scored L50.

The course now contains ten selected introductory lessons plus L31–L50: **30 originals**
and **1,799 puzzles** in this edition. Only the first two fit direct movement programs;
retained IDs and saved progress keep their meanings. Retired records remain importable.
Herbert Benchmark ranks models by coverage/code-length points, then tokens. Best Effort
ends when the first AI finishes its selected set. README shows updated English app captures.
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

Code and the 30 original lessons are MIT licensed. Archived community content has
separate, unconfirmed redistribution rights; it is not relicensed under MIT.
See [NOTICE.md](https://github.com/hugogu/herbert/blob/main/NOTICE.md).
The App Store scheme contains only the originals; this DMG is the open-source edition.

中文：下载下方 DMG，打开后将 Herbert 拖到“应用程序”。支持 macOS 14+ 的 Apple Silicon
与 Intel Mac，无需 Xcode。此预览版尚未经过 Apple 公证；如首次启动被阻止，可按上方
Apple 指引在“系统设置 → 隐私与安全”中确认打开。含 30 道原创题和 1,769 道社区题。
0.3.2 保存并实时显示最终回答、推理、部分输出与脱敏后的服务商错误详情，修复重试时丢失推理和空 assistant 消息。
提示词 v3 增加坐标尺与两道完整示例；原创课程精简为十道入门题和二十道进阶题，保留存档与历史记录。
AI 使用自己的 API 额度，密钥保存在钥匙串中。

See the [changelog](https://github.com/hugogu/herbert/blob/main/CHANGELOG.md) for changes
and the [README](https://github.com/hugogu/herbert#readme) for screenshots and controls.
