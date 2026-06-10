import AppKit
import Shared

/// Callback fired when text selection changes in any application.
public typealias SelectionHandler = (_ selectedText: String, _ cursorPosition: CGPoint) -> Void

/// Monitors text selection by polling the Accessibility API at regular intervals.
/// This is more reliable than AXObserver or NSEvent global monitors, which are
/// unreliable for terminal apps and accessory-mode applications.
///
/// CPU cost is kept low by polling at a conservative interval and skipping
/// Accessibility reads outside the configured app allowlist.
public final class SelectionObserver: @unchecked Sendable {
    private let accessibilityManager = AccessibilityManager.shared
    private var onSelection: SelectionHandler?
    private var pollTimer: Timer?
    private var isRunning = false
    private var allowedApps = Set(Config.defaultAllowedApps)

    // Track last selection to avoid duplicate callbacks
    private var lastSelectedText: String = ""

    // Poll interval in seconds. Keep this conservative because AX calls can be
    // expensive in some apps.
    private let pollInterval: TimeInterval = 1.0

    public init() {}

    /// Start monitoring text selection changes.
    /// - Parameter handler: Called on the main thread when new text is selected.
    ///
    /// **Important:** This must be called after `NSApplication.shared.run()` has started
    /// (i.e. from `applicationDidFinishLaunching`). Timers scheduled before the app
    /// run loop is active will never fire.
    public func start(handler: @escaping SelectionHandler) {
        guard !isRunning else { return }
        self.onSelection = handler
        self.isRunning = true
        self.allowedApps = Set(ConfigManager.load().allowedApps)

        // Create the timer and explicitly add it to the main run loop in .common modes.
        // Using .common ensures the timer fires even when menus are open, windows are
        // being dragged, or the run loop is in a non-default mode.
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForSelection()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer

        fputs("[info] SelectionObserver started (polling every \(pollInterval)s)\n", stderr)
        Logger.shared.info("SelectionObserver started (polling every \(pollInterval)s).")
    }

    /// Stop monitoring.
    public func stop() {
        guard isRunning else { return }
        isRunning = false

        pollTimer?.invalidate()
        pollTimer = nil
        onSelection = nil
        lastSelectedText = ""

        Logger.shared.info("SelectionObserver stopped.")
    }

    public var running: Bool { isRunning }

    // MARK: - Selection Detection

    private func checkForSelection() {
        guard isFrontmostAppAllowed() else {
            lastSelectedText = ""
            return
        }

        guard let text = accessibilityManager.currentSelectedText(),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // Text was deselected — reset tracking so re-selecting same text works
            if !lastSelectedText.isEmpty {
                lastSelectedText = ""
            }
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't fire for the same selection twice
        guard trimmed != lastSelectedText else { return }
        lastSelectedText = trimmed

        let position = NSEvent.mouseLocation
        onSelection?(trimmed, position)
    }

    private func isFrontmostAppAllowed() -> Bool {
        accessibilityManager.isFrontmostApplicationAllowed(allowedApps)
    }
}
