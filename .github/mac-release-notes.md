Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. No Xcode is needed. Requires **macOS 14 or later**; the same app
supports **Apple Silicon and Intel**.

This open-source preview includes **30 original lessons + 1,769 archived community
problems**, automatic English/Chinese/Japanese UI, Modern and Classic boards,
movement trails, grid dots, and local progress with JSON backup import/export.

**Updated in 0.3.5:** Benchmark results now show **total points / (100 × selected puzzles)**
as a percentage in live progress, history and share images. Solved counts sit beside the
provider; model display names omit pricing suffixes such as `(free)`.

The puzzle picker integrates search, original/community/selected filters, chapter
groups, board thumbnails, byte budgets and bulk selection actions.

Long reasoning streams no longer fail because repeated SSE metadata exceeds the old
4 MiB transport limit. Individual events and actual answer/reasoning content remain
bounded, with partial output preserved on failure. The 64K model output default remains
configurable. Best Effort waits for every AI; Mac history and answer dialogs are resizable.

The course has continuous **L01–L30** numbers. New L07 “Turning rose” and L08 “Tandem lanterns”
replace the former L25/L26 with symmetric walled boards. Other boards, saved progress
identities and historical snapshots are retained. Both editions contain 30 originals;
this open-source preview also contains the 1,769 community puzzles. Prompt v4 retains
the verified public examples and refers to the course finale by its current identity.
README screenshots are actual app captures; English documentation uses English UI.

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
0.3.5 将评测成绩显示为总满分百分比，移动通过题数、清理模型名称后缀，并重做题目选择页。修复长推理因 SSE 包装数据达到旧 4 MiB 上限而失败的问题。

默认单次输出上限为 65,536 tokens，可从新比赛已选模型旁的参数按钮直接修改。
Best Effort 等待所有 AI 完成；Mac 历史默认可见三列模型，历史和答案窗口均可调整大小；推理可折叠并按 Markdown 显示。
原创课程连续编号 L01–L30，新 L07「旋转玫瑰」和 L08「双灯相映」替换原 L25/L26。
AI 使用自己的 API 额度，密钥保存在钥匙串中。

See the [changelog](https://github.com/hugogu/herbert/blob/main/CHANGELOG.md) for changes
and the [README](https://github.com/hugogu/herbert#readme) for screenshots and controls.
