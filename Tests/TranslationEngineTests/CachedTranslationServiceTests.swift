import Foundation
import Testing
@testable import TranslationEngine

@Suite("CachedTranslationService Tests")
struct CachedTranslationServiceTests {

    private func makeSUT() -> (mock: MockTranslationService, cached: CachedTranslationService) {
        let mock = MockTranslationService()
        let cached = CachedTranslationService(service: mock, cacheSize: 50)
        return (mock, cached)
    }

    // MARK: - First call delegates to underlying

    @Test func firstCallDelegatesToUnderlyingService() async throws {
        let (mock, cached) = makeSUT()
        mock.translatedTextOverride = "Xin chao"

        let result = try await cached.translate(text: "Hello", from: "en", to: "vi")

        #expect(result.originalText == "Hello")
        #expect(result.translatedText == "Xin chao")
        #expect(result.targetLang == "vi")
        #expect(mock.callCount == 1)
    }

    // MARK: - Second call returns cached

    @Test func secondCallWithSameInputReturnsCached() async throws {
        let (mock, cached) = makeSUT()
        mock.translatedTextOverride = "Xin chao"

        let first = try await cached.translate(text: "Hello", from: "en", to: "vi")
        let second = try await cached.translate(text: "Hello", from: "en", to: "vi")

        #expect(first == second)
        #expect(mock.callCount == 1, "Second call should hit cache")
    }

    @Test func cacheCountIncreasesAfterTranslation() async throws {
        let (_, cached) = makeSUT()
        #expect(cached.cacheCount == 0)

        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        #expect(cached.cacheCount == 1)
    }

    // MARK: - Different inputs

    @Test func differentInputsBothCallUnderlying() async throws {
        let (mock, cached) = makeSUT()

        let r1 = try await cached.translate(text: "Hello", from: "en", to: "vi")
        let r2 = try await cached.translate(text: "Goodbye", from: "en", to: "vi")

        #expect(mock.callCount == 2)
        #expect(r1.originalText != r2.originalText)
        #expect(r1.translatedText == "mock-Hello")
        #expect(r2.translatedText == "mock-Goodbye")
        #expect(cached.cacheCount == 2)
    }

    @Test func differentTargetLanguagesCachedSeparately() async throws {
        let (mock, cached) = makeSUT()

        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "Hello", from: "en", to: "ja")
        #expect(mock.callCount == 2)
        #expect(cached.cacheCount == 2)

        // Repeating should hit cache
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "Hello", from: "en", to: "ja")
        #expect(mock.callCount == 2, "Repeated calls should hit cache")
    }

    // MARK: - clearCache

    @Test func clearCacheEmptiesAllEntries() async throws {
        let (_, cached) = makeSUT()
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "World", from: "en", to: "vi")
        #expect(cached.cacheCount == 2)

        cached.clearCache()
        #expect(cached.cacheCount == 0)
    }

    @Test func afterClearCacheNextCallGoesToUnderlying() async throws {
        let (mock, cached) = makeSUT()
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        #expect(mock.callCount == 1)

        cached.clearCache()
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        #expect(mock.callCount == 2, "After clearing, same text should call underlying again")
    }

    // MARK: - Error propagation

    @Test func errorFromUnderlyingIsPropagated() async {
        let (mock, cached) = makeSUT()
        mock.errorToThrow = TranslationError.rateLimited

        await #expect(throws: TranslationError.self) {
            try await cached.translate(text: "Hello", from: "en", to: "vi")
        }
        #expect(cached.cacheCount == 0, "Failed translations should not be cached")
    }

    @Test func errorDoesNotCacheResult() async throws {
        let (mock, cached) = makeSUT()
        mock.errorToThrow = TranslationError.networkError(underlying: URLError(.notConnectedToInternet))

        _ = try? await cached.translate(text: "Hello", from: "en", to: "vi")
        #expect(cached.cacheCount == 0)

        mock.errorToThrow = nil
        mock.translatedTextOverride = "Xin chao"

        let result = try await cached.translate(text: "Hello", from: "en", to: "vi")
        #expect(result.translatedText == "Xin chao")
        #expect(mock.callCount == 2, "Should call underlying again after previous failure")
        #expect(cached.cacheCount == 1)
    }

    // MARK: - Call tracking

    @Test func mockRecordsCallArguments() async throws {
        let (mock, cached) = makeSUT()
        _ = try await cached.translate(text: "Hello", from: "en", to: "vi")
        _ = try await cached.translate(text: "World", from: "en", to: "ja")

        #expect(mock.calls.count == 2)
        #expect(mock.calls[0].text == "Hello")
        #expect(mock.calls[0].from == "en")
        #expect(mock.calls[0].to == "vi")
        #expect(mock.calls[1].text == "World")
        #expect(mock.calls[1].to == "ja")
    }
}
