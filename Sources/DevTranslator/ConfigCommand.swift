import ArgumentParser
import Foundation
import Shared

struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "View or update DevTranslator configuration."
    )

    @Option(name: .long, help: "Set target language (e.g., vi, ja, ko)")
    var lang: String?

    @Option(name: .long, help: "Set source language (empty for auto-detect)")
    var from: String?

    @Option(name: .long, help: "Set API timeout in milliseconds")
    var timeout: Int?

    @Option(name: .long, help: "Set translation cache size")
    var cacheSize: Int?

    @Flag(name: .long, help: "Show current configuration")
    var show: Bool = false

    @Flag(name: .long, help: "Reset configuration to defaults")
    var reset: Bool = false

    func run() throws {
        if reset {
            try ConfigManager.save(.default)
            print("Configuration reset to defaults.")
            return
        }

        var config = ConfigManager.load()
        var changed = false

        if let lang {
            config.targetLang = lang
            changed = true
        }
        if let from {
            config.sourceLang = from
            changed = true
        }
        if let timeout {
            config.apiTimeoutMs = timeout
            changed = true
        }
        if let cacheSize {
            config.cacheSize = cacheSize
            changed = true
        }

        if changed {
            try ConfigManager.save(config)
            print("Configuration updated.")
        }

        if show || !changed {
            printConfig(config)
        }
    }

    private func printConfig(_ config: Config) {
        let allowedApps = config.allowedApps
            .sorted()
            .map { "  - \($0)" }
            .joined(separator: "\n")

        print("""
        DevTranslator Configuration
        ──────────────────────────────
        Target language:  \(config.targetLang.isEmpty ? "(auto)" : config.targetLang)
        Source language:  \(config.sourceLang.isEmpty ? "(auto-detect)" : config.sourceLang)
        Shortcut:         \(config.shortcut)
        Auto-start:       \(config.autostart)
        Selection icon:   \(config.showSelectionIcon)
        Popup duration:   \(config.popupDuration)s
        API timeout:      \(config.apiTimeoutMs)ms
        Cache size:       \(config.cacheSize)
        Config file:      \(AppConstants.configFilePath.path)
        Allowed apps:
        \(allowedApps)
        """)
    }
}
