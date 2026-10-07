import Foundation

/// Shared by the native UI and the interpreter so errors follow the app language too.
public enum HerbertStrings {
    public static func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: Bundle.module.localizedString(forKey: key, value: nil, table: nil), arguments: arguments)
    }

    static func text(_ key: String, language: String, arguments: [CVarArg] = []) -> String {
        let selected =
            Bundle.preferredLocalizations(from: ["en", "zh-Hans", "ja"], forPreferences: [language]).first ?? "en"
        let bundle = Bundle(path: Bundle.module.path(forResource: selected, ofType: "lproj")!)!
        return String(format: bundle.localizedString(forKey: key, value: nil, table: nil), arguments: arguments)
    }
}
