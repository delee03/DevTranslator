# macOS Status Bar Plan

## Goal

Add a macOS menu bar/status bar controller so users can see DevTranslator's state and control the daemon without returning to the terminal.

This is not the next implementation priority. Build it after the release/install path and daemon diagnostics are stable.

## Why This Matters

DevTranslator depends on background behavior that is otherwise invisible:

- Accessibility permission must be granted.
- The selection daemon must be running.
- Translation can be paused or resumed.
- Target language should be visible and easy to confirm.

A status bar item gives users a persistent, low-friction control surface.

## Current Fit

The daemon already starts an AppKit runtime in `DaemonController`:

```swift
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.run()
```

That shape can host an `NSStatusItem` without showing a Dock icon.

## Proposed Files

```text
Sources/PopupUI/StatusBarController.swift
Sources/DevTranslator/DaemonController.swift
```

Optional later:

```text
Sources/Shared/AppState.swift
```

Only add shared app state if the status bar starts duplicating daemon state logic.

## Initial Menu

```text
DevTranslator: Running
Accessibility: Granted
Target Language: vi
---
Pause
Translate Current Selection
Open Accessibility Settings
Diagnose
Quit
```

Paused state:

```text
DevTranslator: Paused
Resume
```

Permission warning state:

```text
DevTranslator: Needs Permission
Accessibility: Not Granted
Open Accessibility Settings
```

## Status Behavior

- Running: normal template icon.
- Paused: dimmed icon or alternate title.
- Permission missing: warning menu item and optional warning icon state.
- Translation in progress: avoid noisy animation for the first version.
- Translation failed: keep failure visible in popup/logs; do not spam status bar notifications.

## Implementation Sketch

Create a lightweight controller around `NSStatusBar.system.statusItem`.

```swift
final class StatusBarController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func start(actions: Actions) {
        item.button?.title = "Dt"
        item.menu = buildMenu(actions: actions)
    }
}
```

Wire it from `DaemonController.startServices()`:

```swift
statusBar.start(
    actions: .init(
        togglePause: { [weak self] in self?.togglePause() },
        translateSelection: { [weak self] in self?.handleHotkeyPress() },
        openAccessibilitySettings: { PermissionHelper.openAccessibilitySettings() },
        quit: { NSApp.terminate(nil) }
    )
)
```

Keep ownership one-way:

- `DaemonController` owns runtime state.
- `StatusBarController` renders state and forwards user actions.
- `StatusBarController` should not start/stop the daemon directly.

## State Needed From Daemon

Expose enough state to refresh the menu:

```swift
struct DaemonStatus {
    let isPaused: Bool
    let accessibilityGranted: Bool
    let targetLanguage: String
}
```

Refresh points:

- daemon startup
- pause/resume
- config changes, if config becomes reloadable
- app activation or menu opening

For the first version, rebuild the menu when the user opens it and when pause state changes.

## User Experience Rules

- No Dock icon.
- No persistent window.
- Menu labels should be short and operational.
- Avoid marketing copy in the menu.
- Do not show selected text in the menu.
- Do not log selected text while implementing this feature.

## Packaging Consideration

The first implementation can live inside the existing daemon process.

For a polished public release, consider moving the status bar into a real `.app` bundle. A bundle gives macOS a stable identity for:

- Accessibility permission
- menu bar icon assets
- login item behavior
- signing and notarization
- user trust prompts

Do not block the first status bar implementation on app bundling, but keep the design compatible with that migration.

## Suggested Implementation Order

1. Add `StatusBarController` with static menu and Quit action.
2. Wire Pause/Resume to `DaemonController.togglePause()`.
3. Add Accessibility status and "Open Accessibility Settings".
4. Add "Translate Current Selection".
5. Replace text title with template icon from `Assets/icon-menubarTemplate.png`.
6. Add focused manual QA notes for Terminal, iTerm2, and VS Code/Cursor terminals.

## Acceptance Criteria

- `devtranslator start --foreground` shows a `Dt` status bar item.
- Menu shows running/paused state accurately.
- Pause/Resume works from the menu.
- "Translate Current Selection" uses the same path as the hotkey.
- "Open Accessibility Settings" opens the correct macOS settings pane.
- Quit removes the PID file and exits cleanly.
- No selected text is shown in status bar UI or logs.

## Risks

- Unbundled CLI identity may make Accessibility permission confusing.
- Login/autostart behavior will need LaunchAgent or bundled app work.
- Menu state can drift if config changes while daemon is running.
- Status item icon assets may need bundling work when installed outside SwiftPM.

