import HerbertCore
import SwiftUI

private enum ProblemFilter: String, CaseIterable {
    case all = "全部"
    #if !APP_STORE
        case originals = "原创课程"
        case community = "社区题库"
        case foundation = "入门"
    #endif
    case favorites = "收藏"
    case completed = "已完成"
}

struct LibraryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var filter: ProblemFilter = .all

    private var filtered: [Problem] {
        store.problems.filter { problem in
            let record = store.progress(for: problem.id)
            let included: Bool
            switch filter {
            case .all: included = true
            #if !APP_STORE
                case .originals: included = problem.lesson != nil
                case .community: included = problem.lesson == nil
                case .foundation: included = problem.isFoundation
            #endif
            case .favorites: included = record.isFavorite
            case .completed: included = record.bestBytes != nil
            }
            return included
                && (query.isEmpty
                    || "\(problem.number) \(problem.id) \(problem.title) \(problem.displayTitle) \(problem.author)"
                        .localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                if query.isEmpty, filter == .all, let next = store.resumeProblem { continueCard(next) }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("探索关卡").font(.system(size: 23, weight: .bold))
                        Spacer()
                        Text("\(filtered.count) PROBLEMS").font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Palette.muted).accessibilityIdentifier("catalog-count")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ProblemFilter.allCases, id: \.self) { item in
                                Button {
                                    filter = item
                                } label: {
                                    Text(LocalizedStringKey(item.rawValue)).font(.system(size: 13, weight: .medium))
                                        .padding(.horizontal, 15).frame(minHeight: 40)
                                        .background(filter == item ? Palette.ink : Color.white, in: Capsule())
                                        .foregroundStyle(filter == item ? .white : Palette.muted)
                                        .overlay(
                                            Capsule().stroke(filter == item ? Color.clear : Palette.line, lineWidth: 1))
                                }.buttonStyle(.plain).accessibilityAddTraits(filter == item ? .isSelected : [])
                                    .accessibilityIdentifier("filter-\(item)")
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                        TextField("搜索编号、名称或作者", text: $query)
                            .font(.system(size: 14)).textFieldStyle(.plain)
                            .accessibilityIdentifier("problem-search")
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain).accessibilityLabel("清除搜索").accessibilityIdentifier("clear-search")
                        }
                    }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Palette.line, lineWidth: 1))
                }
                if let error = store.catalogMessage {
                    ContentUnavailableView("关卡载入失败", systemImage: "exclamationmark.triangle", description: Text(error))
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        "这里还没有关卡", systemImage: "square.grid.2x2", description: Text("试试其他筛选，或搜索关卡编号。"))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 290), spacing: 14)], spacing: 14) {
                        ForEach(filtered) { problem in
                            NavigationLink(value: problem) {
                                ProblemCard(problem: problem, progress: store.progress(for: problem.id))
                            }.buttonStyle(.plain).accessibilityIdentifier("problem-\(problem.id)")
                        }
                    }
                }
                HStack(spacing: 8) {
                    Circle().fill(Palette.mint).frame(width: 5, height: 5)
                    #if APP_STORE
                        Text("50 道原创关卡 · 按学习顺序探索 · 全部离线可玩")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    #else
                        Text("50 道原创课程 + 社区题库 · 全部离线可玩")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    #endif
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            }.padding(24).frame(maxWidth: 1120)
                .frame(maxWidth: .infinity)
        }
        .background(Palette.paper)
        .navigationTitle("Herbert")
        .navigationDestination(for: Problem.self) { problem in GameDestination(problem: problem, store: store) }
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 15) {
            Eyebrow(text: "A LITTLE ROBOT. A BIG IDEA.")
            HStack(alignment: .bottom) {
                Text("把思路，\n变成路径。").font(.system(size: 34, weight: .bold, design: .rounded)).lineSpacing(4)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 5) {
                    Text(String(store.completedCount)).font(.system(size: 36, weight: .light, design: .monospaced))
                    Text("已解锁的灵感").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
            }
            Text("用最短的代码，带 Herbert 点亮所有目标。")
                .font(.system(size: 13)).foregroundStyle(Palette.muted)
        }.padding(.top, 10)
    }

    private func continueCard(_ problem: Problem) -> some View {
        NavigationLink(value: problem) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(
                        text: store.snapshot.lastProblemID == nil ? "YOUR FIRST EXPEDITION" : "PICK UP YOUR THOUGHTS",
                        color: Palette.mintLight)
                    Text(LocalizedStringKey(store.snapshot.lastProblemID == nil ? "从第一步开始" : "继续你的探索"))
                        .font(.system(size: 23, weight: .semibold)).foregroundStyle(.white)
                    Text("\(problem.number)  ·  \(problem.displayTitle)")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    HStack(spacing: 6) {
                        Text("进入关卡").font(.system(size: 12, weight: .bold))
                        Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold))
                    }.foregroundStyle(Palette.mintLight).padding(.top, 5)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up").font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.mintLight)
                    .frame(width: 76, height: 96)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                    .rotationEffect(.degrees(12))
            }.padding(22).background(Palette.ink, in: RoundedRectangle(cornerRadius: 22))
        }.buttonStyle(.plain).accessibilityIdentifier("continue-problem")
    }
}

private struct ProblemCard: View {
    let problem: Problem
    let progress: ProblemProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow(text: problem.number)
                Spacer()
                if progress.isFavorite {
                    Image(systemName: "bookmark.fill").font(.system(size: 10)).foregroundStyle(Palette.amber)
                }
                if progress.bestBytes != nil {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint)
                }
            }
            if let board = try? Board(problem: problem) {
                BoardDrawing(
                    board: board, position: board.start, heading: .north, visited: [], focused: true, miniature: true
                )
                .frame(height: 105).padding(8)
                .background(Palette.paper.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            }
            Text(problem.displayTitle).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            HStack {
                Text(problem.author).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                Spacer(minLength: 4)
                Text(progress.bestBytes.map { "✓ \($0) B" } ?? "≤ \(problem.byteLimit) B")
                    .font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Palette.mint)
            }
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.line.opacity(0.8), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                L10n.text(
                    "关卡 %@，%@，最多 %ld byte%@", problem.number, problem.displayTitle, problem.byteLimit,
                    progress.bestBytes == nil ? "" : L10n.text("，已完成"))
            )
    }
}
