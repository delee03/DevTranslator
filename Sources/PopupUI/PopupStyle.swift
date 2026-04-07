import AppKit

/// Styling constants for the translation popup, aware of dark/light mode.
public enum PopupStyle {
    // MARK: - Dimensions

    public static let popupWidth: CGFloat = 320
    public static let popupMaxHeight: CGFloat = 200
    public static let popupCornerRadius: CGFloat = 10
    public static let popupPadding: CGFloat = 12

    public static let iconSize: CGFloat = 24
    public static let iconCornerRadius: CGFloat = 6

    public static let animationDuration: TimeInterval = 0.2

    // MARK: - Colors

    public static var popupBackgroundColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 0.95)
                : NSColor(white: 1.0, alpha: 0.95)
        }
    }

    public static var textColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? .white
                : .black
        }
    }

    public static var secondaryTextColor: NSColor {
        .secondaryLabelColor
    }

    public static var borderColor: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.1)
                : NSColor(white: 0.0, alpha: 0.1)
        }
    }

    public static let accentColor = NSColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 1.0) // #e94560

    // MARK: - Fonts

    public static let translationFont = NSFont.systemFont(ofSize: 14, weight: .regular)
    public static let codeFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    public static let buttonFont = NSFont.systemFont(ofSize: 12, weight: .medium)

    // MARK: - Shadow

    public static func popupShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 12
        return shadow
    }
}
