# 验证记录

日期：2026-10-07–08（Asia/Shanghai）。环境：Apple Silicon Mac，Xcode 27.0，Swift 6.4。未使用第三方依赖。

## Herbert Benchmark · 0.3.1（10 月 8 日）

- AI 配置合入 Battlefield 标题栏，主导航保留四个 Tab；Mac 新比赛的参赛模型与题目并排。逐题进度同时承担排名，使用无宽度上限的模型列、两行答案、尝试次数在分数前、表头用量与右上角错误提示；共享规则按 Markdown 显示。
- 新增版本化目标覆盖/代码长度计分，每题取最佳已判定尝试；同分依次比较所有输入和输出 Token、完成时间。旧历史保留旧计分。Best Effort 首个模型完成整套题目即终止全场，取消其他请求并保留已判定结果。试运行使用题目快照与提交答案，返回当前/历史比赛，不写个人游戏进度。
- `scripts/check.sh`：69 项 Swift 测试（40 项引擎/存档、29 项 Battlefield 单元与 HTTP 集成）、15 项 Python 检查及严格格式检查通过。新增部分分、短程序、陷阱清空、最佳尝试、缓存及重试 Token 排名、浮点持久化、旧历史迁移、失败反馈和 Best Effort 成功/耗尽机会后的取消检查。没有调用付费模型。
- `.build/battlefield-031-captures.xcresult`：6 项默认版 Battlefield 原生 Mac UI 用例通过，覆盖服务商、参数持久化、紧凑新比赛、Markdown、并行重试、原生计分、当前/历史答案试运行与返回、PNG 分享、用户终止。首次布局检查发现 Mac 未使用并排布局，改用实际可用宽度判断后通过。
- `.build/battlefield-031-store-ui.xcresult`：原创版完整 Mac UI 回归通过，13 项功能用例通过、3 项截图用例按设计跳过；同时覆盖原有游戏、连续墙、三语、轨迹/网格、草稿和进阶课程。
- `.build/battlefield-031-readme-final.xcresult`：4 项英文截图流程通过。三题确定性客户端基准得到 240 / 103.75 分，并检查模型排序和答案行高度不超过 64 点。截图仅演示功能，不代表商业模型成绩。检查试运行截图后精简了该页面的课程讲解；`.build/battlefield-031-trial-final.xcresult` 独立复跑通过，确认默认 Mac 窗口的运行按钮可直接点击，并重新导出试运行截图。
- 原创版与社区版中英文画廊流程均通过，共导出 40 张实际 App 窗口/棋盘 PNG；另选 8 张英文 AI 窗口 PNG，逐张检查语言、数量、棋盘和遮挡。图片未经修改；英文 README 全部使用英文 UI。
- 社区版与原创版的 iOS/Mac Release 构建全部通过，Mac 预览为 arm64/x86_64。原创版两份实际 `.app` 均通过资源隔离审计：恰好 50 题，无社区目录、社区 bundle 或参考答案。课程、资源及工程重复生成一致；保留本地原有 scheme 修改。
- 本地 0.3.1（4）通用 Mac DMG 已压缩、校验并只读挂载审计，检查签名、沙盒、出站网络权限、双架构、1,819 题和无测试答案。GitHub 发布另由 tag 对应的 CI 从源代码重新构建、审计并发布。
- 没有真实服务商 API 请求、iPhone/iPad 运行时验证、TestFlight/App Store 上传或 Apple 公证；Mac 预览采用 ad-hoc 签名。真机检查见 [App Store 清单](app-store.md)。

## AI Battlefield · 0.3.0（10 月 8 日）

