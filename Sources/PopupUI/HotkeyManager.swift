import AppKit
import Shared

/// Registers and manages the global keyboard shortcut (Cmd+Shift+T) for triggering translation.
public final class HotkeyManager {
    private var monitor: Any?
    private var onTrigger: (() -> Void)?

    public init() {}

    /// Start listening for the global hotkey.
    /// - Parameter handler: Called on the main thread when the hotkey is pressed.
    public func register(handler: @escaping () -> Void) {
        self.onTrigger = handler

        // Parse the shortcut from config
        let config = ConfigManager.load()
        let (modifiers, keyCode) = parseShortcut(config.shortcut)

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers,
                  event.keyCode == keyCode else {
                return
            }

            if Thread.isMainThread {
                self?.onTrigger?()
            } else {
                CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) {
                    self?.onTrigger?()
                }
                CFRunLoopWakeUp(CFRunLoopGetMain())
            }
        }

        Logger.shared.info("Hotkey registered: \(config.shortcut)")
    }

    /// Stop listening for the hotkey.
    public func unregister() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        onTrigger = nil
    }

    /// Parse a shortcut string like "cmd+shift+t" into modifier flags and key code.
    private func parseShortcut(_ shortcut: String) -> (NSEvent.ModifierFlags, UInt16) {
        let parts = shortcut.lowercased().split(separator: "+").map(String.init)
        var modifiers: NSEvent.ModifierFlags = []
        var key = ""

        for part in parts {
            switch part {
            case "cmd", "command": modifiers.insert(.command)
            case "shift": modifiers.insert(.shift)
            case "ctrl", "control": modifiers.insert(.control)
            case "alt", "option": modifiers.insert(.option)
            default: key = part
            }
        }

        let keyCode = keyCodeForCharacter(key)
        return (modifiers, keyCode)
    }

    /// Map a character to its macOS virtual key code.
    private func keyCodeForCharacter(_ char: String) -> UInt16 {
        let keyMap: [String: UInt16] = [
            "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E,
            "f": 0x03, "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26,
            "k": 0x28, "l": 0x25, "m": 0x2E, "n": 0x2D, "o": 0x1F,
            "p": 0x23, "q": 0x0C, "r": 0x0F, "s": 0x01, "t": 0x11,
            "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07, "y": 0x10,
            "z": 0x06,
        ]
        return keyMap[char.lowercased()] ?? 0x11 // Default to "t"
    }
}
