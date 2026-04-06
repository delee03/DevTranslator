import Foundation
@testable import TranslationEngine

/// A mock `TranslationService` that records calls and returns preconfigured results.
/// Used by `CachedTranslationServiceTests` and `GoogleTranslateServiceTests`.
final class MockTranslationService: TranslationService, @unchecked Sendable {
    /// Number of times `translate` was called.
    private(set) var callCount = 0

    /// Records of all calls made to `translate`.
    private(set) var calls: [(text: String, from: String, to: String)] = []

    /// If set, `translate` will throw this error.
    var errorToThrow: Error?

    /// Override the translated text. If nil, defaults to "mock-<originalText>".
    var translatedTextOverride: String?

    /// Override the detected source language. If nil, defaults to the `from` parameter.
    var detectedSourceLangOverride: String?

    func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        callCount += 1
        calls.append((text: text, from: from, to: to))

        if let error = errorToThrow {
            throw error
        }

        let translated = translatedTextOverride ?? "mock-\(text)"
        let source = detectedSourceLangOverride ?? from

        return TranslationResult(
            originalText: text,
            translatedText: translated,
            sourceLang: source,
            targetLang: to
        )
    }

    /// Reset recorded state.
    func reset() {
        callCount = 0
        calls = []
        errorToThrow = nil
        translatedTextOverride = nil
        detectedSourceLangOverride = nil
    }
}
