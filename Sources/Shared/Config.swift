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
    public var allowedApps: [String]

    public static let defaultAllowedApps = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.todesktop.230313mzl4w4u92", // Cursor
        "dev.warp.Warp",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "org.alacritty",
    ]

    public static let `default` = Config(
        targetLang: AppConstants.defaultTargetLanguage,
        sourceLang: AppConstants.defaultSourceLanguage,
        shortcut: "cmd+shift+t",
        autostart: true,
        showSelectionIcon: true,
        popupDuration: AppConstants.defaultPopupDuration,
        apiTimeoutMs: AppConstants.defaultAPITimeoutMs,
        cacheSize: AppConstants.defaultCacheSize,
        allowedApps: defaultAllowedApps
    )

    public init(
        targetLang: String = AppConstants.defaultTargetLanguage,
        sourceLang: String = AppConstants.defaultSourceLanguage,
        shortcut: String = "cmd+shift+t",
        autostart: Bool = true,
        showSelectionIcon: Bool = true,
        popupDuration: Int = AppConstants.defaultPopupDuration,
        apiTimeoutMs: Int = AppConstants.defaultAPITimeoutMs,
        cacheSize: Int = AppConstants.defaultCacheSize,
        allowedApps: [String] = Config.defaultAllowedApps
    ) {
        self.targetLang = targetLang
        self.sourceLang = sourceLang
        self.shortcut = shortcut
        self.autostart = autostart
        self.showSelectionIcon = showSelectionIcon
        self.popupDuration = popupDuration
        self.apiTimeoutMs = apiTimeoutMs
        self.cacheSize = cacheSize
        self.allowedApps = allowedApps
    }

    private enum CodingKeys: String, CodingKey {
        case targetLang
        case sourceLang
        case shortcut
        case autostart
        case showSelectionIcon
        case popupDuration
        case apiTimeoutMs
        case cacheSize
        case allowedApps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.targetLang = try container.decode(String.self, forKey: .targetLang)
        self.sourceLang = try container.decode(String.self, forKey: .sourceLang)
        self.shortcut = try container.decode(String.self, forKey: .shortcut)
        self.autostart = try container.decode(Bool.self, forKey: .autostart)
        self.showSelectionIcon = try container.decode(Bool.self, forKey: .showSelectionIcon)
        self.popupDuration = try container.decode(Int.self, forKey: .popupDuration)
        self.apiTimeoutMs = try container.decode(Int.self, forKey: .apiTimeoutMs)
        self.cacheSize = try container.decode(Int.self, forKey: .cacheSize)
        self.allowedApps = try container.decodeIfPresent([String].self, forKey: .allowedApps) ?? Self.defaultAllowedApps
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

    public static func load(from path: URL = AppConstants.configFilePath) -> Config {
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

    public static func save(_ config: Config, to path: URL = AppConstants.configFilePath) throws {
        let dir = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try encoder.encode(config)
        try data.write(to: path, options: .atomic)
    }
}
