import SwiftUI

/// Shared Markdown presentation for rules and model reasoning; no HTML or remote media is loaded.
struct BattlefieldRulesView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.hasPrefix("```") {
                    Text(
                        block.split(separator: "\n", omittingEmptySubsequences: false).dropFirst()
                            .filter { !$0.hasPrefix("```") }.joined(
                                separator: "\n")
                    )
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Palette.mint).padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.mintLight.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                } else if let level = headingLevel(block) {
                    Text(inline(String(block.dropFirst(level + 1))))
                        .font(level == 1 ? .title.bold() : (level == 2 ? .title3.bold() : .headline))
                        .padding(.top, 8)
                } else if block == "---" || block == "***" {
                    Divider()
                } else if block.hasPrefix("> ") {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle().fill(Palette.mint).frame(width: 3)
                        Text(inline(block.replacingOccurrences(of: "> ", with: ""))).font(.callout)
                    }.fixedSize(horizontal: false, vertical: true)
                } else if block.hasPrefix("- ") || block.hasPrefix("* ")
                    || block.range(of: #"^\d+\. "#, options: .regularExpression) != nil
                {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(block.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            Text(inline(line.hasPrefix("- ") || line.hasPrefix("* ") ? "• " + line.dropFirst(2) : line))
                                .font(.callout).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    Text(inline(block.replacingOccurrences(of: "\n", with: " "))).font(.callout).lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }.foregroundStyle(Palette.ink).textSelection(.enabled)
    }

    private var blocks: [String] {
        var result: [String] = []
        var current: [String] = []
        var fenced = false
        for line in source.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                if !fenced && !current.isEmpty {
                    result.append(current.joined(separator: "\n"))
                    current = []
                }
                current.append(line)
                fenced.toggle()
                if !fenced {
                    result.append(current.joined(separator: "\n"))
                    current = []
                }
                continue
            }
            if !fenced && headingLevel(line) != nil {
                if !current.isEmpty {
                    result.append(current.joined(separator: "\n"))
                    current = []
                }
                result.append(line)
                continue
            }
            if line.isEmpty && !fenced {
                if !current.isEmpty {
                    result.append(current.joined(separator: "\n"))
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { result.append(current.joined(separator: "\n")) }
        return result
    }

    private func headingLevel(_ line: String) -> Int? {
        let count = line.prefix { $0 == "#" }.count
        return (1...6).contains(count) && line.dropFirst(count).hasPrefix(" ") ? count : nil
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
