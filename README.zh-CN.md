# Herbert

[English](README.md) · **简体中文** · [参与贡献](CONTRIBUTING.md) · [更新记录](CHANGELOG.md)

![原生 Mac App：Flower 关卡、H 语言编辑器与运行控制](docs/screenshots/flower.png)

*实际原生 Mac App 截图，关卡 0037「Flower」由 nai 创作。编辑器中的代码是入门示例，并非这道题的解法。*

| 0037 · Flower | 0027 · Shuriken | 0361 · Butterfly |
| --- | --- | --- |
| [![Flower 棋盘](docs/screenshots/flower-board.png)](docs/screenshots/flower.png) | [![Shuriken 棋盘](docs/screenshots/shuriken-board.png)](docs/screenshots/shuriken.png) | [![Butterfly 棋盘](docs/screenshots/butterfly-board.png)](docs/screenshots/butterfly.png) |
| nai · ≤ 20 bytes | snuke · ≤ 39 bytes | nadsuki · ≤ 27 bytes |

截图来自运行中的 App；点击棋盘查看完整界面。最近发布为 **0.1.0 预览版**；当前 main 开发版界面会自动匹配系统的中文、英文或日文语言偏好，其他语言回退至英文。


用最短的 H 语言程序，带 Herbert 点亮所有目标。原生 SwiftUI 游戏，共用一个与界面无关的游戏引擎，支持 **iPhone / iPad（iOS 17+）和原生 Mac（macOS 14+）**。

## 棋盘风格

| 现代风格（默认） | Classic 经典风格与轨迹 |
| --- | --- |
| [![现代 Flower 棋盘](docs/screenshots/flower-board.png)](docs/screenshots/flower.png) | [![经典 Flower 棋盘与蓝色运动轨迹](docs/screenshots/flower-classic-board.png)](docs/screenshots/flower-classic.png) |

两张均为实际 App 截图。经典风格参考原站规则页中的棋盘；示例执行了四条指令，只有实际移动才会留下轨迹。棋盘右上角的滑杆图标可设置风格、网格点和运动轨迹。新增功能目前位于 main，将纳入下一版本。

## 运行

需要 Xcode 16 或更新版本及 Swift 6，无第三方依赖；本机验证工具链为 Xcode 27.0。

```sh
open Herbert.xcodeproj
```

选择 `Herbert` scheme 和目标设备，点击 Run。连接 iPhone/iPad 真机时，在 Signing & Capabilities 中选择自己的 Development Team。项目没有预设签名账号。

```sh
# 引擎、关卡、持久化与备份集成测试
swift test

# 格式检查和测试
scripts/check.sh

# 原生 Mac
xcodebuild -project Herbert.xcodeproj -scheme Herbert -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY=- build

# iPhone / iPad 编译，不需要开发者签名
xcodebuild -project Herbert.xcodeproj -scheme Herbert -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# Mac 界面自动化（会启动测试专用游戏实例）
xcodebuild -project Herbert.xcodeproj -scheme Herbert -destination 'platform=macOS,arch=arm64' CODE_SIGN_IDENTITY=- test
```

## 已实现

- 原版 H 语言：`s/l/r`、单字母过程、递归、最多 26 个参数、可为空的命令参数、数值参数、加减法、非正参数跳过调用、±255 数值限制。
- 原版计数：每个字母 1 byte，每个数值常量 1 byte，标点与空白不计；每关按原站限制判定，步数不影响最短解记录。
- 25×25 棋盘：目标、墙、陷阱，踩陷阱清空已点亮目标，撞墙或边界留在原地，点亮全部目标立即通关。
- 离线原版题库：保留编号、标题、作者、长度限制、原站最短记录快照、数据校验摘要与来源；数量和缺失项以 `docs/problem-import-manifest.json` 为准。
- 手机上下布局与固定运行栏；iPad/Mac 并排棋盘和编辑器；原生可选中文本编辑器、光标处插入指令、更多符号、代码模板、单步、暂停/继续、重置、4 档速度、触觉反馈。
- 有内容区域自动聚焦、完整棋盘切换、双指缩放和放大后拖动。颜色配合目标环、陷阱叉与墙形状区分元素，支持 VoiceOver 棋盘状态描述。
- 关卡搜索、入门/收藏/完成筛选、继续最近关卡、中英日分步玩法手册。
- 当前快照包含 **1,769 个可玩关卡**，来源列表全部 21 页，最后原版编号 2077；排除 0000 空占位项，缺失项为零。
- 自动保存草稿、收藏、最短解与完成日期；本地 JSON 原子写入；损坏存档暂停自动写入，避免覆盖原文件；JSON 备份导入/导出，导入前重放并校验解法，合并时保留更短的有效解。
- 中英日自动匹配：覆盖导航、玩法手册、无障碍描述和 H 语言错误提示；保留关卡原始名称和作者。
- 棋盘右上角设置支持现代（默认）/ Classic 经典风格、显示网格点、显示运动轨迹；偏好保存在本机，切换关卡和重启后保留。
- 轨迹记录当前运行走过的路径，单步和极速均完整记录；隐藏后继续记录，重新显示即可查看，重置棋盘或修改代码会清空。
- 切到后台自动暂停执行并保存；Mac 支持 `⌘ Return` 运行/暂停。

