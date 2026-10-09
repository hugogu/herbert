Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. Requires **macOS 14+**; supports **Apple Silicon and Intel**. No Xcode needed.

**Updated in 0.3.8:**

- Add **Anthropic-compatible Messages API** providers with native authentication,
  model discovery, streaming thinking, signed content replay and cache-aware usage.
  A dedicated **Google Gemini** provider joins OpenRouter, SiliconFlow and OpenAI-compatible endpoints.
- **Manual retry** gives a specific model one extra attempt on a non-accepted puzzle,
  including saved matches. It preserves prompts, model settings, prior answers, best
  scores, remaining budgets and overload cooldowns. The icon sits beside the status
  on the first line, leaving the program preview and timing the full second line.
- Retain full responses and diagnostics. Recover explicitly marked final H answers
  from reasoning or incomplete fences while keeping their original output. Interrupted
  or truncated responses remain separate from rejected programs. Playground can run
  over-limit programs as trials without recording accepted progress.
- Treat **429 rate limits as Overloaded**, honor provider retry hints and apply
  exponential backoff to transient failures. Stop cancels pending waits and requests.
  **402 credit failures become Burnout** and stop that entrant's automatic requests.
- Show each attempt's time and each model's cumulative attempt time, including
  retries and failures. Align model time with the top of the normalized percentage,
  with total points underneath. Share cards use the same input/output and reported
  total tokens, include time and points, and omit unavailable cache rates.
- Open **Match history as a full page** that expands with the main Mac window.
  Keep answer dialogs resizable with collapsible Markdown reasoning. Compact result
  headers, contextual help and landscape layouts give boards and code more space.
- **Copy AI prompt** from a puzzle's details to reuse Battlefield's exact rules,
  worked examples and board in an external chat. Community puzzles show archived
  best-answer lengths; a board guide explains walls and traps.

The preview includes **30 original lessons + 1,769 archived community problems**,
automatic English/Chinese/Japanese UI, Modern and Classic boards, movement trails,
grid dots and local progress with JSON backups. Original lessons are numbered L01–L30.

Herbert Benchmark judges H programs in the native engine. Rankings use normalized
coverage/code-efficiency scores, with total points as a reference. Match Settings
provides optional time and per-model, per-problem token budgets, both off by default,
and three attempts per problem. All models can finish their selected attempts.

AI is optional and requires your API key/credits. Keys stay in Keychain; settings and
history stay local. Streaming estimates and cancellation cannot guarantee provider
billing. See [setup and scoring](https://github.com/hugogu/herbert/blob/v0.3.8/docs/ai-battlefield.md)
and [privacy](https://github.com/hugogu/herbert/blob/v0.3.8/PRIVACY.md).

**Signing:** this preview is ad-hoc signed and has not been notarized by Apple.
If macOS blocks the first launch, follow [Apple's instructions](https://support.apple.com/en-us/102445)
for **System Settings → Privacy & Security → Open Anyway** after trying to open it.

**Integrity:** download the accompanying `.sha256` file into the same directory and run:

```sh
shasum -a 256 -c Herbert-macOS-universal.dmg.sha256
```

GitHub Actions tests, builds both architectures, audits the signature, sandbox and
bundled catalogs, mounts the DMG read-only to verify it, and publishes after Mac/iOS
builds pass. Native Mac UI tests use deterministic fixtures; paid provider calls and
iPhone/iPad runtime checks remain device verification work.

Code and the 30 originals are MIT licensed. Community content has separate, unconfirmed
redistribution rights. See [NOTICE.md](https://github.com/hugogu/herbert/blob/v0.3.8/NOTICE.md).
The App Store scheme contains only originals; this DMG is the open-source edition.

中文：0.3.8 新增 Anthropic Messages 与 Google Gemini 服务商、逐题手动重试、完整响应诊断与明确最终答案恢复。
429 过载遵守服务商提示等待，402 额度错误归为 Burnout。超长程序可试运行但不保存为通过。
每次尝试独立计时，模型累计用时与百分比顶部对齐、总分显示在下方；分享图统一 Token 统计并省略缺失缓存率。
历史改为可随主窗口扩展的整页，保留返回、答案检查和试运行；优化横屏布局，支持复制题目 AI 提示词。

下载下方 DMG 后将 Herbert 拖入“应用程序”。支持 macOS 14+，包含 30 道原创和 1,769 道社区题，
中英日界面、连续墙、轨迹与网格、本地历史和 PNG 分享。预览版尚未经过 Apple 公证。
AI 使用自己的 API 额度；密钥留在钥匙串，本地预算与取消请求无法保证最终账单。

See the [changelog](https://github.com/hugogu/herbert/blob/v0.3.8/CHANGELOG.md)
and [README](https://github.com/hugogu/herbert/tree/v0.3.8#readme) for screenshots and controls.
