import Foundation
@testable import TranslationEngine

/// A mock `TranslationService` that records calls and returns preconfigured results.
final class MockTranslationService: TranslationService, @unchecked Sendable {
    private(set) var callCount = 0
    private(set) var calls: [(text: String, from: String, to: String)] = []

    var errorToThrow: Error?
    var translatedTextOverride: String?
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

    func reset() {
        callCount = 0
        calls = []
        errorToThrow = nil
        translatedTextOverride = nil
        detectedSourceLangOverride = nil
    }
}
