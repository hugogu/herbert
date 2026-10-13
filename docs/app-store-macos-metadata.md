# App Store Connect metadata — macOS

Draft for the **Herbot Bot** App Store edition. Copy the text inside each block into the matching App Store Connect field. The store target contains the 30 original lessons and optional AI Battlefield; it does not include the community puzzle archive.

## App record

| Field | Prepared value / action |
| --- | --- |
| App name | **Herbot Bot**. This matches `CFBundleDisplayName`; App Store Connect still needs to confirm the name is available. |
| Bundle ID | `info.hugogu.Herbert` |
| SKU | Keep the SKU already assigned to the existing App Store Connect record. It is an internal identifier, not store-page text. |
| Version / build | **0.4.0 (13)**, after confirming the uploaded macOS archive has these values. |
| Minimum macOS | **macOS 14.0** |
| Primary category | **Games → Puzzle** |
| Secondary category | **Education** (optional) |
| Primary metadata language | **English (U.S.)**; add Simplified Chinese and Japanese localizations if desired. The app itself supports English, Simplified Chinese, and Japanese. |
| Copyright | `2026 Hugo Gu` — the repository license names Hugo Gu and Herbert contributors; confirm the person/entity to enter is the actual rights holder for this release. |
| Price | Account-owner decision. If paid, accept the Paid Apps Agreement and set a price before submission. |
| Availability | For the previously requested non-mainland-China launch, select the intended storefronts and leave **China mainland** unchecked. Confirm separately whether Hong Kong, Macao, and Taiwan should be included. |

The seller/developer name comes from the Apple Developer account. For an individual account, Apple uses the account holder’s legal name; an organization may use an eligible registered trade name. Check the displayed seller name before submission.

## English (U.S.) metadata

### Name

```text
Herbot Bot
```

### Subtitle

```text
A tiny language, big puzzles
```

### Promotional text

```text
Guide a little robot through 30 original puzzles. Learn procedures, parameters, and recursion, then make every byte count. Play the core game offline.
```

### Description

```text
Program a little robot. Make every byte count.

Herbot Bot is a native Mac puzzle game built around H, a compact language with three movement commands. Write a program, run it on a 25 × 25 board, and light every target while staying within the puzzle’s byte limit.

LEARN BY SOLVING
Begin with simple moves, then discover procedures, parameters, and recursion through 30 original puzzles. Optional hints help you find a way forward.

EXPERIMENT FREELY
Edit code, run it, step through instructions, and watch the robot’s route. Walls stop movement; traps clear lit targets. The built-in engine checks whether your program completes each board within its code limit.

KEEP YOUR PROGRESS
Drafts, favorites, completions, preferences, and shortest accepted solutions are saved locally on your Mac. Import or export progress as JSON. No account is required, and the puzzle course works offline.

OPTIONAL AI BATTLEFIELD
Connect your own API key to a supported AI provider and run generated H programs through the built-in judge. Compare models, inspect answers and reasoning, and revisit match history. AI features require an internet connection and may incur charges from your provider. You choose whether to send puzzle and conversation data; requests go directly to the providers you configure.

MADE FOR MAC
A native SwiftUI app for macOS 14 or later. Press Command–Return to run or pause a program. The interface and lessons are available in English, Simplified Chinese, and Japanese.

Herbot Bot is an independent implementation of publicly available rules and is not affiliated with Wild Noodle Corporation or Microsoft. Wild Noodle created the original Herbert challenge and H language. The 30-puzzle course in this edition was designed for this project.
```

### Keywords

```text
programming,puzzle,logic,recursion,code,offline,robot,algorithm
```

## 简体中文元数据

### 名称

```text
Herbot Bot
```

### 副标题

```text
三条指令，解开递归谜题
```

### 推广文本

```text
带领小机器人挑战 30 道原创关卡。学习过程、参数与递归，不断精简代码。基础游戏可离线游玩。
```

### 描述

```text
编写短小程序，带领小机器人点亮全部目标。

Herbot Bot 是一款原生 Mac 编程解谜游戏。你将使用只有三个移动指令的 H 语言，在 25 × 25 棋盘上规划路线，并在每关的代码字节限制内点亮全部目标。

边解谜，边学习
从简单移动开始，在 30 道原创关卡中逐步学习过程、参数与递归。每关提供可选提示，帮助你继续探索。

自由尝试不同思路
编辑并运行代码，逐步执行指令，观察机器人的路线。墙会阻挡移动；踩到陷阱会熄灭已点亮的目标。内置引擎会检查程序是否在代码长度限制内完成关卡。

进度保存在本机
草稿、收藏、通关记录、偏好设置和最短通过代码保存在你的 Mac 上。支持以 JSON 导入或导出进度。无需注册账号，基础关卡可离线游玩。

可选 AI Battlefield
连接你自己的 API Key，让 AI 服务生成 H 程序，再由内置判题器进行验证。比较不同模型的结果，查看回答、推理内容和比赛历史。AI 功能需要联网，服务商可能另行收费。题目和对话会直接发送到你配置的服务商；是否发送由你决定。

为 Mac 原生打造
原生 SwiftUI 应用，支持 macOS 14 或更新版本。按下 Command–Return 即可运行或暂停程序。应用界面和课程支持英语、简体中文与日语。

Herbot Bot 是依据公开规则独立实现的作品，与 Wild Noodle Corporation 或 Microsoft 无隶属关系。最初的 Herbert 挑战和 H 语言由 Wild Noodle 创作；本版本的 30 道课程关卡由本项目设计。
```

### 关键词

```text
编程,解谜,逻辑,递归,代码,机器人,离线,益智
```

## 日本語メタデータ

### 名前

```text
Herbot Bot
```

### サブタイトル

