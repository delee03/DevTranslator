import Foundation

public enum AppConstants {
    public static let appName = "DevTranslator"
    public static let version = "0.1.0"

    public static let configDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/devtranslator")
    }()

    public static let configFilePath: URL = {
        configDirectory.appendingPathComponent("config.json")
    }()

    public static let defaultTargetLanguage = "vi"
    public static let defaultSourceLanguage = ""  // auto-detect
    public static let defaultCacheSize = 500
    public static let defaultAPITimeoutMs = 3000
    public static let defaultPopupDuration = 10

    public static let googleTranslateBaseURL = "https://translate.googleapis.com/translate_a/single"
}
