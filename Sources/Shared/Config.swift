import Foundation

public struct Config: Codable, Equatable {
    public var targetLang: String
    public var sourceLang: String
    public var shortcut: String
    public var autostart: Bool
    public var showSelectionIcon: Bool
    public var popupDuration: Int
    public var apiTimeoutMs: Int
    public var cacheSize: Int

    public static let `default` = Config(
        targetLang: AppConstants.defaultTargetLanguage,
        sourceLang: AppConstants.defaultSourceLanguage,
        shortcut: "cmd+shift+t",
        autostart: true,
        showSelectionIcon: true,
        popupDuration: AppConstants.defaultPopupDuration,
        apiTimeoutMs: AppConstants.defaultAPITimeoutMs,
        cacheSize: AppConstants.defaultCacheSize
    )

    public init(
        targetLang: String = AppConstants.defaultTargetLanguage,
        sourceLang: String = AppConstants.defaultSourceLanguage,
        shortcut: String = "cmd+shift+t",
        autostart: Bool = true,
        showSelectionIcon: Bool = true,
        popupDuration: Int = AppConstants.defaultPopupDuration,
        apiTimeoutMs: Int = AppConstants.defaultAPITimeoutMs,
        cacheSize: Int = AppConstants.defaultCacheSize
    ) {
        self.targetLang = targetLang
        self.sourceLang = sourceLang
        self.shortcut = shortcut
        self.autostart = autostart
        self.showSelectionIcon = showSelectionIcon
        self.popupDuration = popupDuration
        self.apiTimeoutMs = apiTimeoutMs
        self.cacheSize = cacheSize
    }
}

// MARK: - Loading & Saving

public enum ConfigManager {
    private static let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()

    private static let decoder = JSONDecoder()

    public static func load() -> Config {
        let path = AppConstants.configFilePath
        guard FileManager.default.fileExists(atPath: path.path) else {
            return .default
        }
        do {
            let data = try Data(contentsOf: path)
            return try decoder.decode(Config.self, from: data)
        } catch {
            Logger.shared.warning("Failed to load config, using defaults: \(error.localizedDescription)")
            return .default
        }
    }

    public static func save(_ config: Config) throws {
        let dir = AppConstants.configDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: AppConstants.configFilePath, options: .atomic)
    }
}
