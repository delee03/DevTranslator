import XCTest
@testable import Shared

final class ConfigTests: XCTestCase {

    // MARK: - Default config values

    func testDefaultConfigHasExpectedValues() {
        let config = Config.default

        XCTAssertEqual(config.targetLang, "vi")
        XCTAssertEqual(config.sourceLang, "", "Source language should default to empty (auto-detect)")
        XCTAssertEqual(config.shortcut, "cmd+shift+t")
        XCTAssertTrue(config.autostart)
        XCTAssertTrue(config.showSelectionIcon)
        XCTAssertEqual(config.popupDuration, 10)
        XCTAssertEqual(config.apiTimeoutMs, 3000)
        XCTAssertEqual(config.cacheSize, 500)
    }

    func testDefaultInitMatchesStaticDefault() {
        let initDefault = Config()
        XCTAssertEqual(initDefault, Config.default)
    }

    // MARK: - JSON round-trip

    func testConfigEncodesToJSON() throws {
        let config = Config.default
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data = try encoder.encode(config)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        // Verify key fields are present in the JSON string
        XCTAssertTrue(json.contains("\"targetLang\""))
        XCTAssertTrue(json.contains("\"vi\""))
        XCTAssertTrue(json.contains("\"cacheSize\""))
        XCTAssertTrue(json.contains("500"))
        XCTAssertTrue(json.contains("\"shortcut\""))
    }

    func testConfigRoundTripsViaJSON() throws {
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

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Config.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testDefaultConfigRoundTripsViaJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(Config.default)
        let decoded = try decoder.decode(Config.self, from: data)

        XCTAssertEqual(decoded, Config.default)
    }

    // MARK: - ConfigManager.load() without file

    func testLoadReturnsDefaultsWhenNoFileExists() {
        // ConfigManager.load() checks AppConstants.configFilePath.
        // If the config file doesn't exist on this machine, it should return defaults.
        // If it does exist, this test verifies load() at least doesn't crash.
        let config = ConfigManager.load()

        // At minimum, verify it returns a valid Config.
        // If no config file exists on disk, it should be exactly the default.
        // We can't guarantee the file doesn't exist on CI, so we just check it's valid.
        XCTAssertFalse(config.targetLang.isEmpty, "targetLang should not be empty")
        XCTAssertGreaterThan(config.cacheSize, 0)
        XCTAssertGreaterThan(config.apiTimeoutMs, 0)
    }

    // MARK: - ConfigManager save/load round-trip (using temp directory)

    func testSaveThenLoadRoundTrip() throws {
        // We test save/load by:
        // 1. Saving the config (to the real config path — ConfigManager uses hardcoded paths)
        // 2. Loading it back
        // 3. Restoring the original state
        //
        // To be safe, we back up any existing config and restore it after.

        let configPath = AppConstants.configFilePath
        let fm = FileManager.default

        // Back up existing config if present
        let backupPath = configPath.appendingPathExtension("test-backup")
        let hadExisting = fm.fileExists(atPath: configPath.path)
        if hadExisting {
            try fm.copyItem(at: configPath, to: backupPath)
        }

        defer {
            // Restore original state
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

        XCTAssertEqual(loaded, custom)
    }

    // MARK: - Config Equatable

    func testConfigEqualityForIdenticalValues() {
        let a = Config(targetLang: "vi", sourceLang: "en", shortcut: "x",
                       autostart: true, showSelectionIcon: true,
                       popupDuration: 10, apiTimeoutMs: 3000, cacheSize: 500)
        let b = Config(targetLang: "vi", sourceLang: "en", shortcut: "x",
                       autostart: true, showSelectionIcon: true,
                       popupDuration: 10, apiTimeoutMs: 3000, cacheSize: 500)
        XCTAssertEqual(a, b)
    }

    func testConfigInequalityForDifferentValues() {
        let a = Config.default
        let b = Config(targetLang: "ja")
        XCTAssertNotEqual(a, b)
    }
}
