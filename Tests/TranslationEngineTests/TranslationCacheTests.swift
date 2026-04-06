import XCTest
@testable import TranslationEngine

final class TranslationCacheTests: XCTestCase {

    // MARK: - Helpers

    private func makeResult(
        original: String = "Hello",
        translated: String = "Xin chao",
        source: String = "en",
        target: String = "vi"
    ) -> TranslationResult {
        TranslationResult(
            originalText: original,
            translatedText: translated,
            sourceLang: source,
            targetLang: target
        )
    }

    // MARK: - Basic put / get

    func testPutAndGet() {
        let cache = TranslationCache(maxSize: 10)
        let result = makeResult()

        cache.put(result, from: "en")
        let fetched = cache.get(text: "Hello", from: "en", to: "vi")

        XCTAssertEqual(fetched, result)
    }

    // MARK: - Cache miss

    func testGetReturnsNilOnMiss() {
        let cache = TranslationCache(maxSize: 10)

        let fetched = cache.get(text: "Hello", from: "en", to: "vi")

        XCTAssertNil(fetched)
    }

    func testGetReturnsNilForWrongKey() {
        let cache = TranslationCache(maxSize: 10)
        cache.put(makeResult(), from: "en")

        // Different text
        XCTAssertNil(cache.get(text: "Goodbye", from: "en", to: "vi"))
        // Different source lang
        XCTAssertNil(cache.get(text: "Hello", from: "fr", to: "vi"))
        // Different target lang
        XCTAssertNil(cache.get(text: "Hello", from: "en", to: "ja"))
    }

    // MARK: - LRU eviction

