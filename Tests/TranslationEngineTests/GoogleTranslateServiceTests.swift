import Foundation
import Testing
@testable import TranslationEngine

@Suite("GoogleTranslateService Tests")
struct GoogleTranslateServiceTests {

    // MARK: - Empty input

    @Test func emptyInputThrowsEmptyInputError() async {
        let service = GoogleTranslateService()

        await #expect(throws: TranslationError.self) {
            try await service.translate(text: "", from: "en", to: "vi")
        }
    }

    @Test func whitespaceOnlyInputThrowsEmptyInputError() async {
        let service = GoogleTranslateService()

        await #expect(throws: TranslationError.self) {
            try await service.translate(text: "   \n\t  ", from: "en", to: "vi")
        }
    }

    // MARK: - Error descriptions

    @Test func translationErrorDescriptions() {
        #expect(TranslationError.emptyInput.errorDescription == "No text to translate")
        #expect(TranslationError.invalidURL.errorDescription == "Invalid translation URL")
        #expect(TranslationError.invalidResponse.errorDescription == "Could not parse translation response")
        #expect(TranslationError.rateLimited.errorDescription == "Rate limited by translation service. Try again in a moment.")
        #expect(TranslationError.timeout.errorDescription == "Translation request timed out")
    }

    @Test func networkErrorDescriptionIncludesUnderlying() {
        let underlying = URLError(.notConnectedToInternet)
        let error = TranslationError.networkError(underlying: underlying)
        let description = error.errorDescription ?? ""
        #expect(description.hasPrefix("Network error:"))
    }

    // MARK: - Protocol conformance via mock

    @Test func mockServiceConformsToProtocol() async throws {
        let mock = MockTranslationService()
        mock.translatedTextOverride = "Xin chao"
        mock.detectedSourceLangOverride = "en"

        let result = try await mock.translate(text: "Hello", from: "", to: "vi")

        #expect(result.originalText == "Hello")
        #expect(result.translatedText == "Xin chao")
        #expect(result.sourceLang == "en")
        #expect(result.targetLang == "vi")
    }

    @Test func mockServiceThrowsConfiguredError() async {
        let mock = MockTranslationService()
        mock.errorToThrow = TranslationError.invalidResponse

        await #expect(throws: TranslationError.self) {
            try await mock.translate(text: "Hello", from: "en", to: "vi")
        }
    }

    @Test func mockServiceRecordsCallCount() async throws {
        let mock = MockTranslationService()

        #expect(mock.callCount == 0)
        _ = try await mock.translate(text: "A", from: "en", to: "vi")
        _ = try await mock.translate(text: "B", from: "en", to: "vi")
        #expect(mock.callCount == 2)
    }

    // MARK: - TranslationResult

    @Test func translationResultEquality() {
        let a = TranslationResult(originalText: "Hi", translatedText: "Chao",
                                  sourceLang: "en", targetLang: "vi")
        let b = TranslationResult(originalText: "Hi", translatedText: "Chao",
                                  sourceLang: "en", targetLang: "vi")
        #expect(a == b)
    }

    @Test func translationResultInequality() {
        let a = TranslationResult(originalText: "Hi", translatedText: "Chao",
                                  sourceLang: "en", targetLang: "vi")
        let b = TranslationResult(originalText: "Hi", translatedText: "Konnichiwa",
                                  sourceLang: "en", targetLang: "ja")
        #expect(a != b)
    }
}
