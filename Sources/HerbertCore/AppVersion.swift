import Foundation

/// The version players see and quote in bug reports, such as "1.1.0 (15)".
public struct AppVersion: Equatable, Sendable, CustomStringConvertible {
    public let marketing: String
    public let build: String?

    /// Nil without a marketing version, as in a bare test runner.
    public init?(infoDictionary: [String: Any]?) {
        guard let marketing = infoDictionary?["CFBundleShortVersionString"] as? String, !marketing.isEmpty else {
            return nil
        }
        self.marketing = marketing
        let build = infoDictionary?["CFBundleVersion"] as? String
        self.build = build?.isEmpty == false ? build : nil
    }

    public static let current = AppVersion(infoDictionary: Bundle.main.infoDictionary)

    public var description: String { build.map { "\(marketing) (\($0))" } ?? marketing }
}
