import Foundation
import HerbertCore

/// HTTP transport has no credential persistence and never trusts a client score.
public struct CloudClient: Sendable {
    public let endpoint: URL
    private let session: URLSession
    public init(endpoint: URL, session: URLSession? = nil) throws {
        guard endpoint.scheme == "https", endpoint.host != nil, endpoint.user == nil, endpoint.password == nil,
            endpoint.query == nil, endpoint.fragment == nil, ["", "/"].contains(endpoint.path)
        else { throw CloudError.invalidEndpoint }
        self.endpoint = endpoint
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            self.session = URLSession(configuration: configuration)
        }
    }
    public func leaderboard() async throws -> Leaderboard { try await send("v1/leaderboard") }
    public func problemLeaderboard(_ problemID: Int) async throws -> ProblemLeaderboard {
        try await send("v1/problems/\(problemID)/leaderboard")
    }
    public func problemBests() async throws -> ProblemBests { try await send("v1/problems/bests") }
    public func challenge() async throws -> LoginChallenge { try await send("v1/auth/challenge", method: "POST") }
    public func signIn(challenge: LoginChallenge, identityToken: String, authorizationCode: String) async throws
        -> CloudSession
    {
        try await send(
            "v1/auth/apple", method: "POST",
            body: [
                "challenge_id": challenge.challengeID, "nonce": challenge.nonce,
                "identity_token": identityToken, "authorization_code": authorizationCode,
            ])
    }
    public func refresh(_ token: String) async throws -> CloudSession {
        try await send("v1/auth/refresh", method: "POST", body: ["refresh_token": token])
    }
    public func me(token: String) async throws -> CloudUser { try await send("v1/me", token: token) }
    public func updateDisplayName(_ name: String, token: String) async throws -> CloudUser {
        try await send("v1/me", method: "PATCH", body: ["display_name": name], token: token)
    }
    public func logout(token: String) async throws {
        let _: Acknowledgment = try await send("v1/auth/logout", method: "POST", token: token)
    }
    public func deleteAccount(token: String) async throws {
        let _: Acknowledgment = try await send("v1/me", method: "DELETE", token: token)
    }
    public func submit(problem: Problem, source: String, token: String) async throws
        -> SubmissionResult
    {
        try await send(
            "v1/submissions", method: "POST",
            body: [
                "request_id": CloudPuzzle.submissionID(problem: problem, source: source), "problem_id": problem.id,
                "puzzle_version": CloudPuzzle.version(problem), "source": source,
            ], token: token)
    }
    private struct Acknowledgment: Decodable { let ok: Bool }
    private func send<T: Decodable>(
        _ path: String, method: String = "GET", body: [String: any Sendable]? = nil, token: String? = nil
    ) async throws -> T {
        var request = URLRequest(
            url: endpoint.appendingPathComponent(path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request, delegate: CloudNoRedirects())
        guard let http = response as? HTTPURLResponse, data.count <= 1_048_576 else { throw CloudError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let failure = try? JSONDecoder().decode(ServiceError.self, from: data)
            var message = failure?.error ?? HerbertStrings.text("排行榜请求失败，请稍后重试。")
            if let code = failure?.code {
                message = HerbertStrings.text(
                    code == "nickname_not_allowed"
                        ? "昵称不适合公开展示，请选择其他昵称。"
                        : code.hasPrefix("apple_")
                            ? (http.statusCode == 401 ? "Apple 登录验证失败，请重新登录。" : "Apple 登录暂时不可用，请稍后重试。")
                            : "排行榜请求失败，请稍后重试。")
            }
            if let reference = failure?.reference, UUID(uuidString: reference) != nil {
                message += " · " + HerbertStrings.text("参考编号：%@", reference)
            }
            throw CloudError.request(http.statusCode, message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    private struct ServiceError: Decodable {
        let error: String
        let code: String?
        let reference: String?
    }
}

/// Never forward an account token or uploaded program through an HTTP redirect.
final class CloudNoRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) { completionHandler(nil) }
}
