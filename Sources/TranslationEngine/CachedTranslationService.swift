import Foundation

/// Wraps a `TranslationService` with an LRU cache layer.
public final class CachedTranslationService: TranslationService {
    private let underlying: any TranslationService
    private let cache: TranslationCache

    public init(service: any TranslationService, cacheSize: Int = 500) {
        self.underlying = service
        self.cache = TranslationCache(maxSize: cacheSize)
    }

    public func translate(text: String, from sourceLang: String, to targetLang: String) async throws -> TranslationResult {
        // Check cache first
        if let cached = cache.get(text: text, from: sourceLang, to: targetLang) {
            return cached
        }

        // Cache miss — fetch from backend
        let result = try await underlying.translate(text: text, from: sourceLang, to: targetLang)
        cache.put(result, from: sourceLang)
        return result
    }

    /// Expose cache count for testing/status.
    public var cacheCount: Int {
        cache.count
    }

    /// Clear the translation cache.
    public func clearCache() {
        cache.clear()
    }
}
