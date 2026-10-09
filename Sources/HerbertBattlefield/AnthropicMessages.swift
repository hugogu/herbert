import Foundation

/// Native content must be replayed verbatim, including signatures and opaque redacted thinking.
public struct AnthropicContentBlock: Codable, Equatable, Sendable {
    public var type: String
    public var text: String?
    public var thinking: String?
    public var signature: String?
    public var data: String?

    public init(
        type: String, text: String? = nil, thinking: String? = nil, signature: String? = nil, data: String? = nil
    ) {
        self.type = type
        self.text = text
        self.thinking = thinking
        self.signature = signature
        self.data = data
    }

    var byteCount: Int {
        [text, thinking, signature, data].compactMap { $0 }.reduce(0) { $0 + $1.utf8.count }
    }
}

enum AnthropicMessages {
    static func body(for request: AICompletionRequest) throws -> [String: Any] {
        let entrant = request.participant.entrant
        let parameters = try entrant.preset.parameters.validated()
        var body = try JSONSerialization.jsonObject(with: Data(parameters.extraJSON.utf8)) as! [String: Any]
        // Chat Completions parameters are not interchangeable with Messages parameters.
        guard Set(body.keys).isSubset(of: ["thinking", "output_config", "top_k"]) else {
            throw BattlefieldError.invalidParameters
        }
        let cap = min(
            request.maxOutputTokens ?? entrant.preset.model.maximumOutputTokens ?? 65_536,
            entrant.preset.model.maximumOutputTokens ?? Int.max)
        guard cap > 0, parameters.temperature.map({ $0 <= 1 }) ?? true else {
            throw BattlefieldError.invalidParameters
        }
        body = ReasoningDefaults.applying(to: body, entrant: entrant, maxOutputTokens: cap)
        body["model"] = entrant.preset.model.id
        body["max_tokens"] = cap
        body["stream"] = true
        let system = request.messages.filter { $0.role == "system" }.map(\.content)
        if !system.isEmpty { body["system"] = system.joined(separator: "\n\n") }
        body["messages"] = try request.messages.filter { $0.role != "system" }.map { message in
            guard ["user", "assistant"].contains(message.role) else { throw BattlefieldError.invalidParameters }
            var value: [String: Any] = ["role": message.role, "content": message.content]
            if message.role == "assistant", let blocks = message.contentBlocks, !blocks.isEmpty {
                value["content"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(blocks))
            }
            return value
        }
        if let temperature = parameters.temperature { body["temperature"] = temperature }
        if let topP = parameters.topP { body["top_p"] = topP }
        if let thinking = body["thinking"] as? [String: Any], thinking["type"] as? String == "enabled" {
            guard let budget = thinking["budget_tokens"] as? Int, budget >= 1024, budget < cap,
                parameters.temperature.map({ $0 == 1 }) ?? true
            else { throw BattlefieldError.invalidParameters }
        }
        return body
    }

    static func decodeModels(_ data: Data) throws -> (models: [AIModel], next: String?) {
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let records = envelope["data"] as? [[String: Any]]
        else { throw BattlefieldError.invalidResponse }
        let models = records.compactMap { record -> AIModel? in
            guard let id = record["id"] as? String, !id.isEmpty, id.count <= 512,
                record["lifecycle"] as? String != "retired"
            else { return nil }
            let capabilities = record["capabilities"] as? [String: Any]
            let thinking = capabilities?["thinking"] as? [String: Any]
            let types = thinking?["types"] as? [String: Any]
            let effort = capabilities?["effort"] as? [String: Any]
            func supports(_ object: Any?) -> Bool { (object as? [String: Any])?["supported"] as? Bool == true }
            return AIModel(
                id: id, name: record["display_name"] as? String ?? record["name"] as? String,
                contextLength: record["max_input_tokens"] as? Int ?? record["context_length"] as? Int,
                maximumOutputTokens: record["max_tokens"] as? Int ?? record["max_output_tokens"] as? Int,
                supportedReasoningEfforts: effort.map { effort in
                    ["max", "xhigh", "high", "medium", "low"].filter { supports(effort[$0]) }
                },
                supportedThinkingTypes: types.map { types in
                    ["adaptive", "enabled", "disabled"].filter { supports(types[$0]) }
                })
        }
        let more = envelope["has_more"] as? Bool == true
        let cursor = envelope["last_id"] as? String
        guard !more || (cursor.map { !$0.isEmpty && $0.count <= 512 } == true && !records.isEmpty) else {
            throw BattlefieldError.invalidResponse
        }
        return (models, more ? cursor : nil)
    }

