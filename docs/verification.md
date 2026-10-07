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
| Mac UI：快捷键与单步 | 快捷指令键插入 ssss，四次单步后通关：通过 |

开源发布前重新执行完整原生 UI 测试：三个功能用例全部通过，截图用例按设计跳过；零失败。另以 `HERBERT_CAPTURE_SCREENSHOTS=1` 单独运行截图用例，通过并导出 7 张实际界面/棋盘 PNG。早先因另一全屏应用遮挡导致的点击失败已由本次完整通过记录取代。

本轮结果：`.build/opensource-ui-tests.xcresult`（完整 UI 测试）和 `.build/readme-screenshots.xcresult`（截图）；截图已人工检查，来源与重现方法见 [截图说明](screenshots/README.md)。UI 测试使用独立存档，不覆盖正常用户存档。`scripts/check.sh` 再次通过 18 项 Swift 单元/集成测试、3 项 Python 导入器测试和严格格式检查；版本调整为 0.1.0 后再次完成 iOS 无签名编译。

Xcode 的 App Intents 元数据工具输出了 “Metadata extraction skipped, no AppIntents.framework dependency found” 提示；本应用没有实现 App Intents。该提示不影响构建结果，Swift 编译及严格格式检查没有代码警告。

## 未验证范围

- 本机没有安装 iOS Simulator runtime，没有执行 iPhone/iPad 模拟器运行、触觉实测或真机触摸/横竖屏验证。iOS 构建成功不等于这些运行时验证已完成。
- Mac 的 x86_64 架构完成编译和链接，实际界面自动化在 Apple Silicon 上执行，没有 Intel 真机运行测试。
- 未配置 Apple Developer Team、TestFlight、App Store 发布、Developer ID 分发签名或 notarization。Mac ZIP 是本地 ad-hoc 签名构建；iOS 请打开 Xcode 工程选择自己的签名团队后在真机运行。
- 未连接 Cloudflare，不包含在线排名/账号。原站题库再分发授权尚未确认，不适用本项目 MIT 许可；见 [NOTICE.md](../NOTICE.md)。

本地交付文件：`outputs/Herbert-macOS.zip`；构建源工程：`Herbert.xcodeproj`。

## 开源仓库验证

GitHub [CI 运行 37634662467](https://github.com/hugogu/herbert/actions/runs/37634662467) 在提交 `41c089d` 上通过全部步骤：严格格式检查、Python/Swift 测试、生成工程一致性检查、Mac Release 和 iPhone/iPad 无签名构建。在线 README 已检查实际图片载入与三列关卡画廊。审阅中发现 Flower 棋盘局部截图受到其他窗口遮挡，因此截图测试在每次捕获前显式激活 App，并重新生成及检查图片。MIT 徽章改为仓库内 SVG，避免外部图片服务载入失败。
