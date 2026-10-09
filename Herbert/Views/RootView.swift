import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case library = "关卡"
    case guide = "手册"
    case progress = "记录"
    case battlefield = "AI Battlefield"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .library: "square.grid.2x2"
        case .guide: "book.closed"
        case .progress: "chart.bar.xaxis"
        case .battlefield: "flag.checkered"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selection: AppSection? = .library
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    var body: some View {
        Group {
            #if os(iOS)
                if sizeClass == .compact { phoneTabs } else { splitView }
            #else
                splitView
            #endif
        }
        .foregroundStyle(Palette.ink)
    }

    #if os(iOS)
        private var phoneTabs: some View {
            TabView {
                NavigationStack { LibraryView() }.tabItem { Label("关卡", systemImage: "square.grid.2x2") }
                NavigationStack { GuideView() }.tabItem { Label("手册", systemImage: "book.closed") }
                NavigationStack { ProgressViewScreen() }.tabItem { Label("记录", systemImage: "chart.bar.xaxis") }
                NavigationStack { BattlefieldView() }.tabItem { Label("AI Battlefield", systemImage: "flag.checkered") }
            }
        }
    #endif

    private var splitView: some View {
        NavigationSplitView {
            GeometryReader { geometry in
                let compact = geometry.size.height < 500
                VStack(alignment: .leading, spacing: compact ? 8 : 28) {
                    HStack(spacing: 12) {
                        RobotMark().scaleEffect(compact ? 0.78 : 1)
                            .frame(width: compact ? 36 : 46, height: compact ? 36 : 46)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("herbert").font(.system(size: compact ? 22 : 26, weight: .bold, design: .rounded))
                                .accessibilityIdentifier("sidebar-brand")
                            if !compact { Eyebrow(text: "THINK IN PATTERNS") }
                        }
                    }.padding(.horizontal, 20).padding(.top, compact ? 8 : 30)
                    List(AppSection.allCases, selection: $selection) { section in
                        Label(LocalizedStringKey(section.rawValue), systemImage: section.symbol)
                            .padding(.vertical, compact ? 0 : 9).tag(section)
                            .accessibilityIdentifier("section-\(section.id)")
                    }
                    .listStyle(.sidebar).scrollContentBackground(.hidden)
                    .environment(\.defaultMinListRowHeight, 44)
                    if compact {
                        HStack {
                            Label("\(store.completedCount) / \(store.problems.count)", systemImage: "checkmark.circle")
                                .monospacedDigit().accessibilityIdentifier("sidebar-progress")
                            Spacer(minLength: 4)
                            Label("本机保存", systemImage: "internaldrive").labelStyle(.iconOnly)
                                .foregroundStyle(Palette.mint)
                        }.font(.caption).foregroundStyle(Palette.muted).padding(12)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow(text: "YOUR EXPLORATION")
                            Text("\(store.completedCount) / \(store.problems.count)")
                                .font(.system(size: 25, weight: .medium, design: .monospaced))
                                .accessibilityIdentifier("sidebar-progress")
                            Text("每一段简洁的代码，\n都是一次漂亮的思考。")
                                .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                            Label("本机保存", systemImage: "internaldrive").font(.caption).foregroundStyle(Palette.mint)
                        }.padding(24)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }.background(Palette.paper)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 270)
        } detail: {
            NavigationStack {
                switch selection ?? .library {
                case .library: LibraryView()
                case .guide: GuideView()
                case .progress: ProgressViewScreen()
                case .battlefield: BattlefieldView()
                }
            }
        }
    }
}
