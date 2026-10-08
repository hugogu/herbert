import Foundation
import HerbertCore

/// Optional archive. App Store targets link HerbertCore only.
public enum CommunityProblemCatalog {
    public static func bundled() throws -> [Problem] {
        guard let url = Bundle.module.url(forResource: "problems", withExtension: "json") else {
            throw CatalogError.missingResource
        }
        return try ProblemCatalog.decode(Data(contentsOf: url))
    }
}
