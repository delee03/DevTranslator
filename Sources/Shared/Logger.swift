import Foundation
import os

public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public final class Logger {
    public static let shared = Logger()

    private let osLog = os.Logger(subsystem: "com.devtranslator", category: "general")
    public var minLevel: LogLevel = .info

    private init() {}

    public func debug(_ message: String) {
        log(message, level: .debug)
    }

    public func info(_ message: String) {
        log(message, level: .info)
    }

    public func warning(_ message: String) {
        log(message, level: .warning)
    }

    public func error(_ message: String) {
        log(message, level: .error)
    }

    private func log(_ message: String, level: LogLevel) {
        guard level >= minLevel else { return }
        switch level {
        case .debug:
            osLog.debug("\(message, privacy: .public)")
        case .info:
            osLog.info("\(message, privacy: .public)")
        case .warning:
            osLog.warning("\(message, privacy: .public)")
        case .error:
            osLog.error("\(message, privacy: .public)")
        }
    }
}
