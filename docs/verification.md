# 验证记录

日期：2026-10-07（Asia/Shanghai）。环境：Apple Silicon Mac，Xcode 27.0，Swift 6.4。未使用第三方依赖。

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
| Mac UI：快捷键与单步 | 快捷指令键插入 ssss，四次单步后通关：补验通过 |

原生 UI 全量测试的一轮运行受另一全屏应用遮挡，快捷键用例丢失两次点击而失败；其余两项通过。没有修改产品代码规避该环境问题，随后以 `-only-testing:HerbertUITests/HerbertUITests/testCommandKeysInsertAtCaretAndSingleStepCompletes` 单独重跑，用例通过。因此三个界面用例均有最终通过记录，但全量末次运行记录本身包含该环境失败。

测试产物位于 `.build/xcode/Logs/Test/`，最终补验结果为 `Test-Herbert-2026.10.07_21-19-01-+0800.xcresult`。UI 测试使用独立的测试存档，不覆盖正常用户存档。另通过原生辅助功能界面和截图检查了游戏棋盘、编辑器、语法错误提示和重置后的状态。

Xcode 的 App Intents 元数据工具输出了 “Metadata extraction skipped, no AppIntents.framework dependency found” 提示；本应用没有实现 App Intents。该提示不影响构建结果，Swift 编译及严格格式检查没有代码警告。

## 未验证范围

- 本机没有安装 iOS Simulator runtime，没有执行 iPhone/iPad 模拟器运行、触觉实测或真机触摸/横竖屏验证。iOS 构建成功不等于这些运行时验证已完成。
- Mac 的 x86_64 架构完成编译和链接，实际界面自动化在 Apple Silicon 上执行，没有 Intel 真机运行测试。
- 未配置 Apple Developer Team、TestFlight、App Store 发布、Developer ID 分发签名或 notarization。Mac ZIP 是本地 ad-hoc 签名构建；iOS 请打开 Xcode 工程选择自己的签名团队后在真机运行。
- 未连接 Cloudflare，不包含在线排名/账号。公开分发原站题库前应确认再分发授权。

本地交付文件：`outputs/Herbert-macOS.zip`；构建源工程：`Herbert.xcodeproj`。
