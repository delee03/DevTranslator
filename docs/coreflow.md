# Core Flow: Floating Icon Click Detection

## The Problem

DevTranslator runs as an `.accessory` macOS app (no dock icon) with a floating `NSPanel` that appears when text is selected. The icon must be clickable while another app (e.g., Terminal) is frontmost.

## Why Standard Approaches Fail

| Approach | Why it fails |
|----------|-------------|
| `NSView.mouseDown` | Not delivered — accessory apps' floating panels don't receive mouse events when another app is active |
| `NSEvent.addGlobalMonitorForEvents` | Only observes events sent to **other** apps; clicks on the panel are routed to the owning app but swallowed |
| `NSEvent.addLocalMonitorForEvents` | Only observes events for **this** app; the accessory app's event loop doesn't process the click |
| `NSPanel.canBecomeKey = true` | Doesn't help — the window server consumes the event before AppKit dispatches it |

## What Works: `CGEvent.tapCreate`

A **CGEvent tap** intercepts mouse events at the Core Graphics session level, before the window server routes them to any app. This is the same mechanism used by [PopClip](https://www.popclip.app/).

```swift
CGEvent.tapCreate(
    tap: .cgSessionEventTap,      // session-level interception
    place: .headInsertEventTap,   // before dispatch
    options: .listenOnly,         // observe, don't consume
    eventsOfInterest: (1 << CGEventType.leftMouseDown.rawValue),
    callback: { ... },
    userInfo: refcon
)
```

**Requirements:** Accessibility permission (`AXIsProcessTrusted()`).

## Multi-Monitor Coordinate Handling

CG and Cocoa use different coordinate systems (top-left vs bottom-left origin). Manual conversion via `screenHeight - cgY` only works for the main display.

**Correct approach:** Use `NSEvent.mouseLocation` inside the CGEvent callback. It returns proper Cocoa coordinates on any display.

```swift
// WRONG — breaks on non-main displays
let cocoaY = NSScreen.main!.frame.height - cgEvent.location.y

// CORRECT — works everywhere
let cocoaPoint = NSEvent.mouseLocation
```

## Service Startup for Unbundled CLI Apps

`NSApplication.delegate.applicationDidFinishLaunching` is unreliable for CLI tools built with SwiftPM (no `.app` bundle). Use `DispatchQueue.main.async` before `app.run()` to defer setup until the run loop is active:

```swift
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

DispatchQueue.main.async {
    startTimers()
    installEventTaps()
}

app.run() // blocks, processes the queued async block
```

## Debugging

Stream daemon logs in real time:

```bash
log stream --predicate 'subsystem == "com.devtranslator"' --level debug
```

Show recent logs:

```bash
log show --predicate 'subsystem == "com.devtranslator"' --last 60s --style compact
```