    func testLRUEvictionWhenFull() {
        let cache = TranslationCache(maxSize: 3)

        let r1 = makeResult(original: "one",   translated: "mot",  target: "vi")
        let r2 = makeResult(original: "two",   translated: "hai",  target: "vi")
        let r3 = makeResult(original: "three", translated: "ba",   target: "vi")
        let r4 = makeResult(original: "four",  translated: "bon",  target: "vi")

        cache.put(r1, from: "en")
        cache.put(r2, from: "en")
        cache.put(r3, from: "en")

        XCTAssertEqual(cache.count, 3)

        // Inserting a 4th item should evict "one" (LRU)
        cache.put(r4, from: "en")

        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.get(text: "one", from: "en", to: "vi"),
                     "Least recently used item 'one' should have been evicted")
        XCTAssertNotNil(cache.get(text: "two",   from: "en", to: "vi"))
        XCTAssertNotNil(cache.get(text: "three", from: "en", to: "vi"))
        XCTAssertNotNil(cache.get(text: "four",  from: "en", to: "vi"))
    }

    func testLRUEvictionRespectsAccessOrder() {
        let cache = TranslationCache(maxSize: 3)

        let r1 = makeResult(original: "one",   translated: "mot", target: "vi")
        let r2 = makeResult(original: "two",   translated: "hai", target: "vi")
        let r3 = makeResult(original: "three", translated: "ba",  target: "vi")
        let r4 = makeResult(original: "four",  translated: "bon", target: "vi")

        cache.put(r1, from: "en")
        cache.put(r2, from: "en")
        cache.put(r3, from: "en")

        // Access "one" to make it recently used
        _ = cache.get(text: "one", from: "en", to: "vi")

        // Now insert "four" — "two" should be evicted (it's now the LRU)
        cache.put(r4, from: "en")

        XCTAssertEqual(cache.count, 3)
        XCTAssertNil(cache.get(text: "two", from: "en", to: "vi"),
                     "'two' should have been evicted as LRU after 'one' was accessed")
        XCTAssertNotNil(cache.get(text: "one",   from: "en", to: "vi"))
        XCTAssertNotNil(cache.get(text: "three", from: "en", to: "vi"))
        XCTAssertNotNil(cache.get(text: "four",  from: "en", to: "vi"))
    }

    // MARK: - Count

    func testCountReflectsEntries() {
        let cache = TranslationCache(maxSize: 10)

        XCTAssertEqual(cache.count, 0)

        cache.put(makeResult(original: "a", translated: "x", target: "vi"), from: "en")
        XCTAssertEqual(cache.count, 1)

        cache.put(makeResult(original: "b", translated: "y", target: "vi"), from: "en")
        XCTAssertEqual(cache.count, 2)
    }

    func testCountDoesNotIncreaseForDuplicateKey() {
        let cache = TranslationCache(maxSize: 10)

        let r1 = makeResult(original: "Hello", translated: "Xin chao", target: "vi")
        let r2 = makeResult(original: "Hello", translated: "Xin chao (updated)", target: "vi")

        cache.put(r1, from: "en")
        cache.put(r2, from: "en")

        XCTAssertEqual(cache.count, 1, "Replacing same key should not increase count")
    }

    // MARK: - Clear

    func testClearEmptiesCache() {
        let cache = TranslationCache(maxSize: 10)

        cache.put(makeResult(original: "a", translated: "x", target: "vi"), from: "en")
        cache.put(makeResult(original: "b", translated: "y", target: "vi"), from: "en")

        XCTAssertEqual(cache.count, 2)

        cache.clear()

        XCTAssertEqual(cache.count, 0)
        XCTAssertNil(cache.get(text: "a", from: "en", to: "vi"))
        XCTAssertNil(cache.get(text: "b", from: "en", to: "vi"))
    }

    // MARK: - Same text, different language pairs

    func testSameTextDifferentLanguagePairsAreSeparateEntries() {
        let cache = TranslationCache(maxSize: 10)

        let toVietnamese = makeResult(original: "Hello", translated: "Xin chao", source: "en", target: "vi")
        let toJapanese  = makeResult(original: "Hello", translated: "Konnichiwa", source: "en", target: "ja")
        let fromFrench  = makeResult(original: "Hello", translated: "Bonjour-ish", source: "fr", target: "vi")

        cache.put(toVietnamese, from: "en")
        cache.put(toJapanese, from: "en")
        cache.put(fromFrench, from: "fr")

        XCTAssertEqual(cache.count, 3)

        let fetchedVi = cache.get(text: "Hello", from: "en", to: "vi")
        let fetchedJa = cache.get(text: "Hello", from: "en", to: "ja")
        let fetchedFr = cache.get(text: "Hello", from: "fr", to: "vi")

        XCTAssertEqual(fetchedVi?.translatedText, "Xin chao")
        XCTAssertEqual(fetchedJa?.translatedText, "Konnichiwa")
        XCTAssertEqual(fetchedFr?.translatedText, "Bonjour-ish")
    }

    // MARK: - Thread safety

    func testConcurrentAccessDoesNotCrash() async {
        let cache = TranslationCache(maxSize: 100)

        // Use a task group to hammer the cache from many concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask {
                    let text = "item-\(i % 50)"
                    let result = TranslationResult(
                        originalText: text,
                        translatedText: "translated-\(i % 50)",
                        sourceLang: "en",
                        targetLang: "vi"
                    )
                    cache.put(result, from: "en")
                    _ = cache.get(text: text, from: "en", to: "vi")
                }
            }
        }

        // If we got here without a crash, thread safety is working.
        // The cache should have at most 100 entries.
        XCTAssertLessThanOrEqual(cache.count, 100)
        XCTAssertGreaterThan(cache.count, 0)
    }

    func testConcurrentReadsAndWritesReturnConsistentResults() async {
        let cache = TranslationCache(maxSize: 50)

        // Pre-populate
        for i in 0..<50 {
            let result = TranslationResult(
                originalText: "key-\(i)",
                translatedText: "val-\(i)",
                sourceLang: "en",
                targetLang: "vi"
            )
            cache.put(result, from: "en")
        }

        // Concurrent reads should return correct or nil (if evicted), never garbage
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let key = "key-\(i % 50)"
                    if let result = cache.get(text: key, from: "en", to: "vi") {
                        XCTAssertEqual(result.originalText, key)
                        XCTAssertEqual(result.translatedText, "val-\(i % 50)")
                    }
                }
                group.addTask {
                    let result = TranslationResult(
                        originalText: "new-\(i)",
                        translatedText: "newval-\(i)",
                        sourceLang: "en",
                        targetLang: "vi"
                    )
                    cache.put(result, from: "en")
                }
            }
        }

        XCTAssertLessThanOrEqual(cache.count, 50)
    }

    // MARK: - Edge cases

    func testMaxSizeClampedToAtLeastOne() {
        let cache = TranslationCache(maxSize: 0)
        let result = makeResult()

        cache.put(result, from: "en")
        XCTAssertEqual(cache.count, 1, "maxSize of 0 should be clamped to 1")

        let fetched = cache.get(text: "Hello", from: "en", to: "vi")
        XCTAssertEqual(fetched, result)
    }

    func testPutUpdatesExistingEntry() {
        let cache = TranslationCache(maxSize: 10)

        let original = makeResult(original: "Hello", translated: "Xin chao", target: "vi")
        let updated  = makeResult(original: "Hello", translated: "Chao ban", target: "vi")

        cache.put(original, from: "en")
        cache.put(updated, from: "en")

        let fetched = cache.get(text: "Hello", from: "en", to: "vi")
        XCTAssertEqual(fetched?.translatedText, "Chao ban",
                       "Putting the same key again should update the value")
    }
}
