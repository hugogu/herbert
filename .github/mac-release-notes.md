Download **Herbert-macOS-universal.dmg** below, open it, and drag **Herbert.app** to
**Applications**. Requires **macOS 14+**; supports **Apple Silicon and Intel**. No Xcode needed.

**Updated in 0.3.7:**

- One **Match Settings** panel replaces modes: optional time limit, optional independent
  token budget per model and problem, and three attempts per problem by default.
  Both limits start off. Budgets include input and output across retries, including reasoning.
- Reaching an output or problem token limit marks that problem **Burnout**, retains
  received reasoning, and cancels its remaining retries. Other problems and models continue.
- Remove per-model output caps. Unlimited requests use advertised model capacity or
  omit the cap for provider defaults; known provider limits still apply. Historical
  parameters remain readable, while active settings migrate to the new policy.
- **Model Settings** enables automatic thinking and the highest supported reasoning
  effort by default, with provider-aware parameters, a JSON preview and explicit overrides.
- Shorten model display names by removing provider prefixes before `:` and pricing
  suffixes. Move token accounting notes below progress. Both READMEs include the
  user-provided six-model example and refreshed English app captures.

The preview includes **30 original lessons + 1,769 archived community problems**,
automatic English/Chinese/Japanese UI, Modern and Classic boards, movement trails,
grid dots and local progress with JSON backups. Original lessons are numbered L01–L30.

Herbert Benchmark judges actual H programs in the native engine. Progress, history
and share images show normalized coverage/code-efficiency scores, token usage and cache
rates. Mac history opens with three model columns; history and answer dialogs resize.
Reasoning collapses independently and renders as Markdown. Puzzle selection includes
search, source filters, chapter groups, board previews and bulk actions.

AI is optional and requires your API key/credits. Keys stay in Keychain; settings and
history stay local. Provider failures retain partial output and diagnostics, and are
not treated as rejected H programs. Streaming estimates and cancellation cannot guarantee
provider billing. See [setup and scoring](https://github.com/hugogu/herbert/blob/main/docs/ai-battlefield.md)
and [privacy](https://github.com/hugogu/herbert/blob/main/PRIVACY.md).

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
redistribution rights. See [NOTICE.md](https://github.com/hugogu/herbert/blob/main/NOTICE.md).
The App Store scheme contains only originals; this DMG is the open-source edition.

中文：0.3.7 取消比赛模式，统一为比赛设置：默认不限时、不限 Token，每题最多 3 次机会。
可对每个模型每道题设置相同的独立预算，累计输入、输出与推理及重试用量。
达到输出或每题预算上限后标记 Burnout，保留内容、不再重试此题，后续题目和其他模型继续。
移除模型单独输出上限，默认启用服务商支持的思考与最高推理等级，允许高级 JSON 覆盖。
清理模型名服务商前缀，将用量提示移到表格下方，README 增加用户提供的六模型示例。

下载下方 DMG 后将 Herbert 拖入“应用程序”。支持 macOS 14+，包含 30 道原创和 1,769 道社区题，
中英日界面、连续墙、轨迹与网格、本地历史和 PNG 分享。预览版尚未经过 Apple 公证。
AI 使用自己的 API 额度；密钥留在钥匙串，本地预算与取消请求无法保证最终账单。

See the [changelog](https://github.com/hugogu/herbert/blob/main/CHANGELOG.md)
and [README](https://github.com/hugogu/herbert#readme) for screenshots and controls.