- 新增独立 `HerbertBattlefield` 模块与两个导航 Tab；配置和完整比赛快照本地保存，运行时密钥不参与 Codable，App 使用钥匙串。两个发行版都链接 AI 模块，社区模块的打包边界保留。
- `scripts/check.sh`：40 项原有 Swift 测试、22 项 Battlefield 单元/HTTP 集成测试、15 项 Python 检查及严格格式检查全部通过。覆盖相同提示词、并行、失败反馈、重试、原生 byte/陷阱规则、限时、共享/独立 Token 预算、取消、用量核对、缓存缺失、原子存储与损坏/超限数据保护。
- HTTP 测试使用 URLProtocol 的实际字节流：模型鉴权与 SiliconFlow 查询参数、SSE 空行/CRLF/CR/Unicode/分行数据、JSON 回退、输出参数、401/429/重定向，以及收到响应头后的底层请求取消。没有调用付费服务商。
- `.build/battlefield-community-regression.xcresult`：默认版完整 Mac UI 回归通过，12 项功能用例通过、2 项截图用例按设计跳过。新增服务商添加/自动发现/移除、参数重启持久化、双模型答错后重试/各得 100 分、历史恢复、PNG 生成和手动终止；原有游戏用例全部通过。
- `.build/battlefield-store-regression.xcresult`：原创版完整 Mac UI 回归也通过，12 项功能用例通过、2 项截图用例跳过，确认原生 50 题筛选和新增 AI 功能在该 target 可用。
- `.build/battlefield-readme-final.xcresult`：最终英文截图流程通过，导出 5 张未修改的实际 App 窗口截图，逐张检查语言、数量、原生反馈与分享预览。全部使用隔离的确定性客户端和内存密钥，不代表商业模型成绩。界面测试发现并修复了重复格式化导致数字显示为 0 的问题，新增静态回归检查及真实 UI 数量断言。
- 两个 scheme 的 Mac/iOS Release 构建通过；Mac 预览包含 arm64/x86_64。原创版两个实际 `.app` 均通过资源检查：50 题、无社区目录、社区 bundle 或参考答案。工程及课程重复生成一致。
- `outputs/v0.3.0-final/Herbert-macOS-universal.dmg` 已压缩、校验并只读挂载，重新检查实际包的 0.3.0（3）元数据、双架构、完整签名、沙盒、AI 出站网络权限、1,819 题和无测试答案。预览仍为 ad-hoc 签名。
- 初始原生 UI 自动化因桌面锁定未进入用例，恢复交互桌面后验证通过。截图使用可选显示器选择，不将设备显示器名称写入项目。
- 未进行真实 OpenRouter/SiliconFlow 请求或 iPhone/iPad 运行时验证。没有 TestFlight/App Store 上传、Developer ID 签名或公证；真机 API/钥匙串/后台/分享检查见 [App Store 说明](app-store.md)。

## 20 道进阶题与 README 选图（10 月 8 日）

- 新增 L31–L50，原创题共 50 道、十章。原先 30 道棋盘、编号、预算和参考解保持不变；社区 JSON 的 SHA-256 仍为 `c16b984bfefe35588139682ec2a41783f74b2f212fb6a2d43d45b96b88651d64`。
- 研究社区 #0001–#0020 的完整棋盘、安全连通性与候选程序；8 题找到原预算内的解，12 题未找到。分析中区分空间观察、验证解、原记录最佳和未证明的最优性，见 [进阶设计](advanced-course-design.zh-CN.md)。没有复制社区棋盘作为原创题。
- 50 个参考解均通过真实 Swift 引擎的完成、byte、位置、朝向、步数、撞墙和陷阱次数检查；预期来自独立几何路线。L31/L32 去墙后同一程序不能通关。L37/L44 的已知简单循环进入未完成的重复状态，修订后不能解题；候选搜索不证明最优性或唯一解法。
- `scripts/check.sh`：40 项 Swift 单元/集成测试、8 项 Python 测试及严格格式检查全部通过。
- `ruby scripts/check_hoj_reference.rb` 对固定 HOJ 提交重放：17 组语言/byte 用例、50 道原创题、8 个社区试解及 #0001 撞墙继续执行用例全部通过。
- 课程和工程生成器对 10 份产物重复生成一致。英文 README 的全部截图引用均指向 `en/`，两份 README 的图片和图片链接均存在。
- 两个 scheme 的 iOS / Mac Release 构建全部通过；原创版两份实际 `.app` 均通过资源隔离审计，恰好 50 题，不含社区目录、社区 bundle 或测试参考答案。
- `.build/advanced-store-functional.xcresult`：原创版完整 Mac UI 自动化通过，8 项功能用例通过、2 项截图用例按设计跳过。新增在实际 UI 输入 L31 与 L50 的参考程序、以极速完成并开启轨迹；同时覆盖连续墙像素、三语、提示、草稿、设置及重置。
- `.build/advanced-community-final.xcresult`：开源版完整 Mac UI 自动化同样通过，8 项功能用例通过、2 项截图用例跳过；确认 1,819 / 50 / 1,769 的目录筛选。首次运行在输入 L50 长程序时遇到 XCTest 键盘事件合成超时；诊断采样中 App 主线程处于事件等待，未见计算阻塞。未修改代码，隔离复跑完整套件后通过。
- 中英文原创版截图流程均通过，各导出 11 张实际 Mac 窗口/棋盘截图，共 22 张，已逐张检查语言、棋盘与遮挡。主图 L49，画廊 L38/L44/L50，Classic 与 Modern 使用同一 L49。
- 初始截图测试在启用自动化模式时超时，未进入用例；正常 Xcode 测试入口重新启动协调进程后恢复。一次 GUI 与 CLI 测试并发造成输入干扰；停止 GUI 测试、串行执行后截图和上述完整回归通过。未修改系统安全设置或绕过认证。
- 没有进行 iPhone/iPad 运行时验证或 TestFlight/App Store 上传；新增真机检查见 [App Store 清单](app-store.md)。

