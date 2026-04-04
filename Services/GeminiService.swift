import Foundation
import SwiftUI

class GeminiService {
    static let shared = GeminiService()

    private let apiKey: String = {
        guard let key = Bundle.main.infoDictionary?["GeminiAPIKey"] as? String,
              !key.isEmpty,
              key != "YOUR_ACTUAL_KEY_HERE",
              !key.hasPrefix("$(")
        else {
            print("[GeminiService] API key not resolved from Info.plist")
            return ""
        }
        print("[GeminiService] API key loaded: \(key.prefix(10))...")
        return key
    }()

    private let textModelURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
    private let imageModelURL = "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict"
    private let geminiImageURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    private init() {}

    // MARK: - Public: Generate Full Story (Text + Images)

    /// Called from StoryViewModel. Generates story text, then illustrations.
    /// The `onPageIllustrated` callback fires after each image completes for progress tracking.
    func generateStory(
        childName: String,
        theme: String,
        style: StoryStyle,
        pageCount: Int,
        onPageIllustrated: (@Sendable (Int) -> Void)? = nil
    ) async throws -> Story {
        guard !apiKey.isEmpty else {
            print("[GeminiService] No API key — using mock story")
            return generateMockStory(childName: childName, theme: theme, style: style, pageCount: pageCount)
        }

        // 1. Generate story text via Gemini
        print("[GeminiService] Generating story text...")
        let prompt = buildPrompt(childName: childName, theme: theme, style: style, pageCount: pageCount)
        var pages = try await callTextAPI(prompt: prompt)
        print("[GeminiService] Story text generated: \(pages.count) pages")

        // 2. Generate illustrations via Imagen concurrently
        print("[GeminiService] Generating illustrations...")
        pages = await generateIllustrations(for: pages, childName: childName, style: style, onPageDone: onPageIllustrated)

        let title = "\(childName)'s \(theme.prefix(30).trimmingCharacters(in: .whitespaces)) Story"
        return Story(
            title: title,
            childName: childName,
            theme: theme,
            style: style,
            pages: pages
        )
    }

    // MARK: - Text Generation (Gemini 2.0 Flash)

    private func buildPrompt(childName: String, theme: String, style: StoryStyle, pageCount: Int) -> String {
        """
        You are a children's storybook author. Write a \(pageCount)-page illustrated children's story.

        Child's name: \(childName)
        Theme: \(theme)
        Style: \(style.rawValue)

        For each page, provide:
        1. The story text (2-3 sentences, age-appropriate for 3-6 year olds)
        2. A detailed image description for an illustrator (describe the scene, characters, colors, mood — 1-2 sentences)
        3. A single SF Symbol icon name that represents the scene (e.g. "sun.max.fill", "star.fill", "heart.fill", "tree.fill")

        Respond ONLY with a valid JSON array, no markdown, no code fences, no extra text:
        [{"pageNumber": 1, "text": "...", "imageDescription": "...", "emoji": "star.fill"}]

        Make the story warm, engaging, and end with a positive message.
        Use simple vocabulary. Make \(childName) the hero of the story.
        """
    }

    private func callTextAPI(prompt: String) async throws -> [StoryPage] {
        guard let url = URL(string: "\(textModelURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.85, "maxOutputTokens": 4096]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("[GeminiService] Text API request sending to: \(textModelURL)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[GeminiService] Text API network error: \(error.localizedDescription)")
            throw GeminiError.apiError
        }

        guard let http = response as? HTTPURLResponse else {
            print("[GeminiService] Text API: no HTTP response")
            throw GeminiError.apiError
        }

        print("[GeminiService] Text API HTTP \(http.statusCode), response size: \(data.count) bytes")

        if http.statusCode == 429 {
            let retry = parseRetryDelay(from: data) ?? 45
            print("[GeminiService] Text API rate limited, retry after \(retry)s")
            throw GeminiError.rateLimited(retryAfter: retry)
        }
        guard http.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "(binary)"
            print("[GeminiService] Text API error body: \(responseBody.prefix(800))")
            throw GeminiError.httpError(statusCode: http.statusCode)
        }

