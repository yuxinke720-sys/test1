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
        You are a children's book character designer. Carefully examine the child in these photos \
        and return ONLY a detailed appearance description in English (max 80 words). \
        You MUST include ALL of the following: \
        (1) Hair: exact color, length, and style (e.g. black shoulder-length braids with pink bows), \
        (2) Eyes: color and shape, \
        (3) Skin tone, \
        (4) Face shape, \
        (5) Top/jacket: exact color, style, and any distinctive details (e.g. pink zip-up hoodie with white drawstrings), \
        (6) Bottom: exact color and style (e.g. light blue denim shorts), \
        (7) Any accessories (e.g. white sneakers, red hair clips). \
        Output a single fluent sentence. Do not include names, background, or any explanation.
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
    static func resizeImage(_ image: UIImage, maxSide: CGFloat) -> UIImage {
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
        referenceImageB64: String = "",
        userUID: String = "",
        onPageIllustrated: (@Sendable (Int) -> Void)? = nil
    ) async throws -> Story {

        print("[AIService] generateStory called — childName: \(childName), theme: \(theme)")

        // 1. Generate story text via Cloud Function
        print("[AIService] Generating story text via Firebase…")
        var (generatedTitle, pages) = try await callGenerateStory(
            childName: childName,
            theme: theme,
            style: style,
            pageCount: pageCount,
            childAppearance: childAppearance
        )
        print("[AIService] Story text generated: \(pages.count) pages, title: \(generatedTitle)")

        // Use a stable ID for this story so images land in the right directory
        let storyId = UUID()

        // 2. Generate illustrations concurrently — saved to disk
        if AppConfig.skipImageGeneration {
            print("[AIService] ⚠️ Developer Mode: Skipping image generation to save tokens")
        } else {
            print("[AIService] Generating illustrations…")
            pages = await generateIllustrations(
                for: pages, storyId: storyId,
                childName: childName, style: style,
                childAppearance: childAppearance,
                referenceImageB64: referenceImageB64,
                userUID: userUID,
                onPageDone: onPageIllustrated
            )
        }

        let finalTitle: String
        if generatedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalTitle = "\(childName)'s Magical Adventure"
            print("[AIService] Title: using fallback — \"\(finalTitle)\"")
        } else {
            finalTitle = generatedTitle
            print("[AIService] Title: using AI-generated — \"\(finalTitle)\"")
        }
        return Story(id: storyId, title: finalTitle, childName: childName, theme: theme, style: style, pages: pages)
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

    func generateImage(prompt: String, referenceImageB64: String = "") async throws -> Data {
        var data: [String: Any] = ["prompt": prompt]
        if !referenceImageB64.isEmpty {
            data["referenceImageB64"] = referenceImageB64
        }
        let result = try await callFunction("generateImage", data: data)
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
    /// and parses the response into a title + [StoryPage].
    private func callGenerateStory(
        childName: String,
        theme: String,
        style: StoryStyle,
        pageCount: Int,
        childAppearance: String
    ) async throws -> (title: String, pages: [StoryPage]) {

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

    private func parseStoryJSON(_ rawText: String) throws -> (title: String, pages: [StoryPage]) {
        // Strip markdown code fences
        var clean = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("```json") { clean = String(clean.dropFirst(7)) }
        else if clean.hasPrefix("```") { clean = String(clean.dropFirst(3)) }
        if clean.hasSuffix("```") { clean = String(clean.dropLast(3)) }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        // Diagnostic: log first 300 chars of cleaned model output
        let preview = String(clean.prefix(300))
        print("[AIService] parseStoryJSON raw (first 300): \(preview)")

        guard let jsonData = clean.data(using: .utf8) else {
            throw AIServiceError.parsingError
        }

        let parsed = try JSONSerialization.jsonObject(with: jsonData)

        let arr: [[String: Any]]
        var title = ""

        if let directArray = parsed as? [[String: Any]] {
            // Model returned a plain array (ignored new schema) — still usable, no title
            print("[AIService] parseStoryJSON WARNING: model returned plain array, no title available")
            arr = directArray
        } else if let wrapper = parsed as? [String: Any] {
            title = wrapper["title"] as? String ?? ""
            if title.isEmpty {
                print("[AIService] parseStoryJSON WARNING: wrapper has no 'title' key. Keys: \(wrapper.keys.sorted())")
            } else {
                print("[AIService] parseStoryJSON: extracted title = \"\(title)\"")
            }
            if let nested = wrapper["pages"] as? [[String: Any]] {
                arr = nested
            } else if let nestedData = wrapper["storyData"] as? String {
                // storyData is a nested JSON string — recurse
                let result = try parseStoryJSON(nestedData)
                return (title: title.isEmpty ? result.title : title, pages: result.pages)
            } else {
                print("[AIService] parseStoryJSON: wrapper keys = \(wrapper.keys.sorted()), no usable array found")
                throw AIServiceError.parsingError
            }
        } else {
            print("[AIService] parseStoryJSON: unexpected root type: \(type(of: parsed))")
            throw AIServiceError.parsingError
        }

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
        return (title: title, pages: pages)
    }

    // MARK: - Image Generation (via Cloud Function)

    private func generateIllustrations(
        for pages: [StoryPage],
        storyId: UUID,
        childName: String,
        style: StoryStyle,
        childAppearance: String,
        referenceImageB64: String = "",
        userUID: String,
        onPageDone: (@Sendable (Int) -> Void)?
    ) async -> [StoryPage] {

        print("[AIService] referenceImageB64 length: \(referenceImageB64.count)")

        // Build the appearance block once — placed first for maximum model attention
        let appearanceBlock: String
        if !childAppearance.trimmingCharacters(in: .whitespaces).isEmpty {
            appearanceBlock = "SUBJECT: A child named \(childName). CRITICAL APPEARANCE — the child MUST strictly match ALL of the following in every detail: \(childAppearance). MANDATORY: Maintain the exact same hairstyle, hair color, and outfit from this description throughout the entire illustration. Do not alter or simplify any physical feature."
        } else {
            appearanceBlock = "SUBJECT: A child named \(childName)."
        }

        let referenceClause: String
        if !referenceImageB64.isEmpty {
            referenceClause = "Match the character's exact clothing colors, hairstyle, and accessories as shown in the reference photo. "
        } else {
            referenceClause = ""
        }

        var result = pages

        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, page) in pages.enumerated() {
                group.addTask {
                    let vibeStyleClause: String
                    switch style {
                    case .warmCozy:
                        vibeStyleClause = "Needle felted storybook style, thick felted wool texture on the surface, minimalist and poetic flat art style, mysterious and serene, tiny intricate wool fibers covering the entire scene, fuzzy pilling effect, felt craft aesthetic, composed of fine wool fuzz. "
                        print("[AIService] Warm & Cozy vibe: injecting needle felt texture prompt")
                    default:
                        vibeStyleClause = ""
                    }

                    let imagePrompt = "\(appearanceBlock) \(referenceClause)SCENE: \(page.imageDescription). \(vibeStyleClause)ART DIRECTION: Children's book illustration, \(style.rawValue) style, warm colorful lighting, soft friendly atmosphere."
                    print("[AIService] imagePrompt preview: \(imagePrompt.prefix(200))")
                    print("[AIService] Generating image \(index + 1)/\(pages.count)")

                    do {
                        let imgData = try await self.generateImage(prompt: imagePrompt, referenceImageB64: referenceImageB64)
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