    static func usage(_ object: [String: Any], fallback: TokenUsage) -> TokenUsage {
        func count(_ key: String) -> Int? {
            guard let number = object[key] as? Int, (0...1_000_000_000).contains(number) else { return nil }
            return number
        }
        let input = count("input_tokens").map {
            $0 + (count("cache_creation_input_tokens") ?? 0) + (count("cache_read_input_tokens") ?? 0)
        }
        let output = count("output_tokens")
        return TokenUsage(
            input: input ?? fallback.input, output: output ?? fallback.output,
            cached: count("cache_read_input_tokens"), estimated: input == nil || output == nil)
    }

    static func finishReason(_ value: String?) -> String? {
        switch value {
        case "end_turn", "stop_sequence": "stop"
        case "max_tokens", "model_context_window_exceeded": "length"
        case "refusal", "tool_use", "pause_turn": "error"
        default: value
        }
    }

    static func decodeBlock(_ object: [String: Any]) throws -> AnthropicContentBlock {
        guard let type = object["type"] as? String, ["text", "thinking", "redacted_thinking"].contains(type) else {
            throw BattlefieldError.invalidResponse
        }
        return AnthropicContentBlock(
            type: type, text: object["text"] as? String, thinking: object["thinking"] as? String,
            signature: object["signature"] as? String, data: object["data"] as? String)
    }

    static func decodeReply(_ data: Data, messages: [AIMessage], apiKey: String) throws -> AIReply {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIHTTPError(status: 200, providerResponse: ProviderDiagnostics.response(data, apiKey: apiKey))
        }
        if ProviderDiagnostics.hasError(object) {
            throw AIHTTPError(status: 200, providerResponse: ProviderDiagnostics.response(data, apiKey: apiKey))
        }
        guard object["type"] as? String == "message", let content = object["content"] as? [[String: Any]],
            let reason = object["stop_reason"] as? String
        else { throw AIHTTPError(status: 200, providerResponse: ProviderDiagnostics.response(data, apiKey: apiKey)) }
        var accumulator = AnthropicStreamAccumulator(messages: messages, apiKey: apiKey)
        for block in content { try accumulator.append(try decodeBlock(block)) }
        accumulator.finishReason = finishReason(reason)
        if let usage = object["usage"] as? [String: Any] { accumulator.mergeUsage(usage) }
        let reply = accumulator.reply
        if reply.providerFailed {
            throw AIHTTPError(
                status: 200, providerResponse: ProviderDiagnostics.response(data, apiKey: apiKey), partialReply: reply)
        }
        return reply
    }
}

struct AnthropicStreamAccumulator: CompletionStreamAccumulator {
    let messages: [AIMessage]
    let apiKey: String
    private(set) var blocks: [AnthropicContentBlock] = []
    private var openBlock: Int?
    private var started = false
    private var usageFields: [String: Any] = [:]
    private var contentBytes = 0
    private var generatedBytes = 0
    private var usageUpdated = false
    private(set) var text = ""
    private(set) var reasoning: AIReasoning?
    var finishReason: String?
    var done = false
    var maximumContentBytes = AIResponseLimits.contentBytes

    init(messages: [AIMessage], apiKey: String, maximumContentBytes: Int = AIResponseLimits.contentBytes) {
        self.messages = messages
        self.apiKey = apiKey
        self.maximumContentBytes = maximumContentBytes
    }

    var contentBlocks: [AnthropicContentBlock]? { blocks.isEmpty ? nil : blocks }
    var reportedUsage: TokenUsage? {
        usageFields.isEmpty ? nil : AnthropicMessages.usage(usageFields, fallback: estimatedUsage)
    }
    private var estimatedUsage: TokenUsage {
        .estimate(messages: messages, outputBytes: generatedBytes)
    }
    var usage: TokenUsage {
        var usage = reportedUsage ?? estimatedUsage
        // message_start reports only the initial output count. Estimate until final cumulative usage arrives.
        if finishReason == nil {
            usage.output = max(usage.output, estimatedUsage.output)
            usage.total = usage.input + usage.output
            usage.estimated = true
        }
        return usage
    }
    var isFinal: Bool { finishReason != nil && reportedUsage != nil }
    var isComplete: Bool { done }
    var shouldPublish: Bool { usageUpdated || done }
    var reply: AIReply {
        AIReply(
            text: text, usage: usage, finishReason: finishReason, reasoning: reasoning, contentBlocks: contentBlocks)
    }

