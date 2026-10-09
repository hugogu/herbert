# 验证记录

日期：2026-10-07–09（Asia/Shanghai）。环境：Apple Silicon Mac，Xcode 27.0，Swift 6.4。未使用第三方依赖。

## 0.3.7：统一设置与 Burnout（10 月 9 日）

- `scripts/check.sh`：104 项 Swift 测试（43 项 Core、61 项 Battlefield）、15 项 Python 检查及严格格式检查通过；最终清理未修改变量警告后再次通过。新增可选时限、每模型每题累计输入/输出预算、跨题/跨模型隔离、输出截断无重试、流式超限取消子请求、晚到回调忽略、无上限请求省略 cap、推理默认参数及显式覆盖、旧配置解码/升级和磁盘持久化检查。
- `.build/battlefield037-ui.xcresult` 中 9 项 Battlefield 用例通过，两项设置检查因通用 identifier 取到无 value 的外层容器而失败。改用原生 checkbox/switch 后，`.build/battlefield037-settings-ui.xcresult` 两项均通过，覆盖默认限制关闭、组合限制、移除模型输出 cap、自动推理开关保存与重启。
- `.build/battlefield037-final-ui.xcresult` 最终 Burnout/设置复核两项通过，确认输出上限后无 Attempt 2、无 Rejected、推理可展开。`.build/battlefield037-store-ui.xcresult` 同两项在原创版通过。全新构建目录的 `.build/battlefield037-final-settings-capture.xcresult` 额外确认 Model Settings 英文标题，导出最终英文设置图。
- 社区版和原创版 Mac/iOS Release 构建通过；两份原创版实际 `.app` 均通过资源审计：30 道原创题，无社区目录或参考答案。工程、课程与三语资源重复生成一致；个人未提交的 scheme 修改保持原样。
- 本地 0.3.7（10）Mac DMG 通过签名、沙盒/出站网络权限、arm64/x86_64、最低 macOS 版本、30 原创 + 1,769 社区目录、无参考答案及只读挂载检查。GitHub tag 发布从源码独立构建。
- 中英文 README 增加用户提供的六模型截图：十题选择且含 Stopped，仅作为运行示例，不据此宣称完整受控排名。其他 Battlefield 截图来自实际英文 App 的确定性测试客户端；旧 64K 编辑器/拒绝推理图已移除，改为统一设置和 Burnout 界面。
- 没有调用付费服务商，没有 iOS Simulator runtime；真实服务商参数接受程度、iPhone/iPad 运行时、Apple 签名与公证仍需开发者检查。

## 0.3.3：输出预算、比赛复盘与连续课程（10 月 9 日）

- `scripts/check.sh`：86 项 Swift 测试（43 项 Core、43 项 Battlefield）、15 项 Python 检查及严格格式检查通过。新增 65,536 默认上限、实际请求与服务商较低上限、旧配置升级、显式自定义值和历史参数不变，以及 Best Effort 中较慢 AI 在首个 AI 成功或耗尽尝试后继续作答并取得更高分的回归。
- 设置 schema 1 升级为 2：旧预设中恰好为 4,096 的上限迁移至 65,536，其他自定义值保留；schema 2 中主动保存的 4,096 不再升级。历史比赛的输出预算不变。新比赛的模型参数按钮与服务商配置共用同一持久化编辑器；实际请求仍受服务商声明上限与剩余比赛预算约束。
- 原创课程改为连续 L01–L30。原 L25/L26 重新设计为当前 L07「旋转玫瑰」和 L08「双灯相映」，以连续墙围出四重旋转花瓣和双框连桥；新的内部 ID 防止旧棋盘的通关记录误标新题完成。全部 30 个参考程序通过原生引擎和固定 HOJ 参考引擎，另验证 17 个语言/byte 案例、8 个社区研究题及撞墙后继续执行。独立几何预期、对称性、预算与后八道入门题必须使用过程的检查均通过。
- 课程、测试答案、三语资源与文档重复生成完全一致。统一提示词仅更新课程末题的描述，两个教学棋盘与参考程序不变，版本记录为 `herbert-h-v4`。历史快照继续保留当时的编号、规则和棋盘。
- 默认版 Mac 完整 UI 回归中 17 项通过，嵌套推理控件的点击检查首次失败；改为整行按钮后，独立复跑通过，验证 Markdown 标题、展开/折叠、最终回答仍可见及 HTTP 错误正文。其余检查涵盖三模型历史可见、历史与答案弹窗宽高拖动、64K 修改/重启保存/恢复、Best Effort、分享、试运行返回、三语、轨迹/网格及新 L07/L08 实际运行通关。
- `.build/battlefield-033-store-full.xcresult`：原创版完整 Mac UI 套件通过，18 项通过、社区画廊 1 项按设计跳过；包含两个弹窗宽高调整、推理 Markdown、全部 Battlefield 流程、三语、轨迹/网格、连续墙、新 L07/L08 与进阶题运行，以及英文原创画廊。
- `.build/battlefield-033-final-gallery.xcresult`：三项最终截图检查通过；输出参数标签重复显示已修正，64K 编辑器与默认三模型历史重新导出，中文原创画廊导出 15 张。中文社区画廊最初因恢复窗口后立即选择显示器，触发 XCTest 次屏截图失败；补充等待窗口和菜单目标后，`.build/battlefield-033-chinese-community-retry.xcresult` 通过并导出 9 张。中英文原创各 15 张、社区各 9 张及英文 Battlefield 12 张，共 60 张当前文档原生 PNG 已检查语言、编号、棋盘、布局及遮挡，未修改图片；英文 README 的截图路径全部指向 `en/`，两份 README 本地链接均有效。
- 两个 scheme 的 Mac 和无签名 iOS Release 构建全部通过；新增代码无编译警告，仅有 Xcode 的无 AppIntents 依赖元数据提示。两个实际原创版 `.app` 资源审计均通过：30 道原创题，不含社区包或参考答案。工程重复生成一致，原先本地 scheme 修改逐字节保留。
- `outputs/v0.3.3-verified/Herbert-macOS-universal.dmg` 已压缩、校验并只读挂载验证：0.3.3（6）、arm64/x86_64、macOS 14+、完整 ad-hoc 签名、沙盒与出站网络权限、30 + 1,769 题且无测试答案。GitHub 发布由 tag 对应源码重新构建并验证。
- 没有调用真实付费模型，没有 iPhone/iPad 运行时测试、TestFlight/App Store 上传或 Apple 公证。HTTP 400 和模型成绩均来自隔离的确定性测试客户端。

