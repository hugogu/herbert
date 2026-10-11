import CryptoKit
import Foundation
import HerbertCore

public enum CloudPuzzle {
    public static let rulesVersion = "herbert-h-v1"
    public static func version(_ problem: Problem) -> String {
        let identity = "\(rulesVersion)\n\(problem.id)\n\(problem.byteLimit)\n" + problem.rows.joined(separator: "\n")
        return SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public struct CloudUser: Codable, Sendable {
    public let userID: String
    public let displayName: String
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case displayName = "display_name"
    }
}
public struct CloudSession: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Double
    public var user: CloudUser?
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}
public struct LoginChallenge: Codable, Sendable {
    public let challengeID: String
    public let nonce: String
    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case nonce
    }
}
public struct Leaderboard: Codable, Sendable {
    public let puzzleCount: Int
    public let entries: [LeaderboardEntry]
    enum CodingKeys: String, CodingKey {
        case puzzleCount = "puzzle_count"
        case entries
    }
}
public struct LeaderboardEntry: Codable, Identifiable, Sendable {
    public let rank: Int
    public let userID: String
    public let displayName: String
    public let points: Double
    public let percentage: Double
    public let solved: Int
    public var id: String { userID }
    enum CodingKeys: String, CodingKey {
        case rank
        case userID = "user_id"
        case displayName = "display_name"
        case points, percentage, solved
    }
}
public struct ProblemLeaderboard: Codable, Sendable {
    public let problemID: Int
    public let puzzleVersion: String
    public let entries: [ProblemLeaderboardEntry]
    enum CodingKeys: String, CodingKey {
        case problemID = "problem_id"
        case puzzleVersion = "puzzle_version"
        case entries
    }
}
public struct ProblemLeaderboardEntry: Codable, Identifiable, Sendable {
    public let rank: Int
    public let userID: String
    public let displayName: String
    public let points: Double
    public let bytes: Int
    public let accepted: Int
    public let litTargets: Int
    public let targetCount: Int
    public var id: String { userID }
    enum CodingKeys: String, CodingKey {
        case rank, points, bytes, accepted
        case userID = "user_id"
        case displayName = "display_name"
        case litTargets = "lit_targets"
        case targetCount = "target_count"
    }
}
public struct SubmissionResult: Codable, Sendable {
    public let accepted: Bool
    public let bytes: Int
    public let points: Double
    public let feedback: String
}
public enum CloudError: Error, LocalizedError {
    case invalidEndpoint, invalidResponse
    case request(Int, String)
    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint: "A secure leaderboard URL is required."
        case .invalidResponse: "The leaderboard returned an invalid response."
        case .request(let status, let message): "\(message) (HTTP \(status))"
        }
    }
}
