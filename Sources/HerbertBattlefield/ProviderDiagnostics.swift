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
    case overloaded
    case timedout
    case tempUnavailable
    case accessDenied
    case generic(message: String)

    public var status: ProblemAnswerStatus {
        switch self {
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
        case .timedout, .accessDenied, .generic: false
        }
    }

    public var shouldStopEntrant: Bool {
        switch self {
        case .accessDenied, .generic: true
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
            return (nil, nil, nil, nil)
        }
        var dict: [String: Any]?
        if let array = json as? [[String: Any]] {
            dict = array.first
        } else if let object = json as? [String: Any] {
            dict = object
        }
        guard let target = dict else { return (nil, nil, nil, nil) }

        let errorObj = target["error"]
        let errorDict = errorObj as? [String: Any]
        let code = errorDict?["code"] as? Int ?? target["code"] as? Int
        let message = errorDict?["message"] as? String ?? (errorObj as? String) ?? target["message"] as? String
        let status = errorDict?["status"] as? String ?? target["status"] as? String
        let metadata = errorDict?["metadata"] as? [String: Any] ?? target["metadata"] as? [String: Any]
        let errorType = metadata?["error_type"] as? String
        return (code, message, status, errorType)
    }

    public static func classify(
        _ error: any Error, detail: String? = nil, entrant: Entrant? = nil
    ) -> AIProblemErrorClassification {
        let (code, message, statusStr, errorType) = extractPayload(from: detail)
        let effectiveCode = code ?? (error as? AIHTTPError)?.status
        let combined = [
            message,
            statusStr,
            errorType,
            detail,
            error.localizedDescription,
        ].compactMap { $0 }.joined(separator: " ").lowercased()

        let ns = error as NSError
        if (error as? URLError)?.code == .timedOut
            || (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorTimedOut)
            || (ns.domain == NSURLErrorDomain && combined.contains("timed out"))
        {
            return .timedout
        }

        if effectiveCode == 502 || combined.contains("502") {
            let isExceededLimit =
                combined.contains("exceeded")
                && (combined.contains("limit")
                    || combined.contains("wall-clock")
                    || combined.contains("wall clock")
                    || combined.contains("second")
                    || combined.contains("timeout")
                    || combined.contains("timed out"))
            if isExceededLimit {
                return .timedout
            }

            let isConnectionLost =
                combined.contains("connection lost")
                || combined.contains("network connection")
                || combined.contains("connection reset")
                || combined.contains("bad gateway")
                || combined.contains("provider_unavailable")
                || combined.contains("temporarily unavailable")
            if isConnectionLost || effectiveCode == 502 {
                return .tempUnavailable
            }
        }

        if (error as? URLError)?.code == .networkConnectionLost
            || (error as? URLError)?.code == .cannotConnectToHost
            || (ns.domain == NSURLErrorDomain
                && (ns.code == NSURLErrorNetworkConnectionLost || ns.code == NSURLErrorCannotConnectToHost))
        {
            return .tempUnavailable
        }

        if effectiveCode == 403 || combined.contains("403") {
            return .accessDenied
        }

        if effectiveCode == 503 || combined.contains("503") {
            let isOverloaded =
                combined.contains("high demand")
                || combined.contains("spikes in demand")
                || combined.contains("overloaded")
                || combined.contains("over capacity")
                || combined.contains("unavailable")
                || entrant?.kind == .gemini
                || entrant?.preset.model.id.lowercased().contains("gemini") == true
            if isOverloaded || effectiveCode == 503 {
                return .overloaded
            }
        }

        if combined.contains("high demand") || combined.contains("spikes in demand") {
            return .overloaded
        }
        if combined.contains("streaming request exceeded") {
            return .timedout
        }
        if combined.contains("network connection lost") {
            return .tempUnavailable
        }
        if combined.contains("terms of service") && combined.contains("prohibited") {
            return .accessDenied
        }

        let desc = (error as? AIHTTPError)?.localizedDescription ?? error.localizedDescription
        return .generic(message: desc)
    }
}

extension AIReply {
    public var providerFailed: Bool { ["error", "content_filter"].contains(finishReason ?? "") }
}
