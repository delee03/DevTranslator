# Contributing to DevTranslator

Thanks for your interest! Here's everything you need to get started.

## Quick Setup

```bash
git clone https://github.com/delee03/DevTranslator.git
cd DevTranslator
swift build
swift test --enable-swift-testing --disable-xctest
```

**Requirements:** macOS 13+, Swift 5.9+ (Xcode 15+ or Command Line Tools)

## Making Changes

1. Fork the repo and create a branch (`feature/...`, `fix/...`, `docs/...`)
2. Make your changes — keep commits focused
3. Make sure tests pass
4. Open a PR against `main`

## Project Structure

| Module | What | Difficulty |
|--------|------|-----------|
| `TranslationEngine` | Google Translate API client, LRU cache | Easy |
| `Shared` | Config, logging, constants | Easy |
| `DevTranslator` | CLI entry point, subcommands | Medium |

## Testing

We use **Swift Testing** (not XCTest):

```swift
import Testing
@testable import TranslationEngine

@Test func cacheEvictsLRU() {
    let cache = TranslationCache(maxSize: 2)
    // ...
    #expect(cache.get(text: "old", from: "en", to: "vi") == nil)
}
```

```bash
swift test --enable-swift-testing --disable-xctest
```

## Guidelines

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use `async/await`, not completion handlers
- No force-unwraps (`!`) in production code
- Minimize dependencies — discuss new ones in an issue first
- One feature/fix per PR

## Reporting Bugs

[Open an issue](https://github.com/delee03/DevTranslator/issues/new) with: what happened, steps to reproduce, your macOS version, terminal app, and `devtranslator --version`.

## License

Contributions are licensed under [MIT](LICENSE).
