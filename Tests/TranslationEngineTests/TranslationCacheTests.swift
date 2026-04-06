import Testing
@testable import TranslationEngine

@Suite("TranslationCache Tests")
struct TranslationCacheTests {

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

    @Test func putAndGet() {
        let cache = TranslationCache(maxSize: 10)
        let result = makeResult()

        cache.put(result, from: "en")
        let fetched = cache.get(text: "Hello", from: "en", to: "vi")

        #expect(fetched == result)
    }

    // MARK: - Cache miss

    @Test func getReturnsNilOnMiss() {
        let cache = TranslationCache(maxSize: 10)
        let fetched = cache.get(text: "Hello", from: "en", to: "vi")
        #expect(fetched == nil)
    }

    @Test func getReturnsNilForWrongKey() {
        let cache = TranslationCache(maxSize: 10)
        cache.put(makeResult(), from: "en")

        #expect(cache.get(text: "Goodbye", from: "en", to: "vi") == nil)
        #expect(cache.get(text: "Hello", from: "fr", to: "vi") == nil)
        #expect(cache.get(text: "Hello", from: "en", to: "ja") == nil)
    }

    // MARK: - LRU eviction

    @Test func lruEvictionWhenFull() {
        let cache = TranslationCache(maxSize: 3)

        let r1 = makeResult(original: "one",   translated: "mot",  target: "vi")
        let r2 = makeResult(original: "two",   translated: "hai",  target: "vi")
        let r3 = makeResult(original: "three", translated: "ba",   target: "vi")
        let r4 = makeResult(original: "four",  translated: "bon",  target: "vi")

        cache.put(r1, from: "en")
        cache.put(r2, from: "en")
        cache.put(r3, from: "en")
        #expect(cache.count == 3)

        cache.put(r4, from: "en")
        #expect(cache.count == 3)
        #expect(cache.get(text: "one", from: "en", to: "vi") == nil, "LRU item 'one' should be evicted")
        #expect(cache.get(text: "two",   from: "en", to: "vi") != nil)
        #expect(cache.get(text: "three", from: "en", to: "vi") != nil)
        #expect(cache.get(text: "four",  from: "en", to: "vi") != nil)
    }

    @Test func lruEvictionRespectsAccessOrder() {
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

        // Now "two" is LRU
        cache.put(r4, from: "en")
        #expect(cache.count == 3)
        #expect(cache.get(text: "two", from: "en", to: "vi") == nil, "'two' should be evicted as LRU")
        #expect(cache.get(text: "one",   from: "en", to: "vi") != nil)
        #expect(cache.get(text: "three", from: "en", to: "vi") != nil)
        #expect(cache.get(text: "four",  from: "en", to: "vi") != nil)
    }

    // MARK: - Count

    @Test func countReflectsEntries() {
        let cache = TranslationCache(maxSize: 10)
        #expect(cache.count == 0)

        cache.put(makeResult(original: "a", translated: "x", target: "vi"), from: "en")
        #expect(cache.count == 1)

        cache.put(makeResult(original: "b", translated: "y", target: "vi"), from: "en")
        #expect(cache.count == 2)
    }

    @Test func countDoesNotIncreaseForDuplicateKey() {
        let cache = TranslationCache(maxSize: 10)
        cache.put(makeResult(original: "Hello", translated: "Xin chao", target: "vi"), from: "en")
        cache.put(makeResult(original: "Hello", translated: "Xin chao (updated)", target: "vi"), from: "en")
        #expect(cache.count == 1, "Replacing same key should not increase count")
    }

    // MARK: - Clear

    @Test func clearEmptiesCache() {
        let cache = TranslationCache(maxSize: 10)
        cache.put(makeResult(original: "a", translated: "x", target: "vi"), from: "en")
        cache.put(makeResult(original: "b", translated: "y", target: "vi"), from: "en")
        #expect(cache.count == 2)

        cache.clear()
        #expect(cache.count == 0)
        #expect(cache.get(text: "a", from: "en", to: "vi") == nil)
        #expect(cache.get(text: "b", from: "en", to: "vi") == nil)
    }

    // MARK: - Same text, different language pairs

    @Test func sameTextDifferentLanguagePairsAreSeparate() {
        let cache = TranslationCache(maxSize: 10)

        let toVi = makeResult(original: "Hello", translated: "Xin chao", source: "en", target: "vi")
        let toJa = makeResult(original: "Hello", translated: "Konnichiwa", source: "en", target: "ja")
        let fromFr = makeResult(original: "Hello", translated: "Bonjour-ish", source: "fr", target: "vi")

        cache.put(toVi, from: "en")
        cache.put(toJa, from: "en")
        cache.put(fromFr, from: "fr")

        #expect(cache.count == 3)
        #expect(cache.get(text: "Hello", from: "en", to: "vi")?.translatedText == "Xin chao")
        #expect(cache.get(text: "Hello", from: "en", to: "ja")?.translatedText == "Konnichiwa")
        #expect(cache.get(text: "Hello", from: "fr", to: "vi")?.translatedText == "Bonjour-ish")
    }

    // MARK: - Thread safety

    @Test func concurrentAccessDoesNotCrash() async {
        let cache = TranslationCache(maxSize: 100)

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

        #expect(cache.count <= 100)
        #expect(cache.count > 0)
    }

    // MARK: - Edge cases

    @Test func maxSizeClampedToAtLeastOne() {
        let cache = TranslationCache(maxSize: 0)
        cache.put(makeResult(), from: "en")
        #expect(cache.count == 1, "maxSize of 0 should be clamped to 1")
    }

    @Test func putUpdatesExistingEntry() {
        let cache = TranslationCache(maxSize: 10)
        cache.put(makeResult(original: "Hello", translated: "Xin chao", target: "vi"), from: "en")
        cache.put(makeResult(original: "Hello", translated: "Chao ban", target: "vi"), from: "en")

        let fetched = cache.get(text: "Hello", from: "en", to: "vi")
        #expect(fetched?.translatedText == "Chao ban", "Should update existing value")
    }
}
