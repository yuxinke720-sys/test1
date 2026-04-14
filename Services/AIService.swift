// CHANGED: Added analyzeChildAppearance(from:) for vision-based feature extraction.
// CHANGED: Added childAppearance parameter to generateStory() and generateIllustrations().
// CHANGED: Image prompts now lead with appearance description when available.
import Foundation
import SwiftUI

class AIService {
    static let shared = AIService()

    private let textAPIKey: String
    private let textModelID: String
    private let imageAPIKey: String
    private let imageModelID: String

    private let textBaseURL = "https://ark.cn-beijing.volces.com/api/v3/chat/completions"
    private let imageBaseURL = "https://ark.cn-beijing.volces.com/api/v3/images/generations"

    private init() {
        let info = Bundle.main.infoDictionary ?? [:]

        func resolve(_ key: String) -> String {
            guard let val = info[key] as? String, !val.isEmpty, !val.hasPrefix("$(") else { return "" }
            return val
        }

        textAPIKey  = resolve("DoubaoTextAPIKey")
        textModelID = resolve("DoubaoTextModelID")
        imageAPIKey = resolve("DoubaoImageAPIKey")
        imageModelID = resolve("DoubaoImageModelID")

        print("[AIService] text model: \(textModelID), image model: \(imageModelID)")
        if textAPIKey.isEmpty  { print("[AIService] WARNING: text API key missing") }
        if imageAPIKey.isEmpty { print("[AIService] WARNING: image API key missing") }
    }

    // MARK: - Public: Analyze Child Appearance from Photos

