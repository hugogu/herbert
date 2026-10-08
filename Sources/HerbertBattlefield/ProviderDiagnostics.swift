import Foundation

enum ProviderDiagnostics {
    static let byteLimit = 65_536

    static func response(_ data: Data, apiKey: String, truncated: Bool = false) -> String {
        let sensitive: Set<String> = [
            "authorization", "apikey", "accesskey", "accesstoken", "refreshtoken",
            "password", "secret", "token", "cookie", "setcookie",
        ]
        func redact(_ value: Any) -> Any {
            if let object = value as? [String: Any] {
                return object.mapValues { redact($0) }.reduce(into: [String: Any]()) { result, pair in
                    let normalized = pair.key.lowercased().filter { $0.isLetter || $0.isNumber }
                    result[pair.key] = sensitive.contains(normalized) ? "[REDACTED]" : pair.value
                }
            }
            if let array = value as? [Any] { return array.map(redact) }
            return value
        }
        let body = data.prefix(byteLimit)
        var text: String
        if let object = try? JSONSerialization.jsonObject(with: body),
            let encoded = try? JSONSerialization.data(
                withJSONObject: redact(object), options: [.prettyPrinted, .sortedKeys])
        {
            text = String(decoding: encoded, as: UTF8.self)
        } else {
            text = String(decoding: body, as: UTF8.self)
        }
        if !apiKey.isEmpty { text = text.replacingOccurrences(of: apiKey, with: "[REDACTED]") }
        for pattern in [
            #"(?i)Bearer\s+[^\s\"'<>]+"#,
            #"(?i)(?:api[_-]?key|access[_-]?token|password|secret)\s*[=:]\s*[^\s&\"'<>]+"#,
            #"https?://[^\s\"'<>]+\?[^\s\"'<>]*"#,
        ] {
            text = text.replacingOccurrences(of: pattern, with: "[REDACTED]", options: .regularExpression)
        }
        if truncated || data.count > byteLimit { text += "\n[Provider response truncated at 64 KiB]" }
        return text
    }
}
