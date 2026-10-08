import SwiftUI

/// Renders the headings, paragraphs and fenced examples used by our versioned rules prompt.
struct BattlefieldRulesView: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.hasPrefix("```") {
                    Text(
                        block.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().dropLast().joined(
                            separator: "\n")
                    )
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Palette.mint).padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.mintLight.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                } else if block.hasPrefix("# ") {
                    Text(inline(String(block.dropFirst(2)))).font(.title.bold())
                } else if block.hasPrefix("## ") {
                    Text(inline(String(block.dropFirst(3)))).font(.title3.bold()).padding(.top, 8)
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
            if line.hasPrefix("```") { fenced.toggle() }
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

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
