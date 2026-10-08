import Foundation

public struct AICompletionRequest: Sendable {
    public let participant: CompetitionParticipant
    public let messages: [AIMessage]
    public let maxOutputTokens: Int
    public init(participant: CompetitionParticipant, messages: [AIMessage], maxOutputTokens: Int) {
        self.participant = participant
        self.messages = messages
        self.maxOutputTokens = maxOutputTokens
    }
}

public struct AIProgress: Sendable {
    public let text: String
    public let usage: TokenUsage
    public let isFinal: Bool
    public init(text: String, usage: TokenUsage, isFinal: Bool = false) {
        self.text = text
        self.usage = usage
        self.isFinal = isFinal
    }
}

public struct AIReply: Sendable {
    public let text: String
    public let usage: TokenUsage
    public let finishReason: String?
    public init(text: String, usage: TokenUsage, finishReason: String? = "stop") {
        self.text = text
        self.usage = usage
        self.finishReason = finishReason
    }
}

public protocol AIClient: Sendable {
    func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel]
    func complete(
        _ request: AICompletionRequest,
        progress: @escaping @Sendable (AIProgress) async -> Void
    ) async throws -> AIReply
}

public struct AIHTTPError: Error, LocalizedError, Sendable {
    public let status: Int
    public var errorDescription: String? { "AI HTTP \(status)" }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public final class OpenAICompatibleClient: AIClient, Sendable {
    private let session: URLSession
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 600
        configuration.timeoutIntervalForResource = 600
        session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    private func request(provider: ProviderConfiguration, apiKey: String, path: String) throws -> URLRequest {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BattlefieldError.missingKey
        }
        var request = URLRequest(url: try provider.endpoint(path), cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BattlefieldError.invalidResponse }
        if (300..<400).contains(http.statusCode) { throw BattlefieldError.redirected }
        guard (200..<300).contains(http.statusCode) else { throw AIHTTPError(status: http.statusCode) }
    }

