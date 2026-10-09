import Foundation
import HerbertCore
import XCTest

@testable import HerbertBattlefield

@MainActor
final class AITransportTests: XCTestCase {
    private let anthropicAnswer =
        #"{"type":"message","content":[{"type":"text","text":"```h\ns\n```"}],"stop_reason":"end_turn","usage":{"input_tokens":10,"output_tokens":20}}"#

    func testAnthropicDiscoveryPaginatesAndAuthenticatesUsingNativeHeaders() async throws {
        let provider = provider(kind: .anthropic)
        let first = HTTPStub(body: #"{"data":[{"id":"a","display_name":"Model A"}],"has_more":true,"last_id":"a"}"#)
        let second = HTTPStub(body: #"{"data":[{"id":"b","max_tokens":8192}],"has_more":false}"#)
        BattlefieldURLProtocol.registry.addSequence(
            [first, second], host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let models = try await client().models(provider: provider, apiKey: "test-only-secret")
        XCTAssertEqual(models.map(\.id), ["a", "b"])
        XCTAssertEqual(models[0].name, "Model A")
        XCTAssertEqual(models[1].maximumOutputTokens, 8192)
        XCTAssertEqual(second.requests.first?.url?.query, "after_id=a")
        for request in first.requests + second.requests {
            XCTAssertEqual(request.url?.path, "/v1/models")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-only-secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        }
        let repeated = HTTPStub(body: first.body)
        BattlefieldURLProtocol.registry.add(repeated, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        do {
            _ = try await client().models(provider: provider, apiKey: "fixture")
            XCTFail("Repeated cursors must not loop forever")
        } catch { XCTAssertEqual(error as? BattlefieldError, .invalidResponse) }
        XCTAssertEqual(repeated.requests.count, 2)
    }

    func testAnthropicMessagesRequestAndJSONFallbackUseNativeShape() async throws {
        let provider = provider(kind: .anthropic)
        let stub = HTTPStub(body: anthropicAnswer)
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let reply = try await client().complete(
            AICompletionRequest(
                participant: CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "native"))),
                    apiKey: "fixture"),
                messages: [
                    AIMessage(role: "system", content: BattlefieldPrompt.rules),
                    AIMessage(role: "user", content: "Puzzle"),
                ],
                maxOutputTokens: 4096)
        ) { _ in }
        XCTAssertEqual(try BattlefieldJudge.extractProgram(reply.text), "s")
        XCTAssertEqual(reply.usage.total, 30)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "fixture")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(stub.bodies.first)) as? [String: Any])
        XCTAssertEqual(body["system"] as? String, BattlefieldPrompt.rules)
        XCTAssertEqual(body["max_tokens"] as? Int, 4096)
        XCTAssertNil(body["stream_options"])
        XCTAssertNil(body["max_completion_tokens"])
        XCTAssertEqual((body["messages"] as? [[String: String]])?.count, 1)
    }

    func testAnthropicStreamingStopsOnlyAtMessageStopAndRetainsIncompleteOutput() async throws {
        let events = [
            #"{"type":"message_start","message":{"usage":{"input_tokens":10,"cache_read_input_tokens":20,"output_tokens":1}}}"#,
            #"{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"Plan","signature":"signed"}}"#,
            #"{"type":"content_block_stop","index":0}"#,
            #"{"type":"content_block_start","index":1,"content_block":{"type":"text","text":"```h\ns\n```"}}"#,
            #"{"type":"content_block_stop","index":1}"#,
            #"{"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":15}}"#,
        ]
        for complete in [false, true] {
            let provider = provider(kind: .anthropic)
            let stream = events + (complete ? [#"{"type":"message_stop"}"#] : [])
            let stub = HTTPStub(body: stream.map { "data: \($0)\n\n" }.joined(), contentType: "text/event-stream")
            BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
            let collector = ProgressCollector()
            do {
                let reply = try await client().complete(
                    AICompletionRequest(
                        participant: CompetitionParticipant(
                            entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "native"))),
                            apiKey: "fixture"),
                        messages: [], maxOutputTokens: 4096)
                ) { await collector.append($0) }
                XCTAssertTrue(complete)
                XCTAssertEqual(reply.usage.input, 30)
                XCTAssertEqual(reply.usage.output, 15)
                XCTAssertEqual(reply.contentBlocks?[0].signature, "signed")
            } catch {
                XCTAssertFalse(complete)
                XCTAssertEqual(error as? BattlefieldError, .incompleteStream)
            }
            let progress = await collector.items
            XCTAssertEqual(progress.last?.text, "```h\ns\n```")
            XCTAssertEqual(progress.last?.reasoning?.content, "Plan")
            XCTAssertEqual(progress.last?.isFinal, complete)
            XCTAssertTrue(stub.stopped)
        }
    }

    func testAnthropicOverloadBackoffAndTokenLimitIntegrateWithMatchEngine() async throws {
        for limit in [false, true] {
            let provider = provider(kind: .anthropic)
            let failure = HTTPStub(
                body: #"{"type":"error","error":{"type":"overloaded_error","message":"Busy"}}"#,
                status: 529, headers: ["Retry-After": "30"])
            let response = HTTPStub(
                body: limit ? anthropicAnswer.replacingOccurrences(of: "end_turn", with: "max_tokens") : anthropicAnswer
            )
            let sequence = limit ? [response] : [failure, response]
            BattlefieldURLProtocol.registry.addSequence(
                sequence, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
            let result = try await BattlefieldEngine(
                client: client(),
                retrySleep: { delay in
                    XCTAssertGreaterThanOrEqual(delay, 30)
                }
            ).run(
                configuration: CompetitionConfiguration(), problems: Array(try ProblemCatalog.bundled().prefix(1)),
                participants: [
                    CompetitionParticipant(
                        entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "native"))),
                        apiKey: "fixture")
                ]
            ) { _ in }
            let answer = try XCTUnwrap(result.entrants.first?.answers.first)
            XCTAssertEqual(answer.status, limit ? .burnout : .solved)
            XCTAssertEqual(answer.attempts.count, limit ? 1 : 2)
            XCTAssertEqual(answer.attempts.last?.contentBlocks?.last?.text, "```h\ns\n```")
            XCTAssertEqual(answer.attempts.last?.requestedMaxOutputTokens, 65_536)
            XCTAssertEqual(response.requests.count, 1)
            if !limit { XCTAssertNil(answer.attempts.first?.evaluation) }
            let restored = try JSONDecoder().decode(CompetitionResult.self, from: JSONEncoder().encode(result))
            XCTAssertEqual(restored.entrants[0].answers[0], answer)
        }
    }

    func testAnthropicJudgeRetryReplaysSignedContentWithTheSameSharedRules() async throws {
        let provider = provider(kind: .anthropic)
        let rejected = HTTPStub(
            body:
                #"{"type":"message","content":[{"type":"thinking","thinking":"Plan","signature":"original-signature"},{"type":"text","text":"```h\nz\n```"}],"stop_reason":"end_turn"}"#
        )
        let accepted = HTTPStub(body: anthropicAnswer)
        BattlefieldURLProtocol.registry.addSequence(
            [rejected, accepted], host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let result = try await BattlefieldEngine(client: client()).run(
            configuration: .init(), problems: Array(try ProblemCatalog.bundled().prefix(1)),
            participants: [
                CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "native"))),
                    apiKey: "fixture")
            ]
        ) { _ in }
        XCTAssertEqual(result.entrants[0].answers[0].status, .solved)
        XCTAssertEqual(result.entrants[0].answers[0].attempts.count, 2)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(accepted.bodies.first)) as? [String: Any])
        XCTAssertEqual(body["system"] as? String, BattlefieldPrompt.rules)
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 3)
        let blocks = try XCTUnwrap(messages[1]["content"] as? [[String: String]])
        XCTAssertEqual(blocks[0]["signature"], "original-signature")
        XCTAssertEqual(blocks[1]["text"], "```h\nz\n```")
        XCTAssertTrue((messages[2]["content"] as? String)?.contains("Rejected") == true)
    }

    func testUnlimitedRequestOmitsTokenCapAndUsesDiscoveredMaximumReasoningEffort() async throws {
        let provider = provider(kind: .openRouter)
        let stub = HTTPStub(body: #"{"choices":[{"message":{"content":"s"},"finish_reason":"stop"}]}"#)
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let model = AIModel(id: "m", supportedParameters: ["reasoning"], supportedReasoningEfforts: ["xhigh", "high"])
        _ = try await client().complete(
            AICompletionRequest(
                participant: CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: ModelPreset(model: model)), apiKey: "fixture"),
                messages: [], maxOutputTokens: nil)
        ) { _ in }
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(stub.bodies.first)) as? [String: Any])
        XCTAssertNil(body["max_tokens"])
        XCTAssertNil(body["max_completion_tokens"])
        XCTAssertNil(body["enable_thinking"])
        let reasoning = try XCTUnwrap(body["reasoning"] as? [String: Any])
        XCTAssertEqual(reasoning["enabled"] as? Bool, true)
        XCTAssertEqual(reasoning["effort"] as? String, "xhigh")
    }

    func testGeminiDiscoveryStreamingUsageAndThinkingRequest() async throws {
        let provider = provider(kind: .gemini)
        let host = try XCTUnwrap(URL(string: provider.baseURL)?.host)
        let discovery = HTTPStub(body: #"{"data":[{"id":"models/gemini-2.5-flash"}]}"#)
        BattlefieldURLProtocol.registry.add(discovery, host: host)
        let models = try await client().models(provider: provider, apiKey: "fixture")
        XCTAssertEqual(discovery.requests.first?.url?.path, "/v1/models")
        XCTAssertNil(discovery.requests.first?.url?.query)
        let stub = HTTPStub(
            body: """
                data: {"choices":[{"delta":{"content":"s"},"finish_reason":"stop"}]}

                data: {"choices":[],"usage":{"prompt_tokens":20,"completion_tokens":10,"total_tokens":30}}

                data: [DONE]

                """, contentType: "text/event-stream")
        BattlefieldURLProtocol.registry.add(stub, host: host)
        let reply = try await client().complete(
            AICompletionRequest(
                participant: CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: ModelPreset(model: try XCTUnwrap(models.first))),
                    apiKey: "fixture"), messages: [], maxOutputTokens: nil)
        ) { _ in }
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(stub.bodies.first)) as? [String: Any])
        XCTAssertEqual(body["model"] as? String, "models/gemini-2.5-flash")
        XCTAssertEqual(body["reasoning_effort"] as? String, "high")
        XCTAssertNil(body["enable_thinking"])
        XCTAssertNil(body["max_tokens"])
        XCTAssertEqual((body["stream_options"] as? [String: Bool])?["include_usage"], true)
        XCTAssertEqual(reply.text, "s")
        XCTAssertEqual(reply.usage.total, 30)
        XCTAssertFalse(reply.usage.estimated)
    }

    func testInBandFailuresAreClassifiedRetriedAndPersistedThroughTheHTTPClient() async throws {
        let cases: [(String, ProblemAnswerStatus, Int)] = [
            (#"{"error":{"code":429,"details":[{"retryDelay":"28s"}],"message":"Quota exceeded"}}"#, .overloaded, 2),
            (#"{"choices":[{"error":{"code":503,"message":"high demand"}}]}"#, .overloaded, 2),
            (
                #"{"error":{"code":502,"message":"Streaming request exceeded the 900 second wall-clock limit."}}"#,
                .timedout, 1
            ),
            (#"{"error":{"code":502,"message":"Network connection lost."}}"#, .tempUnavailable, 2),
            (#"{"error":{"code":403,"message":"Forbidden"}}"#, .accessDenied, 1),
        ]
        for (payload, status, attempts) in cases {
            let provider = provider()
            let stub = HTTPStub(
                body:
                    "data: {\"choices\":[{\"delta\":{\"reasoning\":\"Partial planning\"}}],\"usage\":{\"prompt_tokens\":10,\"completion_tokens\":20}}\n\n"
                    + "data: \(payload)\n\n", contentType: "text/event-stream")
            BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
            var configuration = CompetitionConfiguration()
            configuration.attemptsPerProblem = 2
            let result = try await BattlefieldEngine(client: client(), retrySleep: { _ in }).run(
                configuration: configuration, problems: Array(try ProblemCatalog.bundled().prefix(2)),
                participants: [
                    CompetitionParticipant(
                        entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "m"))),
                        apiKey: "fixture")
                ]
            ) { _ in }
            let answer = try XCTUnwrap(result.entrants.first?.answers.first)
            XCTAssertEqual(answer.status, status)
            XCTAssertEqual(answer.attempts.count, attempts)
            XCTAssertTrue(
                answer.attempts.allSatisfy {
                    $0.evaluation == nil && $0.finishedAt != nil && $0.reasoning?.content == "Partial planning"
                        && $0.usage.output == 20 && $0.usage.partial
                })
            XCTAssertEqual(result.entrants[0].answers[1].status, status == .accessDenied ? .cancelled : status)
            XCTAssertEqual(stub.requests.count, status == .accessDenied ? 1 : 2 * attempts)
            let restored = try JSONDecoder().decode(CompetitionResult.self, from: JSONEncoder().encode(result))
            XCTAssertEqual(restored.entrants[0].answers[0].status, status)
            XCTAssertEqual(restored.entrants[0].answers[0].attempts, answer.attempts)
        }
    }

    func testClientPreservesResourceDeadlineSeparateFromInactivityTimeout() {
        let configuration = URLSessionConfiguration.ephemeral
        let resourceDeadline = configuration.timeoutIntervalForResource
        _ = OpenAICompatibleClient(configuration: configuration)
        XCTAssertEqual(configuration.timeoutIntervalForResource, resourceDeadline)
        XCTAssertGreaterThan(resourceDeadline, 600)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 600)
    }

    func testHTTPAndInBand429RetainRetryAfterHeaderAndGeminiRetryInfo() async throws {
        for (status, contentType, body) in [
            (
                429, "application/json",
                #"[{"error":{"code":429,"details":[{"retryDelay":"28s"}],"message":"Please retry in 28.626942979s."}}]"#
            ),
            (200, "application/json", #"{"error":{"code":429,"message":"Please retry in 28.626942979s."}}"#),
            (
                200, "text/event-stream",
                "data: {\"error\":{\"code\":429,\"message\":\"Please retry in 28.626942979s.\"}}\n\n"
            ),
        ] {
            let provider = provider(kind: .gemini)
            let stub = HTTPStub(
                body: body, contentType: contentType,
                status: status, headers: ["Retry-After": "60"])
            BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
            do {
                _ = try await client().complete(
                    AICompletionRequest(
                        participant: CompetitionParticipant(
                            entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "m"))),
                            apiKey: "fixture"),
                        messages: [], maxOutputTokens: nil)
                ) { _ in }
                XCTFail("Expected an HTTP 429")
            } catch let error as AIHTTPError {
                XCTAssertEqual(error.retryAfter, 60)
                XCTAssertEqual(ProviderDiagnostics.classify(error), .overloaded)
                XCTAssertEqual(ProviderRetryPolicy.delay(for: error, consecutiveFailure: 1, jitter: 0), 60)
                XCTAssertTrue(error.providerResponse?.contains("28.626942979s") == true)
            }
        }
    }

    func testInBandStreamErrorsRetainFinishReasonPartialOutputAndUsage() async throws {
        for terminal in [
            #"{"choices":[{"delta":{},"finish_reason":"error"}]}"#,
            #"{"error":{"message":"upstream timeout test-only-secret","code":502},"choices":[{"delta":{},"finish_reason":"error"}]}"#,
            #"{"choices":[{"delta":{},"error":{"message":"provider disconnected"},"finish_reason":"error"}]}"#,
            #"{"error":{"message":"generation failed"}}"#,
        ] {
            let provider = provider()
            let stub = HTTPStub(
                body:
                    "data: {\"choices\":[{\"delta\":{\"reasoning\":\"Still planning\"}}],\"usage\":{\"prompt_tokens\":100,\"completion_tokens\":23}}\n\n"
                    + "data: \(terminal)\n\ndata: [DONE]\n\n", contentType: "text/event-stream")
            BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
            let collector = ProgressCollector()
            do {
                _ = try await client().complete(
                    AICompletionRequest(
                        participant: CompetitionParticipant(
                            entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "m"))),
                            apiKey: "test-only-secret"), messages: [], maxOutputTokens: 65_536)
                ) { await collector.append($0) }
                XCTFail("Provider error must not become a judgeable answer")
            } catch let error as AIHTTPError {
                XCTAssertEqual(error.status, 200)
                XCTAssertEqual(error.partialReply?.finishReason, "error")
                XCTAssertEqual(error.partialReply?.reasoning?.content, "Still planning")
                XCTAssertEqual(error.partialReply?.usage.output, 23)
                XCTAssertFalse(error.providerResponse?.contains("test-only-secret") == true)
            }
            let progress = await collector.items
            XCTAssertEqual(progress.last?.reasoning?.content, "Still planning")
            XCTAssertEqual(progress.last?.isFinal, false)
            XCTAssertTrue(stub.stopped)
        }
    }

    func testJSONProviderFailuresAreNotCompletedAnswersAndNullErrorsAreAllowed() throws {
        for reason in ["error", "content_filter"] {
            let body = """
                {"choices":[{"message":{"content":"s","reasoning":"Plan"},"finish_reason":"\(reason)"}],"usage":{"prompt_tokens":5,"completion_tokens":10}}
                """
            XCTAssertThrowsError(try OpenAICompatibleClient.decodeReply(Data(body.utf8), messages: [])) { error in
                let reply = (error as? AIHTTPError)?.partialReply
                XCTAssertEqual(reply?.text, "s")
                XCTAssertEqual(reply?.reasoning?.content, "Plan")
                XCTAssertEqual(reply?.finishReason, reason)
                XCTAssertEqual(reply?.usage.output, 10)
            }
        }
        let body = #"{"error":null,"choices":[{"error":null,"message":{"content":"s"},"finish_reason":"stop"}]}"#
        XCTAssertEqual(try OpenAICompatibleClient.decodeReply(Data(body.utf8), messages: []).text, "s")
        var accumulator = ChatStreamAccumulator(messages: [])
        try accumulator.consume(
            #"{"error":null,"choices":[{"error":null,"delta":{"content":"s"},"finish_reason":"stop"}]}"#)
        XCTAssertEqual(accumulator.text, "s")
    }

    func testPrematureEOFReportsIncompleteStreamAndFlushesPartialReasoning() async throws {
        let provider = provider()
        let stub = HTTPStub(
            body: "data: {\"choices\":[{\"delta\":{\"reasoning\":\"Still planning\"}}]}\n\n",
            contentType: "text/event-stream")
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let collector = ProgressCollector()
        do {
            _ = try await client().complete(
                AICompletionRequest(
                    participant: CompetitionParticipant(
                        entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "m"))),
                        apiKey: "key"),
                    messages: [], maxOutputTokens: 65_536)
            ) { await collector.append($0) }
            XCTFail("Unfinished stream must not be judged")
        } catch {
            XCTAssertEqual(error as? BattlefieldError, .incompleteStream)
        }
        let progress = await collector.items
        XCTAssertEqual(progress.last?.reasoning?.content, "Still planning")
        XCTAssertEqual(progress.last?.isFinal, false)
    }

    func testSSEPreservesEmptyLinesUnicodeMultilineAndAllLineEndings() throws {
        for separator in ["\n", "\r\n", "\r"] {
            var parser = ServerSentEventParser()
            let bytes =
                (": heartbeat" + separator + "data: 第一行" + separator
                + "data: second line" + separator + separator + "data: [DONE]" + separator + separator).utf8
            var events: [String] = []
            for byte in bytes { if let event = try parser.consume(byte) { events.append(event) } }
            XCTAssertEqual(events, ["第一行\nsecond line", "[DONE]"])
            XCTAssertNil(try parser.finish())
        }
        var parser = ServerSentEventParser()
        for byte in "data: no final newline".utf8 { _ = try parser.consume(byte) }
        XCTAssertEqual(try parser.finish(), "no final newline")
    }

    private func client() -> OpenAICompatibleClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BattlefieldURLProtocol.self]
        return OpenAICompatibleClient(configuration: configuration)
    }

    private func provider(kind: ProviderKind = .compatible) -> ProviderConfiguration {
        var provider = ProviderConfiguration(kind: kind)
        provider.baseURL = "https://\(UUID().uuidString.lowercased()).example/v1"
        return provider
    }

    func testDiscoveryUsesAuthenticatedModelsEndpointAndChatFilter() async throws {
        let provider = provider(kind: .siliconFlow)
        let stub = HTTPStub(body: #"{"data":[{"id":"chat-model"}]}"#)
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let models = try await client().models(provider: provider, apiKey: "test-only-secret")
        XCTAssertEqual(models.map(\.id), ["chat-model"])
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/models")
        XCTAssertEqual(request.url?.query, "sub_type=chat")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only-secret")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testStreamingRequestCapsOutputAndCountsFinalUsageOnce() async throws {
        var provider = provider()
        provider.outputTokenParameter = .maxCompletionTokens
        var preset = ModelPreset(model: AIModel(id: "chat-model"))
        preset.parameters.temperature = 0.2
        preset.parameters.extraJSON = #"{"seed":42}"#
        let stub = HTTPStub(
            body: """
                data: {"choices":[{"delta":{"content":"```h\\ns"},"finish_reason":null}]}

                data: {"choices":[{"delta":{"content":"\\n```"},"finish_reason":"stop"}]}

                data: {"choices":[],"usage":{"prompt_tokens":90,"completion_tokens":12,"total_tokens":102,"prompt_tokens_details":{"cached_tokens":45}}}

                data: [DONE]


                """, contentType: "text/event-stream")
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let collector = ProgressCollector()
        let reply = try await client().complete(
            AICompletionRequest(
                participant: CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: preset), apiKey: "test-only-secret"),
                messages: [AIMessage(role: "user", content: "a puzzle")], maxOutputTokens: 37
            )
        ) { await collector.append($0) }
        XCTAssertEqual(reply.text, "```h\ns\n```")
        XCTAssertEqual(reply.usage.total, 102)
        XCTAssertEqual(reply.usage.cached, 45)
        let progress = await collector.items
        XCTAssertEqual(progress.last?.usage.total, 102)
        XCTAssertEqual(progress.last?.isFinal, true)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/v1/chat/completions")
        let body = try XCTUnwrap(stub.bodies.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "chat-model")
        XCTAssertEqual(json["max_completion_tokens"] as? Int, 37)
        XCTAssertNil(json["max_tokens"])
        XCTAssertEqual(json["seed"] as? Int, 42)
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertNotNil(json["stream_options"])
        XCTAssertNil(json["apiKey"])
    }

    func testLargeWireStreamDoesNotCountSSEMetadataAsModelOutput() async throws {
        let provider = provider()
        // Providers repeat IDs and usage metadata per token. This is >4 MiB on the wire,
        // but only 70 KB of actual reasoning, followed by a valid final answer.
        let chunk =
            "data: {\"id\":\"" + String(repeating: "metadata", count: 64)
            + "\",\"choices\":[{\"delta\":{\"reasoning_content\":\"think. \"}}]}\n\n"
        let body =
            String(repeating: chunk, count: 10_000)
            + "data: {\"choices\":[{\"delta\":{\"content\":\"```h\\ns\\n```\"},\"finish_reason\":\"stop\"}]}\n\n"
            + "data: [DONE]\n\n"
        XCTAssertGreaterThan(body.utf8.count, 4 * 1024 * 1024)
        let stub = HTTPStub(body: body, contentType: "text/event-stream")
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let reply = try await client().complete(
            AICompletionRequest(
                participant: CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "m"))), apiKey: "key"),
                messages: [], maxOutputTokens: 65_536)
        ) { _ in }
        XCTAssertEqual(reply.reasoning?.content, String(repeating: "think. ", count: 10_000))
        XCTAssertEqual(try BattlefieldJudge.extractProgram(reply.text), "s")
        XCTAssertEqual(reply.finishReason, "stop")
        XCTAssertTrue(stub.stopped)
    }

    func testContentAndIndividualEventsRemainBoundedIndependentlyOfWireSize() throws {
        var accumulator = ChatStreamAccumulator(messages: [], maximumContentBytes: 8)
        try accumulator.consume(#"{"choices":[{"delta":{"reasoning":"1234","content":"s"}}]}"#)
        XCTAssertThrowsError(try accumulator.consume(#"{"choices":[{"delta":{"reasoning":"5678"}}]}"#)) {
            XCTAssertEqual($0 as? BattlefieldError, .responseTooLarge)
        }
        XCTAssertEqual(accumulator.text, "s")
        XCTAssertEqual(accumulator.reasoning?.content, "1234")
        func feed(_ input: String, into parser: inout ServerSentEventParser) throws {
            for byte in input.utf8 { _ = try parser.consume(byte) }
        }
        var parser = ServerSentEventParser(maximumEventBytes: 16)
        XCTAssertThrowsError(try feed("data: " + String(repeating: "x", count: 17), into: &parser))
        var multiline = ServerSentEventParser(maximumEventBytes: 16)
        XCTAssertThrowsError(try feed("data: 12345678\ndata: 12345678\n\n", into: &multiline))
        var normal = ServerSentEventParser(maximumEventBytes: 16)
        var events = 0
        for byte in String(repeating: "data: 12345678\n\n", count: 100).utf8 {
            if try normal.consume(byte) != nil { events += 1 }
        }
        XCTAssertEqual(events, 100)
    }

    func testJSONFallbackAndMissingUsageRemainEstimated() async throws {
        let provider = provider(kind: .openRouter)
        let stub = HTTPStub(body: #"{"choices":[{"message":{"content":"s"},"finish_reason":"stop"}]}"#)
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let reply = try await client().complete(
            AICompletionRequest(
                participant: CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "m"))), apiKey: "key"),
                messages: [AIMessage(role: "user", content: "puzzle")], maxOutputTokens: 10
            )
        ) { _ in }
        XCTAssertEqual(reply.text, "s")
        XCTAssertTrue(reply.usage.estimated)
        XCTAssertNil(reply.usage.cached)
        let body = try XCTUnwrap(stub.bodies.first)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["stream_options"])
    }

    func testCancellationAfterHeadersCancelsUnderlyingStream() async throws {
        let provider = provider()
        let stub = HTTPStub(
            body: "data: {\"choices\":[{\"delta\":{\"content\":\"s\"}}]}\n\n", contentType: "text/event-stream",
            staysOpen: true)
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let client = client()
        let task = Task {
            try await client.complete(
                AICompletionRequest(
                    participant: CompetitionParticipant(
                        entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "m"))),
                        apiKey: "key"),
                    messages: [AIMessage(role: "user", content: "puzzle")], maxOutputTokens: 10
                )
            ) { _ in }
        }
        for _ in 0..<100 where stub.requests.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(stub.requests.isEmpty)
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled stream returned a reply")
        } catch {}
        for _ in 0..<100 where !stub.stopped { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(stub.stopped)
    }

    func testHTTPFailuresDoNotExposeBodyAndRedirectsAreRejected() async throws {
        for status in [401, 429, 302] {
            let provider = provider()
            let stub = HTTPStub(body: "secret echoed by server", status: status)
            BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
            do {
                _ = try await client().models(provider: provider, apiKey: "key")
                XCTFail("Expected failure")
            } catch {
                XCTAssertFalse(error.localizedDescription.contains("secret"))
                if status == 302 {
                    XCTAssertEqual(error as? BattlefieldError, .redirected)
                } else {
                    XCTAssertEqual((error as? AIHTTPError)?.status, status)
                }
            }
            XCTAssertEqual(stub.requests.count, 1)
        }
    }
    func testReasoningStreamIsPreservedAndReplayedUsingOriginalField() async throws {
        let provider = provider()
        let stub = HTTPStub(
            body: """
                data: {"choices":[{"delta":{"reasoning_content":"Check the wall. "}}]}

                data: {"choices":[{"delta":{"reasoning_content":"Turn right.","content":"z"},"finish_reason":"stop"}]}

                data: [DONE]


                """, contentType: "text/event-stream")
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let collector = ProgressCollector()
        let reasoning = AIReasoning(content: "Earlier reasoning")
        let reply = try await client().complete(
            AICompletionRequest(
                participant: CompetitionParticipant(
                    entrant: Entrant(provider: provider, preset: ModelPreset(model: AIModel(id: "kimi-for-coding"))),
                    apiKey: "test-only-secret"),
                messages: [
                    AIMessage(role: "assistant", content: "z", reasoning: reasoning),
                    AIMessage(role: "user", content: "retry"),
                ], maxOutputTokens: 4096
            )
        ) { await collector.append($0) }
        XCTAssertEqual(reply.text, "z")
        XCTAssertEqual(reply.reasoning?.content, "Check the wall. Turn right.")
        XCTAssertEqual(reply.reasoning?.field, .content)
        let progress = await collector.items
        XCTAssertEqual(progress.last?.reasoning, reply.reasoning)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(stub.bodies.first)) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        XCTAssertEqual(messages[0]["reasoning_content"] as? String, "Earlier reasoning")
        XCTAssertNil(messages[1]["reasoning_content"])
    }

    func testFailedStreamFlushesPartialFinalAndReasoningText() async throws {
        let provider = provider()
        let stub = HTTPStub(
            body: """
                data: {"choices":[{"delta":{"content":"partial answer","reasoning_content":"partial reasoning"}}]}

                data: {"error":{"message":"generation failed"}}


                """, contentType: "text/event-stream")
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        let collector = ProgressCollector()
        do {
            _ = try await client().complete(
                AICompletionRequest(
                    participant: CompetitionParticipant(
                        entrant: Entrant(
                            provider: provider,
                            preset: ModelPreset(model: AIModel(id: "m"))), apiKey: "key"),
                    messages: [AIMessage(role: "user", content: "puzzle")], maxOutputTokens: 4096
                )
            ) { await collector.append($0) }
            XCTFail("Expected stream error")
        } catch let error as AIHTTPError {
            XCTAssertTrue(error.providerResponse?.contains("generation failed") == true)
        }
        let progress = await collector.items
        XCTAssertEqual(progress.last?.text, "partial answer")
        XCTAssertEqual(progress.last?.reasoning?.content, "partial reasoning")
        XCTAssertEqual(progress.last?.isFinal, false)
    }

    func testReasoningOnlyJSONAndEmptyReasoningRemainDistinctFromMissing() throws {
        let only = try OpenAICompatibleClient.decodeReply(
            Data(
                #"{"choices":[{"message":{"content":"","reasoning_content":"Still planning"},"finish_reason":"length"}]}"#
                    .utf8), messages: [])
        XCTAssertEqual(only.text, "")
        XCTAssertEqual(only.reasoning?.content, "Still planning")
        XCTAssertEqual(only.finishReason, "length")
        let empty = try OpenAICompatibleClient.decodeReply(
            Data(#"{"choices":[{"message":{"content":"s","reasoning_content":""}}]}"#.utf8), messages: [])
        XCTAssertNotNil(empty.reasoning)
        let alias = try OpenAICompatibleClient.decodeReply(
            Data(#"{"choices":[{"message":{"content":"s","reasoning":"Plan"}}]}"#.utf8), messages: [])
        XCTAssertEqual(alias.reasoning?.field, .reasoning)
    }

    func testHTTP400RetainsUsefulDiagnosticsAndRedactsCredentials() async throws {
        let provider = provider()
        let stub = HTTPStub(
            body:
                #"{"error":{"message":"assistant content is empty at index 2","type":"invalid_request_error","param":"messages"},"api_key":"test-only-secret","nested":{"authorization":"Bearer another-secret"},"request_id":"request-123"}"#,
            status: 400)
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        do {
            _ = try await client().complete(
                AICompletionRequest(
                    participant: CompetitionParticipant(
                        entrant: Entrant(
                            provider: provider, preset: ModelPreset(model: AIModel(id: "kimi-for-coding"))),
                        apiKey: "test-only-secret"),
                    messages: [AIMessage(role: "user", content: "puzzle")], maxOutputTokens: 4096
                )
            ) { _ in }
            XCTFail("Expected 400")
        } catch let error as AIHTTPError {
            XCTAssertEqual(error.status, 400)
            let details = try XCTUnwrap(error.providerResponse)
            XCTAssertTrue(details.contains("assistant content is empty"))
            XCTAssertTrue(details.contains("invalid_request_error"))
            XCTAssertTrue(details.contains("request-123"))
            XCTAssertFalse(details.contains("test-only-secret"))
            XCTAssertFalse(details.contains("another-secret"))
        }
    }

    func testProviderErrorBodyIsBoundedAndOpenErrorStreamCanBeCancelled() async throws {
        let provider = provider()
        let stub = HTTPStub(body: String(repeating: "x", count: 100_000), status: 400, staysOpen: true)
        BattlefieldURLProtocol.registry.add(stub, host: try XCTUnwrap(URL(string: provider.baseURL)?.host))
        do {
            _ = try await client().models(provider: provider, apiKey: "test-only-secret")
            XCTFail("Expected error")
        } catch let error as AIHTTPError {
            XCTAssertLessThan(try XCTUnwrap(error.providerResponse).utf8.count, 66_000)
            XCTAssertTrue(error.providerResponse?.contains("truncated") == true)
        }
        XCTAssertTrue(stub.stopped)
    }

    func testInBandAndUnexpectedJSONErrorsPreserveProviderDetails() throws {
        var accumulator = ChatStreamAccumulator(messages: [], apiKey: "test-only-secret")
        XCTAssertThrowsError(try accumulator.consume(#"{"error":{"message":"bad reasoning field test-only-secret"}}"#))
        { error in
            let diagnostic = (error as? AIHTTPError)?.providerResponse ?? ""
            XCTAssertTrue(diagnostic.contains("bad reasoning field"))
            XCTAssertFalse(diagnostic.contains("test-only-secret"))
        }
        XCTAssertThrowsError(
            try OpenAICompatibleClient.decodeReply(
                Data(#"{"error":{"message":"unsupported model"}}"#.utf8), messages: [])
        ) { error in
            XCTAssertTrue((error as? AIHTTPError)?.providerResponse?.contains("unsupported model") == true)
        }
    }

}

private actor ProgressCollector {
    var items: [AIProgress] = []
    func append(_ progress: AIProgress) { items.append(progress) }
}

private final class HTTPStub: @unchecked Sendable {
    let body: String
    let contentType: String
    let status: Int
    let staysOpen: Bool
    let headers: [String: String]
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private var recordedBodies: [Data] = []
    private var didStop = false
    var requests: [URLRequest] { lock.withLock { recorded } }
    var bodies: [Data] { lock.withLock { recordedBodies } }
    var stopped: Bool { lock.withLock { didStop } }
    init(
        body: String, contentType: String = "application/json", status: Int = 200, staysOpen: Bool = false,
        headers: [String: String] = [:]
    ) {
        self.body = body
        self.contentType = contentType
        self.status = status
        self.staysOpen = staysOpen
        self.headers = headers
    }
    func record(_ request: URLRequest) {
        var body = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
            stream.close()
        }
        lock.withLock {
            recorded.append(request)
            recordedBodies.append(body)
        }
    }
    func stop() { lock.withLock { didStop = true } }
}

private final class StubRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var stubs: [String: [HTTPStub]] = [:]
    func add(_ stub: HTTPStub, host: String) { addSequence([stub], host: host) }
    func addSequence(_ values: [HTTPStub], host: String) { lock.withLock { stubs[host] = values } }
    func get(_ host: String) -> HTTPStub? { lock.withLock { stubs[host]?.first } }
    func take(_ host: String) -> HTTPStub? {
        lock.withLock {
            guard let first = stubs[host]?.first else { return nil }
            if stubs[host]!.count > 1 { stubs[host]!.removeFirst() }
            return first
        }
    }
}

private final class BattlefieldURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = StubRegistry()
    private var activeStub: HTTPStub?
    override class func canInit(with request: URLRequest) -> Bool { registry.get(request.url?.host ?? "") != nil }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let stub = Self.registry.take(url.host ?? ""),
            let response = HTTPURLResponse(
                url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": stub.contentType].merging(stub.headers) { _, value in value })
        else { return }
        activeStub = stub
        stub.record(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        if !stub.staysOpen { client?.urlProtocolDidFinishLoading(self) }
    }
    override func stopLoading() { activeStub?.stop() }
}
