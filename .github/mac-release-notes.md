Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. Requires **macOS 14+**; supports **Apple Silicon and Intel**. No Xcode needed.

**New in 1.1.0:**

- **20 new original lessons.** Master lessons L31–L40 and synthesis lessons L41–L50 add four
  chapters on wall-assisted synchronization, argument swaps, mutual recursion, inverse paths and
  layered recursive composition. The course now has 50 puzzles in ten chapters; earlier lessons,
  their IDs and saves are unchanged.
- **3D board style.** Beside Modern and Classic, the board can be drawn as a lit diorama with stone
  walls and glowing discs. Drag to turn it, pinch to zoom, double-tap to reset, or use the turn and
  tilt buttons. **Enlarge board** opens a stage with camera controls, follow-Herbert, progress, a
  program preview and the run controls. It is only a view; scores and saves are unaffected.
- **AI Battlefield:** cancel a single puzzle while a model is generating it and retry it later;
  model columns stay in place during a match; headers and share images show average output speed;
  **New match** starts from the previous match's choices. With token limits off, requests ask for
  each model's whole output capacity, and automatic thinking uses the highest effort DeepSeek
  advertises. Very long answers no longer stall the answer view, and the retry button can be
  tapped on iPad and iPhone.
- `a():` is accepted for a procedure without parameters; byte counts are unchanged.
- The Guide ends with the app version and build, such as Version 1.1.0 (15), to quote in bug
  reports.

This build includes **50 original puzzles + 1,769 archived community problems**, automatic
English/Chinese/Japanese UI, Modern, Classic and 3D boards, movement trails, grid dots and local
progress with JSON backups. Original puzzles are numbered L01–L50.

**AI Battlefield** pits models from OpenRouter, SiliconFlow, Google Gemini and OpenAI- or
Anthropic-compatible APIs against the puzzles. Programs are judged by the native engine with
normalized coverage/code-efficiency scores, retries, timing, token usage and shareable result
cards. AI is optional and uses your own API key and credits. Keys stay in Keychain; settings and
history stay local. Streaming estimates and cancellation cannot guarantee provider billing. See
[setup and scoring](https://github.com/hugogu/herbert/blob/v1.1.0/docs/ai-battlefield.md) and
[privacy](https://github.com/hugogu/herbert/blob/v1.1.0/PRIVACY.md).

**Signing:** this DMG is ad-hoc signed and has not been notarized by Apple.
If macOS blocks the first launch, follow [Apple's instructions](https://support.apple.com/en-us/102445)
for **System Settings → Privacy & Security → Open Anyway** after trying to open it.

**Integrity:** download the accompanying `.sha256` file into the same directory and run:

```sh
shasum -a 256 -c Herbert-macOS-universal.dmg.sha256
```

GitHub Actions tests, builds both architectures, audits the signature, sandbox and
bundled catalogs, mounts the DMG read-only to verify it, and publishes after Mac/iOS
builds pass. Native Mac UI tests use deterministic fixtures; paid provider calls and
real iPhone/iPad devices remain manual verification work.

Code and the 50 originals are MIT licensed. Community content has separate, unconfirmed
redistribution rights. See [NOTICE.md](https://github.com/hugogu/herbert/blob/v1.1.0/NOTICE.md).
The App Store edition contains only the originals; this DMG is the open-source edition.

中文：Herbert 1.1.0 发布。新增 20 道原创关卡：L31–L40 大师课与 L41–L50 综合课，课程扩展为十章 50 题，原有关卡、编号与存档不变。新增 3D 棋盘风格，可拖动旋转、双指缩放、双击复原；「放大棋盘」进入大舞台，镜头可跟随 Herbert，计分与存档不受影响。AI Battlefield 可在生成中取消单题并稍后重试，比赛中模型列保持原位，模型标题与分享图显示平均输出速度，新比赛沿用上一场的选择；不限 Token 时请求模型的全部输出容量，自动推理使用 DeepSeek 公布的最高强度；超长回答不再卡住界面，iPad 与 iPhone 上的重试按钮可以正常点按。无参数过程可写作 `a():`，byte 计数不变。手册末尾显示版本号与 build，便于反馈问题。

下载下方 DMG 后将 Herbert 拖入“应用程序”。支持 macOS 14+，包含 50 道原创和 1,769 道社区题，
中英日界面、Modern / Classic / 3D 棋盘、轨迹与网格、本地历史和 PNG 分享。此 DMG 尚未经过 Apple 公证。
AI 使用自己的 API 额度；密钥留在钥匙串，本地预算与取消请求无法保证最终账单。

See the [changelog](https://github.com/hugogu/herbert/blob/v1.1.0/CHANGELOG.md)
and [README](https://github.com/hugogu/herbert/tree/v1.1.0#readme) for screenshots and controls.
