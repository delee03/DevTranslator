import AppKit
import ArgumentParser
import Foundation
import SelectionMonitor
import Shared

struct DiagnoseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "diagnose",
        abstract: "Debug Accessibility API integration with the frontmost app."
    )

    func run() throws {
        guard PermissionHelper.isAccessibilityGranted else {
            print("Accessibility permission: NOT GRANTED")
            print("Grant access in System Settings → Privacy & Security → Accessibility")
            throw ExitCode.failure
        }
        print("Accessibility permission: granted\n")

        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("ERROR: No frontmost application found.")
            throw ExitCode.failure
        }

        print("Frontmost app: \(frontApp.localizedName ?? "unknown") (PID: \(frontApp.processIdentifier))")
        print("Bundle ID: \(frontApp.bundleIdentifier ?? "unknown")\n")

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Try to get focused element
        print("--- Focused Element ---")
        var focusedRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef)
        print("AXFocusedUIElement: \(focusedResult == .success ? "found" : "FAILED (\(focusedResult.rawValue))")")

        guard focusedResult == .success, let focused = focusedRef else {
            print("\nCannot get focused element. This app may not support Accessibility.")
            print("Try clicking inside a text area in the app first, then run diagnose again.")
            throw ExitCode.failure
        }

        let focusedElement = focused as! AXUIElement

        // Read role
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleRef) == .success {
            print("  Role: \(roleRef as? String ?? "unknown")")
        }

        // Read subrole
        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSubroleAttribute as CFString, &subroleRef) == .success {
            print("  Subrole: \(subroleRef as? String ?? "unknown")")
        }

        // List all attributes
        print("\n--- Available Attributes ---")
        var attrNames: CFArray?
        if AXUIElementCopyAttributeNames(focusedElement, &attrNames) == .success, let names = attrNames as? [String] {
            for name in names.sorted() {
                var value: CFTypeRef?
                let status = AXUIElementCopyAttributeValue(focusedElement, name as CFString, &value)
                let valueStr: String
                if status == .success {
                    if let s = value as? String {
                        valueStr = "\"\(s.prefix(80))\(s.count > 80 ? "..." : "")\""
                    } else {
                        valueStr = "\(type(of: value))"
                    }
                } else {
                    valueStr = "(error: \(status.rawValue))"
                }
                print("  \(name) = \(valueStr)")
            }
        } else {
            print("  Could not list attributes")
        }

        // Specifically check text selection
        print("\n--- Text Selection ---")

        var selectedTextRef: CFTypeRef?
        let selectedResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextRef)
        if selectedResult == .success, let text = selectedTextRef as? String {
            print("AXSelectedText: \"\(text.prefix(100))\"")
        } else {
            print("AXSelectedText: NOT AVAILABLE (error: \(selectedResult.rawValue))")
        }

        var selectedRangeRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef)
        if rangeResult == .success {
            print("AXSelectedTextRange: found")
        } else {
            print("AXSelectedTextRange: NOT AVAILABLE (error: \(rangeResult.rawValue))")
        }

        var valueRef: CFTypeRef?
        let valueResult = AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute as CFString, &valueRef)
        if valueResult == .success, let text = valueRef as? String {
            print("AXValue: \"\(text.prefix(100))\"")
        } else {
            print("AXValue: NOT AVAILABLE (error: \(valueResult.rawValue))")
        }

        print("\n--- Diagnosis Complete ---")
        print("If AXSelectedText shows your selected text, the daemon should work.")
        print("If NOT AVAILABLE, this terminal may need a different detection strategy.")
    }
}
