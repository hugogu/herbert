Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. Requires **macOS 14+**; supports **Apple Silicon and Intel**. No Xcode needed.

**New in 1.0.0:**

- Herbert reaches 1.0. Its original-only App Store edition, **Herbot Bot**, is prepared for
  iPhone, iPad and Mac, with listing text in English, Simplified Chinese and Japanese, captioned
  screenshots, a support page and a privacy policy that covers both editions. This DMG remains the
  open-source **Herbert** edition.
- The 30 originals are called puzzles in the English and Japanese interface, and puzzle details
  show PUZZLE / ORIGINAL SERIES in all three languages.
- On iPad, **Dismiss keyboard** and the s/l/r keys work again after the landscape keyboard
  reflows a puzzle.
- The Guide credits and rule links are translated into English and Japanese.
- Since 0.3.9, the project also credits Wild Noodle Corporation for the original Herbert
  challenge and its founder Brian Conte for the `h` language, distinct from the later quolc-led
  Herbert Online Judge community archive.

This build includes **30 original puzzles + 1,769 archived community problems**, automatic
English/Chinese/Japanese UI, Modern and Classic boards, movement trails, grid dots and local
progress with JSON backups. Original puzzles are numbered L01–L30.

**AI Battlefield** pits models from OpenRouter, SiliconFlow, Google Gemini and OpenAI- or
Anthropic-compatible APIs against the puzzles. Programs are judged by the native engine with
normalized coverage/code-efficiency scores, retries, timing, token usage and shareable result
cards. AI is optional and uses your own API key and credits. Keys stay in Keychain; settings and
history stay local. Streaming estimates and cancellation cannot guarantee provider billing. See
[setup and scoring](https://github.com/hugogu/herbert/blob/v1.0.0/docs/ai-battlefield.md) and
[privacy](https://github.com/hugogu/herbert/blob/v1.0.0/PRIVACY.md).

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

Code and the 30 originals are MIT licensed. Community content has separate, unconfirmed
redistribution rights. See [NOTICE.md](https://github.com/hugogu/herbert/blob/v1.0.0/NOTICE.md).
The App Store edition contains only the originals; this DMG is the open-source edition.

中文：Herbert 1.0.0 发布。仅含原创关卡的 App Store 版 **Herbot Bot** 已备齐 iPhone、iPad 与 Mac 的中英日商店文案、带说明的截图、支持页面和覆盖两个版本的隐私政策；本 DMG 仍是开源版 **Herbert**。英文和日文界面将 30 道原创关卡称为谜题（puzzle），题目说明显示「关卡 / 原创系列」。修复 iPad 横屏键盘弹出后「收起键盘」和 s/l/r 键失效的问题，补齐手册致谢与规则链接的英日翻译，并沿用 0.4.0 对 Herbert 挑战与 H 语言来源的更正。

下载下方 DMG 后将 Herbert 拖入“应用程序”。支持 macOS 14+，包含 30 道原创和 1,769 道社区题，
中英日界面、连续墙、轨迹与网格、本地历史和 PNG 分享。此 DMG 尚未经过 Apple 公证。
AI 使用自己的 API 额度；密钥留在钥匙串，本地预算与取消请求无法保证最终账单。

See the [changelog](https://github.com/hugogu/herbert/blob/v1.0.0/CHANGELOG.md)
and [README](https://github.com/hugogu/herbert/tree/v1.0.0#readme) for screenshots and controls.
