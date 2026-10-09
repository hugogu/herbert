import Foundation
import XCTest

@testable import HerbertBattlefield

final class AnthropicMessagesTests: XCTestCase {
    private func request(model: AIModel = AIModel(id: "fixture"), cap: Int? = nil, extra: String = "{}")
        -> AICompletionRequest
    {
        var preset = ModelPreset(model: model)
        preset.parameters.extraJSON = extra
        return AICompletionRequest(
            participant: CompetitionParticipant(
                entrant: Entrant(provider: ProviderConfiguration(kind: .anthropic), preset: preset), apiKey: "fixture"),
            messages: [AIMessage(role: "system", content: "Rules"), AIMessage(role: "user", content: "Puzzle")],
            maxOutputTokens: cap)
    }

    func testNativeRequestUsesSystemFieldMandatoryCapAndCapabilityBasedThinking() throws {
        let model = AIModel(
            id: "fixture", maximumOutputTokens: 100_000, supportedReasoningEfforts: ["max", "high"],
            supportedThinkingTypes: ["adaptive", "enabled"])
        let body = try AnthropicMessages.body(for: request(model: model))
        XCTAssertEqual(body["model"] as? String, "fixture")
        XCTAssertEqual(body["system"] as? String, "Rules")
        XCTAssertEqual((body["messages"] as? [[String: String]])?.map { $0["role"] }, ["user"])
        XCTAssertEqual(body["max_tokens"] as? Int, 100_000)
        XCTAssertEqual((body["thinking"] as? [String: String])?["type"], "adaptive")
        XCTAssertEqual((body["output_config"] as? [String: String])?["effort"], "max")
        XCTAssertNil(body["reasoning_effort"])
        XCTAssertNil(body["stream_options"])
        XCTAssertEqual(try AnthropicMessages.body(for: request())["max_tokens"] as? Int, 65_536)
        XCTAssertNil(try AnthropicMessages.body(for: request())["thinking"], "Do not guess unknown model capabilities")
        XCTAssertEqual(try AnthropicMessages.body(for: request(cap: 90_000))["max_tokens"] as? Int, 90_000)
        XCTAssertEqual(
            try AnthropicMessages.body(for: request(model: model, cap: 200_000))["max_tokens"] as? Int, 100_000)
    }

