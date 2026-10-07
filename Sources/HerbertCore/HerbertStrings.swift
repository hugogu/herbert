import Foundation

/// Shared by the native UI and the interpreter so errors follow the app language too.
public enum HerbertStrings {
    public static func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: Bundle.module.localizedString(forKey: key, value: nil, table: nil), arguments: arguments)
    }

    static func text(_ key: String, language: String, arguments: [CVarArg] = []) -> String {
        let selected =
            Bundle.preferredLocalizations(from: ["en", "zh-Hans", "ja"], forPreferences: [language]).first ?? "en"
        // Older SwiftPM versions lowercase language resource directory names.
        let path =
            Bundle.module.path(forResource: selected.lowercased(), ofType: "lproj")
            ?? Bundle.module.path(forResource: selected, ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? Bundle.module
        return String(format: bundle.localizedString(forKey: key, value: nil, table: nil), arguments: arguments)
    }
}
