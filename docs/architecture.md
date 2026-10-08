# 架构与数据演进

## 游戏与界面

`HProgram` 编译、验证签名和调用关系并计算 byte 数；`HMachine` 是可暂停的虚拟机，每次 tick 限量展开，避免无移动的递归阻塞主线程。`GameSession` 负责棋盘规则、步数限制与通关判定。它们不依赖 SwiftUI、UIKit、AppKit 或存储。

`GameModel` 控制执行任务和速度，在生命周期变化、修改代码和离开页面时取消任务。修改代码重置棋盘；暂停不改变草稿；只有代码满足 byte 限制且全部目标点亮时才登记最短解。游戏状态从初始棋盘加草稿重新运行，存档不包含不可移植的虚拟机内存。

界面使用 SwiftUI；输入框分别由 UITextView 和 NSTextView 提供原生选区、光标、复制粘贴与外接键盘支持，快捷键向当前选区插入。Canvas 绘制棋盘，缩略图与游戏共用绘制代码。

## 本地存档

题库分为两个模块：`HerbertCore` 仅包含原创的 30 题和语言资源，`HerbertCommunity` 包含可选社区快照。
默认 `Herbert` target 链接两者并先显示原创课程；`HerbertAppStore` 仅链接前者，编译条件 `APP_STORE` 控制对应文案与筛选。
不是运行时隐藏资源。构建后的 App Store .app 由 `scripts/check_app_store_bundle.py` 验证题库隔离。
原创 ID 为 10001–10030，显示编号 L01–L30；社区 ID 保持不变。下一关按当前目录顺序查找，不按数值大小猜测。
目标、提示和名称采用同一套三语资源；参考解在测试 target 中独立打包，不进入应用。

`ProgressRepository` 目前由 `LocalProgressRepository` 实现。AppStore 协调草稿防抖保存、应用退后台时立即保存与错误提示。缺少文件返回空存档；已有文件损坏或版本不支持时报告错误并暂停保存。保存先校验 schema，再原子写入。

`ProgressSnapshot` v1：

| 字段 | 含义 |
| --- | --- |
| `schemaVersion` | 目前为 1；未来版本必须通过迁移解码，不能默默丢弃未知数据 |
| `lastProblemID` | 最近打开的稳定题号 |
| `records[].problemID` | 稳定业务标识，原创与社区使用不同范围 |
| `draft` / `updatedAt` | 正在编辑的代码与更新时间 |
| `bestSolution` / `bestBytes` | 已验证的最短解 |
| `completedAt` | 首次完成日期 |
| `isFavorite` | 收藏状态 |

备份先完成解码、schema 检查、题号检查与解法重放，再一次写入合并结果。解法验证在后台任务进行，保持界面可响应。草稿/收藏取更新时间较新的记录；解法取更小 byte 数，平手保留本机解法和日期。输入大小限制 32 MiB。所有处理成功后才更新内存快照和本地文件，失败不修改已有记录。

这里的本地 `Codable` JSON 沿用 Swift 命名。未来数据库表和列一律 `snake_case`，无需把 DB 命名暴露给 Swift 模型。

## Cloudflare 的后续接入

这次没有创建云资源、部署 Worker、添加数据库或引入账号。以下是未来可实现的演进路径：

1. 保留本地 repository 作为离线真相来源，新增异步 SyncCoordinator 和 outbox。不要用同步 HTTP 替换每次按键后的本地写入。
2. App 通过认证后的 Worker HTTP API 同步；Worker 校验用户身份、记录归属、输入上限和程序结果，再用 D1 prepared statements 读写。API 返回 `Cache-Control: no-store`，不缓存用户数据。
3. 初版建议表 `players`、`problem_progress`、`sync_operations`；列 `player_id`、`problem_id`、`draft`、`best_solution`、`best_bytes`、`completed_at`、`is_favorite`、`updated_at`、`revision`。使用 D1 migrations 管理 DDL，不能直接改生产表。
4. `problem_progress` 使用 `(player_id, problem_id)` 复合唯一键；增量同步采用服务端 revision/游标和 operation_id 幂等键。仅靠设备时间戳不足以处理时钟偏移和同时编辑。
5. 本地备份合并规则适用于手动迁移。云端并发编辑草稿应保留冲突副本，不能因为时间更新而静默覆盖另一个设备的未提交思路；完成记录按 byte 数取最短，时间可取最早可信完成日期。
6. 未来删收藏、删草稿或删除账号若支持同步，采用 tombstone 与明确的恢复/保留策略，不用 hard delete；题库和个人记录分开管理。
7. 在账号绑定和首轮上传前，展示具体数据范围；添加远端实现、模拟 HTTP 集成测试与网络中断/重试测试后再启用同步。

如此升级时，棋盘、解释器和大部分 UI 无需更改；本地 v1 数据可通过一次明确迁移继续使用。

## Board appearance and localization

`GameSession.trail` records undirected edges only after a successful move. Turning and
blocked moves add nothing; traps reset target states but preserve the trail. Preparing
a new run clears it. A 25×25 board has at most 1,200 distinct edges, so recursive walks
and Turbo batches cannot grow history without bound. Display toggles never affect execution.

Board style, grid dots, and trail visibility use local UserDefaults, separate from puzzle
progress and JSON backups. UI tests use an isolated preferences suite and progress file.
Progress still goes through `ProgressRepository`; future cloud sync requires an authenticated
Worker rather than client D1 credentials.

One set of `Localizable.strings` resources is bundled in both the native app and HerbertCore.
Foundation/SwiftUI match the system or per-app preferred language (en, zh-Hans, ja), with en
as development-language fallback. `HerbertStrings` formats core diagnostics and dynamic
labels; ordinary SwiftUI labels use native localization keys.
