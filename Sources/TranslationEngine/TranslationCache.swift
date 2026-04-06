import Foundation

/// Thread-safe LRU cache for translation results.
public final class TranslationCache: @unchecked Sendable {
    private let maxSize: Int
    private var cache: [String: TranslationResult] = [:]
    private var accessOrder: [String] = []  // Most recently used at the end
    private let lock = NSLock()

    public init(maxSize: Int = 500) {
        self.maxSize = max(1, maxSize)
    }

    /// Look up a cached translation.
    public func get(text: String, from sourceLang: String, to targetLang: String) -> TranslationResult? {
        let key = cacheKey(text: text, from: sourceLang, to: targetLang)
        lock.lock()
        defer { lock.unlock() }

        guard let result = cache[key] else { return nil }

        // Move to end (most recently used)
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
            accessOrder.append(key)
        }
        return result
    }

    /// Store a translation result in the cache.
    public func put(_ result: TranslationResult, from sourceLang: String) {
        let key = cacheKey(text: result.originalText, from: sourceLang, to: result.targetLang)
        lock.lock()
        defer { lock.unlock() }

        if cache[key] != nil {
            // Already exists — move to end
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        } else if cache.count >= maxSize {
            // Evict least recently used
            let evictKey = accessOrder.removeFirst()
            cache.removeValue(forKey: evictKey)
        }

        cache[key] = result
        accessOrder.append(key)
    }

    /// Number of cached entries.
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    /// Clear all cached entries.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
        accessOrder.removeAll()
    }

    private func cacheKey(text: String, from sourceLang: String, to targetLang: String) -> String {
        "\(sourceLang):\(targetLang):\(text)"
    }
}
