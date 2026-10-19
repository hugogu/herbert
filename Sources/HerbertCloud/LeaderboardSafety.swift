import Foundation

public enum LeaderboardSafety {
    /// Opens a draft for the user to review; never sends a report automatically.
    public static func reportURL(userID: String, displayName: String) -> URL? {
        var url = URLComponents()
        url.scheme = "mailto"
        url.path = "hugogu@outlook.com"
        url.queryItems = [
            URLQueryItem(name: "subject", value: "Herbert leaderboard report"),
            URLQueryItem(name: "body", value: "Player: \(displayName)\nUser ID: \(userID)\n\nReason:\n"),
        ]
        return url.url
    }
}