```text
小さな言語で解くロジックパズル
```

### プロモーションテキスト

```text
小さなロボットを30のオリジナルパズルへ。手続き・パラメータ・再帰を学び、コードを1バイトずつ短くしよう。基本のゲームはオフラインで遊べます。
```

### 説明

```text
小さなプログラムで、ロボットをゴールへ導こう。

Herbot Bot は、3つの移動命令を持つ小さな言語 H を使う、Mac 向けのネイティブパズルゲームです。プログラムを書き、25 × 25 の盤面でロボットを動かして、各問題のバイト数制限内ですべての目標を点灯させましょう。

パズルを解きながら学ぶ
簡単な移動から始め、30のオリジナルパズルを通して手続き、パラメータ、再帰を学びます。行き詰まったときに使えるヒントも用意しています。

自由に試してみよう
コードを編集して実行し、命令を一つずつ進めながらロボットのルートを確認できます。壁に当たると進めず、トラップに触れると点灯した目標がリセットされます。内蔵エンジンが、コードの長さ制限内で盤面をクリアできたか判定します。

進捗はMacに保存
下書き、お気に入り、クリア記録、設定、最短のクリアコードをMacにローカル保存します。JSON形式で進捗を読み込み・書き出しできます。アカウント登録は不要で、基本のパズルはオフラインで遊べます。

オプションのAI Battlefield
自分のAPIキーで対応するAIサービスに接続し、生成されたHプログラムを内蔵ジャッジで検証できます。モデルごとの結果を比べ、回答や推論、試合履歴を確認できます。AI機能にはインターネット接続が必要で、サービス提供元から利用料金が請求される場合があります。問題や会話データは設定したサービスに直接送信され、送信するかどうかは利用者が選べます。

Mac向けネイティブアプリ
SwiftUIで開発したネイティブアプリで、macOS 14以降に対応しています。Command–Returnキーでプログラムを実行または一時停止できます。英語、簡体字中国語、日本語に対応しています。

Herbot Bot は公開されているルールに基づく独立した実装であり、Wild Noodle Corporation および Microsoft とは提携していません。Herbert のオリジナルチャレンジと言語 H は Wild Noodle が制作し、本エディションの30問は本プロジェクトが制作しました。
```

### キーワード

```text
プログラミング,パズル,論理,再帰,コード,ロボット
```

## URLs and support

| App Store Connect field | Value |
| --- | --- |
| Privacy Policy URL (required) | `https://github.com/hugogu/herbert/blob/main/PRIVACY.md` |
| Support URL (required) | `https://github.com/hugogu/herbert/issues` |
| Marketing URL (optional) | `https://github.com/hugogu/herbert` |
| Support email | `hugogu@outlook.com` |
| User Privacy Choices URL (optional) | Leave blank unless a separate privacy-choices page is created. |

## Version text

For an initial release, if App Store Connect requests version notes, use:

```text
Initial release: explore 30 original H-language puzzles, learn recursion, and optionally test AI-generated programs with the built-in judge.
```

## App Review notes

```text
Herbot Bot contains a 30-puzzle course that works offline and requires no account or purchase.

To review the core game, launch the app, select L01, enter “s” in the program editor, and run it. The Guide explains the H language and controls. Progress backup is available in Settings.

AI Battlefield is optional and requires an API key and account from a provider selected by the reviewer. The developer does not provide shared credentials or proxy the requests. Saving a provider or refreshing its model list sends an authenticated model-list request to that provider. Starting a match shows the data-sharing and provider-cost disclosure; puzzle and conversation data are sent only after the reviewer chooses “Agree & start match.” No AI request is needed to access or review the core puzzle course.
```

## Before submitting

- **Screenshots and video:** Dedicated English and Simplified Chinese media is prepared with the `HerbertAppStore` target. See [the media guide](app-store-macos-media.md) for the capture/export workflow and upload instructions. Use the **2880 × 1800 RGB PNGs** and the **1920 × 1080, 27-second MP4** in `outputs/app-store-macos/0.4.0/<locale>/`; README captures have different dimensions. Upload each language to its corresponding App Store Connect localization.
- **App Privacy:** Do not mark “No data collected” without completing a provider-by-provider review. The core puzzle data is local, but optional AI features contact user-configured providers: model discovery sends a request, and agreed matches send rules, selected boards, prompts, answers, and judge feedback. Apple says the declaration must include the app developer’s and third-party partners’ practices. The reviewer should verify each provider’s retention and use before selecting data categories.
- **Privacy policy revision:** `PRIVACY.md` currently says it is effective for version 0.3.2. Review it against the 0.4.0 build and update that version note before submitting; the policy URL should open without authentication.
- **Age rating:** Complete the current App Store Connect questionnaire from the shipped app’s actual content and capabilities; do not infer a rating from the puzzle genre alone, especially with optional AI-generated text.
- **EU DSA:** Apple may still require a trader-status declaration even when the app is not offered in EU storefronts. This is a self-assessment, not an automatic result of charging for the app. If the app is offered in the EU and the developer is a trader, Apple verifies and displays the required trader contact details.
- **Rights and attribution:** The store build excludes community problems, but the MIT license in this repository does not by itself grant rights to third-party names or original material. Keep the attribution and non-affiliation statement, and confirm the rights needed to distribute under the Herbert name and use the historical rules before submission.
- **Account and archive:** Confirm the seller name, copyright holder, existing SKU, price, storefronts, encryption/export-compliance answers, and that the uploaded `HerbertAppStore` Mac archive is version 0.4.0/build 13.

## Apple references

- [App information and name/subtitle limits](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform version information: promotional text, description, keywords](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Mac screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [App privacy disclosures](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [EU Digital Services Act trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
