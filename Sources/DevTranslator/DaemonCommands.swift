import ArgumentParser
import Foundation

// MARK: - Phase 2 Placeholder Commands

struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start the selection monitoring daemon."
    )

    func run() throws {
        print("Daemon support is coming in Phase 2.")
        print("For now, use: devtranslator \"text to translate\"")
    }
}

struct StopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the selection monitoring daemon."
    )

    func run() throws {
        print("Daemon support is coming in Phase 2.")
    }
}

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check if the daemon is running."
    )

    func run() throws {
        print("Daemon support is coming in Phase 2.")
        print("CLI translation is available: devtranslator \"text\"")
    }
}

struct ToggleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle translation on/off without stopping the daemon."
    )

    func run() throws {
        print("Daemon support is coming in Phase 2.")
    }
}
