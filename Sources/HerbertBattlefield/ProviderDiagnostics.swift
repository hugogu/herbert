import Foundation

enum ProviderDiagnostics {
    static let byteLimit = 65_536

    static func hasError(_ object: [String: Any]) -> Bool {
        object["error"].map { !($0 is NSNull) } ?? false
    }

    static func failure(_ error: any Error, apiKey: String) -> (message: String, detail: String?) {
        if let provider = error as? AIHTTPError {
            return (
                provider.localizedDescription, provider.providerResponse.map { response(Data($0.utf8), apiKey: apiKey) }
            )
        }
        if let local = error as? BattlefieldError {
            let message: String
            switch local {
            case .incompleteStream:
                message = "The response stream ended before completion. Partial output was retained."
            case .responseTooLarge:
                message = "The response exceeded the local processing limit. Partial output was retained."
            default: message = local.localizedDescription
            }
            return (message, nil)
        }
        let network = error as NSError
        let description: String
        switch (network.domain, network.code) {
        case (NSURLErrorDomain, NSURLErrorTimedOut): description = "AI network request timed out"
        case (NSURLErrorDomain, NSURLErrorNetworkConnectionLost): description = "AI connection was lost"
        case (NSURLErrorDomain, NSURLErrorNotConnectedToInternet): description = "No internet connection"
        default: description = "AI request failed"
        }
        let code = "\(network.domain) \(network.code)"
        return (
            response(Data("\(description) (\(code))".utf8), apiKey: apiKey),
            response(Data("\(code)\n\(network.localizedDescription)".utf8), apiKey: apiKey)
        )
    }

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

public enum AIProblemErrorClassification: Sendable, Equatable {
    case burnout
    case overloaded
    case timedout
    case tempUnavailable
    case accessDenied
    case generic(message: String)

    public var status: ProblemAnswerStatus {
        switch self {
        case .burnout: .burnout
        case .overloaded: .overloaded
        case .timedout: .timedout
        case .tempUnavailable: .tempUnavailable
        case .accessDenied: .accessDenied
        case .generic: .error
        }
    }

    public var isRetriable: Bool {
        switch self {
        case .overloaded, .tempUnavailable: true
        case .burnout, .timedout, .accessDenied, .generic: false
        }
    }

    public var shouldStopEntrant: Bool {
        switch self {
        case .burnout, .accessDenied, .generic: true
        case .overloaded, .tempUnavailable, .timedout: false
        }
    }
}

extension ProviderDiagnostics {
    static func extractPayload(
        from detail: String?
    ) -> (code: Int?, message: String?, status: String?, errorType: String?) {
        guard let detail, let data = detail.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data)
        else {
            return (nil, detail, nil, nil)
        }
        var dict: [String: Any]?
        if let array = json as? [[String: Any]] {
            dict = array.first
        } else if let object = json as? [String: Any] {
            dict = object
        }
        guard let target = dict else { return (nil, nil, nil, nil) }

        let choice = (target["choices"] as? [[String: Any]])?.first
        let errorObj = target["error"].flatMap { $0 is NSNull ? nil : $0 } ?? choice?["error"]
        let errorDict = errorObj as? [String: Any]
        let rawCode = errorDict?["code"] ?? target["code"]
        let code = (rawCode as? Int) ?? (rawCode as? String).flatMap(Int.init)
        let message = errorDict?["message"] as? String ?? (errorObj as? String) ?? target["message"] as? String
        let status = errorDict?["status"] as? String ?? target["status"] as? String
        let metadata = errorDict?["metadata"] as? [String: Any] ?? target["metadata"] as? [String: Any]
        let errorType = metadata?["error_type"] as? String ?? errorDict?["type"] as? String
        return (code, message, status, errorType)
    }

    static func classify(
        _ error: any Error, detail: String? = nil
    ) -> AIProblemErrorClassification {
        let provider = error as? AIHTTPError
        let detail = detail ?? provider?.providerResponse
        let (code, message, status, errorType) = extractPayload(from: detail)
        // An HTTP failure is authoritative; only successful HTTP streams use in-band codes.
        let effectiveCode = provider.flatMap { (400..<600).contains($0.status) ? $0.status : nil } ?? code
        let combined = [message, status, errorType, error.localizedDescription]
            .compactMap { $0 }.joined(separator: " ").lowercased()
        let network = error as NSError
        if network.domain == NSURLErrorDomain {
            switch network.code {
            case NSURLErrorTimedOut: return .timedout
            case NSURLErrorNetworkConnectionLost, NSURLErrorCannotConnectToHost: return .tempUnavailable
            default: break
            }
        }
        switch effectiveCode {
        case 402: return .burnout
        case 403: return .accessDenied
        case 502:
            if combined.contains("exceeded")
                && (combined.contains("wall-clock") || combined.contains("wall clock")
                    || combined.contains("timeout") || combined.contains("timed out")
                    || (combined.contains("second") && combined.contains("limit")))
            {
                return .timedout
            }
            return .tempUnavailable
        case 429, 503, 529: return .overloaded
        case nil, 200:
            if combined.contains("high demand") || combined.contains("spikes in demand")
                || errorType == "overloaded_error" || errorType == "rate_limit_error"
            {
                return .overloaded
            }
            if combined.contains("streaming request exceeded") { return .timedout }
            if combined.contains("network connection lost") { return .tempUnavailable }
            if combined.contains("terms of service") && combined.contains("prohibited") { return .accessDenied }
        default: break
        }
        return .generic(message: error.localizedDescription)
    }

}

extension AIReply {
    public var providerFailed: Bool { ["error", "content_filter"].contains(finishReason ?? "") }
}
