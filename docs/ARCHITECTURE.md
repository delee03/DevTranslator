# DevTranslator Architecture

## Overview

DevTranslator is a pure Swift macOS application with three layers:

```
┌─────────────────────────────────┐
│  CLI / Daemon Entry Point       │  ArgumentParser + RunLoop
├─────────────────────────────────┤
│  Translation Engine             │  URLSession + LRU Cache
├─────────────────────────────────┤
│  Shared Utilities               │  Config, Logger, Constants
└─────────────────────────────────┘
```

Future layers (Phase 2+):

```
┌─────────────────────────────────┐
│  Status Bar App                 │  NSStatusItem menu bar
├─────────────────────────────────┤
│  Popup UI                       │  NSPanel overlay window
├─────────────────────────────────┤
│  Selection Monitor              │  AXUIElement (Accessibility API)
├─────────────────────────────────┤
│  Translation Engine             │  (same as above)
└─────────────────────────────────┘
```

---

## How Translation Works

### The Google Translate Endpoint

We use the **same HTTP endpoint that Google Translate's web frontend uses** — no official API, no API key, no auth. This is the approach used by [translate-shell](https://github.com/soimort/translate-shell), [py-googletrans](https://github.com/ssut/py-googletrans), and the Ddict browser extension.

```
GET https://translate.googleapis.com/translate_a/single
  ?client=gtx        ← identifies as Google Translate web client
  &sl=auto           ← source language (auto-detect, or specific code)
  &tl=vi             ← target language
  &dt=t              ← return translation segments
  &dt=bd             ← return dictionary entries if available
  &q=Hello world     ← URL-encoded text to translate
```

You can verify this yourself: open Chrome DevTools on translate.google.com, type something, and watch the Network tab.

### Response Format

Google returns a nested JSON array (not a clean object):

```json
[
  [
    ["Xin chào thế giới", "Hello world", null, null, 10]
  ],
  null,
  "en"
]
```

| Path | Contains |
|------|----------|
| `[0][*][0]` | Translated text segments — join them to get the full translation |
| `[2]` | Detected source language code (e.g., `"en"`) |

We parse with `JSONSerialization` since the structure is too irregular for `Codable`. See `GoogleTranslateService.parseResponse()` and `parseDetectedLanguage()`.

### Why Not the Official API?

The official Google Cloud Translation API requires an API key, billing account, and costs $20/million characters. For a free, zero-config developer tool, the unofficial endpoint is the right choice. It has been stable for years across many open-source projects.

If Google changes the endpoint, the `TranslationService` protocol makes it easy to swap backends (DeepL, LibreTranslate, etc.) without touching the rest of the codebase.

---

## Request Flow

### CLI Mode (`devtranslator "Hello world"`)

```
User input ("Hello world")
    │
    ▼
┌─────────────────────────┐
│ CLI (ArgumentParser)     │  Parses args/stdin, loads config
│                          │  Determines source + target language
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│ CachedTranslationService │  Wraps GoogleTranslateService
│                          │  Checks LRU cache first
└─────────┬───────────────┘
          │ cache hit? → return immediately
          │ cache miss ↓
          ▼
┌─────────────────────────┐
│ GoogleTranslateService   │  Builds URL with query params
│                          │  Sends GET via URLSession (async/await)
│                          │  Timeout: 3 seconds
└─────────┬───────────────┘
          │
          ▼
  translate.googleapis.com
          │
          ▼
┌─────────────────────────┐
│ Parse JSON response      │  Extract [0][*][0] segments → join
│                          │  Extract [2] → detected language
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│ Store in LRU cache       │  Key: "auto:vi:Hello world"
│                          │  For instant lookup next time
└─────────┬───────────────┘
          │
          ▼
   stdout: "Xin chào thế giới"
```

### Pipe Mode (`echo "text" | devtranslator`)

Same flow, except the CLI detects stdin is not a terminal (`isatty(STDIN_FILENO) == 0`), reads all lines from stdin, joins them, and feeds the result into the translation flow above.

### Daemon Mode (Phase 2 — not yet implemented)