## HOJ 兼容性与连续墙体（10 月 8 日）

- 对照 `quolc/hoj` 固定提交 `f5d1ee4e3616c1b2cf79e70a0ccee267b5f09ea3` 和实时取得的原站规则页；没有复制参考源码或素材。该仓库仅含解释器与示例判题片段，不包含完整排行榜或 Flash 客户端。
- 修正 `x` / `*` 解码反转：墙 / 陷阱含义与参考判题器一致。社区 JSON SHA-256 仍为 `c16b984bfefe35588139682ec2a41783f74b2f212fb6a2d43d45b96b88651d64`，逐字节未变；原创课程同步修正符号而保留布局与解题路径。
- 17 组独立差分用例的指令序列及 byte 数在 Swift 与 Ruby 两端一致；30 道原创题的参考解全部通过参考 Ruby 判题器，也通过真实 Swift 引擎的长度、陷阱与完成验证。
- `scripts/check.sh`：37 项 Swift 测试、8 项 Python 测试和严格格式检查全部通过。墙轮廓测试覆盖全部 512 种 3×3 排列、边界、拐角、洞和对角分离。
- `.build/hoj-store-functional.xcresult`：原创版完整 Mac UI 自动化通过，7 项功能用例通过、2 项截图用例按设计跳过。新增从实际棋盘截图采样的检查，Modern 和 Classic 在墙格接缝处与格内颜色一致。
- `.build/hoj-community-final.xcresult`：开源版完整 Mac UI 自动化同样通过，7 项功能用例通过、2 项截图用例跳过；目录筛选为 1,799 / 30 / 1,769，包含接缝像素、语言、课程、草稿与设置持久化检查。
- 开源与原创两种 scheme 的 iOS / Mac Release 构建全部通过；原创版两份实际 `.app` 通过资源隔离检查，仍为 30 题且无社区资源和参考答案。
- 两种版本的中英文截图流程全部通过，共导出 36 张实际原生 Mac 截图；逐一检查修改后的完整窗口、棋盘局部、语言与遮挡情况。英文 README 的图片全部指向 `docs/screenshots/en/`。
- 一次 Mac 测试进程在启用自动化模式时超时，未进入用例；重新启动测试后上述完整测试通过。首次像素检查采样到 Modern 墙下的淡网格点，改为在格内无网格点处取参照色后通过，没有放宽接缝颜色阈值。
- 规则差异与旧存档说明见 [兼容性审计](hoj-compatibility.zh-CN.md)。没有进行 iOS 运行时验证、TestFlight 上传或 App Store 发布。