    func analyzeChildAppearance(from images: [UIImage]) async throws -> String {
        guard !textAPIKey.isEmpty else { throw AIServiceError.invalidKey }
        guard !images.isEmpty else { throw AIServiceError.apiError }

        // Take up to 3 images, resize to max 512px, encode as base64 JPEG
        let selected = Array(images.prefix(3))
        var contentParts: [[String: Any]] = []

        contentParts.append([
            "type": "text",
            "text": """
            You are a children's book illustrator assistant. Analyze the child in these photos and \
            return ONLY a concise appearance description in English (max 40 words). Cover: hair color \
            and style, eye color/shape, skin tone, face shape. Example output: \
            'A young girl with curly auburn hair, bright green eyes, fair skin, and a round cheerful \
            face.' Do not include names, clothing, or background details.
            """
        ])

        for img in selected {
            let resized = Self.resizeImage(img, maxSide: 512)
            guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { continue }
            let b64 = jpegData.base64EncodedString()
            contentParts.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(b64)"]
            ])
        }

        guard let url = URL(string: textBaseURL) else { throw AIServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(textAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": textModelID,
            "messages": [["role": "user", "content": contentParts]],
            "max_tokens": 200,
            "thinking": ["type": "disabled"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIServiceError.apiError }

        let rawBody = String(data: data, encoding: .utf8) ?? "(binary, \(data.count) bytes)"
        print("[AIService] Vision API HTTP \(http.statusCode), \(data.count) bytes")
        print("[AIService] Vision RAW RESPONSE:\n\(rawBody)")

        guard http.statusCode == 200 else {
            throw AIServiceError.httpError(statusCode: http.statusCode)
        }

        let description = try extractContent(from: data)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        print("[AIService] Child appearance: \(description)")
        return description
    }

    /// Resize a UIImage so its longest side is at most `maxSide` points.
    private static func resizeImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        guard max(size.width, size.height) > maxSide else { return image }
        let scale = maxSide / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // MARK: - Public: Generate Full Story

    func generateStory(
        childName: String,
        theme: String,
        style: StoryStyle,
        pageCount: Int,
        childAppearance: String = "",
        onPageIllustrated: (@Sendable (Int) -> Void)? = nil
    ) async throws -> Story {
        guard !textAPIKey.isEmpty else {
            print("[AIService] No text API key — using mock story")
            return generateMockStory(childName: childName, theme: theme, style: style, pageCount: pageCount)
        }

        // 1. Generate story text
        print("[AIService] Generating story text...")
        let prompt = buildPrompt(childName: childName, theme: theme, style: style, pageCount: pageCount)
        var pages = try await callTextAPI(prompt: prompt)
        print("[AIService] Story text generated: \(pages.count) pages")

        // Use a stable ID for this story so images land in the right directory
        let storyId = UUID()

        // 2. Generate illustrations concurrently — saved to disk
        print("[AIService] Generating illustrations...")
        pages = await generateIllustrations(for: pages, storyId: storyId, childName: childName, style: style, childAppearance: childAppearance, onPageDone: onPageIllustrated)

        let title = "\(childName)'s \(theme.prefix(30).trimmingCharacters(in: .whitespaces)) Story"
        return Story(id: storyId, title: title, childName: childName, theme: theme, style: style, pages: pages)
    }

    // MARK: - Text-only generation (for testing)

    func generateText(prompt: String) async throws -> String {
        guard !textAPIKey.isEmpty else { throw AIServiceError.invalidKey }
        return try await callRawTextAPI(prompt: prompt)
    }

    // MARK: - Image-only generation (for testing)

    func generateImage(prompt: String) async throws -> Data {
        guard !imageAPIKey.isEmpty else { throw AIServiceError.invalidKey }
        return try await callImageAPI(prompt: prompt)
    }

    // MARK: - Text Generation (Doubao /chat/completions)

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

    private func callRawTextAPI(prompt: String) async throws -> String {
        guard let url = URL(string: textBaseURL) else { throw AIServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(textAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": textModelID,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 4000,
            "thinking": ["type": "disabled"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIServiceError.apiError }

        // Always dump the full response for debugging
        let rawBody = String(data: data, encoding: .utf8) ?? "(binary, \(data.count) bytes)"
        print("[AIService] Text API HTTP \(http.statusCode), \(data.count) bytes")
        print("[AIService] RAW RESPONSE:\n\(rawBody)")

        guard http.statusCode == 200 else {
            throw AIServiceError.httpError(statusCode: http.statusCode)
        }

        return try extractContent(from: data)
    }

    /// Robust content extraction. Handles:
    /// - `content` as a plain String (standard OpenAI format)
    /// - `content` as an Array of parts (`[{"type":"text","text":"..."}]`)
    /// - `content` missing/empty → falls back to `reasoning_content` (thinking models)
    private func extractContent(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[AIService] extractContent: response is not a JSON object")
            throw AIServiceError.parsingError
        }

        // Check for API-level error envelope
        if let error = json["error"] as? [String: Any] {
            let msg = (error["message"] as? String) ?? "unknown API error"
            print("[AIService] extractContent: API error envelope: \(msg)")
            throw AIServiceError.parsingError
        }

        guard let choices = json["choices"] as? [[String: Any]], !choices.isEmpty else {
            print("[AIService] extractContent: no 'choices' array")
            throw AIServiceError.parsingError
        }

        let choice = choices[0]

        // Log finish_reason — if "length", max_tokens truncation is the problem
        if let finish = choice["finish_reason"] as? String {
            print("[AIService] finish_reason: \(finish)")
        }

        guard let message = choice["message"] as? [String: Any] else {
            print("[AIService] extractContent: no 'message' object")
            throw AIServiceError.parsingError
        }

        // Try content as String
        if let contentStr = message["content"] as? String, !contentStr.isEmpty {
            return contentStr
        }

        // Try content as Array of parts ({"type": "text", "text": "..."})
        if let contentArr = message["content"] as? [[String: Any]] {
            let joined = contentArr
                .compactMap { $0["text"] as? String }
                .joined(separator: "\n")
            if !joined.isEmpty { return joined }
        }

        // Fallback to reasoning_content (thinking models)
        if let reasoning = message["reasoning_content"] as? String, !reasoning.isEmpty {
            print("[AIService] content empty — falling back to reasoning_content")
            return "[reasoning_content]\n\(reasoning)"
        }

        print("[AIService] extractContent: content and reasoning_content are both empty/missing")
        throw AIServiceError.emptyContent
    }

    private func callTextAPI(prompt: String) async throws -> [StoryPage] {
        guard let url = URL(string: textBaseURL) else { throw AIServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(textAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": textModelID,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 4000,
            "thinking": ["type": "disabled"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIServiceError.apiError }

        print("[AIService] Text API HTTP \(http.statusCode), \(data.count) bytes")

        guard http.statusCode == 200 else {
            let errBody = String(data: data, encoding: .utf8) ?? ""
            print("[AIService] Text API error: \(errBody)")
            throw AIServiceError.httpError(statusCode: http.statusCode)
        }

        return try parseTextResponse(data: data)
    }

    private func parseTextResponse(data: Data) throws -> [StoryPage] {
        let rawText = try extractContent(from: data)

        // Strip markdown code fences
        var clean = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        else if clean.hasPrefix("```") { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```") { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = clean.data(using: .utf8),
              let arr = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        else { throw AIServiceError.parsingError }

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

        guard !pages.isEmpty else { throw AIServiceError.parsingError }
        return pages
    }

    // MARK: - Image Generation (Doubao /images/generations)

    private func callImageAPI(prompt: String) async throws -> Data {
        guard let url = URL(string: imageBaseURL) else { throw AIServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(imageAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        // Doubao requires image dimensions ≥ 3,686,400 pixels (1920×1920 minimum).
        // 2048×2048 = 4,194,304 px gives a safe margin above the minimum.
        let body: [String: Any] = [
            "model": imageModelID,
            "prompt": prompt,
            "size": "2048x2048",
            "n": 1,
            "response_format": "b64_json"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIServiceError.imageGenerationFailed }
        guard http.statusCode == 200 else {
            let errBody = String(data: data, encoding: .utf8) ?? ""
            print("[AIService] Image API HTTP \(http.statusCode): \(errBody)")
            throw AIServiceError.imageGenerationFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArr = json["data"] as? [[String: Any]],
              let b64 = dataArr.first?["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64)
        else {
            print("[AIService] Image parse failed: \(String(data: data, encoding: .utf8)?.prefix(300) ?? "nil")")
            throw AIServiceError.imageGenerationFailed
        }

        return imageData
    }

    private func generateIllustrations(
        for pages: [StoryPage],
        storyId: UUID,
        childName: String,
        style: StoryStyle,
        childAppearance: String,
        onPageDone: (@Sendable (Int) -> Void)?
    ) async -> [StoryPage] {
        guard !imageAPIKey.isEmpty else {
            print("[AIService] No image API key — skipping illustrations")
            return pages
        }

        // Build the appearance prefix once — empty string if no description available
        let appearanceClause: String
        if !childAppearance.trimmingCharacters(in: .whitespaces).isEmpty {
            appearanceClause = "The child protagonist has the following appearance: \(childAppearance). "
        } else {
            appearanceClause = ""
        }

        var result = pages

        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, page) in pages.enumerated() {
                group.addTask {
                    let imagePrompt = "\(appearanceClause)Children's book illustration for a \(style.rawValue) children's story. Scene: \(page.imageDescription). Style: warm, colorful, cartoon, soft lighting, friendly characters. A child named \(childName)."
                    print("[AIService] Generating image \(index + 1)/\(pages.count)")

                    do {
                        let data = try await self.callImageAPI(prompt: imagePrompt)
                        print("[AIService] Image \(index + 1) generated: \(data.count) bytes")
                        // Save to disk, return relative path
                        let path = try await ImageStorageService.shared.save(
                            imageData: data,
                            storyId: storyId,
                            pageNumber: page.pageNumber
                        )
                        return (index, path)
                    } catch {
                        print("[AIService] Image \(index + 1) FAILED: \(error.localizedDescription)")
                        return (index, nil)
                    }
                }
            }

            var completed = 0
            for await (index, path) in group {
                if let path { result[index].imageStoragePath = path }
                completed += 1
                onPageDone?(completed)
            }
        }

        let successCount = result.filter { $0.imageStoragePath != nil }.count
        print("[AIService] Illustrations complete: \(successCount)/\(pages.count)")
        return result
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

enum AIServiceError: LocalizedError {
    case invalidURL
    case apiError
    case parsingError
    case emptyContent
    case invalidKey
    case httpError(statusCode: Int)
    case imageGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .apiError: return "Failed to generate story. Please try again."
        case .parsingError: return "Failed to parse the story. Please try again."
        case .emptyContent: return "Model returned empty content (reasoning may have consumed max_tokens). Check console for raw response."
        case .invalidKey: return "API key not configured. Check your Doubao API keys."
        case .httpError(let c): return "Server error (HTTP \(c)). Please try again later."
        case .imageGenerationFailed: return "Could not generate illustration. Story saved without images."
        }
    }
}
