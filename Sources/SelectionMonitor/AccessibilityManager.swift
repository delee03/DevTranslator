import AppKit
import Shared

/// Reads selected text from the currently focused application using the macOS Accessibility API.
public final class AccessibilityManager: @unchecked Sendable {
    public static let shared = AccessibilityManager()

    private init() {}

    /// Get the currently focused application's AXUIElement.
    public func focusedApplication() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AXUIElementCreateApplication(app.processIdentifier)
    }

    /// Get the focused UI element within an application.
    public func focusedElement(of app: AXUIElement) -> AXUIElement? {
        var element: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &element)
        guard result == .success, let el = element else { return nil }
        return (el as! AXUIElement)
    }

    /// Read the selected text from a UI element.
    /// Tries AXSelectedText first, falls back to AXSelectedTextRange + AXValue.
    public func selectedText(from element: AXUIElement) -> String? {
        // Primary: AXSelectedText — most terminals support this
        if let text = attributeValue(of: element, attribute: kAXSelectedTextAttribute as CFString) as? String,
           !text.isEmpty {
            Logger.shared.debug("Read selected text via AXSelectedText (\(text.count) chars)")
            return text
        }

        // Fallback: read selected range + full text value, then extract substring
        // Ghostty and some other terminals don't implement AXSelectedText but do
        // expose AXSelectedTextRange + AXValue
        if let rangeValue = attributeValue(of: element, attribute: kAXSelectedTextRangeAttribute as CFString) {
            var textRange = CFRange(location: 0, length: 0)
            let isAXValue = CFGetTypeID(rangeValue) == AXValueGetTypeID()
            if isAXValue, AXValueGetValue(rangeValue as! AXValue, .cfRange, &textRange), textRange.length > 0 {
                Logger.shared.debug("AXSelectedTextRange: location=\(textRange.location) length=\(textRange.length)")
                if let fullText = attributeValue(of: element, attribute: kAXValueAttribute as CFString) as? String {
                    // Safely extract the substring
                    let utf16 = fullText.utf16
                    let startIdx = utf16.index(utf16.startIndex, offsetBy: textRange.location, limitedBy: utf16.endIndex) ?? utf16.endIndex
                    let endIdx = utf16.index(startIdx, offsetBy: textRange.length, limitedBy: utf16.endIndex) ?? utf16.endIndex
                    if let selected = String(utf16[startIdx..<endIdx]) {
                        if !selected.isEmpty {
                            Logger.shared.debug("Read selected text via AXValue fallback (\(selected.count) chars)")
                            return selected
                        }
                    }
                }
            } else {
                Logger.shared.debug("AXSelectedTextRange: length=0 or not AXValue type")
            }
        } else {
            Logger.shared.debug("AXSelectedTextRange: not available")
        }

        Logger.shared.debug("Could not read selected text from focused element")
        return nil
    }

    /// Get the currently selected text from whatever app is in the foreground.
    /// Convenience method combining focusedApplication + focusedElement + selectedText.
    public func currentSelectedText() -> String? {
        guard let app = focusedApplication(),
              let element = focusedElement(of: app) else {
            return nil
        }
        return selectedText(from: element)
    }

    /// Get the bounds of the selected text in **Cocoa screen coordinates** (bottom-left origin).
    /// Uses the AXBoundsForRange parameterized attribute with the selected text range.
    /// Returns nil if bounds cannot be determined.
    public func selectedTextBounds(from element: AXUIElement) -> CGRect? {
        // Get the selected text range first
        guard let rangeValue = attributeValue(of: element, attribute: kAXSelectedTextRangeAttribute as CFString) else {
            Logger.shared.debug("selectedTextBounds: no AXSelectedTextRange")
            return nil
        }

        // Use the range as parameter to get bounds via AXBoundsForRange
        var boundsRef: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsRef
        )

        if result == .success, let axValue = boundsRef {
            var rect = CGRect.zero
            if CFGetTypeID(axValue) == AXValueGetTypeID(),
               AXValueGetValue(axValue as! AXValue, .cgRect, &rect) {
                let cocoa = cgRectToCocoaScreen(rect)
                Logger.shared.debug("selectedTextBounds via AXBoundsForRange: \(cocoa)")
                return cocoa
            }
        }

        Logger.shared.debug("selectedTextBounds: AXBoundsForRange failed (\(result.rawValue)), no bounds available")
        return nil
    }

    /// Convert a Core Graphics screen rect (top-left origin) to Cocoa screen rect (bottom-left origin).
    private func cgRectToCocoaScreen(_ cgRect: CGRect) -> CGRect {
        guard let screenHeight = NSScreen.main?.frame.height else { return cgRect }
        // CG: y goes down from top. Cocoa: y goes up from bottom.
        // Cocoa.y = screenHeight - CG.y - rect.height
        return CGRect(
            x: cgRect.origin.x,
            y: screenHeight - cgRect.origin.y - cgRect.height,
            width: cgRect.width,
            height: cgRect.height
        )
    }

    /// Read an attribute value from an AXUIElement.
    private func attributeValue(of element: AXUIElement, attribute: CFString) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success else { return nil }
        return value
    }
}
