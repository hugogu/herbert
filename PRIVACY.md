# Privacy

Effective for Herbert **0.3.1**. Herbert's developer does not operate an account,
analytics, advertising or cloud storage service for this app.

## Offline game

Puzzles, human-written programs, favorites, progress and preferences stay in local app
storage. The game requires no network connection. JSON progress export/import occurs
only when requested. Opening an external link uses your browser and that site's policy.

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
programs, feedback, prompts, puzzle snapshots, model parameters and usage, but no keys.
App data may be included in operating-system device backups according to your settings;
Herbert implements no cloud synchronization.

Removing a provider in AI Providers deletes its configuration and Keychain entry.
Existing match histories remain for review. Match histories are retained locally until
app data is removed; 0.3.1 does not offer individual history deletion. Operating-system
app/container removal and backup retention vary by platform. Avoid assuming that deleting
the app removes Keychain entries; remove providers in the app first if desired.

## Share images

The app renders result images on your device. They include provider/model display names,
ranks, scores and usage, but omit keys, endpoints, raw responses and additional prompts.
An image is sent only through the system share destination you choose. Herbert does not
host shared images or publish match results automatically.

## Contact

Questions or deletion guidance: [hugogu@outlook.com](mailto:hugogu@outlook.com).
For security issues, see [SECURITY.md](SECURITY.md).

---

中文：普通游戏完全离线。AI Battlefield 由你自行选择服务商并提供 API Key；保存或刷新服务商会发送模型查询，
点击“同意并开始比赛”会直接发送规则、题目、附加提示词和当前题目的对话。服务商可能保存请求并收取 API 费用。
开发者不代理请求，不收集副本。密钥保存在关闭同步的系统钥匙串中，配置和完整比赛历史保存在本机。
分享图片仅通过你选择的系统分享目标发送，图片不包含密钥、端点或原始对话。移除服务商会删除其密钥与配置，但保留比赛历史。

日本語：通常のゲームは完全にオフラインです。AI Battlefield では利用者がサービスと API キーを指定します。
保存・更新時はモデル一覧、同意して開始するとルール、問題、追加プロンプト、今回の問題の会話を直接サービスに送信します。
サービスがリクエストを保存し、料金を請求する場合があります。開発者はリクエストを中継・収集しません。
キーは同期しないシステムのキーチェーン、設定と試合履歴は本機に保存します。共有画像は選択した共有先にだけ送信します。
