import AppKit
import Shared
import TranslationEngine

/// Floating popup panel that displays the translation result.
public final class TranslationPopup {
    private var panel: NSPanel?
    private var dismissTimer: Timer?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private let dismissDuration: TimeInterval

    public init(dismissAfter: TimeInterval = 10) {
        self.dismissDuration = dismissAfter
    }

    /// Show the translation popup near the given screen position.
    /// - Parameters:
    ///   - translation: The translated text to display.
    ///   - position: Screen coordinates (Cocoa bottom-left origin).
    public func show(translation: String, near position: CGPoint) {
        dismiss()

        let contentView = buildContentView(translation: translation)
        let contentSize = contentView.fittingSize
        let width = min(max(contentSize.width + PopupStyle.popupPadding * 2, PopupStyle.popupWidth), 480)
        let height = min(contentSize.height + PopupStyle.popupPadding * 2, PopupStyle.popupMaxHeight)

        let frame = NSRect(
            x: position.x - width / 2,
            y: position.y + 8,
            width: width,
            height: height
        )

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true

        let container = PopupContainerView(frame: NSRect(origin: .zero, size: frame.size))
        container.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: container.topAnchor, constant: PopupStyle.popupPadding),
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: PopupStyle.popupPadding),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -PopupStyle.popupPadding),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -PopupStyle.popupPadding),
        ])
        panel.contentView = container

        if let screen = NSScreen.main {
            var adjusted = frame
            if adjusted.maxX > screen.visibleFrame.maxX {
                adjusted.origin.x = screen.visibleFrame.maxX - adjusted.width - 8
            }
            if adjusted.minX < screen.visibleFrame.minX {
                adjusted.origin.x = screen.visibleFrame.minX + 8
            }
            if adjusted.maxY > screen.visibleFrame.maxY {
                adjusted.origin.y = position.y - height - 8
            }
            if adjusted.minY < screen.visibleFrame.minY {
                adjusted.origin.y = screen.visibleFrame.minY + 8
            }
            panel.setFrame(adjusted, display: true)
        }

        self.panel = panel

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = PopupStyle.animationDuration
            panel.animator().alphaValue = 1.0
        }

        dismissTimer?.invalidate()
        let autoDismiss = Timer(timeInterval: dismissDuration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
        RunLoop.main.add(autoDismiss, forMode: .common)
        dismissTimer = autoDismiss

        removeClickMonitors()

        // Global monitor: dismiss when clicking in another app (e.g., terminal)
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            if let panel = self?.panel, !panel.frame.contains(NSEvent.mouseLocation) {
                self?.dismiss()
            }
        }

        // Local monitor: dismiss when clicking elsewhere within this app
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            if let panel = self?.panel, !panel.frame.contains(NSEvent.mouseLocation) {
                self?.dismiss()
            }
            return event
        }
    }

    /// Show an error message in the popup.
    public func showError(_ message: String, near position: CGPoint) {
        show(translation: "⚠ \(message)", near: position)
    }

    /// Dismiss the popup.
    public func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        removeClickMonitors()

        guard let panel = self.panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = PopupStyle.animationDuration
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
        })
    }

    private func removeClickMonitors() {
        if let m = globalClickMonitor { NSEvent.removeMonitor(m); globalClickMonitor = nil }
        if let m = localClickMonitor { NSEvent.removeMonitor(m); localClickMonitor = nil }
    }

    // MARK: - Content Building

    private func buildContentView(translation: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        let textField = NSTextField(wrappingLabelWithString: translation)
        textField.font = PopupStyle.translationFont
        textField.textColor = PopupStyle.textColor
        textField.isSelectable = true
        textField.maximumNumberOfLines = 8
        stack.addArrangedSubview(textField)

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyTranslation(_:)))
        copyButton.font = PopupStyle.buttonFont
        copyButton.bezelStyle = .inline
        copyButton.contentTintColor = PopupStyle.accentColor
        copyButton.tag = translation.hashValue
        // Accessibility identifier used to pass translation text to the copy action
        copyButton.setAccessibilityIdentifier(translation)
        stack.addArrangedSubview(copyButton)

        return stack
    }

    @objc private func copyTranslation(_ sender: NSButton) {
        let translation = sender.accessibilityIdentifier()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translation, forType: .string)

        sender.title = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sender.title = "Copy"
        }
    }
}

// MARK: - Popup Container View

/// Custom NSView that draws the styled popup background.
private class PopupContainerView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: PopupStyle.popupCornerRadius, yRadius: PopupStyle.popupCornerRadius)

        PopupStyle.popupBackgroundColor.setFill()
        path.fill()

        PopupStyle.borderColor.setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }

    override var allowsVibrancy: Bool { true }
}
