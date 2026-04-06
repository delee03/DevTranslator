import XCTest
@testable import TranslationEngine

final class GoogleTranslateServiceTests: XCTestCase {

    // MARK: - Empty input

    func testEmptyInputThrowsEmptyInputError() async {
        let service = GoogleTranslateService()

        do {
            _ = try await service.translate(text: "", from: "en", to: "vi")
            XCTFail("Expected TranslationError.emptyInput")
        } catch let error as TranslationError {
            guard case .emptyInput = error else {
                XCTFail("Expected .emptyInput, got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected TranslationError.emptyInput, got: \(error)")
        }
    }

    func testWhitespaceOnlyInputThrowsEmptyInputError() async {
        let service = GoogleTranslateService()

        do {
            _ = try await service.translate(text: "   \n\t  ", from: "en", to: "vi")
            XCTFail("Expected TranslationError.emptyInput")
        } catch let error as TranslationError {
            guard case .emptyInput = error else {
                XCTFail("Expected .emptyInput, got: \(error)")
                return
            }
        } catch {
            XCTFail("Expected TranslationError.emptyInput, got: \(error)")
        }
    }

    // MARK: - Response parsing

    /// Since `parseResponse` and `parseDetectedLanguage` are private,
    /// we cannot test them directly. Instead, we verify:
    /// 1. The error descriptions are correct (proving the enum is well-formed)
    /// 2. The mock service correctly fulfills the TranslationService protocol
    /// 3. The empty input validation works (the only path testable without network)

    func testTranslationErrorDescriptions() {
        XCTAssertEqual(
            TranslationError.emptyInput.errorDescription,
            "No text to translate"
        )
        XCTAssertEqual(
            TranslationError.invalidURL.errorDescription,
            "Invalid translation URL"
        )
        XCTAssertEqual(
            TranslationError.invalidResponse.errorDescription,
            "Could not parse translation response"
        )
        XCTAssertEqual(
            TranslationError.rateLimited.errorDescription,
            "Rate limited by translation service. Try again in a moment."
        )
        XCTAssertEqual(
            TranslationError.timeout.errorDescription,
            "Translation request timed out"
        )
    }

    func testNetworkErrorDescriptionIncludesUnderlyingError() {
        let underlying = URLError(.notConnectedToInternet)
        let error = TranslationError.networkError(underlying: underlying)

        let description = error.errorDescription ?? ""
        XCTAssertTrue(description.hasPrefix("Network error:"),
                      "Network error description should start with 'Network error:'")
    }

    // MARK: - TranslationError pattern matching

    func testTranslationErrorCasesAreDistinct() {
        let errors: [TranslationError] = [
            .invalidURL,
            .networkError(underlying: URLError(.badURL)),
            .invalidResponse,
            .rateLimited,
            .timeout,
            .emptyInput,
        ]

        for error in errors {
            switch error {
            case .invalidURL, .networkError, .invalidResponse,
                 .rateLimited, .timeout, .emptyInput:
                break // All cases covered
            }
        }
        // If this compiles, all cases are handled
    }

    // MARK: - Protocol conformance via mock

    func testMockServiceConformsToTranslationServiceProtocol() async throws {
        let mock = MockTranslationService()
        mock.translatedTextOverride = "Xin chao"
        mock.detectedSourceLangOverride = "en"

        let result = try await mock.translate(text: "Hello", from: "", to: "vi")

        XCTAssertEqual(result.originalText, "Hello")
        XCTAssertEqual(result.translatedText, "Xin chao")
        XCTAssertEqual(result.sourceLang, "en")
        XCTAssertEqual(result.targetLang, "vi")
    }

    func testMockServiceThrowsConfiguredError() async {
        let mock = MockTranslationService()
        mock.errorToThrow = TranslationError.invalidResponse

        do {
            _ = try await mock.translate(text: "Hello", from: "en", to: "vi")
            XCTFail("Expected error to be thrown")
        } catch let error as TranslationError {
            guard case .invalidResponse = error else {
                XCTFail("Expected .invalidResponse, got: \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testMockServiceRecordsCallCount() async throws {
        let mock = MockTranslationService()

        XCTAssertEqual(mock.callCount, 0)

        _ = try await mock.translate(text: "A", from: "en", to: "vi")
        _ = try await mock.translate(text: "B", from: "en", to: "vi")

        XCTAssertEqual(mock.callCount, 2)
    }

    // MARK: - TranslationResult

    func testTranslationResultEquality() {
        let a = TranslationResult(originalText: "Hi", translatedText: "Chao",
                                  sourceLang: "en", targetLang: "vi")
        let b = TranslationResult(originalText: "Hi", translatedText: "Chao",
                                  sourceLang: "en", targetLang: "vi")
        XCTAssertEqual(a, b)
    }

    func testTranslationResultInequality() {
        let a = TranslationResult(originalText: "Hi", translatedText: "Chao",
                                  sourceLang: "en", targetLang: "vi")
        let b = TranslationResult(originalText: "Hi", translatedText: "Konnichiwa",
                                  sourceLang: "en", targetLang: "ja")
        XCTAssertNotEqual(a, b)
    }
}