## 原创课程与发行版本（10 月 8 日）

- 30 道独立设计的原创关卡，六章各五题，稳定 ID 10001–10030；名称、学习目标与两级提示支持中英日。
- `scripts/check.sh`：26 项 Swift 单元/集成测试、8 项 Python 检查和严格格式检查通过。全部 30 个参考程序均由真实 H 编译器/引擎重放，在 byte 限制内完成；检查陷阱次数、无阻挡参考路径、三语文案、存档身份及题库 ID 不冲突。
- 社区 JSON 移入可选 `HerbertCommunity` 模块，与移动前逐字节相同；默认开源版为 1,799 题，原创版为 30 题。
- `HerbertAppStore` 的 iOS / Mac Release 构建通过；两份实际 `.app` 均通过资源审计：仅 30 道原创题，不含社区 bundle、社区 JSON 或测试参考答案。
- 默认 `Herbert` 的 iOS / Mac 构建通过；工程与课程生成器对 10 份产物的重复生成结果一致。
- `.build/curriculum-store-functional.xcresult`：原创版完整 Mac UI 测试通过，六项功能用例通过、两个截图用例按设计跳过。覆盖课程目标/提示逐条展开、L01 通关及下一关提示重置、草稿恢复、错误重置、三语与棋盘偏好/轨迹。
- `.build/curriculum-community-functional.xcresult`：开源版同样六项功能用例全部通过、两个截图用例跳过；额外验证 1,799 / 30 / 1,769 的目录筛选。
- `scripts/capture_screenshots.sh en store` 和 `zh-Hans store` 均通过：共 14 张实际原创版 Mac 截图，已检查语言、完整棋盘、运行栏及无其他窗口遮挡；英文 README 仅使用英文界面。
- 个人签名配置保留在被忽略的 `Config/Local.xcconfig`；共享工程不包含个人 Team ID。
- 本轮仍未进行 iPhone/iPad 运行时验证；[真机清单](app-store.md)供设备持有人执行。没有上传 TestFlight 或 App Store。

## 英文 README 截图更新（10 月 8 日）

- 截图流程显式设置并断言界面语言；默认英文，传入 `zh-Hans` 可生成中文截图。
- `scripts/capture_screenshots.sh en` 通过，导出 9 张实际 App 截图，已逐张检查英文文案、棋盘与轨迹显示。
- 英文 README 的图片及完整界面链接均指向独立的 `docs/screenshots/en/`；中文 README 保留中文截图。
- README 的全部截图引用均已检查文件存在；`scripts/check.sh` 的 23 项 Swift、5 项 Python 检查及严格格式检查再次通过。
- `.build/english-readme-ui.xcresult`：完整 6 项原生 Mac UI 测试全部通过，包含英文截图流程。
- SwiftPM 语言资源目录大小写兼容修复已通过 GitHub CI（`07fbdcd`），包括测试、项目生成一致性及 Mac/iOS 编译。

## 本轮多语言与棋盘更新

- `scripts/check.sh`：23 项 Swift 单元/集成测试、5 项 Python 导入器/翻译检查和严格格式检查全部通过。
- 中英日自动匹配，英文回退、错误参数格式、翻译键完整性均已覆盖。
- `.build/feature-complete.xcresult`：6 项原生 Mac UI 用例全部通过，覆盖英文/日文界面与解释器错误、中文解题流程、轨迹隐藏后继续记录、Classic/网格点切换与重启后的偏好恢复。截图用例在本次明确启用。
- 轨迹测试覆盖转向、墙/边界阻挡、陷阱、暂停、新运行清空、批量执行，以及重复 60,000 条指令仅保存一条重复边的内存边界。
- iPhone/iPad 最终无签名编译通过；Mac Release 构建通过，二进制包含 arm64 和 x86_64。
- README 更新 9 张实际 Mac App 截图，包括 Classic 与蓝色轨迹；截图用例使用合法的 H 过程声明顺序，等待设置弹层消失后捕获。
- UI 测试同时隔离进度文件与偏好设置，避免改写正常用户配置。仍未安装 iOS Simulator runtime，本轮没有 iPhone/iPad 运行时验证。