    func testManualThinkingBudgetRespectsMatchCapAndExplicitOverridesWin() throws {
        let model = AIModel(id: "manual", supportedThinkingTypes: ["enabled"])
        let body = try AnthropicMessages.body(for: request(model: model, cap: 4096))
        XCTAssertEqual((body["thinking"] as? [String: Any])?["budget_tokens"] as? Int, 3072)
        XCTAssertNil(try AnthropicMessages.body(for: request(model: model, cap: 1024))["thinking"])
        XCTAssertEqual(
            (try AnthropicMessages.body(for: request(model: model, extra: #"{"thinking":{"type":"disabled"}}"#))[
                "thinking"]
                as? [String: String])?["type"], "disabled")
        XCTAssertThrowsError(
            try AnthropicMessages.body(
                for: request(cap: 100, extra: #"{"thinking":{"type":"enabled","budget_tokens":1024}}"#)))
        XCTAssertThrowsError(try AnthropicMessages.body(for: request(extra: #"{"enable_thinking":true}"#)))
        XCTAssertThrowsError(try AnthropicMessages.body(for: request(extra: #"{"max_tokens":10}"#)))
    }

    func testDiscoveryDecodesNamesTokenLimitsThinkingAndEffortWithoutGuessingIDs() throws {
        let data = Data(
            #"{"data":[{"id":"native","display_name":"Native model","max_input_tokens":200000,"max_tokens":128000,"capabilities":{"thinking":{"supported":true,"types":{"adaptive":{"supported":true},"enabled":{"supported":false}}},"effort":{"supported":true,"high":{"supported":true},"max":{"supported":true}}}},{"id":"alias","name":"Gateway alias"},{"id":"retired","lifecycle":"retired"}],"has_more":true,"last_id":"retired"}"#
                .utf8)
        let page = try AnthropicMessages.decodeModels(data)
        XCTAssertEqual(page.next, "retired")
        XCTAssertEqual(page.models.map(\.id), ["native", "alias"])
        XCTAssertEqual(page.models[0].name, "Native model")
        XCTAssertEqual(page.models[0].maximumOutputTokens, 128_000)
        XCTAssertEqual(page.models[0].contextLength, 200_000)
        XCTAssertEqual(page.models[0].supportedReasoningEfforts, ["max", "high"])
        XCTAssertEqual(page.models[0].supportedThinkingTypes, ["adaptive"])
        XCTAssertNil(page.models[1].supportedThinkingTypes)
        XCTAssertThrowsError(try AnthropicMessages.decodeModels(Data(#"{"data":[],"has_more":true}"#.utf8)))
    }

    func testJSONReplyPreservesOrderedSignedAndRedactedBlocksForJudgeRetryAndHistory() throws {
        let data = Data(
            #"{"type":"message","content":[{"type":"thinking","thinking":"Check walls","signature":"signed-original"},{"type":"redacted_thinking","data":"opaque-original"},{"type":"text","text":"```h\nz\n```"}],"stop_reason":"end_turn","usage":{"input_tokens":10,"cache_creation_input_tokens":20,"cache_read_input_tokens":30,"output_tokens":40}}"#
                .utf8)
        let reply = try AnthropicMessages.decodeReply(data, messages: [], apiKey: "fixture")
        XCTAssertEqual(reply.text, "```h\nz\n```")
        XCTAssertEqual(reply.reasoning?.content, "Check walls")
        XCTAssertEqual(reply.usage.input, 60)
        XCTAssertEqual(reply.usage.cached, 30)
        XCTAssertEqual(reply.usage.total, 100)
        XCTAssertFalse(reply.usage.estimated)
        let messages = BattlefieldPrompt.retryMessages(request().messages, reply: reply, feedback: "Unknown procedure")
        let retry = AICompletionRequest(participant: request().participant, messages: messages, maxOutputTokens: nil)
        let body = try AnthropicMessages.body(for: retry)
        let native = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let blocks = try XCTUnwrap(native[1]["content"] as? [[String: String]])
        XCTAssertEqual(blocks[0]["signature"], "signed-original")
        XCTAssertEqual(blocks[1]["data"], "opaque-original")
        XCTAssertEqual(blocks[2]["text"], reply.text)
        XCTAssertNil(native[1]["reasoning_content"])
        var attempt = AnswerAttempt(number: 1)
        attempt.contentBlocks = reply.contentBlocks
        attempt.reasoning = reply.reasoning
        XCTAssertEqual(try JSONDecoder().decode(AnswerAttempt.self, from: JSONEncoder().encode(attempt)), attempt)
        let legacy = Data(#"{"role":"assistant","content":"s"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(AIMessage.self, from: legacy).contentBlocks)
    }

    func testStreamCumulativeUsageAndStopLifecycle() throws {
        var stream = AnthropicStreamAccumulator(messages: [], apiKey: "fixture")
        try stream.consume(
            #"{"type":"message_start","message":{"usage":{"input_tokens":5,"cache_read_input_tokens":10,"cache_creation_input_tokens":20,"output_tokens":1}}}"#
        )
        try stream.consume(
            #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}}"#
        )
        try stream.consume(
            #"{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"Plan"}}"#)
        try stream.consume(
            #"{"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"signed"}}"#)
        try stream.consume(#"{"type":"content_block_stop","index":0}"#)
        try stream.consume(#"{"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}}"#)
        try stream.consume(#"{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"s"}}"#)
        try stream.consume(#"{"type":"content_block_stop","index":1}"#)
        try stream.consume(#"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":9}}"#)
        try stream.consume(#"{"type":"ping"}"#)
        XCTAssertFalse(stream.isComplete, "A stop reason does not replace the terminal message_stop event")
        XCTAssertEqual(stream.usage.input, 35)
        XCTAssertEqual(stream.usage.output, 9, "Cumulative usage must not be added per event")
        try stream.consume(#"{"type":"message_stop"}"#)
        XCTAssertTrue(stream.done)
        XCTAssertEqual(stream.text, "s")
        XCTAssertEqual(stream.reasoning?.content, "Plan")
        XCTAssertEqual(stream.contentBlocks?[0].signature, "signed")
    }

    func testInitialUsageDoesNotFreezeLiveOutputEstimatesOrPublishEveryThinkingDelta() throws {
        var stream = AnthropicStreamAccumulator(messages: [], apiKey: "fixture")
        try stream.consume(#"{"type":"message_start","message":{"usage":{"input_tokens":5,"output_tokens":1}}}"#)
        XCTAssertTrue(stream.shouldPublish)
        try stream.consume(
            #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":""}}"#)
        try stream.consume(
            "{\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"thinking_delta\",\"thinking\":\"\(String(repeating: "a", count: 400))\"}}"
        )
        XCTAssertEqual(stream.usage.output, 100)
        XCTAssertTrue(stream.usage.estimated)
        XCTAssertFalse(stream.shouldPublish, "Thinking deltas should use the shared update throttle")
        try stream.consume(#"{"type":"content_block_stop","index":0}"#)
        try stream.consume(#"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":25}}"#)
        XCTAssertTrue(stream.shouldPublish)
        XCTAssertEqual(stream.usage.output, 25)
        XCTAssertFalse(stream.usage.estimated)
    }

    func testLimitsRefusalsAndOverloadsAreNotJudgeRejections() throws {
        for reason in ["max_tokens", "model_context_window_exceeded"] {
            XCTAssertEqual(AnthropicMessages.finishReason(reason), "length")
        }
        let refusal = Data(
            #"{"type":"message","content":[{"type":"text","text":"refused"}],"stop_reason":"refusal"}"#.utf8)
        XCTAssertThrowsError(try AnthropicMessages.decodeReply(refusal, messages: [], apiKey: "fixture")) {
            XCTAssertEqual(($0 as? AIHTTPError)?.partialReply?.finishReason, "error")
        }
        for type in ["overloaded_error", "rate_limit_error"] {
            var stream = AnthropicStreamAccumulator(messages: [], apiKey: "secret")
            try stream.consume(#"{"type":"message_start","message":{}}"#)
            try stream.consume(
                #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"Partial"}}"#)
            XCTAssertThrowsError(
                try stream.consume("{\"type\":\"error\",\"error\":{\"type\":\"\(type)\",\"message\":\"secret\"}}")
            ) {
                XCTAssertEqual(ProviderDiagnostics.classify($0), .overloaded)
                XCTAssertEqual(($0 as? AIHTTPError)?.partialReply?.reasoning?.content, "Partial")
                XCTAssertFalse(($0 as? AIHTTPError)?.providerResponse?.contains("secret") == true)
            }
        }
        XCTAssertEqual(ProviderDiagnostics.classify(AIHTTPError(status: 529)), .overloaded)
        var stream = AnthropicStreamAccumulator(messages: [], apiKey: "fixture", maximumContentBytes: 4)
        try stream.consume(#"{"type":"message_start","message":{}}"#)
        try stream.consume(
            #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"1234"}}"#)
        XCTAssertThrowsError(
            try stream.consume(
                #"{"type":"content_block_delta","index":0,"delta":{"type":"signature_delta","signature":"5"}}"#)
        ) {
            XCTAssertEqual($0 as? BattlefieldError, .responseTooLarge)
        }
    }
}
