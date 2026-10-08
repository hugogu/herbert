import Foundation
import XCTest

@testable import HerbertBattlefield

@MainActor
final class AITransportTests: XCTestCase {
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
