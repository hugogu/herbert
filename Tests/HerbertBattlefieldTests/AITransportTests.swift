import Foundation
import XCTest

@testable import HerbertBattlefield

@MainActor
final class AITransportTests: XCTestCase {
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
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private var recordedBodies: [Data] = []
    private var didStop = false
    var requests: [URLRequest] { lock.withLock { recorded } }
    var bodies: [Data] { lock.withLock { recordedBodies } }
    var stopped: Bool { lock.withLock { didStop } }
    init(body: String, contentType: String = "application/json", status: Int = 200, staysOpen: Bool = false) {
        self.body = body
        self.contentType = contentType
        self.status = status
        self.staysOpen = staysOpen
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
    private var stubs: [String: HTTPStub] = [:]
    func add(_ stub: HTTPStub, host: String) { lock.withLock { stubs[host] = stub } }
    func get(_ host: String) -> HTTPStub? { lock.withLock { stubs[host] } }
}

private final class BattlefieldURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = StubRegistry()
    override class func canInit(with request: URLRequest) -> Bool { registry.get(request.url?.host ?? "") != nil }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url, let stub = Self.registry.get(url.host ?? ""),
            let response = HTTPURLResponse(
                url: url, statusCode: stub.status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": stub.contentType])
        else { return }
        stub.record(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(stub.body.utf8))
        if !stub.staysOpen { client?.urlProtocolDidFinishLoading(self) }
    }
    override func stopLoading() { Self.registry.get(request.url?.host ?? "")?.stop() }
}
