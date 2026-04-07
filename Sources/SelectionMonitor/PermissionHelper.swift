import AppKit
import Shared

/// Manages macOS Accessibility permission checking and prompting.
public enum PermissionHelper {

    /// Check if the app has Accessibility permission.
    public static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Check permission and prompt the user if not granted.
    /// When `prompt` is true, macOS shows the system dialog asking
    /// the user to grant Accessibility access in System Settings.
    @discardableResult
    public static func checkAndPrompt(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            Logger.shared.warning("Accessibility permission not granted.")
            if prompt {
                printPermissionGuide()
            }
        } else {
            Logger.shared.info("Accessibility permission granted.")
        }

        return trusted
    }

    /// Print user-friendly instructions for granting Accessibility permission.
    public static func printPermissionGuide() {
        let message = """

        ⚠ DevTranslator needs Accessibility permission to detect text selection.

        To grant access:
          1. Open System Settings → Privacy & Security → Accessibility
          2. Click the "+" button
          3. Add your terminal app (or DevTranslator if running standalone)
          4. Restart DevTranslator

        Or run:
          open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

        """
        fputs(message, stderr)
    }

    /// Open the Accessibility pane in System Settings.
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
