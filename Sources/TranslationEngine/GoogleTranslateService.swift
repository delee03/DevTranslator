import Foundation
import Shared

public enum TranslationError: Error, LocalizedError {
    case invalidURL
    case networkError(underlying: Error)
    case invalidResponse
    case rateLimited
    case timeout
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid translation URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Could not parse translation response"
        case .rateLimited:
            return "Rate limited by translation service. Try again in a moment."
        case .timeout:
            return "Translation request timed out"
        case .emptyInput:
            return "No text to translate"
        }
    }
}

/// Google Translate unofficial API client.
/// Uses the same `client=gtx` endpoint that the web frontend uses.
public final class GoogleTranslateService: TranslationService {
    private let session: URLSession
    private let baseURL: String

    public init(timeoutMs: Int = AppConstants.defaultAPITimeoutMs) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = TimeInterval(timeoutMs) / 1000.0
        config.timeoutIntervalForResource = TimeInterval(timeoutMs) / 1000.0
        self.session = URLSession(configuration: config)
        self.baseURL = AppConstants.googleTranslateBaseURL
    }

    public func translate(text: String, from sourceLang: String, to targetLang: String) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationError.emptyInput
        }

        let url = try buildURL(text: trimmed, from: sourceLang, to: targetLang)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch let error as URLError where error.code == .timedOut {
            throw TranslationError.timeout
        } catch {
            throw TranslationError.networkError(underlying: error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                throw TranslationError.rateLimited
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw TranslationError.invalidResponse
            }
        }

        let translatedText = try parseResponse(data)
        let detectedSource = try parseDetectedLanguage(data) ?? sourceLang

        return TranslationResult(
            originalText: trimmed,
            translatedText: translatedText,
            sourceLang: detectedSource,
            targetLang: targetLang
        )
    }

    // MARK: - Private

    private func buildURL(text: String, from sourceLang: String, to targetLang: String) throws -> URL {
        var components = URLComponents(string: baseURL)
        let sl = sourceLang.isEmpty ? "auto" : sourceLang
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sl),
            URLQueryItem(name: "tl", value: targetLang),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "dt", value: "bd"),
            URLQueryItem(name: "q", value: text),
        ]
        guard let url = components?.url else {
            throw TranslationError.invalidURL
        }
        return url
    }

    /// Parse the translated text from Google's JSON response.
    ///
    /// Response format is a nested JSON array. The translated segments are at `[0][*][0]`:
    /// ```
    /// [[["translated segment 1", "original segment 1", ...], ["translated segment 2", ...]], ...]
    /// ```
    private func parseResponse(_ data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [Any],
              let sentences = root.first as? [[Any]] else {
            throw TranslationError.invalidResponse
        }

        let translated = sentences.compactMap { segment -> String? in
            guard let text = segment.first as? String else { return nil }
            return text
        }

        let result = translated.joined()
        guard !result.isEmpty else {
            throw TranslationError.invalidResponse
        }
        return result
    }

    /// Parse the detected source language from the response.
    /// It's typically at `[2]` in the root array.
    private func parseDetectedLanguage(_ data: Data) throws -> String? {
        let json = try JSONSerialization.jsonObject(with: data)
        guard let root = json as? [Any], root.count > 2 else {
            return nil
        }
        return root[2] as? String
    }
}
