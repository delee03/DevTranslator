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
        #expect(config.allowedApps.contains("com.mitchellh.ghostty"))
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
            cacheSize: 100,
            allowedApps: ["com.apple.Terminal", "com.mitchellh.ghostty"]
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

    @Test func decodingLegacyConfigUsesDefaultAllowedApps() throws {
        let json = """
        {
          "targetLang": "ja",
          "sourceLang": "en",
          "shortcut": "cmd+shift+t",
          "autostart": true,
          "showSelectionIcon": true,
          "popupDuration": 10,
          "apiTimeoutMs": 3000,
          "cacheSize": 500
        }
        """

        let decoded = try JSONDecoder().decode(Config.self, from: Data(json.utf8))

        #expect(decoded.targetLang == "ja")
        #expect(decoded.allowedApps == Config.defaultAllowedApps)
    }

    // MARK: - ConfigManager.load() without file

    @Test func loadReturnsDefaultConfigWhenFileDoesNotExist() {
        let configPath = temporaryConfigPath()

        let config = ConfigManager.load(from: configPath)

        #expect(config == Config.default)
    }

    // MARK: - ConfigManager save/load round-trip

    @Test func saveThenLoadRoundTrip() throws {
        let configPath = temporaryConfigPath()
        defer { try? FileManager.default.removeItem(at: configPath.deletingLastPathComponent()) }

        let custom = Config(
            targetLang: "ko",
            sourceLang: "de",
            shortcut: "cmd+ctrl+t",
            autostart: false,
            showSelectionIcon: false,
            popupDuration: 7,
            apiTimeoutMs: 2000,
            cacheSize: 250,
            allowedApps: ["com.mitchellh.ghostty"]
        )

        try ConfigManager.save(custom, to: configPath)
        let loaded = ConfigManager.load(from: configPath)
        #expect(loaded == custom)
    }

    private func temporaryConfigPath() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("devtranslator-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    // MARK: - Equatable

    @Test func configEqualityForIdenticalValues() {
        let a = Config(targetLang: "vi", sourceLang: "en", shortcut: "x",
                       autostart: true, showSelectionIcon: true,
                       popupDuration: 10, apiTimeoutMs: 3000, cacheSize: 500,
                       allowedApps: ["com.apple.Terminal"])
        let b = Config(targetLang: "vi", sourceLang: "en", shortcut: "x",
                       autostart: true, showSelectionIcon: true,
                       popupDuration: 10, apiTimeoutMs: 3000, cacheSize: 500,
                       allowedApps: ["com.apple.Terminal"])
        #expect(a == b)
    }

    @Test func configInequalityForDifferentValues() {
        #expect(Config.default != Config(targetLang: "ja"))
    }
}
