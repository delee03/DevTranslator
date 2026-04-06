import XCTest
@testable import TranslationEngine

final class CachedTranslationServiceTests: XCTestCase {

    private var mock: MockTranslationService!
    private var cached: CachedTranslationService!

    override func setUp() {
        super.setUp()
        mock = MockTranslationService()
        cached = CachedTranslationService(service: mock, cacheSize: 50)
    }

    override func tearDown() {
        mock = nil
        cached = nil
        super.tearDown()
    }

    // MARK: - First call goes to underlying service

    func testFirstCallDelegatesToUnderlyingService() async throws {
        mock.translatedTextOverride = "Xin chao"

        let result = try await cached.translate(text: "Hello", from: "en", to: "vi")

        XCTAssertEqual(result.originalText, "Hello")
        XCTAssertEqual(result.translatedText, "Xin chao")
        XCTAssertEqual(result.targetLang, "vi")
        XCTAssertEqual(mock.callCount, 1, "Underlying service should be called once")
    }

    // MARK: - Second call returns cached result

    func testSecondCallWithSameInputReturnsCachedResult() async throws {
        mock.translatedTextOverride = "Xin chao"

        let first = try await cached.translate(text: "Hello", from: "en", to: "vi")
        let second = try await cached.translate(text: "Hello", from: "en", to: "vi")

        XCTAssertEqual(first, second)
        XCTAssertEqual(mock.callCount, 1,
                       "Underlying service should only be called once; second call should hit cache")
    }

    func testCacheCountIncreasesAfterTranslation() async throws {
        XCTAssertEqual(cached.cacheCount, 0)

        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")

        XCTAssertEqual(cached.cacheCount, 1)
    }

    // MARK: - Different inputs both get translated

    func testDifferentInputsBothCallUnderlyingService() async throws {
        let r1 = try await cached.translate(text: "Hello", from: "en", to: "vi")
        let r2 = try await cached.translate(text: "Goodbye", from: "en", to: "vi")

        XCTAssertEqual(mock.callCount, 2, "Each unique input should call the underlying service")
        XCTAssertNotEqual(r1.originalText, r2.originalText)
        XCTAssertEqual(r1.translatedText, "mock-Hello")
        XCTAssertEqual(r2.translatedText, "mock-Goodbye")
        XCTAssertEqual(cached.cacheCount, 2)
    }

    func testDifferentTargetLanguagesAreCachedSeparately() async throws {
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "Hello", from: "en", to: "ja")

        XCTAssertEqual(mock.callCount, 2)
        XCTAssertEqual(cached.cacheCount, 2)

        // Repeating should hit cache
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "Hello", from: "en", to: "ja")

        XCTAssertEqual(mock.callCount, 2, "Repeated calls should hit cache, not underlying service")
    }

    // MARK: - clearCache

    func testClearCacheEmptiesAllEntries() async throws {
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "World", from: "en", to: "vi")
        XCTAssertEqual(cached.cacheCount, 2)

        cached.clearCache()

        XCTAssertEqual(cached.cacheCount, 0)
    }

    func testAfterClearCacheNextCallGoesToUnderlyingService() async throws {
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        XCTAssertEqual(mock.callCount, 1)

        cached.clearCache()

        // Translating the same text should call the underlying service again
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        XCTAssertEqual(mock.callCount, 2,
                       "After clearing cache, the same text should go to the underlying service again")
    }

    // MARK: - Error propagation

    func testErrorFromUnderlyingServiceIsPropagated() async {
        mock.errorToThrow = TranslationError.rateLimited

        do {
            _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
            XCTFail("Expected error to be thrown")
        } catch let error as TranslationError {
            switch error {
            case .rateLimited:
                break // expected
            default:
                XCTFail("Expected .rateLimited, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(cached.cacheCount, 0,
                       "Failed translations should not be cached")
    }

    func testErrorDoesNotCacheResult() async {
        mock.errorToThrow = TranslationError.networkError(underlying: URLError(.notConnectedToInternet))

        _ = try? await cached.translate(text: "Hello", from: "en", to: "vi")

        XCTAssertEqual(cached.cacheCount, 0, "Failed translation should not be cached")

        // Now make it succeed
        mock.errorToThrow = nil
        mock.translatedTextOverride = "Xin chao"

        let result = try? await cached.translate(text: "Hello", from: "en", to: "vi")

        XCTAssertEqual(result?.translatedText, "Xin chao")
        XCTAssertEqual(mock.callCount, 2, "Should call underlying service again after previous failure")
        XCTAssertEqual(cached.cacheCount, 1)
    }

    // MARK: - Mock call tracking

    func testMockRecordsCallArguments() async throws {
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "World", from: "en", to: "ja")

        XCTAssertEqual(mock.calls.count, 2)
        XCTAssertEqual(mock.calls[0].text, "Hello")
        XCTAssertEqual(mock.calls[0].from, "en")
        XCTAssertEqual(mock.calls[0].to, "vi")
        XCTAssertEqual(mock.calls[1].text, "World")
        XCTAssertEqual(mock.calls[1].to, "ja")
    }
}
