import Foundation
import HerbertCore
import XCTest

@testable import HerbertCloud

final class CloudClientTests: XCTestCase {
    func testRejectsUnsafeOrAmbiguousEndpoints() throws {
        for value in [
            "http://example.com", "https://user:pass@example.com", "https://example.com?token=secret",
            "https://example.com/path", "https://example.com#fragment",
        ] {
            XCTAssertThrowsError(try CloudClient(endpoint: XCTUnwrap(URL(string: value))))
        }
        XCTAssertNoThrow(try CloudClient(endpoint: XCTUnwrap(URL(string: "https://api.example.com"))))
    }
    func testPuzzleIdentityIncludesBoardLimitAndID() throws {
        let puzzle = try XCTUnwrap(ProblemCatalog.bundled().first)
        let version = CloudPuzzle.version(puzzle)
        XCTAssertEqual(version.count, 64)
        let changed = Problem(
            id: puzzle.id, title: puzzle.title, author: puzzle.author, byteLimit: puzzle.byteLimit + 1,
            rows: puzzle.rows)
        XCTAssertNotEqual(version, CloudPuzzle.version(changed))
    }
    func testRedirectsCannotForwardCredentialsToAnotherHost() throws {
        let url = try XCTUnwrap(URL(string: "https://untrusted.example.com"))
        var request = URLRequest(url: url)
        request.setValue("Bearer sensitive", forHTTPHeaderField: "Authorization")
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 307, httpVersion: nil, headerFields: nil))
        CloudNoRedirects().urlSession(
            .shared, task: URLSession.shared.dataTask(with: request),
            willPerformHTTPRedirection: response, newRequest: request
        ) { redirected in
            XCTAssertNil(redirected)
        }
    }
    func testTransportSubmitsProgramWithoutClaimedScoreOrIdentity() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        let client = try CloudClient(
            endpoint: XCTUnwrap(URL(string: "https://api.example.com")), session: URLSession(configuration: config))
        let puzzle = try XCTUnwrap(ProblemCatalog.bundled().first)
        let result = try await client.submit(problem: puzzle, source: "s", requestID: UUID(), token: "test-session")
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.points, 80)
    }
    func testPublicProblemLeaderboardDecodesScoresAndDoesNotSendCredentials() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        let client = try CloudClient(
            endpoint: XCTUnwrap(URL(string: "https://api.example.com")), session: URLSession(configuration: config))
        let ranking = try await client.problemLeaderboard(10001)
        XCTAssertEqual(ranking.problemID, 10001)
        XCTAssertEqual(ranking.entries.first?.points, 80)
        XCTAssertEqual(ranking.entries.first?.litTargets, 1)
        XCTAssertEqual(ranking.entries.first?.bytes, 1)
    }
    func testNicknameUpdateUsesAuthenticatedPatchWithoutClaimedUserID() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        let client = try CloudClient(
            endpoint: XCTUnwrap(URL(string: "https://api.example.com")), session: URLSession(configuration: config))
        let user = try await client.updateDisplayName("小机器人", token: "test-session")
        XCTAssertEqual(user.userID, "alice")
        XCTAssertEqual(user.displayName, "小机器人")
    }
}
private final class MockProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let isRanking = request.url?.path == "/v1/problems/10001/leaderboard"
        if isRanking {
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
        } else {
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-session")
        }
        var bytes = request.httpBody ?? Data()
        if bytes.isEmpty, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let n = stream.read(&buffer, maxLength: buffer.count)
                if n <= 0 { break }
                bytes.append(contentsOf: buffer.prefix(n))
            }
        }
        let body = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        let reply: String
        if isRanking {
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            reply =
                #"{"problem_id":10001,"puzzle_version":"current","entries":[{"rank":1,"user_id":"alice","display_name":"Alice","points":80,"bytes":1,"accepted":1,"lit_targets":1,"target_count":1}]}"#
        } else if request.url?.path == "/v1/me" {
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(Set(body?.keys.map { $0 } ?? []), Set(["display_name"]))
            XCTAssertEqual(body?["display_name"] as? String, "小机器人")
            reply = #"{"user_id":"alice","display_name":"小机器人"}"#
        } else {
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/v1/submissions")
            XCTAssertEqual(
                Set(body?.keys.map { $0 } ?? []), Set(["source", "problem_id", "puzzle_version", "request_id"]))
            XCTAssertEqual(body?["source"] as? String, "s")
            reply = #"{"accepted":true,"bytes":1,"points":80,"feedback":"Accepted"}"#
        }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