    mutating func append(_ block: AnthropicContentBlock) throws {
        guard blocks.count < 4096, block.byteCount <= maximumContentBytes - contentBytes else {
            throw BattlefieldError.responseTooLarge
        }
        contentBytes += block.byteCount
        blocks.append(block)
        if let value = block.text {
            text += value
            generatedBytes += value.utf8.count
        }
        if let value = block.thinking {
            if reasoning == nil { reasoning = AIReasoning(content: "") } else { reasoning?.content += "\n\n" }
            reasoning?.content += value
            generatedBytes += value.utf8.count
        }
    }

    mutating func mergeUsage(_ usage: [String: Any]) {
        usageUpdated = true
        for key in ["input_tokens", "output_tokens", "cache_creation_input_tokens", "cache_read_input_tokens"] {
            if let number = usage[key] as? Int, (0...1_000_000_000).contains(number) { usageFields[key] = number }
        }
    }

    mutating func consume(_ payload: String) throws {
        usageUpdated = false
        let data = Data(payload.utf8)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = object["type"] as? String
        else {
            throw AIHTTPError(
                status: 200, providerResponse: ProviderDiagnostics.response(data, apiKey: apiKey), partialReply: reply)
        }
        if type == "error" || ProviderDiagnostics.hasError(object) {
            throw AIHTTPError(
                status: 200, providerResponse: ProviderDiagnostics.response(data, apiKey: apiKey), partialReply: reply)
        }
        switch type {
        case "message_start":
            guard !started, let message = object["message"] as? [String: Any] else {
                throw BattlefieldError.invalidResponse
            }
            started = true
            if let usage = message["usage"] as? [String: Any] { mergeUsage(usage) }
        case "content_block_start":
            guard started, openBlock == nil, object["index"] as? Int == blocks.count,
                let block = object["content_block"] as? [String: Any]
            else { throw BattlefieldError.invalidResponse }
            try append(try AnthropicMessages.decodeBlock(block))
            openBlock = blocks.count - 1
        case "content_block_delta":
            guard let index = openBlock, object["index"] as? Int == index,
                let delta = object["delta"] as? [String: Any]
            else { throw BattlefieldError.invalidResponse }
            let key: WritableKeyPath<AnthropicContentBlock, String?>
            let fragment: String
            switch delta["type"] as? String {
            case "text_delta":
                guard blocks[index].type == "text", let text = delta["text"] as? String else {
                    throw BattlefieldError.invalidResponse
                }
                key = \.text
                fragment = text
            case "thinking_delta":
                guard blocks[index].type == "thinking", let thinking = delta["thinking"] as? String else {
                    throw BattlefieldError.invalidResponse
                }
                key = \.thinking
                fragment = thinking
            case "signature_delta":
                guard blocks[index].type == "thinking", let signature = delta["signature"] as? String else {
                    throw BattlefieldError.invalidResponse
                }
                key = \.signature
                fragment = signature
            default: return
            }
            guard fragment.utf8.count <= maximumContentBytes - contentBytes else {
                throw BattlefieldError.responseTooLarge
            }
            contentBytes += fragment.utf8.count
            blocks[index][keyPath: key] = (blocks[index][keyPath: key] ?? "") + fragment
            if key == \.text {
                text += fragment
                generatedBytes += fragment.utf8.count
            } else if key == \.thinking {
                if reasoning == nil { reasoning = AIReasoning(content: "") }
                reasoning?.content += fragment
                generatedBytes += fragment.utf8.count
            }
        case "content_block_stop":
            guard let index = openBlock, object["index"] as? Int == index else {
                throw BattlefieldError.invalidResponse
            }
            openBlock = nil
        case "message_delta":
            guard started, openBlock == nil else { throw BattlefieldError.invalidResponse }
            if let reason = (object["delta"] as? [String: Any])?["stop_reason"] as? String {
                finishReason = AnthropicMessages.finishReason(reason)
            }
            if let usage = object["usage"] as? [String: Any] { mergeUsage(usage) }
            if reply.providerFailed {
                throw AIHTTPError(
                    status: 200, providerResponse: ProviderDiagnostics.response(data, apiKey: apiKey),
                    partialReply: reply)
            }
        case "message_stop":
            guard started, openBlock == nil, finishReason != nil else { throw BattlefieldError.incompleteStream }
            done = true
        default: break  // Ping and future event types do not end a response.
        }
    }
}