        do {
            let pages = try parseTextResponse(data: data)
            print("[GeminiService] Text API parsed \(pages.count) pages successfully")
            return pages
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "(binary)"
            print("[GeminiService] Text API parse failed. Raw response: \(responseBody.prefix(800))")
            throw error
        }
    }

    private func parseTextResponse(data: Data) throws -> [StoryPage] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let rawText = parts.first?["text"] as? String
        else { throw GeminiError.parsingError }

        // Strip markdown code fences
        var clean = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        else if clean.hasPrefix("```") { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```") { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = clean.data(using: .utf8),
              let arr = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        else { throw GeminiError.parsingError }

        let pages = arr.compactMap { dict -> StoryPage? in
            guard let num = dict["pageNumber"] as? Int,
                  let text = dict["text"] as? String
            else { return nil }
            return StoryPage(
                pageNumber: num,
                text: text,
                imageDescription: dict["imageDescription"] as? String ?? "",
                emoji: dict["emoji"] as? String ?? "book.fill"
            )
        }

        guard !pages.isEmpty else { throw GeminiError.parsingError }
        return pages
    }

    // MARK: - Image Generation (Imagen 3)

    private func generateIllustrations(
        for pages: [StoryPage],
        childName: String,
        style: StoryStyle,
        onPageDone: (@Sendable (Int) -> Void)?
    ) async -> [StoryPage] {
        var result = pages
        var completed = 0

        // Try Imagen endpoint first, fall back to Gemini inline image generation
        let useImagen = await testImagenAvailability()
        print("[GeminiService] Image strategy: \(useImagen ? "Imagen 3" : "Gemini inline")")

        await withTaskGroup(of: (Int, Data?).self) { group in
            for (index, page) in pages.enumerated() {
                group.addTask {
                    let imagePrompt = "Children's book illustration for a \(style.rawValue) children's story. Scene: \(page.imageDescription). Style: warm, colorful, cartoon, soft lighting, friendly characters. A child named \(childName)."
                    print("[GeminiService] Generating image \(index + 1)/\(pages.count): \(imagePrompt.prefix(80))...")

                    do {
                        let data: Data
                        if useImagen {
                            data = try await self.callImagenAPI(prompt: imagePrompt)
                        } else {
                            data = try await self.callGeminiImageAPI(prompt: imagePrompt)
                        }
                        print("[GeminiService] Image \(index + 1) generated: \(data.count) bytes")
                        return (index, data)
                    } catch {
                        print("[GeminiService] Image \(index + 1) FAILED: \(error.localizedDescription)")
                        return (index, nil)
                    }
                }
            }

            for await (index, data) in group {
                if let data {
                    result[index].imageData = data
                }
                completed += 1
                onPageDone?(completed)
            }
        }

        let successCount = result.filter { $0.imageData != nil }.count
        print("[GeminiService] Illustrations complete: \(successCount)/\(pages.count) succeeded")
        return result
    }

    /// Test if Imagen endpoint is available for this API key
    private func testImagenAvailability() async -> Bool {
        guard let url = URL(string: "\(imageModelURL)?key=\(apiKey)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        let body: [String: Any] = [
            "instances": [["prompt": "test"]],
            "parameters": ["sampleCount": 1]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }

        if http.statusCode == 200 { return true }
        let responseBody = String(data: data, encoding: .utf8) ?? ""
        print("[GeminiService] Imagen test: HTTP \(http.statusCode) — \(responseBody.prefix(200))")
        return false
    }

    // MARK: - Imagen 3 API (Vertex-style endpoint)

    private func callImagenAPI(prompt: String) async throws -> Data {
        guard let url = URL(string: "\(imageModelURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "instances": [["prompt": prompt]],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": "3:4",
                "personGeneration": "allow_all"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.imageGenerationFailed
        }
        guard http.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("[GeminiService] Imagen API HTTP \(http.statusCode): \(errorBody.prefix(500))")
            throw GeminiError.imageGenerationFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let predictions = json["predictions"] as? [[String: Any]],
              let b64 = predictions.first?["bytesBase64Encoded"] as? String,
              let imageData = Data(base64Encoded: b64)
        else {
            print("[GeminiService] Imagen parse failed. Response: \(String(data: data, encoding: .utf8)?.prefix(300) ?? "nil")")
            throw GeminiError.imageGenerationFailed
        }

        return imageData
    }

    // MARK: - Gemini Inline Image Generation (Fallback)

    private func callGeminiImageAPI(prompt: String) async throws -> Data {
        guard let url = URL(string: "\(geminiImageURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "contents": [["parts": [["text": "Generate an image: \(prompt)"]]]],
            "generationConfig": [
                "responseModalities": ["IMAGE", "TEXT"],
                "responseMimeType": "text/plain"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GeminiError.imageGenerationFailed
        }
        guard http.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("[GeminiService] Gemini Image API HTTP \(http.statusCode): \(errorBody.prefix(500))")
            throw GeminiError.imageGenerationFailed
        }

        // Parse: candidates[0].content.parts[] — look for inlineData with image mime type
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else {
            print("[GeminiService] Gemini image parse failed. Response: \(String(data: data, encoding: .utf8)?.prefix(500) ?? "nil")")
            throw GeminiError.imageGenerationFailed
        }

        // Find the part with inlineData (base64 image)
        for part in parts {
            if let inlineData = part["inlineData"] as? [String: Any],
               let b64 = inlineData["data"] as? String,
               let imageData = Data(base64Encoded: b64) {
                return imageData
            }
        }

        print("[GeminiService] No inlineData found in response parts: \(parts)")
        throw GeminiError.imageGenerationFailed
    }

    // MARK: - Helpers

    private func parseRetryDelay(from data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let details = error["details"] as? [[String: Any]]
        else { return nil }
        for detail in details {
            if let metadata = detail["metadata"] as? [String: String],
               let delay = metadata["retryDelay"] {
                return Int(delay.filter { $0.isNumber })
            }
        }
        return nil
    }

    // MARK: - Mock (fallback when no API key)

    private func generateMockStory(childName: String, theme: String, style: StoryStyle, pageCount: Int) -> Story {
        let samplePages: [(String, String)] = [
            ("Once upon a time, \(childName) woke up to a beautiful sunny morning.", "sunrise.fill"),
            ("\(childName) put on their favorite outfit. \"Today I'm going to be brave!\"", "face.smiling"),
            ("At the park, \(childName) saw a tall slide reaching up to the clouds.", "figure.play"),
            ("\(childName) felt butterflies in their tummy. \"It's so high up!\"", "butterfly.fill"),
            ("A friendly squirrel appeared. \"Don't worry, I'll climb with you!\"", "hare.fill"),
            ("Step by step, \(childName) climbed. One step, two steps — almost there!", "ladder.fill"),
            ("At the top, \(childName) could see the whole park!", "tree.fill"),
            ("WHOOOOSH! Down the slide, faster than the wind!", "wind"),
            ("\"AGAIN! AGAIN!\" \(childName) shouted with a big smile.", "face.smiling.inverse"),
            ("That night, \(childName) whispered, \"I was brave today.\"", "star.fill"),
            ("Mom kissed \(childName)'s forehead. \"You can do anything.\"", "heart.fill"),
            ("And \(childName) drifted off to sleep. The End.", "moon.stars.fill"),
        ]
        let pages = (0..<min(pageCount, samplePages.count)).map { i in
            StoryPage(pageNumber: i + 1, text: samplePages[i].0, imageDescription: "", emoji: samplePages[i].1)
        }
        return Story(title: "\(childName)'s Brave Adventure", childName: childName, theme: theme, style: style, pages: pages)
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidURL
    case apiError
    case parsingError
    case rateLimited(retryAfter: Int)
    case invalidKey
    case httpError(statusCode: Int)
    case imageGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .apiError: return "Failed to generate story. Please try again."
        case .parsingError: return "Failed to parse the story. Please try again."
        case .rateLimited(let s): return "Too many requests. Please wait \(s) seconds and try again."
        case .invalidKey: return "Invalid API key. Check your Gemini API key."
        case .httpError(let c): return "Server error (HTTP \(c)). Please try again later."
        case .imageGenerationFailed: return "Could not generate illustration. Story saved without images."
        }
    }
}
