import Foundation

/// Result of a translation request.
public struct TranslationResult: Equatable, Sendable {
    public let originalText: String
    public let translatedText: String
    public let sourceLang: String
    public let targetLang: String

    public init(originalText: String, translatedText: String, sourceLang: String, targetLang: String) {
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLang = sourceLang
        self.targetLang = targetLang
    }
}

/// Protocol for translation backends.
/// Implement this to add support for DeepL, LibreTranslate, etc.
public protocol TranslationService: Sendable {
    /// Translate text from one language to another.
    /// - Parameters:
    ///   - text: The text to translate.
    ///   - from: Source language code (empty string for auto-detect).
    ///   - to: Target language code.
    /// - Returns: The translation result.
    func translate(text: String, from: String, to: String) async throws -> TranslationResult
}
