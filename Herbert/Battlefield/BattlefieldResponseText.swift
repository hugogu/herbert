import HerbertBattlefield
import SwiftUI

/// A single very tall Text causes quadratic CoreText measurement and can draw blank on macOS.
/// Bound each layout operation while keeping the original response in one continuous scroll.
struct BattlefieldResponseText: View {
    let source: String
    let identifier: String

    var body: some View {
        let blocks = ResponseTextLayout.blocks(in: source)
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(blocks.indices, id: \.self) { index in
                let block = blocks[index]
                // The stack itself starts the next block on a new line.
                let text = index < blocks.count - 1 && block.hasSuffix("\n") ? String(block.dropLast()) : block
                Text(verbatim: text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier(index == 0 ? identifier : "\(identifier)-block-\(index)")
            }
        }
    }
}
