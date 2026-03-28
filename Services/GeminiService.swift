import Foundation
import SwiftUI

// MARK: - Gemini API Integration Layer
// Replace the placeholder API key and endpoint with your actual Gemini credentials.

class GeminiService {
    static let shared = GeminiService()

    // TODO: Replace with your actual Gemini API key
    private let apiKey = "YOUR_GEMINI_API_KEY"
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"

    private init() {}

    /// Generate a children's story based on theme, style, child name, and page count.
    func generateStory(
        childName: String,
        theme: String,
        style: StoryStyle,
        pageCount: Int
    ) async throws -> Story {
        let prompt = buildPrompt(childName: childName, theme: theme, style: style, pageCount: pageCount)

        // For demo/development: return a mock story after simulated delay
        // In production, uncomment the API call below
        return try await generateMockStory(
            childName: childName,
            theme: theme,
            style: style,
            pageCount: pageCount
        )

        // MARK: - Production API call (uncomment when ready)
        // return try await callGeminiAPI(prompt: prompt, childName: childName, theme: theme, style: style, pageCount: pageCount)
    }

    private func buildPrompt(childName: String, theme: String, style: StoryStyle, pageCount: Int) -> String {
        """
        You are a children's storybook author. Write a \(pageCount)-page illustrated children's story.

        Child's name: \(childName)
        Theme: \(theme)
        Style: \(style.rawValue)

        For each page, provide:
        1. The story text (2-3 sentences, age-appropriate for 3-6 year olds)
        2. A brief image description for the illustration
        3. A single emoji that best represents the scene

        Format as JSON array:
        [{"pageNumber": 1, "text": "...", "imageDescription": "...", "emoji": "..."}]

        Make the story warm, engaging, and end with a positive message.
        Use simple vocabulary. Make \(childName) the hero of the story.
        """
    }

    // MARK: - Mock story generator for development
    private func generateMockStory(
        childName: String,
        theme: String,
        style: StoryStyle,
        pageCount: Int
    ) async throws -> Story {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 0) // Instant — delay handled by LoadingView

        let samplePages: [(String, String)] = [
            ("Once upon a time, \(childName) woke up to a beautiful sunny morning. Today was going to be a very special day!", "sunrise.fill"),
            ("\(childName) put on their favorite outfit and looked in the mirror with a big smile. \"Today I'm going to be brave!\" they said.", "face.smiling"),
            ("At the park, \(childName) saw a tall, twisty slide that reached up to the clouds. Other kids zoomed down it, laughing and cheering.", "figure.play"),
            ("\(childName) felt butterflies in their tummy. \"It's so high up,\" they whispered, looking at the very top.", "butterfly.fill"),
            ("A friendly squirrel appeared on the railing. \"Don't worry,\" it seemed to say with its twitchy nose. \"I'll climb with you!\"", "hare.fill"),
            ("Step by step, \(childName) climbed the ladder. One step, two steps, three steps — almost there!", "ladder.fill"),
            ("At the top, \(childName) could see the whole park! The trees looked like tiny broccoli and the people looked like ants.", "tree.fill"),
            ("\(childName) sat down, took a deep breath, and... WHOOOOSH! Down the slide they went, faster than the wind!", "wind"),
            ("\"AGAIN! AGAIN!\" \(childName) shouted, running back to the ladder with the biggest smile in the whole wide world.", "face.smiling.inverse"),
            ("That night, snuggled in bed, \(childName) whispered, \"I was brave today.\" And the stars outside twinkled as if to say, \"Yes, you were.\"", "star.fill"),
            ("Mom kissed \(childName)'s forehead. \"You can do anything you set your mind to,\" she said softly.", "heart.fill"),
            ("And \(childName) drifted off to sleep, dreaming of tomorrow's adventures. The End.", "moon.stars.fill"),
        ]

        let pages = (0..<min(pageCount, samplePages.count)).map { i in
            StoryPage(
                pageNumber: i + 1,
                text: samplePages[i].0,
                imageDescription: "Illustration of \(childName) in scene \(i + 1)",
                emoji: samplePages[i].1
            )
        }

        return Story(
            title: "\(childName)'s Brave Adventure",
            childName: childName,
            theme: theme,
            style: style,
            pages: pages
        )
    }

    // MARK: - Production Gemini API call
    @available(*, unavailable, message: "Set your API key first")
    private func callGeminiAPI(
        prompt: String,
        childName: String,
        theme: String,
        style: StoryStyle,
        pageCount: Int
    ) async throws -> Story {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GeminiError.apiError
        }

        // Parse response — adapt to actual Gemini response format
        _ = data
        throw GeminiError.apiError
    }
}

enum GeminiError: LocalizedError {
    case invalidURL
    case apiError
    case parsingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .apiError: return "Failed to generate story. Please try again."
        case .parsingError: return "Failed to parse story data"
        }
    }
}