```
Background daemon (RunLoop)
    │
    ▼
┌─────────────────────────┐
│ SelectionObserver        │  AXObserver watches focused app
│                          │  Fires on AXSelectedTextChanged
└─────────┬───────────────┘
          │ user selects text
          ▼
┌─────────────────────────┐
│ AccessibilityManager     │  Reads AXSelectedText from focused element
│                          │  Falls back to AXValue if needed
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│ SelectionIcon            │  Shows small "Dt" icon near cursor
│                          │  User clicks it (or presses Cmd+Shift+T)
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│ CachedTranslationService │  Same translation flow as CLI mode
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│ TranslationPopup         │  NSPanel overlay near selection
│                          │  Shows translation + Copy button
│                          │  Auto-dismiss after 10 seconds
└─────────────────────────┘
```

---

## Module Details

### TranslationEngine

| File | Responsibility |
|------|---------------|
| `TranslationService.swift` | Protocol: `func translate(text:from:to:) async throws -> TranslationResult`. Implement this to add new backends. |
| `GoogleTranslateService.swift` | Hits `translate.googleapis.com/translate_a/single` via URLSession. Parses the nested JSON array response. Handles errors (timeout, rate limit, invalid response). |
| `TranslationCache.swift` | Thread-safe LRU cache. Key = `sourceLang:targetLang:text`. Protected by `NSLock`. Evicts least-recently-used when full. |
| `CachedTranslationService.swift` | Decorator that wraps any `TranslationService` with `TranslationCache`. Check cache → miss → call underlying → store result. |

### Shared

| File | Responsibility |
|------|---------------|
| `Config.swift` | `Config` struct (Codable) + `ConfigManager` for reading/writing `~/.config/devtranslator/config.json`. Returns hardcoded defaults if file doesn't exist. |
| `Logger.swift` | Thin wrapper around `os.Logger`. Levels: debug, info, warning, error. |
| `Constants.swift` | App name, version, file paths, API base URL, default values. |

### DevTranslator (CLI)

| File | Responsibility |
|------|---------------|
| `DevTranslator.swift` | `@main` entry point. Root command with `TranslateCommand` as default subcommand. |
| `ConfigCommand.swift` | `devtranslator config` — view, update, or reset config via CLI flags. |
| `DaemonCommands.swift` | Placeholder stubs for `start`, `stop`, `status`, `toggle` (Phase 2). |

---

## Cache Design

The LRU cache avoids redundant network requests for repeated translations.

**Key format:** `sourceLang:targetLang:text`
- `"en:vi:Hello"` and `"en:ja:Hello"` are separate entries
- `"auto:vi:Hello"` and `"en:vi:Hello"` are also separate (different source spec)

**Eviction:** When the cache is full (default: 500 entries), the least recently accessed entry is evicted. Both `get` and `put` operations update the access order.

**Thread safety:** All cache operations are protected by `NSLock`. This matters for Phase 2 where multiple translation requests may happen concurrently from the daemon.

---

## Adding a New Translation Backend

1. Create a new file (e.g., `DeepLService.swift`) in `Sources/TranslationEngine/`
2. Implement the `TranslationService` protocol:

```swift
public final class DeepLService: TranslationService {
    public func translate(text: String, from: String, to: String) async throws -> TranslationResult {
        // Hit DeepL API, parse response, return TranslationResult
    }
}
```

3. Wire it up in the CLI or config (e.g., `"backend": "deepl"` in config.json)
4. The cache layer (`CachedTranslationService`) works with any backend automatically

---

## Config System

**Location:** `~/.config/devtranslator/config.json`

**Load behavior:** `ConfigManager.load()` reads the file. If it doesn't exist or is malformed, returns `Config.default` (target: `vi`, timeout: 3000ms, cache: 500). No crash, no error to the user.

**Save behavior:** `ConfigManager.save()` creates the directory if needed, writes pretty-printed JSON with sorted keys.

**All config fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `targetLang` | String | `"vi"` | Target translation language |
| `sourceLang` | String | `""` | Source language (empty = auto-detect) |
| `shortcut` | String | `"cmd+shift+t"` | Global keyboard shortcut |
| `autostart` | Bool | `true` | Start daemon on login |
| `showSelectionIcon` | Bool | `true` | Show floating icon on text selection |
| `popupDuration` | Int | `10` | Popup auto-dismiss seconds |
| `apiTimeoutMs` | Int | `3000` | HTTP request timeout |
| `cacheSize` | Int | `500` | Max cached translations |
