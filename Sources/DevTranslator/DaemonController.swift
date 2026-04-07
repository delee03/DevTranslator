import AppKit
import Foundation
import PopupUI
import SelectionMonitor
import Shared
import TranslationEngine

/// Orchestrates the daemon: selection observer → translation → popup.
/// Runs as an NSApplication to support AppKit UI (popup windows, hotkeys).
public final class DaemonController {
    /// Shared instance for signal handler access.
    static var current: DaemonController?

    private let selectionObserver = SelectionObserver()
    private let selectionIcon = SelectionIcon()
    private let popup: TranslationPopup
    private let hotkeyManager = HotkeyManager()
    private let translationService: CachedTranslationService
    private let config: Config

    private var isPaused = false
    private var lastSelectedText = ""
    private var lastCursorPosition = CGPoint.zero

    public init() {
        self.config = ConfigManager.load()
        self.translationService = CachedTranslationService(
            service: GoogleTranslateService(timeoutMs: config.apiTimeoutMs),
            cacheSize: config.cacheSize
        )
        self.popup = TranslationPopup(dismissAfter: TimeInterval(config.popupDuration))
    }

    /// Start the daemon. This enters the NSApplication run loop and does not return.
    public func start() {
        DaemonController.current = self
        Logger.shared.minLevel = .debug

        // Check Accessibility permission
        guard PermissionHelper.checkAndPrompt(prompt: true) else {
            fputs("Error: Accessibility permission required. Grant access and try again.\n", stderr)
            exit(1)
        }

        // Write PID file
        writePIDFile()

        // Install signal handler for clean shutdown
        signal(SIGINT) { _ in
            DaemonController.cleanup()
            exit(0)
        }
        signal(SIGTERM) { _ in
            DaemonController.cleanup()
            exit(0)
        }

        // SIGUSR1 toggles pause/resume
        signal(SIGUSR1) { _ in
            DispatchQueue.main.async {
                DaemonController.current?.togglePause()
            }
        }

        // Set up NSApplication (required for AppKit UI — panels, event monitors, timers).
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // No dock icon

        // Defer service startup to after app.run() begins processing the main
        // dispatch queue. This is more reliable than applicationDidFinishLaunching
        // for unbundled CLI tools that lack an .app wrapper.
        DispatchQueue.main.async { [self] in
            fputs("[daemon] Run loop active, starting services...\n", stderr)
            self.startServices()
        }

        fputs("DevTranslator daemon running. Press Ctrl+C to stop.\n", stderr)

        // Run the app event loop (blocks forever).
        app.run()
    }

    /// Called by the app delegate once the NSApplication event loop is running.
    /// All timer, event monitor, and window setup must happen here (not before `app.run()`).
    func startServices() {
        // Start selection monitoring
        fputs("[daemon] Starting selection observer...\n", stderr)
        selectionObserver.start { [weak self] text, position in
            fputs("[daemon] Selection callback: \"\(text.prefix(30))\"\n", stderr)
            self?.handleSelection(text: text, position: position)
        }

        // Register global hotkey
        hotkeyManager.register { [weak self] in
            self?.handleHotkeyPress()
        }

        fputs("[daemon] All systems ready. Polling active.\n", stderr)
    }

    /// Toggle pause/resume.
    public func togglePause() {
        isPaused.toggle()
        if isPaused {
            selectionIcon.dismiss()
            popup.dismiss()
            Logger.shared.info("Translation paused.")
        } else {
            Logger.shared.info("Translation resumed.")
        }
    }

    // MARK: - Selection Handling

    private func handleSelection(text: String, position: CGPoint) {
        guard !isPaused, config.showSelectionIcon else { return }

        Logger.shared.debug("Selection detected: \"\(text.prefix(50))\" at (\(position.x), \(position.y))")
        lastSelectedText = text
        lastCursorPosition = position

        // Show the floating "Dt" icon
        selectionIcon.show(near: position) { [weak self] in
            Logger.shared.debug("Icon clicked, translating...")
            self?.translateAndShow()
        }
    }

    private func handleHotkeyPress() {
        guard !isPaused else { return }

        // Read whatever is currently selected
        if let text = AccessibilityManager.shared.currentSelectedText(),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastSelectedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            lastCursorPosition = NSEvent.mouseLocation
            selectionIcon.dismiss()
            translateAndShow()
        }
    }

    private func translateAndShow() {
        let text = lastSelectedText
        let position = lastCursorPosition

        Logger.shared.debug("Translating: \"\(text.prefix(50))\" → \(config.targetLang)")

        Task {
            do {
                let result = try await translationService.translate(
                    text: text,
                    from: config.sourceLang,
                    to: config.targetLang
                )
                Logger.shared.debug("Translation result: \"\(result.translatedText.prefix(50))\"")
                await MainActor.run {
                    popup.show(translation: result.translatedText, near: position)
                }
            } catch {
                let message = (error as? TranslationError)?.localizedDescription
                    ?? "Translation failed — check your internet connection"
                Logger.shared.error("Translation failed: \(message)")
                await MainActor.run {
                    popup.showError(message, near: position)
                }
            }
        }
    }

    // MARK: - PID File Management

    private static var pidFilePath: URL {
        AppConstants.configDirectory.appendingPathComponent("devtranslator.pid")
    }

    private func writePIDFile() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let dir = AppConstants.configDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? "\(pid)".write(to: Self.pidFilePath, atomically: true, encoding: .utf8)
    }

    static func cleanup() {
        try? FileManager.default.removeItem(at: pidFilePath)
    }

    /// Read the PID from the PID file, if it exists and the process is alive.
    public static func runningDaemonPID() -> pid_t? {
        guard let pidString = try? String(contentsOf: pidFilePath, encoding: .utf8),
              let pid = pid_t(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        // Check if process is alive (signal 0 doesn't kill, just checks)
        if kill(pid, 0) == 0 {
            return pid
        }

        // Stale PID file — clean up
        try? FileManager.default.removeItem(at: pidFilePath)
        return nil
    }

    /// Stop a running daemon by sending SIGTERM.
    public static func stopRunningDaemon() -> Bool {
        guard let pid = runningDaemonPID() else { return false }
        kill(pid, SIGTERM)
        // Give it a moment then clean up
        usleep(500_000) // 0.5s
        cleanup()
        return true
    }
}
