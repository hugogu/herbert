import HerbertBattlefield
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct BattlefieldShareView: View {
    let result: CompetitionResult
    @State private var file: URL?
    @State private var preview: CGImage?
    @State private var failed = false

    var body: some View {
        BattlefieldSheet(title: L10n.text("分享结果图片")) {
            VStack(spacing: 16) {
                if let preview, let file {
                    ScrollView {
                        Image(decorative: preview, scale: 1).resizable().scaledToFit().padding(20)
                    }.background(Palette.paper)
                    ShareLink(
                        item: file,
                        preview: SharePreview("Herbert AI Battlefield", image: Image(decorative: preview, scale: 1))
                    ) {
                        Label("分享 PNG 图片", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.borderedProminent).padding(.bottom, 20).accessibilityIdentifier(
                        "shareBattlefieldPNG")
                } else if failed {
                    BattlefieldNotice(text: L10n.text("图片生成失败，请重试。"))
                    Button("重试") { render() }
                } else {
                    ProgressView().padding(40)
                }
            }
        }.task { render() }
    }

    @MainActor
    private func render() {
        failed = false
        do {
            let rendered = try BattlefieldImageExport.render(result)
            file = rendered.url
            preview = rendered.image
        } catch { failed = true }
    }
}

enum BattlefieldImageExport {
    @MainActor
    static func render(_ result: CompetitionResult) throws -> (url: URL, image: CGImage) {
        let renderer = ImageRenderer(content: BattlefieldShareCard(result: result).environment(\.colorScheme, .light))
        renderer.scale = 1
        guard let image = renderer.cgImage else { throw BattlefieldError.invalidResponse }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "Herbert-Shares", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("Herbert-Battlefield-\(result.id.uuidString).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            throw BattlefieldError.invalidResponse
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw BattlefieldError.invalidResponse }
        return (url, image)
    }
}

private struct BattlefieldShareCard: View {
    let result: CompetitionResult
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 16) {
                RobotMark()
                Text("herbert").font(.system(size: 38, weight: .bold, design: .rounded))
                Spacer()
                Text("AI BATTLEFIELD").font(.system(size: 18, weight: .bold, design: .monospaced)).tracking(3)
                    .foregroundStyle(Palette.mint)
            }
            Rectangle().fill(Palette.mint).frame(height: 4)
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.status.title).font(.system(size: 38, weight: .bold, design: .rounded))
                    Text(result.startedAt, format: .dateTime.year().month().day().hour().minute()).font(
                        .system(size: 18)
                    ).foregroundStyle(Palette.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    Text(result.configuration.settingsDescription).font(.system(size: 24, weight: .semibold))
                    Text(L10n.text("%ld 个 AI · %ld 道题", result.entrants.count, result.problems.count))
                        .font(.system(size: 18)).foregroundStyle(Palette.muted)
                }
            }
            ForEach(Array(result.ranked.enumerated()), id: \.element.id) { rank, entrant in
                HStack(spacing: 20) {
                    Text(String(format: "%02d", rank + 1)).font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(rank == 0 ? Palette.mint : Palette.muted).frame(width: 54)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entrant.entrant.preset.model.displayName).font(.system(size: 25, weight: .bold)).lineLimit(
                            2)
                        Text(entrant.entrant.providerName).font(.system(size: 17)).foregroundStyle(Palette.muted)
                        Text(
                            L10n.text(
                                "通过 %ld/%ld · %ld bytes", entrant.solved, result.problems.count,
                                entrant.bytes)
                        )
                        .font(.system(size: 17, design: .monospaced))
                        Text(
                            (entrant.hasEstimatedUsage ? "≈ " : "")
                                + "\(entrant.inputTokens.formatted()) in / \(entrant.outputTokens.formatted()) out · "
                                + L10n.text("缓存") + " " + battlefieldCache(entrant)
                        )
                        .font(.system(size: 16, design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 10)
                    Text(battlefieldPercentage(result.scoreFraction(for: entrant))).font(
                        .system(size: 44, weight: .bold, design: .rounded)
                    )
                    .foregroundStyle(Palette.mint)
                }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
            Text(result.scoringDescription)
                .font(.system(size: 17)).foregroundStyle(Palette.muted)
            if result.entrants.contains(where: \.hasEstimatedUsage) {
                Text("≈ 包含估算或部分用量；实际账单以服务商为准。")
                    .font(.system(size: 16)).foregroundStyle(Palette.muted)
            }
            HStack {
                Text("github.com/hugogu/herbert").font(.system(size: 17, design: .monospaced))
                Spacer()
                Text(String(result.id.uuidString.prefix(8))).font(.system(size: 15, design: .monospaced))
            }.foregroundStyle(Palette.muted)
        }.padding(48).frame(width: 1080).background(Palette.paper).foregroundStyle(Palette.ink)
    }
}
