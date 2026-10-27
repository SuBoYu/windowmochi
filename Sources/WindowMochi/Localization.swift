import Foundation

final class Localizer {
    static let shared = Localizer()
    var selection: String { UserDefaults.standard.string(forKey: "language") ?? "system" }
    private var tables: [String: [String: String]] = [:]
    init() {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        for code in ["en", "zh-Hant", "zh-Hans", "ja"] {
            if let url = bundle.url(forResource: code, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let table = try? JSONDecoder().decode([String: String].self, from: data) { tables[code] = table }
        }
    }
    func select(_ code: String) { UserDefaults.standard.set(code, forKey: "language") }
    var language: String {
        if selection != "system" { return selection }
        for language in Locale.preferredLanguages {
            if language.hasPrefix("zh") {
                return language.contains("Hant") || language.contains("TW") || language.contains("HK") || language.contains("MO") ? "zh-Hant" : "zh-Hans"
            }
            if language.hasPrefix("ja") { return "ja" }
            if language.hasPrefix("en") { return "en" }
        }
        return "en"
    }
    func text(_ key: String, _ args: [CVarArg]) -> String {
        let template = tables[language]?[key] ?? tables["en"]?[key] ?? key
        return String(format: template, locale: Locale(identifier: language), arguments: args)
    }
}
func L(_ key: String, _ args: CVarArg...) -> String { Localizer.shared.text(key, args) }
