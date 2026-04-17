// AIService — routes all AI generation through Firebase Cloud Functions.
// No API keys are stored in the iOS client.
import Foundation
import SwiftUI
import FirebaseFunctions

class AIService {
    static let shared = AIService()

    /// Firebase Functions client, pointed at asia-northeast1 region.
    /// Emulator is configured globally in AppDelegate before this instance is created.
    private let functions = Functions.functions(region: "asia-northeast1")

    private init() {
        print("[AIService] Functions region: asia-northeast1")
    }

    // MARK: - Public: Analyze Child Appearance from Photos

    func analyzeChildAppearance(from images: [UIImage]) async throws -> String {
        guard !images.isEmpty else { throw AIServiceError.apiError }

        // Encode images as base64 for the Cloud Function
        let selected = Array(images.prefix(3))
        var imageB64List: [String] = []

        for img in selected {
            let resized = Self.resizeImage(img, maxSide: 512)
            guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { continue }
            imageB64List.append(jpegData.base64EncodedString())
        }

        let prompt = """
        You are a children's book illustrator assistant. Analyze the child in these photos and \
        return ONLY a concise appearance description in English (max 40 words). Cover: hair color \
        and style, eye color/shape, skin tone, face shape. Example output: \
        'A young girl with curly auburn hair, bright green eyes, fair skin, and a round cheerful \
        face.' Do not include names, clothing, or background details.
        """

        let result = try await callFunction("analyzeAppearance", data: [
            "prompt": prompt,
            "images": imageB64List
        ])

        guard let description = result["storyData"] as? String, !description.isEmpty else {
            print("[AIService] Vision: unexpected response format")
            throw AIServiceError.parsingError
        }

        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[AIService] Child appearance: \(trimmed)")
        return trimmed
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
        userUID: String = "",
        onPageIllustrated: (@Sendable (Int) -> Void)? = nil
    ) async throws -> Story {

        // 1. Generate story text via Cloud Function
        print("[AIService] Generating story text via Firebase…")
        var pages = try await callGenerateStory(
            childName: childName,
            theme: theme,
            style: style,
            pageCount: pageCount,
            childAppearance: childAppearance
        )
        print("[AIService] Story text generated: \(pages.count) pages")

        // Use a stable ID for this story so images land in the right directory
        let storyId = UUID()

        // 2. Generate illustrations concurrently — saved to disk
        print("[AIService] Generating illustrations…")
        pages = await generateIllustrations(
            for: pages, storyId: storyId,
            childName: childName, style: style,
            childAppearance: childAppearance,
            userUID: userUID,
            onPageDone: onPageIllustrated
        )

        let title = "\(childName)'s \(theme.prefix(30).trimmingCharacters(in: .whitespaces)) Story"
        return Story(id: storyId, title: title, childName: childName, theme: theme, style: style, pages: pages)
    }

    // MARK: - Text-only generation (for testing)

    func generateText(prompt: String) async throws -> String {
        let result = try await callFunction("generateStory", data: [
            "childName": "Test",
            "theme": prompt,
            "style": "Warm & Cozy",
            "pageCount": 1
        ])
        guard let text = result["storyData"] as? String else {
            throw AIServiceError.emptyContent
        }
        return text
    }

    // MARK: - Image-only generation (for testing)

    func generateImage(prompt: String) async throws -> Data {
        let result = try await callFunction("generateImage", data: [
            "prompt": prompt
        ])
        guard let b64 = result["imageData"] as? String,
              let imageData = Data(base64Encoded: b64)
        else {
            throw AIServiceError.imageGenerationFailed
        }
        return imageData
    }

    // MARK: - Firebase Callable Helpers

    /// Generic helper: calls a named Cloud Function with the given data dict.
    /// Returns the result dictionary from the onCall response.
    private func callFunction(_ name: String, data: [String: Any]) async throws -> [String: Any] {
        print("[AIService] Calling Cloud Function: \(name)")
        print("[AIService] Expected URL: http://127.0.0.1:5001/storyme-app-d02d2/asia-northeast1/\(name)")
        print("[AIService] Data keys: \(data.keys.sorted())")

        let callable = functions.httpsCallable(name)
        callable.timeoutInterval = 120

        let result: HTTPSCallableResult
        do {
            result = try await callable.call(data)
        } catch {
            print("[AIService] \(name) call failed: \(error)")
            throw AIServiceError.apiError
        }

        guard let dict = result.data as? [String: Any] else {
            print("[AIService] \(name): response is not a dictionary")
            throw AIServiceError.parsingError
        }

        print("[AIService] \(name) success, keys: \(dict.keys.sorted())")
        return dict
    }

    /// Calls the generateStory Cloud Function with structured parameters
    /// and parses the response into [StoryPage].
    private func callGenerateStory(
        childName: String,
        theme: String,
        style: StoryStyle,
        pageCount: Int,
        childAppearance: String
    ) async throws -> [StoryPage] {

        var data: [String: Any] = [
            "childName": childName,
            "theme": theme,
            "style": style.rawValue,
            "pageCount": pageCount
        ]
        if !childAppearance.trimmingCharacters(in: .whitespaces).isEmpty {
            data["childAppearance"] = childAppearance
        }

        let result = try await callFunction("generateStory", data: data)

        guard let storyText = result["storyData"] as? String, !storyText.isEmpty else {
            print("[AIService] generateStory: empty storyData")
            throw AIServiceError.emptyContent
        }

        return try parseStoryJSON(storyText)
    }

    // MARK: - Response Parsing

    private func parseStoryJSON(_ rawText: String) throws -> [StoryPage] {
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

    // MARK: - Image Generation (via Cloud Function)

    private func generateIllustrations(
        for pages: [StoryPage],
        storyId: UUID,
        childName: String,
        style: StoryStyle,
        childAppearance: String,
        userUID: String,
        onPageDone: (@Sendable (Int) -> Void)?
    ) async -> [StoryPage] {

        // Build the appearance prefix once
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
                        let imgData = try await self.generateImage(prompt: imagePrompt)
                        print("[AIService] Image \(index + 1) generated: \(imgData.count) bytes")
                        let path = try await ImageStorageService.shared.save(
                            imageData: imgData,
                            storyId: storyId,
                            pageNumber: page.pageNumber,
                            userUID: userUID
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

    // MARK: - Mock (fallback)

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
        case .emptyContent: return "Model returned empty content. Check console for raw response."
        case .invalidKey: return "API key not configured."
        case .httpError(let c): return "Server error (HTTP \(c)). Please try again later."
        case .imageGenerationFailed: return "Could not generate illustration. Story saved without images."
        }
    }
}
