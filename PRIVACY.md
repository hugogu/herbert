# Privacy

Herbert supports offline use, optional user-configured AI providers, and an optional
verified leaderboard in configured App Store builds. No analytics or advertising
service is integrated. Deployments must publish their operator, retention policy
and data-processing locations before enabling cloud accounts.

## Offline game

Puzzles, human-written programs, favorites, progress and preferences stay in local app
storage. The game requires no network connection. JSON progress export/import occurs
only when requested. Opening an external link uses your browser and that site's policy.

## Optional cloud leaderboard (App Store builds)

Opening the leaderboard contacts its configured HTTPS service and exposes normal
connection information. Uploading solutions requires an explicit Apple login and
confirmation. The service receives an Apple account subject identifier, a generated
nickname, original exercise IDs and H solutions, and computes scores itself. It
does not request your Apple email address or real name. Your generated nickname,
score and completion count are public; submitted programs are private to you and
authorized operators. Drafts, community solutions, AI histories and API keys are
not uploaded. IP-derived hashes are retained briefly for rate limits.

Session credentials stay in device-only Keychain. The service runs on Cloudflare
Workers/D1; the operator controls its configured database location and retention.
Authentication uses Apple. In **Progress → Global leaderboard**, you can sign out
or delete your cloud account. Deletion revokes Apple authorization, removes the
Apple identifier/credential, blanks uploaded programs, hides scores and revokes
sessions. Internal numerical tombstones and operator audit records remain subject
to the published retention policy. Local progress and backups are preserved.
Unconfigured builds and **HerbertLearning** have no cloud account service.

## Optional AI Battlefield

You choose each provider, endpoint, model and API key. **Saving a provider or refreshing
models** sends an authenticated model-list request to that provider. **Agree & start match**
sends the rules, selected puzzle boards, additional prompt and this puzzle's conversation,
including AI answers and judge feedback, directly to your selected providers. Requests
also expose normal connection information such as your IP address. The developer does
not proxy these calls or receive copies. Do not put personal or confidential information
in additional prompts unless you intend to send it to those providers.

Providers may retain data and charge according to their own terms, privacy policy and
API pricing. Review them before configuring a provider or starting a match. OpenRouter
can route requests to downstream model providers. You can use the ordinary game without
configuring or using any AI service. There are no embedded API keys or shared credits.

API keys are stored in the system Keychain with synchronization disabled and device-only
accessibility. They are sent only in authentication headers to the configured HTTPS
endpoint. Changing endpoints requires re-entering the key; redirects are rejected.
Settings and match history are local JSON files. History contains full AI responses,
programs, feedback, the full shared prompt with its version, puzzle snapshots, model parameters and usage. From 0.3.2 it also
retains received model reasoning and bounded provider error details (up to 64 KiB). Known
credential fields, Bearer values and the configured API key are redacted from error details.
Review provider text before sharing it; providers control the contents of their responses.
App data may be included in operating-system device backups according to your settings;
Herbert implements no automatic progress synchronization; the leaderboard is a separate, opt-in upload service.

Removing a provider in AI Providers deletes its configuration and Keychain entry.
Existing match histories remain for review. Match histories are retained locally until
app data is removed; the app does not yet delete individual histories. Operating-system
app/container removal and backup retention vary by platform. Avoid assuming that deleting
the app removes Keychain entries; remove providers in the app first if desired.

## Share images

The app renders result images on your device. They include provider/model display names,
ranks, scores and usage, but omit keys, endpoints, raw responses and additional prompts.
An image is sent only through the system share destination you choose. Herbert does not
host shared images or publish match results automatically.

## Children

The game suits all ages and collects no personal information from anyone, including children.
AI Battlefield needs an account with a third-party AI provider, which sets its own age
requirements.

## Changes

Changes to this policy are published in this file with a new date; the Git history keeps every
earlier version.

## Contact

Questions or deletion guidance: [hugogu@outlook.com](mailto:hugogu@outlook.com).
For help with the app, see [SUPPORT.md](SUPPORT.md). For security issues, see [SECURITY.md](SECURITY.md).

---

中文：本政策适用于开源版 Herbert 与 App Store 版 Herbot Bot。开发者不收集任何个人数据，没有账号、统计、广告、追踪或开发者服务器。
普通游戏完全离线。AI Battlefield 由你自行选择服务商并提供 API Key；保存或刷新服务商会发送模型查询，
点击“同意并开始比赛”会直接发送规则、题目、附加提示词和当前题目的对话。服务商可能保存请求并收取 API 费用。
开发者不代理请求，不收集副本。密钥保存在关闭同步的系统钥匙串中，配置和完整比赛历史保存在本机。
分享图片仅通过你选择的系统分享目标发送，图片不包含密钥、端点或原始对话。移除服务商会删除其密钥与配置，但保留比赛历史。

中文（可选排行榜）：App Store 构建在配置服务后，用户可使用 Apple 登录并主动上传原创题的最短解。
服务端重新验题；匿名昵称、分数和完成数公开，程序只供本人及授权管理员访问。可在排行榜页删除云账号，
撤销授权、移除已上传程序和排名；本地记录保留。HerbertLearning 不含云账号或在线功能。

日本語：通常のゲームは完全にオフラインです。AI Battlefield では利用者がサービスと API キーを指定します。
保存・更新時はモデル一覧、同意して開始するとルール、問題、追加プロンプト、今回の問題の会話を直接サービスに送信します。
サービスがリクエストを保存し、料金を請求する場合があります。開発者はリクエストを中継・収集しません。
キーは同期しないシステムのキーチェーン、設定と試合履歴は本機に保存します。共有画像は選択した共有先にだけ送信します。

任意のランキング：設定済み App Store 版では、Apple でサインインし、明示的な同意後にオリジナル問題の最短解を送信できます。
サーバーが再実行し、匿名名・得点・完了数のみ公開します。クラウドアカウントの削除で認証と送信済みプログラム・順位を除去し、
ローカル記録は残します。HerbertLearning にはクラウドアカウントやオンライン機能はありません。
