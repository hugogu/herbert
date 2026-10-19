/// Contiguous display blocks for raw provider text. Joining the blocks recovers the exact response.
public enum ResponseTextLayout {
    public static func blocks(in source: String) -> [String] {
        var blocks: [String] = []
        var start = source.startIndex
        while start < source.endIndex {
            var end = source.index(start, offsetBy: 4096, limitedBy: source.endIndex) ?? source.endIndex
            if end < source.endIndex, let newline = source[start..<end].lastIndex(of: "\n") {
                end = source.index(after: newline)
            }
            blocks.append(String(source[start..<end]))
            start = end
        }
        return blocks
    }
}
