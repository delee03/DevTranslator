import AppKit
import Shared

/// A small floating "Dt" icon that appears near selected text.
/// Clicking it triggers the translation popup.
public final class SelectionIcon: NSObject {
    private var window: NSWindow?
    private var onClicked: (() -> Void)?
    private var dismissTimer: Timer?
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    public override init() {
        super.init()
    }

    /// Show the selection icon near the given screen position.
    public func show(near position: CGPoint, onClick: @escaping () -> Void) {
        // Dismiss any existing icon first
        dismissImmediate()

        self.onClicked = onClick

        let size = PopupStyle.iconSize
        var frame = NSRect(
            x: position.x + 8,
            y: position.y - size - 4,
            width: size,
            height: size
        )

        // Clamp to visible screen area
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(position) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - size)
            frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - size)
        }

        let window = ClickablePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.ignoresMouseEvents = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.becomesKeyOnlyIfNeeded = true

        let button = IconButton(frame: NSRect(origin: .zero, size: frame.size)) { [weak self] in
            Logger.shared.debug("SelectionIcon clicked")
            self?.dismiss()
            self?.onClicked?()
        }
        window.contentView = button

        self.window = window

        // Fade in
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = PopupStyle.animationDuration
            window.animator().alphaValue = 0.8
        }

        // Auto-dismiss after 5 seconds if not clicked
        dismissTimer?.invalidate()
        let autoDismiss = Timer(timeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
        RunLoop.main.add(autoDismiss, forMode: .common)
        dismissTimer = autoDismiss

        // Global monitor: catches clicks when another app (terminal) is frontmost.
        // This is required because accessory apps don't receive mouseDown on their
        // floating panels when they're not the active app.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            let mouse = NSEvent.mouseLocation
            let frame = self?.window?.frame ?? .zero
            fputs("[debug] GLOBAL click at (\(mouse.x), \(mouse.y)), icon frame: \(frame)\n", stderr)
            if frame.contains(mouse) {
                fputs("[debug] >>> HIT — triggering translation\n", stderr)
                self?.handleClick()
            }
        }

        // Local monitor: catches clicks when the app IS active (fallback).
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            let mouse = NSEvent.mouseLocation
            let frame = self?.window?.frame ?? .zero
            fputs("[debug] LOCAL click at (\(mouse.x), \(mouse.y)), icon frame: \(frame)\n", stderr)
            if frame.contains(mouse) {
                fputs("[debug] >>> HIT — triggering translation\n", stderr)
                self?.handleClick()
                return nil
            }
            return event
        }

        Logger.shared.debug("SelectionIcon shown at (\(position.x), \(position.y))")
    }

    private func handleClick() {
        let callback = onClicked
        dismiss()
        callback?()
    }

    /// Hide with fade-out animation.
    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        removeMonitors()

        guard let window = self.window else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = PopupStyle.animationDuration
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            window.orderOut(nil)
            self?.window = nil
        })
    }

    /// Hide immediately without animation.
    private func dismissImmediate() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        removeMonitors()
        window?.orderOut(nil)
        window = nil
    }

    private func removeMonitors() {
        if let m = globalClickMonitor { NSEvent.removeMonitor(m); globalClickMonitor = nil }
        if let m = localClickMonitor { NSEvent.removeMonitor(m); localClickMonitor = nil }
    }
}

// MARK: - Clickable Panel

/// NSPanel subclass that accepts key status so mouseDown events
/// are delivered to its content view, even when using nonActivatingPanel style.
private class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Icon Button View

/// Custom NSView that draws the "Dt" icon. Uses a closure for click handling
/// instead of target-action (avoids NSObject requirement on the caller).
private class IconButton: NSView {
    private var isHovered = false
    private var trackingArea: NSTrackingArea?
    private let onClick: () -> Void

    init(frame: NSRect, onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds

        let bgColor = isHovered
            ? PopupStyle.accentColor
            : PopupStyle.accentColor.withAlphaComponent(0.85)
        let path = NSBezierPath(roundedRect: bounds, xRadius: PopupStyle.iconCornerRadius, yRadius: PopupStyle.iconCornerRadius)
        bgColor.setFill()
        path.fill()

        let text = "Dt"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true // Accept clicks even when the app isn't focused
    }

    override func mouseDown(with event: NSEvent) {
        onClick()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
        NSCursor.pointingHand.push()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
        NSCursor.pop()
    }
}
