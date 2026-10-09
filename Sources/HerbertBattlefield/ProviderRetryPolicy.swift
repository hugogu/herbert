import Foundation

enum ProviderRetryPolicy {
    static func delay(for error: any Error, consecutiveFailure: Int, jitter: Double = .random(in: 0...1))
        -> TimeInterval
    {
        let backoff = min(60, 2 * pow(2, Double(max(0, min(consecutiveFailure - 1, 5)))))
        let provider = error as? AIHTTPError
        let hints = [provider?.retryAfter, payloadDelay(provider?.providerResponse)].compactMap { valid($0) }
        return max(backoff, hints.max() ?? 0) + backoff * 0.25 * max(0, min(1, jitter))
    }

    static func retryAfter(_ value: String?, now: Date = .now) -> TimeInterval? {
        guard let value else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = valid(Double(text)) { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEEE, dd-MMM-yy HH:mm:ss zzz", "EEE MMM d HH:mm:ss yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return valid(max(0, date.timeIntervalSince(now))) }
        }
        return nil
    }

    static func payloadDelay(_ detail: String?) -> TimeInterval? {
        guard let detail else { return nil }
        var delays: [TimeInterval] = []
        func collect(_ value: Any) {
            if let object = value as? [String: Any] {
                for (key, value) in object {
                    if ["retryDelay", "retry_after", "retry_after_seconds", "retryAfter"].contains(key) {
                        let text = (value as? String) ?? (value as? NSNumber)?.stringValue
                        if let text, let seconds = valid(Double(text.hasSuffix("s") ? String(text.dropLast()) : text)) {
                            delays.append(seconds)
                        }
                    } else if key != "message" {
                        collect(value)
                    }
                }
            } else if let array = value as? [Any] {
                array.forEach(collect)
            }
        }
        if let object = try? JSONSerialization.jsonObject(with: Data(detail.utf8)) { collect(object) }
        // Only inspect the provider error message, never retained model output or reasoning.
        if let message = ProviderDiagnostics.extractPayload(from: detail).message,
            let regex = try? NSRegularExpression(
                pattern: #"(?i)\bretry\s+(?:in|after)\s+(\d+(?:\.\d+)?)\s*s(?:ec(?:ond)?s?)?\b"#)
        {
            for match in regex.matches(in: message, range: NSRange(message.startIndex..., in: message)) {
                if let range = Range(match.range(at: 1), in: message), let delay = valid(Double(message[range])) {
                    delays.append(delay)
                }
            }
        }
        return delays.max()
    }

    private static func valid(_ value: TimeInterval?) -> TimeInterval? {
        guard let value, value.isFinite, value >= 0, value < Double(Int64.max) / 1_000_000_000 else { return nil }
        return value
    }
}
