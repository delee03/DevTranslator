import AppKit
import Shared

/// A small floating "Dt" icon that appears near selected text.
/// Clicking it triggers the translation popup.
///
/// Uses a CGEvent tap for click detection because NSEvent monitors don't
/// fire for accessory-mode apps when another app is frontmost.
public final class SelectionIcon: NSObject {
    private var window: NSWindow?
    private var onClicked: (() -> Void)?
    private var dismissTimer: Timer?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    public override init() {
        super.init()
    }

    /// Show the selection icon near the given screen position.
    public func show(near position: CGPoint, onClick: @escaping () -> Void) {
        dismissImmediate()

        self.onClicked = onClick

        let size = PopupStyle.iconSize
        var frame = NSRect(
            x: position.x + 8,
            y: position.y - size - 4,
            width: size,
            height: size
        )

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

        let button = IconButton(frame: NSRect(origin: .zero, size: frame.size))
        window.contentView = button

        self.window = window

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

        installEventTap()
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
        removeEventTap()

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
        removeEventTap()
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - CGEvent Tap

    private func installEventTap() {
        removeEventTap()

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let eventMask: CGEventMask = (1 << CGEventType.leftMouseDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let icon = Unmanaged<SelectionIcon>.fromOpaque(refcon).takeUnretainedValue()

                guard let window = icon.window else { return Unmanaged.passUnretained(event) }

                // NSEvent.mouseLocation handles multi-monitor coordinate conversion correctly.
                let cocoaPoint = NSEvent.mouseLocation
                let frame = window.frame

                if frame.contains(cocoaPoint) {
                    DispatchQueue.main.async {
                        icon.handleClick()
                    }
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else {
            fputs("[warning] SelectionIcon: failed to create CGEvent tap (Accessibility permission missing?)\n", stderr)
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }
}

// MARK: - Clickable Panel

private class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Icon Button View

/// Custom NSView that draws the "Dt" icon and provides hover feedback.
private class IconButton: NSView {
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    override init(frame: NSRect) {
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
