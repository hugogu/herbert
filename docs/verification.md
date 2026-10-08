# 验证记录

日期：2026-10-07–08（Asia/Shanghai）。环境：Apple Silicon Mac，Xcode 27.0，Swift 6.4。未使用第三方依赖。

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
