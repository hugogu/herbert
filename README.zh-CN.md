# Herbert

[English](README.md) · **简体中文** · [参与贡献](CONTRIBUTING.md) · [更新记录](CHANGELOG.md)

先从 **10 道入门课程关卡**学习移动、避障、过程、递归与指令参数，再挑战 **20 道进阶题**：
让墙参与计数、交换参数、递归折返、互递归及多层子程序组合。
全部 **30 道原创题** 都有中英日目标与两级提示，参考解通过原生引擎和 HOJ 参考引擎验证。
默认开源版另含 1,769 道社区题，共 **1,799 题**；`HerbertAppStore` 仅打包原创的 30 题。
课程连续编号为 **L01–L30**：前十题入门，后二十题进阶。仅前两题可直接逐步写出路线。
L07「旋转玫瑰」和 L08「双灯相映」重新设计为对称、带连续墙的图案。显示编号与内部存档 ID 分开，退役记录仍可导入。

## 下载 Mac 版

**[下载 0.3.7 预览版 DMG](https://github.com/hugogu/herbert/releases/download/v0.3.7/Herbert-macOS-universal.dmg)**
— 支持 macOS 14+，同一个包兼容 Apple Silicon 和 Intel。打开 DMG，将 Herbert 拖到“应用程序”即可安装，无需 Xcode。包含全部 1,799 道题。

此预览版采用 ad-hoc 签名，**尚未经过 Apple 公证**。如果 macOS 阻止首次启动，确认信任下载来源后，可按 [Apple 指引](https://support.apple.com/en-us/102445)在“系统设置 → 隐私与安全 → 仍要打开”中确认。校验摘要、安装和构建方法见 [Mac 分发说明](docs/macos-distribution.md)。

![原创版原生 Mac App：穹顶镶嵌](docs/screenshots/course/course-mosaic.png)

*实际原生 Mac App 的中文截图。L29「穹顶镶嵌」组合收缩层、窗格与四向旋转；每层子过程都要恢复自己的位置和朝向，整体图案才接得起来。*

| L18 · 折页花窗 | L24 · 融雪方印 | L30 · 星穹圣殿 |
| --- | --- | --- |
| [![折页花窗的四向连续墙与递归分支](docs/screenshots/course/course-rosette-board.png)](docs/screenshots/course/course-rosette.png) | [![融雪方印的递归弯折与四个陷阱端点](docs/screenshots/course/course-seal-board.png)](docs/screenshots/course/course-seal.png) | [![星穹圣殿的方形庭院与分杈结构](docs/screenshots/course/course-cathedral-board.png)](docs/screenshots/course/course-cathedral.png) |
| 递归折返 · ≤ 29 bytes | 指令展开层选择 · ≤ 34 bytes | 旋向分杈与组合 · ≤ 56 bytes |

原创题目与这些截图均使用 MIT。预算已验证可达，不宣称最优解。难度来源、社区试解和去掉过于简单解法的过程见[设计说明](docs/advanced-course-design.zh-CN.md)。

## 社区题库示例

以下关卡来自默认开源版，App Store 版不包含这些社区题目。

题目面板新增**原站最短参考**，与通关长度限制和「我的最短解」分别显示。数据来自收录题库时[原站 Problems](http://herbert.tealang.info/problems.php) 的 Best 栏，并非实时纪录或已证明的最优解；缺失时显示「暂无记录」。例如 0027 的限制是 39 bytes，原站最短参考为 14 bytes。[查看实际面板（英文界面）](docs/screenshots/en/community-reference.png)。

点击棋盘下方图例，可在 Modern / Classic 下查看三语说明：**墙阻挡前进；陷阱允许踩入，但会熄灭全部已点亮目标**。两者都继续执行程序，踩陷阱不会回到起点。[查看棋盘说明（英文界面）](docs/screenshots/en/community-board-guide.png)。

| 0037 · Flower | 0027 · Shuriken | 0361 · Butterfly |
| --- | --- | --- |
| [![Flower 棋盘](docs/screenshots/flower-board.png)](docs/screenshots/flower.png) | [![Shuriken 棋盘](docs/screenshots/shuriken-board.png)](docs/screenshots/shuriken.png) | [![Butterfly 棋盘](docs/screenshots/butterfly-board.png)](docs/screenshots/butterfly.png) |
| nai · ≤ 20 bytes | snuke · ≤ 39 bytes | nadsuki · ≤ 27 bytes |

截图来自运行中的 App；点击棋盘查看完整界面。界面会自动匹配系统的中文、英文或日文语言偏好，其他语言回退至英文。

用最短的 H 语言程序，带 Herbert 点亮所有目标。原生 SwiftUI 游戏，共用一个与界面无关的游戏引擎，支持 **iPhone / iPad（iOS 17+）和原生 Mac（macOS 14+）**。

## 棋盘风格

| 现代风格（默认） | Classic 经典风格与轨迹 |
| --- | --- |
| [![现代穹顶镶嵌棋盘](docs/screenshots/course/course-mosaic-board.png)](docs/screenshots/course/course-mosaic.png) | [![经典穹顶镶嵌与蓝色运动轨迹](docs/screenshots/course/course-mosaic-classic-board.png)](docs/screenshots/course/course-mosaic-classic.png) |

两张均为原创 L29 的实际 App 截图，相邻墙格连接成连续轮廓。经典风格参考原站规则页中的棋盘，示例执行了三次成功移动。棋盘右上角的滑杆图标可设置风格、网格点和运动轨迹。

| L07 · 旋转玫瑰 | L08 · 双灯相映 |
| --- | --- |
| [![四向对称的折叠花瓣与连续墙](docs/screenshots/course/course-rose-board.png)](docs/screenshots/course/course-rose.png) | [![底部直桥连接的两个方形灯框](docs/screenshots/course/course-lanterns-board.png)](docs/screenshots/course/course-lanterns.png) |

## AI Battlefield · 0.3.7

比赛统一为「比赛设置」，取消模式选择。默认不限时、不限 Token，每题最多 3 次机会。
可启用统一的**每模型、每题 Token 预算**，累计该题所有尝试的输入与输出（含推理）。
达到输出上限或用尽该题预算时标记 **Burnout**，保留已收到的推理，并取消该题剩余重试；其他题目和模型继续。

- 添加多个 OpenRouter、SiliconFlow、Google Gemini 或兼容服务商，通过 `/models` 自动检测模型并选择默认参赛者。配置本地保存，API Key 留在系统钥匙串。
- 「模型设置」保留采样和高级 JSON，默认启用思考并选择服务商声明的最高推理等级；显式 JSON 可覆盖自动值。输出额度统一由比赛设置和服务商能力决定，不再单独配置每个模型的上限。
- 默认选中 30 道原创题，可自选题目与模型。各模型并行、逐题作答，使用相同的 Markdown 规则和棋盘提示；关闭限制时等待全部模型完成。
- Mac 新比赛将模型与题目并排；进度用紧凑两行展示状态、尝试次数、分数、用时和程序摘要，模型列按成绩排序，表头显示归一化百分比、参考总分、输入/输出/总 Token 与缓存率。每次尝试独立计时，进行中实时更新，完成后保存在历史中。显示名称去掉冒号前的服务商前缀和 `(free)`。
- 历史比赛在「历史」Tab 内整页展示，随 Mac 主窗口扩展；固定的返回按钮可回到历史列表。答案弹窗仍可调整大小，推理可独立折叠并按 Markdown 渲染，iPhone 使用短标题加图标导航。
- 比赛日期与标题同行，用时和总 Token 靠右置于操作按钮下方；计分与答案说明收在进度标题旁的帮助入口。手机横屏使用紧凑侧栏，Playground 优先并排显示棋盘与代码，统计置底，题目与试运行说明可从标题标签展开。
- 点击答案查看提交、判题反馈和完整推理，再到实际棋盘试运行并返回；不改个人草稿、最短解或比赛成绩。正在思考与保留的中断推理明确区分，服务商错误不标成程序 Rejected。
- 在题目页打开「题目说明」或「AI 试运行」，点击「复制 AI 提示词」，可将 Battlefield 的完整英文规则、示例和当前棋盘一次性粘贴到外部 AI 聊天窗口。
- 比赛保存在本机，可生成 PNG 分享图；手动停止取消活动请求。Token 用量说明移到进度表下方。

AI 使用自己的 API 额度，可能产生费用。流式用量会标明估算或不完整数据；本地 Token 限制无法保证服务商最终账单。
iPhone/iPad 进入后台会结束比赛并保存。详情见[配置与用量说明](docs/ai-battlefield.md)和[隐私说明](PRIVACY.md)。

## Herbert Benchmark · AI 编程评测

使用 **30 道原创题**，从移动、墙体约束，到数值/指令参数、递归、多子程序及其组合，
考察模型的程序构造能力。所有回答交给与人类游戏共用的原生 H 引擎，按真实执行结果验题。

**每次得分 = 目标覆盖率 ×（80 + 20 × 代码压缩率）**。覆盖率为最终点亮目标数 / 总目标数，
代码压缩率为 `1 − H byte 数 / 本题 byte 限制`。每次保留两位小数，每题取最佳尝试，再累加总分。
界面、历史与分享图统一显示 **总分 /（100 × 所选题数）× 100%**：8 题获得 160 分即 **20%**。
未完成题目也计入分母；百分比同时反映目标覆盖和代码效率，不等同于通过题数比例。
编译错误或超出长度限制为零分；未完成的有效运行也有部分分，陷阱会清空目标覆盖。
同样通过时，代码越短分数越高；步数不参与评分。按**总分降序 → 输入和输出 Token 总量升序 → 完成时间**排名，
缓存输入和所有重试均计入用量。0.3.0 旧历史保留原来的通过题数计分及排序方式。

比较时保持题目、机会数、比赛设置和提示词一致，并记录采样与推理参数。
统一的**每模型每题 Token 预算**覆盖所有重试；关闭两项限制时，全部模型可以完成各自作答，
使用服务商声明的最大输出能力，未知能力则由服务商决定。
历史保存完整共享提示词及其版本、棋盘、模型参数、收到的答案与计分版本，但服务商的模型版本仍可能变化。
这是参考原站最短代码排名而制定的独立综合计分策略。[完整判分说明](docs/ai-battlefield.md#judge-and-rank)。

![用户提供的六模型 Herbert Benchmark 运行截图](docs/screenshots/en/battlefield/herbert-benchmark-user-run.png)

*用户提供的英文 App 截图：六个模型、所选十题，部分回答已停止，仅演示实际运行，不代表完整的受控模型比较。截图早于 0.3.7，因此仍显示模型名称的服务商前缀。*

[当前进度界面](docs/screenshots/en/battlefield/ai-battlefield.png) · [新比赛](docs/screenshots/en/battlefield/ai-new-match.png) ·
[比赛设置](docs/screenshots/en/battlefield/ai-match-settings.png) · [模型设置](docs/screenshots/en/battlefield/ai-model-settings.png) ·
[题目选择](docs/screenshots/en/battlefield/ai-puzzles.png) · [格式化规则](docs/screenshots/en/battlefield/ai-rules.png) ·
[服务商](docs/screenshots/en/battlefield/ai-providers.png) · [模型](docs/screenshots/en/battlefield/ai-models.png) ·
[原生判题反馈](docs/screenshots/en/battlefield/ai-answer.png) · [Burnout 与保留推理](docs/screenshots/en/battlefield/ai-burnout.png) ·
[正在思考](docs/screenshots/en/battlefield/ai-thinking.png) · [服务商流错误](docs/screenshots/en/battlefield/ai-stream-error.png) · [网络中断详情](docs/screenshots/en/battlefield/ai-network-error.png) ·
[服务商错误详情](docs/screenshots/en/battlefield/ai-provider-error.png) · [棋盘试运行](docs/screenshots/en/battlefield/ai-trial.png) · [分享预览](docs/screenshots/en/battlefield/ai-share.png)

*以上链接为当前版本的确定性测试客户端截图，用于演示界面，不代表商业模型能力或真实费用。*

## 运行

需要 Xcode 16 或更新版本及 Swift 6，无第三方依赖；本机验证工具链为 Xcode 27.0。

```sh
open Herbert.xcodeproj
```

选择 `Herbert` scheme 和目标设备，点击 Run。连接 iPhone/iPad 真机时，在 Signing & Capabilities 中选择自己的 Development Team。项目没有预设签名账号。

| Scheme | 题库 | 用途 |
| --- | --- | --- |
| `Herbert`（默认） | 30 道原创题 + 1,769 道社区题 | 开源版 |
| `HerbertAppStore` | 仅 30 道原创题 | 真机检查、TestFlight、App Store 候选版 |

社区题库位于可选的 `HerbertCommunity` 模块，App Store target 不链接它；不是在界面中隐藏题目。
CI 对构建后的 iOS/Mac 包执行资源检查，拒绝社区数据或测试答案混入。
个人签名团队可写在被 Git 忽略的 `Config/Local.xcconfig` 中：`DEVELOPMENT_TEAM = YOUR_TEAM_ID`。

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
- 原版计数：每个字母 1 byte，每个数值常量 1 byte，标点与空白不计；每关按原站限制判定，步数不影响最短解记录；对照原解释器的发现与差异见 [兼容性审计](docs/hoj-compatibility.zh-CN.md)。
- 25×25 棋盘：目标、墙、陷阱，踩陷阱清空已点亮目标，撞墙或边界留在原地，点亮全部目标立即通关。
- 离线原版题库：保留编号、标题、作者、长度限制、原站最短记录快照、数据校验摘要与来源；数量和缺失项以 `docs/problem-import-manifest.json` 为准。
- 六章各五题的原创课程：独立设计的布局、连续显示编号 L01–L30，内部 ID 与存档含义分开、三语名称/学习目标/提示；参考解只在测试资源中，不进安装包。
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
Sources/HerbertCore/Resources/    原创题库与语言资源
Sources/HerbertCommunity/         可选社区题库，不进 App Store 包
Sources/HerbertBattlefield/       AI 客户端、并行比赛、验题与本地历史
Tests/HerbertCoreTests/           单元测试、原题通关与存档/备份集成测试
Tests/HerbertBattlefieldTests/    比赛引擎、预算、取消、存储及 HTTP/SSE 集成测试
HerbertUITests/                  原生界面自动化
scripts/                        可重复的题库导入、图标和工程生成、检查脚本
docs/                           数据导入清单、规则核对说明、架构与验证记录
```

`Package.swift` 提供独立的 `HerbertCore` Swift package；Xcode 工程通过本地 package 引用它。`scripts/generate_project.py` 可重建已提交的工程，不需要 XcodeGen。增加或移除应用 Swift 文件后，运行此脚本即可更新工程。图标由 `scripts/generate_icon.swift` 绘制，资源已经内置。

## 本地存档与未来 Cloudflare

数据存于应用 Application Support 下的 `Herbert/progress.json`（沙盒中的实际位置由系统决定）。格式带 `schemaVersion`，同一格式也用于备份；未接入云端、账号或分析 SDK。

游戏进度通过 `ProgressRepository` 保存；AI 配置和历史使用独立的 `BattlefieldRepository`，密钥由 Keychain 管理。未来可增加同步协调器，使用 **App → 已认证的 Cloudflare Worker → D1**。客户端不持有 Cloudflare API Token，不直接访问数据库。合并规则和数据迁移建议见 [架构说明](docs/architecture.md)。

## 原版来源与移植边界

- [原站规则](http://herbert.tealang.info/rule.php)
- [原站 Problems](http://herbert.tealang.info/problems.php)
- 原站由 quolc 创建，社区关卡归各作者所有；本项目独立编写游戏代码，没有打包或执行原站 Flash 客户端。
- 应用独立编写的代码、30 道原创题、图标和文档使用 [MIT 许可证](LICENSE)。原站未声明可再分发题库的许可证，授权范围尚未确认；社区题库及其截图布局不在本项目的 MIT 授权范围内。App Store scheme 不包含社区题库。详情见 [第三方内容说明](NOTICE.md)。
- 原站在线排名、账号、投稿与服务器评分未移植；应用展示个人最短代码记录。原站最短记录是导入时的快照，不进行在线比较。
- 按原版限制运行最多 100 万个机器人指令；为保证手机可取消执行，额外限制 100 万次解释器展开、4096 层非尾递归栈、16 KiB 源代码、64 层参数语法嵌套和 128 层运行时参数嵌套。命令参数与待执行栈使用 100 万单位的展开预算，尾递归不增长调用栈。这些保护可能比原站更早停止极端程序。

重新导入题库（会访问原站，默认最多四个并发连接，成功响应缓存，失败可重试）：

```sh
python3 scripts/import_problems.py
```

导入程序从公开列表发现全部页，排除原站 `0000 / Null` 占位项，逐一核对棋盘长度、符号、起点、目标和 byte 限制；有失败时会保存已取得的题目，并在清单列出缺失 ID，以非零状态退出。再次运行使用缓存，仅补取失败请求。原站仅提供旧 HTTP 接口，JSON 内置题库是离线资源，游戏运行不访问原站；可选 AI 功能使用 HTTPS 连接用户配置的服务商。

## 参与贡献

欢迎错误报告、翻译改进、无障碍改进和 iPhone/iPad 真机测试。请阅读
[贡献指南](CONTRIBUTING.md)、[社区行为准则](CODE_OF_CONDUCT.md) 和 [安全策略](SECURITY.md)。
CI 执行格式检查、单元/集成测试和 Mac/iOS 编译；原生界面测试需要交互式 Mac 桌面。
运行 `scripts/capture_screenshots.sh zh-Hans store` 生成原创课程截图；省略 `store` 则生成社区关卡截图。

当前尚未接入云同步或发布 App Store 版；Mac DMG 为未公证的预览版，iPhone/iPad 运行时验证仍待完成。
完整记录见 [验证说明](docs/verification.md)。