以下为 0.1.0 首次发布时的历史验证记录。

| 项目 | 实际结果 |
| --- | --- |
| 公开题库导入 | 21 页，1769 个可玩关卡，1769 个唯一 ID，范围 1–2077，缺失/错误为零；排除 0 / Null |
| 引擎与存档测试 | `swift test --scratch-path .build/swiftpm`：18 项全部通过 |
| 导入器测试 | `python3 -m unittest discover -s scripts -p 'test_*.py'`：3 项全部通过 |
| 格式检查 | `xcrun swift-format lint --strict -r Herbert Sources Tests HerbertUITests scripts/generate_icon.swift Package.swift`：通过，无 lint 诊断 |
| iOS Debug 构建 | `generic/platform=iOS`，关闭签名：通过；目标 iPhone+iPad，最低 iOS 17 |
| Mac Debug 构建 | arm64 原生构建：通过 |
| Mac Release 构建 | 标准 Mac 架构构建：通过；二进制包括 arm64 / x86_64 |
| Mac UI：运行与重启 | 输入 ssss，原题 0001 通关，重启后草稿恢复：通过 |
| Mac UI：错误与重置 | 未定义过程在页面内提示，重置后恢复待运行状态：通过 |
| Mac UI：快捷键与单步 | 快捷指令键插入 ssss，四次单步后通关：通过 |

开源发布前重新执行完整原生 UI 测试：三个功能用例全部通过，截图用例按设计跳过；零失败。另以 `HERBERT_CAPTURE_SCREENSHOTS=1` 单独运行截图用例，通过并导出 7 张实际界面/棋盘 PNG。早先因另一全屏应用遮挡导致的点击失败已由本次完整通过记录取代。

本轮结果：`.build/opensource-ui-tests.xcresult`（完整 UI 测试）和 `.build/readme-screenshots.xcresult`（截图）；截图已人工检查，来源与重现方法见 [截图说明](screenshots/README.md)。UI 测试使用独立存档，不覆盖正常用户存档。`scripts/check.sh` 再次通过 18 项 Swift 单元/集成测试、3 项 Python 导入器测试和严格格式检查；版本调整为 0.1.0 后再次完成 iOS 无签名编译。

Xcode 的 App Intents 元数据工具输出了 “Metadata extraction skipped, no AppIntents.framework dependency found” 提示；本应用没有实现 App Intents。该提示不影响构建结果，Swift 编译及严格格式检查没有代码警告。

## 未验证范围

- 本机没有安装 iOS Simulator runtime，没有执行 iPhone/iPad 模拟器运行、触觉实测或真机触摸/横竖屏验证。iOS 构建成功不等于这些运行时验证已完成。
- Mac 的 x86_64 架构完成编译和链接，实际界面自动化在 Apple Silicon 上执行，没有 Intel 真机运行测试。
- 仓库不预设 Apple Developer Team；未进行 TestFlight、App Store 发布、Developer ID 分发签名或 notarization。Mac ZIP 是本地 ad-hoc 签名构建；iOS 请打开 Xcode 工程选择自己的签名团队后在真机运行。
- 未连接 Cloudflare，不包含在线排名/账号。原站题库再分发授权尚未确认，不适用本项目 MIT 许可；见 [NOTICE.md](../NOTICE.md)。

本地交付文件：`outputs/Herbert-macOS.zip`；构建源工程：`Herbert.xcodeproj`。

## 开源仓库验证

GitHub [CI 运行 37634662467](https://github.com/hugogu/herbert/actions/runs/37634662467) 在提交 `41c089d` 上通过全部步骤：严格格式检查、Python/Swift 测试、生成工程一致性检查、Mac Release 和 iPhone/iPad 无签名构建。在线 README 已检查实际图片载入与三列关卡画廊。审阅中发现 Flower 棋盘局部截图受到其他窗口遮挡，因此截图测试在每次捕获前显式激活 App，并重新生成及检查图片。MIT 徽章改为仓库内 SVG，避免外部图片服务载入失败。