## 结构

```text
Herbert/                         SwiftUI 应用与平台文本编辑器
Sources/HerbertCore/              H 解析器、虚拟机、棋盘、会话与存档
Sources/HerbertCore/Resources/    原站题库快照
Tests/HerbertCoreTests/           单元测试、原题通关与存档/备份集成测试
HerbertUITests/                  原生界面自动化
scripts/                        可重复的题库导入、图标和工程生成、检查脚本
docs/                           数据导入清单、规则核对说明、架构与验证记录
```

`Package.swift` 提供独立的 `HerbertCore` Swift package；Xcode 工程通过本地 package 引用它。`scripts/generate_project.py` 可重建已提交的工程，不需要 XcodeGen。增加或移除应用 Swift 文件后，运行此脚本即可更新工程。图标由 `scripts/generate_icon.swift` 绘制，资源已经内置。

## 本地存档与未来 Cloudflare

数据存于应用 Application Support 下的 `Herbert/progress.json`（沙盒中的实际位置由系统决定）。格式带 `schemaVersion`，同一格式也用于备份；未接入云端、账号或分析 SDK。

所有持久化通过 `ProgressRepository`。未来可在其上增加同步协调器，使用 **App → 已认证的 Cloudflare Worker → D1**。客户端不持有 Cloudflare API Token，不直接访问数据库。合并规则和数据迁移建议见 [架构说明](docs/architecture.md)。

## 原版来源与移植边界

- [原站规则](http://herbert.tealang.info/rule.php)
- [原站 Problems](http://herbert.tealang.info/problems.php)
- 原站由 quolc 创建，社区关卡归各作者所有；本项目独立编写游戏代码，没有打包或执行原站 Flash 客户端。
- 应用独立编写的代码、图标和文档使用 [MIT 许可证](LICENSE)。原站未声明可再分发题库的许可证，授权范围尚未确认；原版题库及截图中的关卡布局不在本项目的 MIT 授权范围内，原作者保留权利。详情见 [第三方内容说明](NOTICE.md)。
- 原站在线排名、账号、投稿与服务器评分未移植；应用展示个人最短代码记录。原站最短记录是导入时的快照，不进行在线比较。
- 按原版限制运行最多 100 万个机器人指令；为保证手机可取消执行，额外限制 100 万次解释器展开、4096 层非尾递归栈、16 KiB 源代码、64 层参数语法嵌套和 128 层运行时参数嵌套。命令参数与待执行栈使用 100 万单位的展开预算，尾递归不增长调用栈。这些保护可能比原站更早停止极端程序。

重新导入题库（会访问原站，默认最多四个并发连接，成功响应缓存，失败可重试）：

```sh
python3 scripts/import_problems.py
```

导入程序从公开列表发现全部页，排除原站 `0000 / Null` 占位项，逐一核对棋盘长度、符号、起点、目标和 byte 限制；有失败时会保存已取得的题目，并在清单列出缺失 ID，以非零状态退出。再次运行使用缓存，仅补取失败请求。原站仅提供旧 HTTP 接口，JSON 内置题库是离线资源，App 本身无需网络权限。

## 参与贡献

欢迎错误报告、翻译改进、无障碍改进和 iPhone/iPad 真机测试。请阅读
[贡献指南](CONTRIBUTING.md)、[社区行为准则](CODE_OF_CONDUCT.md) 和 [安全策略](SECURITY.md)。
CI 执行格式检查、单元/集成测试和 Mac/iOS 编译；原生界面测试需要交互式 Mac 桌面。
运行 `scripts/capture_screenshots.sh zh-Hans` 可重新生成 README 的真实界面截图。

当前尚未接入云同步，没有 App Store 或公证 Mac 安装包；iPhone/iPad 运行时验证仍待完成。
完整记录见 [验证说明](docs/verification.md)。
