import ArgumentParser
import Foundation
import SelectionMonitor
import Shared

// MARK: - Start

struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start the selection monitoring daemon."
    )

    @Flag(name: .long, help: "Run in foreground instead of daemonizing")
    var foreground: Bool = false

    func run() throws {
        // Check if already running
        if let pid = DaemonController.runningDaemonPID() {
            print("DevTranslator daemon is already running (PID: \(pid)).")
            throw ExitCode.failure
        }

        if foreground {
            // Run in foreground (blocks)
            let daemon = DaemonController()
            daemon.start()
        } else {
            // Fork to background
            let binary = ProcessInfo.processInfo.arguments[0]
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = ["start", "--foreground"]

            // Detach stdin/stdout/stderr
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice

            try process.run()
            let pid = process.processIdentifier
            print("DevTranslator daemon started in background (PID: \(pid)).")
        }
    }
}

// MARK: - Stop

struct StopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the selection monitoring daemon."
    )

    func run() throws {
        if DaemonController.stopRunningDaemon() {
            print("DevTranslator daemon stopped.")
        } else {
            print("DevTranslator daemon is not running.")
        }
    }
}

// MARK: - Status

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check if the daemon is running."
    )

    func run() throws {
        if let pid = DaemonController.runningDaemonPID() {
            print("DevTranslator daemon is running (PID: \(pid)).")
        } else {
            print("DevTranslator daemon is not running.")
        }

        let granted = PermissionHelper.isAccessibilityGranted
        print("Accessibility permission: \(granted ? "granted" : "not granted")")
    }
}

// MARK: - Toggle

struct ToggleCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "toggle",
        abstract: "Toggle translation on/off without stopping the daemon."
    )

    func run() throws {
        guard let pid = DaemonController.runningDaemonPID() else {
            print("DevTranslator daemon is not running. Start it with: devtranslator start")
            throw ExitCode.failure
        }

        // Send SIGUSR1 to toggle pause
        kill(pid, SIGUSR1)
        print("Toggle signal sent to daemon (PID: \(pid)).")
    }
}
