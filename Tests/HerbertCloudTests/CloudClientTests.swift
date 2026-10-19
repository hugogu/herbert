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
    func testSubmissionIdentityIsStableAcrossRetriesAndChangesWithContent() throws {
        let puzzle = try XCTUnwrap(ProblemCatalog.bundled().first)
        let id = CloudPuzzle.submissionID(problem: puzzle, source: "s")
        XCTAssertEqual(id.count, 64)
        XCTAssertEqual(id, CloudPuzzle.submissionID(problem: puzzle, source: "s"))
        XCTAssertNotEqual(id, CloudPuzzle.submissionID(problem: puzzle, source: "r"))
        let changed = Problem(
            id: puzzle.id, title: puzzle.title, author: puzzle.author,
            byteLimit: puzzle.byteLimit + 1, rows: puzzle.rows)
        XCTAssertNotEqual(id, CloudPuzzle.submissionID(problem: changed, source: "s"))
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
        let result = try await client.submit(problem: puzzle, source: "s", token: "test-session")
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
        XCTAssertEqual(ranking.entries.first?.steps, 1)
    }
    func testPublicBestReferencesMatchCurrentBoardsOnly() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockProtocol.self]
        let client = try CloudClient(
            endpoint: XCTUnwrap(URL(string: "https://api.example.com")), session: URLSession(configuration: config))
        let bests = try await client.problemBests()
        let puzzles = try ProblemCatalog.bundled()
        XCTAssertEqual(bests.references(for: puzzles), [puzzles[0].id: 1])
        let obsolete = try JSONDecoder().decode(
            ProblemBests.self,
            from: Data(
                #"{"rules_version":"retired","entries":[]}"#.utf8))
        XCTAssertTrue(obsolete.references(for: puzzles).isEmpty)
    }
    func testOldLeaderboardWithoutInstructionsStillDecodes() throws {
        let ranking = try JSONDecoder().decode(
            ProblemLeaderboard.self,
            from: Data(
                #"{"problem_id":10001,"puzzle_version":"old","entries":[{"rank":1,"user_id":"alice","display_name":"Alice","points":80,"bytes":1,"accepted":1,"lit_targets":1,"target_count":1}]}"#
                    .utf8))
        XCTAssertNil(ranking.entries[0].steps)
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
        let isBests = request.url?.path == "/v1/problems/bests"
        if isRanking || isBests {
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
                #"{"problem_id":10001,"puzzle_version":"current","entries":[{"rank":1,"user_id":"alice","display_name":"Alice","points":80,"bytes":1,"accepted":1,"lit_targets":1,"target_count":1,"steps":1}]}"#
        } else if isBests {
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            let puzzle = try! ProblemCatalog.bundled()[0]
            reply = """
                {"rules_version":"herbert-h-v1","entries":[
                {"problem_id":\(puzzle.id),"puzzle_version":"\(CloudPuzzle.version(puzzle))","bytes":1},
                {"problem_id":10002,"puzzle_version":"retired","bytes":0},
                {"problem_id":999999,"puzzle_version":"unknown","bytes":0}]}
                """
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
            XCTAssertEqual(body?["request_id"] as? String,
                CloudPuzzle.submissionID(problem: try! ProblemCatalog.bundled()[0], source: "s"))
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
