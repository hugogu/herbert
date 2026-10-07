import SwiftUI

struct GuideView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Eyebrow(text: "THE ART OF SMALL PROGRAMS")
                Text("三个指令，\n无限种思路。").font(.system(size: 34, weight: .bold, design: .rounded)).lineSpacing(4)
                Text("先看出图案，再用代码表达它。Herbert 会执行你的程序，走到每一个目标上。")
                    .font(.system(size: 14)).foregroundStyle(Palette.muted).lineSpacing(5)
                HStack(spacing: 12) {
                    primitive("s", "前进一步", "arrow.up")
                    primitive("l", "左转 90°", "arrow.turn.up.left")
                    primitive("r", "右转 90°", "arrow.turn.up.right")
                }
                lesson(
                    "01", title: "让所有目标同时亮起",
                    body: "金色圆环是目标，走到上面即可点亮；灰色带 × 的圆环是陷阱，踩到后会清空之前点亮的全部目标。深色方块是墙，撞墙或走到棋盘边界时留在原地，程序继续执行。", code: "ssss")
                lesson(
                    "02", title: "把重复的动作交给过程", body: "用单个小写字母给一段指令命名，s、l、r 保留给基本指令。先声明过程，最后一行写要执行的程序。过程可以调用自己。",
                    code: "a:ssss\na")
                lesson(
                    "03", title: "用数字控制重复次数",
                    body: "参数名是大写字母。任一数值参数小于或等于 0 时，整次调用被跳过。支持 + 和 -；整数的绝对值不能超过 255。下面的程序前进四步。",
                    code: "a(X):sa(X-1)\na(4)")
                lesson(
                    "04", title: "让指令也成为参数", body: "参数也能传入一段指令，甚至空指令。下面的程序依次执行 l、ls、lss、lsss…；这是无限递归，游戏会在点亮所有目标时立即结束。",
                    code: "a(X):Xa(Xs)\na(l)")
                lesson(
                    "05", title: "数值与指令一起传递", body: "过程最多接受 26 个参数，可以混合数值与命令。下面的程序执行四次 s。空命令参数写成 a() 或多参数中的空项，如 a(4,)。",
                    code: "a(X,Y):Ya(X-1,Y)\na(4,s)")
                VStack(alignment: .leading, spacing: 13) {
                    Eyebrow(text: "MAKE EVERY BYTE COUNT")
                    Text("短一点，再短一点。").font(.system(size: 22, weight: .bold))
                    Text(
                        "每个字母算 1 byte，每个完整数值也算 1 byte：12 只算 1 byte。括号、冒号、逗号、加减号和空白不计。只有在本关长度限制内点亮全部目标，才算完成。步数不影响最短代码记录。"
                    )
                    .font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
                    Text("a:sa\na  →  4 byte").font(.system(size: 17, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.mint)
                }.panel()
                VStack(alignment: .leading, spacing: 10) {
                    Text("为你的设备重新设计").font(.headline)
                    Text("用快捷指令键在光标处插入代码。单步执行便于调试，暂停后可继续。双指缩放棋盘，放大后拖动；「全棋盘」显示完整 25×25 区域。切到后台会自动暂停并保存草稿。")
                    Text("Mac：⌘ Return 运行 / 暂停。所有关卡、草稿与最短解都可离线使用。")
                    Text("每次运行最多 100 万步；命令展开、递归深度也有保护上限，以保持界面可响应。")
                }.font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5).panel()
                VStack(alignment: .leading, spacing: 10) {
                    Text("致谢与来源").font(.headline).foregroundStyle(Palette.ink)
                    Text(
                        "Herbert 最初来自 Imagine Cup 编程挑战。本应用依据 quolc 的 Herbert Online Judge 规则独立实现，保留原站题目名称、作者、编号与 byte 限制。原题作者保留其权利。"
                    )
                    Link("原版规则 ↗", destination: URL(string: "http://herbert.tealang.info/rule.php")!)
                    Link("原版 Problems ↗", destination: URL(string: "http://herbert.tealang.info/problems.php")!)
                }.font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4).padding(.vertical, 12)
            }.padding(24).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Palette.paper).navigationTitle("玩法手册")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    private func primitive(_ key: String, _ title: String, _ symbol: String) -> some View {
        VStack(spacing: 11) {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(Palette.mint)
            Text(key).font(.system(size: 28, weight: .bold, design: .monospaced))
            Text(title).font(.system(size: 11)).foregroundStyle(Palette.muted)
        }.frame(maxWidth: .infinity).padding(.vertical, 20).background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func lesson(_ number: String, title: String, body: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Text(number).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Palette.mint)
                Text(title).font(.system(size: 17, weight: .semibold))
            }
            Text(body).font(.system(size: 13)).foregroundStyle(Palette.muted).lineSpacing(5)
            Text(code).font(.system(size: 19, weight: .medium, design: .monospaced)).foregroundStyle(Palette.mint)
                .textSelection(.enabled).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.mintLight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        }.panel()
    }
}
