# 原创题库版本与真机测试

## 选择正确版本

- `Herbert`：默认开源版，先显示原创 L01–L50，再显示社区题；总数 1,799。
- `HerbertAppStore`：iPhone/iPad/native Mac 共用的原创版 target；只有精选的十道入门题与 L31–L50，总数 30。

社区资源在 `Sources/HerbertCommunity/`，App Store target 链接 `HerbertCore` 与不含社区资源的 `HerbertBattlefield`。
`APP_STORE` 编译条件还会移除社区筛选和原站 Problems 链接。参考解位于测试 target，两个应用均不打包答案。
原创关卡、名称、目标与提示使用 MIT；社区题库保留独立 NOTICE。

## 在 iPhone / iPad 上安装

1. 打开 `Herbert.xcodeproj`，选择 **HerbertAppStore** scheme。
2. 连接设备并选择运行目标。启用系统要求的开发者模式和信任设置。
3. 给 app 和 UI test target 选择自己的签名团队。推荐在被 Git 忽略的 `Config/Local.xcconfig` 中写 `DEVELOPMENT_TEAM = YOUR_TEAM_ID`；生成工程时不会覆盖此文件。不要提交个人签名配置、证书或密钥。
4. Run 安装。新安装时应显示 **30 PROBLEMS**，继续卡片为 L01。

两种 scheme 沿用同一个 Bundle ID；同一设备上互相安装会替换应用，不会同时存在。
先导出已有进度备份。已有社区记录会留在本地文件中，但原创版不显示、不计数、不导出这些记录。
原创版导出的备份可以导入两种版本；包含社区题号的完整开源版备份只能导入开源版。

## 真机检查清单

请分别记录 iPhone 和 iPad 的型号、系统版本、应用版本/build、Git commit 和界面语言。

- [ ] 总数为 30，搜索 `0037` 无社区结果；搜索 `L50` 或 `10050` 可找到星穹圣殿。
- [ ] L01：输入 `s` 并运行，应通关；下一关进入 L06，提示重新收起。
- [ ] L06：输入 `rsslsslss`，避开三格连续墙后通关。L12：输入 `a:ssssr` 换行 `aaaa`，检查过程复用。
- [ ] L06：输入 `s` 单步，墙阻挡前进但程序不报错；重置后用 `rsslsslss` 通关。
- [ ] L08：输入 `ssss` 单步四次，第四步踩陷阱，之前点亮的目标清零；重置后用 `ssrsslsssslss` 通关。
- [ ] L09：用 `ssssrssssrssrssss` 运行，踩陷阱后通过重新点亮目标完成。
- [ ] L19、L29、L30：从测试用 [参考解](../Tests/HerbertCoreTests/Fixtures/original-solutions.json) 复制程序，普通速度与极速均能通关，轨迹无断段。
- [ ] L31、L32：参考解故意多走到墙边，机器人停留后继续运行并通关。
- [ ] L44：输入 `sss`，第三次前进踩到陷阱、目标清零；参考解不踩陷阱且可通关。
- [ ] L38、L43、L49、L50：参考解在普通/极速下均通关；较长的多参数、嵌套程序可以编辑、粘贴和暂停。
- [ ] 两条提示逐条展开；最短解、提示不覆盖编辑区或底部运行栏。
- [ ] 运行中切后台会暂停；重新进入可以继续。编辑或重置会清空轨迹。
- [ ] 草稿、收藏、已完成、棋盘风格/网格点/轨迹偏好在退出重启后保留。
- [ ] 导出 JSON 到 Files，再导入；最短解会验证，非法 JSON/无效解提示错误且不覆盖现有记录。
- [ ] Modern / Classic、网格点、轨迹开关、双指缩放和拖动都可用。
- [ ] iPhone 竖屏/横屏、键盘打开/关闭时能编辑并运行，按钮不被遮挡；中文/日文输入法也能操作 H 代码。
- [ ] iPad 全屏、分屏及可用的窗口尺寸下布局正常；外接键盘可编辑、复制粘贴与运行。
- [ ] 分别切换设备或应用的英语、简体中文、日语：课程名称、目标、提示、错误信息匹配语言。
- [ ] 开启 VoiceOver、大字体和减少动态效果检查关键操作；记录任何无法操作或裁切的位置。

## 构建和资源核验

0.3.0 新增可选 AI 请求，提交前应更新公开隐私政策和 App Store Connect 隐私问卷，说明用户自选服务商、发送数据与密钥用途；不要沿用“App 没有网络请求”的旧描述。应用内 AI 配置页可打开隐私说明，比赛前展示发送范围和费用，用户点击“同意并开始比赛”才发送题目与对话。Apple [5.1.2(i)](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing) 要求明确披露第三方 AI 数据共享并取得许可；当前实现及文档不能代替提交时的隐私评估与审核。

隐私清单声明了 UserDefaults 用于本应用偏好的 CA92.1 原因，参见 [Apple TN3183](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)。清单中的 SDK 数据收集声明不等于 App Store Connect 的完整隐私问卷；应按实际服务商数据流单独评估。

真机还需检查：保存服务商自动获取模型、钥匙串持久化、多个模型并行、三种模式、失败重试、断网/额度不足、手动终止、后台结束、重启历史及 PNG 系统分享。用少量题目和服务商侧低额度限制开始测试。Review Notes 需提供可审查 AI 功能的方法，勿将私人长期密钥打包到 App 中。

```sh
scripts/check.sh
xcodebuild -project Herbert.xcodeproj -scheme HerbertAppStore -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath .build/store-ios CODE_SIGNING_ALLOWED=NO build
python3 scripts/check_app_store_bundle.py .build/store-ios/Build/Products/Release-iphoneos/HerbertAppStore.app
```

资源检查必须通过：恰好一份 30 题原创目录，不含社区 JSON、社区 bundle、其他棋盘目录或参考答案。
它只证明题库打包边界，不代替真机验证、隐私政策或商店资料检查。

完成设备测试后，选择 **HerbertAppStore → Product → Archive**。
对归档中的 `Products/Applications/HerbertAppStore.app` 再运行同一资源检查；确保 App Store Connect 的 Bundle ID 和版本/build 与归档一致，再由 Organizer 上传。
原生 macOS 版本需要选择 Mac 目标单独归档与检查。不要用 `Herbert` scheme 的归档提交 App Store。

## 维护原创课程

设计源是 `scripts/generate_original_problems.py`，运行后生成原创 JSON、三语课程文案、课程文档和测试参考解。
修改后运行 `scripts/check.sh`，真实引擎会验证全部参考解在各自 byte 限制内完成。
稳定 ID 10001–10050 用于存档，L01–L50 用于显示；不要用重排题号改变已有题目的含义。
L01–L30 精选十题，选中的布局与预算保持不变；退役的记录仍可导入；L31–L50 的独立几何路线位于 `scripts/advanced_course.py`。
难度与短循环探测说明见 [进阶设计分析](advanced-course-design.zh-CN.md)。
