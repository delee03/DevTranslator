import Foundation
import Testing
@testable import Shared

@Suite("Config Tests")
struct ConfigTests {

    // MARK: - Default config values

    @Test func defaultConfigHasExpectedValues() {
        let config = Config.default

        #expect(config.targetLang == "vi")
        #expect(config.sourceLang == "")
        #expect(config.shortcut == "cmd+shift+t")
        #expect(config.autostart == true)
        #expect(config.showSelectionIcon == true)
        #expect(config.popupDuration == 10)
        #expect(config.apiTimeoutMs == 3000)
        #expect(config.cacheSize == 500)
    }

    @Test func defaultInitMatchesStaticDefault() {
        #expect(Config() == Config.default)
    }

    // MARK: - JSON round-trip

    @Test func configEncodesToJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(Config.default)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"targetLang\""))
        #expect(json.contains("\"vi\""))
        #expect(json.contains("\"cacheSize\""))
        #expect(json.contains("500"))
    }

    @Test func configRoundTripsViaJSON() throws {
        let original = Config(
            targetLang: "ja",
            sourceLang: "en",
            shortcut: "cmd+option+t",
            autostart: false,
            showSelectionIcon: false,
            popupDuration: 5,
            apiTimeoutMs: 5000,
            cacheSize: 100
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded == original)
    }

    @Test func defaultConfigRoundTripsViaJSON() throws {
        let data = try JSONEncoder().encode(Config.default)
        let decoded = try JSONDecoder().decode(Config.self, from: data)
        #expect(decoded == Config.default)
    }

    // MARK: - ConfigManager.load() without file

    @Test func loadReturnsValidConfig() {
        let config = ConfigManager.load()
        #expect(!config.targetLang.isEmpty)
        #expect(config.cacheSize > 0)
        #expect(config.apiTimeoutMs > 0)
    }

    // MARK: - ConfigManager save/load round-trip

    @Test func saveThenLoadRoundTrip() throws {
        let configPath = AppConstants.configFilePath
        let fm = FileManager.default

        // Back up existing config
        let backupPath = configPath.appendingPathExtension("test-backup")
        let hadExisting = fm.fileExists(atPath: configPath.path)
        if hadExisting {
            try fm.copyItem(at: configPath, to: backupPath)
        }

        defer {
            try? fm.removeItem(at: configPath)
            if hadExisting {
                try? fm.moveItem(at: backupPath, to: configPath)
            }
        }

        let custom = Config(
            targetLang: "ko",
            sourceLang: "de",
            shortcut: "cmd+ctrl+t",
            autostart: false,
            showSelectionIcon: false,
            popupDuration: 7,
            apiTimeoutMs: 2000,
            cacheSize: 250
        )

        try ConfigManager.save(custom)
        let loaded = ConfigManager.load()
        #expect(loaded == custom)
    }

    // MARK: - Equatable

    @Test func configEqualityForIdenticalValues() {
        let a = Config(targetLang: "vi", sourceLang: "en", shortcut: "x",
                       autostart: true, showSelectionIcon: true,
                       popupDuration: 10, apiTimeoutMs: 3000, cacheSize: 500)
        let b = Config(targetLang: "vi", sourceLang: "en", shortcut: "x",
                       autostart: true, showSelectionIcon: true,
                       popupDuration: 10, apiTimeoutMs: 3000, cacheSize: 500)
        #expect(a == b)
    }

    @Test func configInequalityForDifferentValues() {
        #expect(Config.default != Config(targetLang: "ja"))
    }
}
