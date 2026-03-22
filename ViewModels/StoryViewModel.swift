import SwiftUI

@MainActor
class StoryViewModel: ObservableObject {
    // Story setup
    @Published var childName: String = "Emma"
    @Published var theme: String = ""
    @Published var selectedStyle: StoryStyle = .warmCozy
    @Published var pageCount: PageCount = .ten
    @Published var selectedThemeChip: String?

    // Generation state
    @Published var isGenerating = false
    @Published var generationStage: GenerationStage = .writing
    @Published var generationProgress: Double = 0
    @Published var illustrationProgress: Int = 0

    // Story result
    @Published var currentStory: Story?
    @Published var currentPage: Int = 0
    @Published var errorMessage: String?

    // Saved stories
    @Published var savedStories: [Story] = []

    let themeChips = [
        ("🦁", "Be Brave"),
        ("🏫", "First Day"),
        ("🤝", "Friends"),
        ("😴", "Bedtime"),
        ("🌈", "Sharing"),
        ("👶", "New Sibling"),
        ("🍎", "New Foods"),
    ]

    var canGenerate: Bool {
        !theme.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func selectThemeChip(_ chip: String) {
        if selectedThemeChip == chip {
            selectedThemeChip = nil
            theme = ""
        } else {
            selectedThemeChip = chip
            theme = "\(childName) learns about \(chip.lowercased())"
        }
    }

    func generateStory() async {
        isGenerating = true
        generationStage = .writing
        generationProgress = 0
        illustrationProgress = 0
        errorMessage = nil

        do {
            // Stage 1: Writing (0-40%)
            generationStage = .writing
            for i in 1...4 {
                try await Task.sleep(nanoseconds: 400_000_000)
                generationProgress = Double(i) * 10
            }

            // Stage 2: Illustrating (40-90%)
            generationStage = .illustrating
            let totalPages = pageCount.rawValue
            for i in 1...totalPages {
                try await Task.sleep(nanoseconds: 300_000_000)
                illustrationProgress = i
                generationProgress = 40 + (Double(i) / Double(totalPages)) * 50
            }

            // Stage 3: Final touches (90-100%)
            generationStage = .finalizing
            try await Task.sleep(nanoseconds: 600_000_000)
            generationProgress = 100

            // Generate the story
            let story = try await GeminiService.shared.generateStory(
                childName: childName,
                theme: theme,
                style: selectedStyle,
                pageCount: pageCount.rawValue
            )

            try await Task.sleep(nanoseconds: 500_000_000)
            currentStory = story
            currentPage = 0
            isGenerating = false
        } catch {
            errorMessage = error.localizedDescription
            isGenerating = false
        }
    }

    func nextPage() {
        guard let story = currentStory, currentPage < story.pages.count - 1 else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentPage += 1
        }
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            currentPage -= 1
        }
    }

    func toggleFavorite() {
        currentStory?.isFavorite.toggle()
    }

    func saveStory() {
        guard let story = currentStory else { return }
        if let index = savedStories.firstIndex(where: { $0.id == story.id }) {
            savedStories[index] = story
        } else {
            savedStories.insert(story, at: 0)
        }
    }

    func resetForNewStory() {
        theme = ""
        selectedThemeChip = nil
        selectedStyle = .warmCozy
        pageCount = .ten
        currentStory = nil
        currentPage = 0
        isGenerating = false
        generationStage = .writing
        generationProgress = 0
        errorMessage = nil
    }
}

enum GenerationStage {
    case writing
    case illustrating
    case finalizing

    var label: String {
        switch self {
        case .writing: return "Crafting your story…"
        case .illustrating: return "Painting each page…"
        case .finalizing: return "Almost ready!"
        }
    }

    var icon: String {
        switch self {
        case .writing: return "✍️"
        case .illustrating: return "🎨"
        case .finalizing: return "✨"
        }
    }
}