    public func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] {
        var request = try request(provider: provider, apiKey: apiKey, path: "models")
        if provider.kind == .siliconFlow {
            var parts = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            parts.queryItems = [URLQueryItem(name: "sub_type", value: "chat")]
            request.url = parts.url
        }
        request.timeoutInterval = 30
        let (bytes, response) = try await session.bytes(for: request)
        defer { bytes.task.cancel() }
        try validate(response)
        return try await withTaskCancellationHandler {
            var data = Data()
            for try await byte in bytes {
                try Task.checkCancellation()
                data.append(byte)
                guard data.count <= 8 * 1024 * 1024 else { throw BattlefieldError.responseTooLarge }
            }
            return try Self.decodeModels(data)
        } onCancel: {
            bytes.task.cancel()
        }
    }

    public static func decodeModels(_ data: Data) throws -> [AIModel] {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let records = envelope["data"] as? [[String: Any]]
        else {
            throw BattlefieldError.invalidResponse
        }
        var seen: Set<String> = []
        return records.compactMap { record in
            guard let id = record["id"] as? String, !id.isEmpty, id.count <= 512,
                seen.insert(id).inserted
            else { return nil }
            if let architecture = record["architecture"] as? [String: Any],
                let modalities = architecture["output_modalities"] as? [String], !modalities.contains("text")
            {
                return nil
            }
            let top = record["top_provider"] as? [String: Any]
            return AIModel(
                id: id, name: record["name"] as? String,
                contextLength: record["context_length"] as? Int,
                supportedParameters: record["supported_parameters"] as? [String],
                maximumOutputTokens: top?["max_completion_tokens"] as? Int)
        }.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    public static func decodeUsage(_ object: [String: Any], fallback: TokenUsage) -> TokenUsage {
        func number(_ object: Any?) -> Int? {
            guard let value = object as? Int, (0...1_000_000_000).contains(value) else { return nil }
            return value
        }
        let input = number(object["prompt_tokens"]) ?? number(object["input_tokens"])
        let output = number(object["completion_tokens"]) ?? number(object["output_tokens"])
        let inputDetails =
            object["prompt_tokens_details"] as? [String: Any]
            ?? object["input_tokens_details"] as? [String: Any]
        let outputDetails =
            object["completion_tokens_details"] as? [String: Any]
            ?? object["output_tokens_details"] as? [String: Any]
        return TokenUsage(
            input: input ?? fallback.input, output: output ?? fallback.output,
            total: number(object["total_tokens"]),
            cached: number(inputDetails?["cached_tokens"]) ?? number(object["prompt_cache_hit_tokens"]),
            reasoning: number(outputDetails?["reasoning_tokens"]),
            estimated: input == nil || output == nil)
    }

    public func complete(
        _ request: AICompletionRequest,
        progress: @escaping @Sendable (AIProgress) async -> Void
    ) async throws -> AIReply {
        try Task.checkCancellation()
        let entrant = request.participant.entrant
        let parameters = try entrant.preset.parameters.validated()
        var body = try JSONSerialization.jsonObject(with: Data(parameters.extraJSON.utf8)) as! [String: Any]
        body["model"] = entrant.preset.model.id
        body["messages"] = request.messages.map { ["role": $0.role, "content": $0.content] }
        body["stream"] = true
        body[entrant.outputTokenParameter.rawValue] = request.maxOutputTokens
        if entrant.kind == .compatible { body["stream_options"] = ["include_usage": true] }
        if let temperature = parameters.temperature {
            if let supported = entrant.preset.model.supportedParameters, !supported.contains("temperature") {
                throw BattlefieldError.invalidParameters
            }
            body["temperature"] = temperature
        }
        if let topP = parameters.topP {
            if let supported = entrant.preset.model.supportedParameters, !supported.contains("top_p") {
                throw BattlefieldError.invalidParameters
            }
            body["top_p"] = topP
        }
        var http = try self.request(
            provider: entrant.provider, apiKey: request.participant.apiKey,
            path: "chat/completions")
        http.httpMethod = "POST"
        http.setValue("text/event-stream, application/json", forHTTPHeaderField: "Accept")
        http.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let (bytes, response) = try await session.bytes(for: http)
        defer { bytes.task.cancel() }
        try validate(response)
        return try await withTaskCancellationHandler {
            if (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")?.contains("text/event-stream")
                != true
            {
                var data = Data()
                for try await byte in bytes {
                    try Task.checkCancellation()
                    data.append(byte)
                    guard data.count <= 4 * 1024 * 1024 else { throw BattlefieldError.responseTooLarge }
                }
                return try Self.decodeReply(data, messages: request.messages)
            }
            var accumulator = ChatStreamAccumulator(messages: request.messages)
            var parser = ServerSentEventParser()
            var received = 0
            var lastUpdate = ContinuousClock.now
            for try await byte in bytes {
                try Task.checkCancellation()
                received += 1
                guard received <= 4 * 1024 * 1024 else { throw BattlefieldError.responseTooLarge }
                if let event = try parser.consume(byte) {
                    try accumulator.consume(event)
                    if ContinuousClock.now - lastUpdate >= .milliseconds(150) || accumulator.reportedUsage != nil {
                        await progress(
                            AIProgress(
                                text: accumulator.text, usage: accumulator.usage,
                                isFinal: accumulator.finishReason != nil && accumulator.reportedUsage != nil))
                        lastUpdate = .now
                    }
                    if accumulator.done { break }
                }
            }
            if let event = try parser.finish() { try accumulator.consume(event) }
            try Task.checkCancellation()
            guard accumulator.done || accumulator.finishReason != nil else { throw BattlefieldError.invalidResponse }
            await progress(AIProgress(text: accumulator.text, usage: accumulator.usage, isFinal: true))
            return AIReply(text: accumulator.text, usage: accumulator.usage, finishReason: accumulator.finishReason)
        } onCancel: {
            bytes.task.cancel()
        }
    }

    public static func decodeReply(_ data: Data, messages: [AIMessage]) throws -> AIReply {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = object["choices"] as? [[String: Any]], let first = choices.first,
            let message = first["message"] as? [String: Any]
        else { throw BattlefieldError.invalidResponse }
        let text = message["content"] as? String ?? ""
        let reasoning = message["reasoning_content"] as? String ?? message["reasoning"] as? String ?? ""
        let fallback = TokenUsage.estimate(messages: messages, outputBytes: text.utf8.count + reasoning.utf8.count)
        let usage = (object["usage"] as? [String: Any]).map { decodeUsage($0, fallback: fallback) } ?? fallback
        return AIReply(text: text, usage: usage, finishReason: first["finish_reason"] as? String)
    }
}

// AsyncBytes.lines can omit empty lines on Apple platforms. SSE needs those exact
// boundaries to separate events, including usage-only events at the end of a stream.
struct ServerSentEventParser {
    private var line: [UInt8] = []
    private var data: [String] = []
    private var skipLF = false

    mutating func consume(_ byte: UInt8) throws -> String? {
        if skipLF {
            skipLF = false
            if byte == 10 { return nil }
        }
        if byte == 13 || byte == 10 {
            skipLF = byte == 13
            return try consumeLine()
        }
        line.append(byte)
        return nil
    }

    private mutating func consumeLine() throws -> String? {
        guard let text = String(bytes: line, encoding: .utf8) else { throw BattlefieldError.invalidResponse }
        line.removeAll(keepingCapacity: true)
        if text.isEmpty {
            guard !data.isEmpty else { return nil }
            let event = data.joined(separator: "\n")
            data.removeAll(keepingCapacity: true)
            return event
        }
        if text.hasPrefix("data:") {
            var value = String(text.dropFirst(5))
            if value.hasPrefix(" ") { value.removeFirst() }
            data.append(value)
        }
        return nil
    }

    mutating func finish() throws -> String? {
        if !line.isEmpty, let event = try consumeLine() { return event }
        guard !data.isEmpty else { return nil }
        defer { data.removeAll() }
        return data.joined(separator: "\n")
    }
}

struct ChatStreamAccumulator {
    let messages: [AIMessage]
    var text = ""
    var reasoningBytes = 0
    var reportedUsage: TokenUsage?
    var finishReason: String?
    var done = false
    var usage: TokenUsage {
        reportedUsage ?? .estimate(messages: messages, outputBytes: text.utf8.count + reasoningBytes)
    }

    mutating func consume(_ payload: String) throws {
        if payload == "[DONE]" {
            done = true
            return
        }
        guard let object = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any],
            object["error"] == nil
        else { throw BattlefieldError.invalidResponse }
        if let choices = object["choices"] as? [[String: Any]], let first = choices.first {
            if let delta = first["delta"] as? [String: Any] {
                text += delta["content"] as? String ?? ""
                reasoningBytes +=
                    (delta["reasoning_content"] as? String ?? delta["reasoning"] as? String ?? "").utf8.count
            }
            if let reason = first["finish_reason"] as? String { finishReason = reason }
        }
        if let usage = object["usage"] as? [String: Any] {
            reportedUsage = OpenAICompatibleClient.decodeUsage(usage, fallback: self.usage)
        }
    }
}