## 0.3.2：回答诊断、提示词与课程精简（10 月 8 日）

- `scripts/check.sh`：83 项 Swift 测试（42 项 Core、41 项 Battlefield）、15 项 Python 检查和严格格式检查通过。新增 SSE/JSON 推理保留、推理字段重放、空回答重试、HTTP 400 脱敏诊断、64 KiB 错误读取边界、失败流部分文本刷新、完整推理的磁盘保存/读取、旧历史解码与推理输入 Token 估算检查。
- 提示词升级 `herbert-h-v3`，明确坐标、墙/边界、数值调用终止、指令参数与递归返回后的工作。两个独立教学棋盘的完整答案通过真实原生判题器：撞墙示例 7 bytes；递归风车 42 bytes、92 个目标。示例不是计分题，未把 L50 或其他基准题的参考答案放进提示词。
- L01–L30 精选十题：L01、L06、L12、L17、L22、L24、L25、L26、L27、L30；保留 L31–L50。原生测试证明后八道入门题逐步指令的长度下界超过预算，只有前两道可以不使用过程。所有选中棋盘、ID、名称、预算、参考程序与独立几何预期均与 0.3.1 一致；这些参考程序此前已经过 HOJ 参考引擎验证。
- 退役的二十个 ID 不复用；本地记录和历史题目快照保留。备份导入允许这些不可游玩的历史记录，同时继续拒绝未知 ID 并重放验证仍在课程中的通关答案。默认版共 1,799 题；原创版与默认 Benchmark 均为 30 题。
- `.build/battlefield-032-community-ui.xcresult`：15 项默认版 Mac UI 用例通过，覆盖全部 Battlefield 流程及原有游戏、三语、连续墙、轨迹/网格、草稿、提示和进阶题。三题确定性演示 L01/L06/L12 得到 240 / 86.53 分；截图不是商业模型成绩。
- `.build/battlefield-032-store-ui.xcresult`：原创版完整 Mac UI 套件通过，16 项通过、社区画廊 1 项按设计跳过；包含实时推理/错误详情、课程与英文截图流程。
- 两个 scheme 的 Mac 与无签名 iOS Release 构建通过；已消除新增的 Swift 编译警告，剩余 AppIntents 提示来自 Xcode 的无依赖元数据处理。两个实际原创版 `.app` 均通过资源审计：30 道原创题，无社区资源或计分题参考答案。Mac DMG 挂载校验确认 0.3.2 (5)、arm64/x86_64、沙盒与出站网络权限、30 + 1,769 题。
- 工程、课程、参考资源、三语与课程文档重复生成一致；保留本地原有 scheme 修改。社区资源 SHA-256 仍为 `c16b984bfefe35588139682ec2a41783f74b2f212fb6a2d43d45b96b88651d64`。
- 英文与中文原创课程各导出 11 张原生截图，社区画廊各 9 张；英文 Battlefield 导出 10 张，包括推理与错误正文。视觉复查以 L25「伸展的罗盘」替换重复阶梯布局的 L16 后，重跑全部单元/集成检查、四份 Release 构建和两种语言的原创截图流程；保留两题不需要过程的入门题，其余八题均需要复用或递归。README 的英文图片路径全部指向 `en/`，本地链接检查通过。
- 没有发起付费 AI 请求。旧版丢弃了 HTTP 错误正文，无法确认用户那次 Kimi 400 的确切原因；已修复丢失推理字段及空 assistant 重试两个请求缺陷，新运行会保留服务商的脱敏诊断。截图中的 400 正文来自确定性测试。没有 iOS Simulator runtime，真机运行与 Apple 签名/公证仍需开发者完成。

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
