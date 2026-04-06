import ArgumentParser
import Foundation
import Shared
import TranslationEngine

@main
struct DevTranslatorCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "devtranslator",
        abstract: "Translate text instantly from the terminal.",
        version: AppConstants.version,
        subcommands: [
            TranslateCommand.self,
            ConfigCommand.self,
            StartCommand.self,
            StopCommand.self,
            StatusCommand.self,
            ToggleCommand.self,
        ],
        defaultSubcommand: TranslateCommand.self
    )
}

struct TranslateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "translate",
        abstract: "Translate text (default command)."
    )

    @Argument(help: "Text to translate. If omitted, reads from stdin.")
    var text: [String] = []

    @Option(name: [.short, .long], help: "Target language code (e.g., vi, ja, ko)")
    var lang: String?

    @Option(name: [.short, .long], help: "Source language code (default: auto-detect)")
    var from: String?

    mutating func run() async throws {
        let config = ConfigManager.load()
        let targetLang = lang ?? config.targetLang
        let sourceLang = from ?? config.sourceLang

        let input: String
        if !text.isEmpty {
            input = text.joined(separator: " ")
        } else if !isTerminalInput() {
            input = readStdin()
        } else {
            throw CleanExit.helpRequest(self)
        }

        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CleanExit.helpRequest(self)
        }

        let service = CachedTranslationService(
            service: GoogleTranslateService(timeoutMs: config.apiTimeoutMs),
            cacheSize: config.cacheSize
        )

        do {
            let result = try await service.translate(text: trimmed, from: sourceLang, to: targetLang)
            print(result.translatedText)
        } catch let error as TranslationError {
            printError(error.localizedDescription)
            throw ExitCode.failure
        }
    }

    private func isTerminalInput() -> Bool {
        isatty(STDIN_FILENO) != 0
    }

    private func readStdin() -> String {
        var lines: [String] = []
        while let line = readLine(strippingNewline: false) {
            lines.append(line)
        }
        return lines.joined()
    }

    private func printError(_ message: String) {
        let stderr = FileHandle.standardError
        stderr.write(Data("Error: \(message)\n".utf8))
    }
}

// MARK: - FileHandle as TextOutputStream for stderr

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
    }
}
