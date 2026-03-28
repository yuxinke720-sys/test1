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

    // Navigation
    var previousScreen: AppScreen = .home

    // Templates
    @Published var selectedTemplate: StoryTemplate?

    // Saved stories
    @Published var savedStories: [Story] = []

    // MARK: - Persistence Keys
    private static let savedStoriesKey = "savedStories"
    private static let lastStoryIDKey = "lastStoryID"
    private static let lastPageKey = "lastPage"

    init() {
        loadSavedStories()
    }

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

    /// Resets page to 0 if the user finished the story (reached the last page).
    func resetPageIfFinished() {
        guard let story = currentStory else { return }
        if currentPage >= story.pages.count - 1 {
            currentPage = 0
        }
    }

    func saveStory() {
        guard let story = currentStory else { return }
        if let index = savedStories.firstIndex(where: { $0.id == story.id }) {
            savedStories[index] = story
        } else {
            savedStories.insert(story, at: 0)
        }
        persistSavedStories()
    }

    /// The 3 most recently read stories, sorted by lastReadAt descending.
    var recentlyReadStories: [Story] {
        savedStories
            .filter { $0.lastReadAt != nil }
            .sorted { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) }
            .prefix(3)
            .map { $0 }
    }

    func markAsRead(_ story: Story) {
        if let index = savedStories.firstIndex(where: { $0.id == story.id }) {
            savedStories[index].lastReadAt = Date()
            persistSavedStories()
        }
    }

    /// Returns days in a given month that have stories.
    func storyDays(for date: Date) -> [Int: Story] {
        let calendar = Calendar.current
        var result: [Int: Story] = [:]
        for story in savedStories {
            let comps = calendar.dateComponents([.year, .month, .day], from: story.createdAt)
            let dateComps = calendar.dateComponents([.year, .month], from: date)
            if comps.year == dateComps.year && comps.month == dateComps.month, let day = comps.day {
                result[day] = story
            }
        }
        return result
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

    // MARK: - Persistence

    private func loadSavedStories() {
        guard let data = UserDefaults.standard.data(forKey: Self.savedStoriesKey),
              let stories = try? JSONDecoder().decode([Story].self, from: data)
        else { return }
        savedStories = stories
    }

    func persistSavedStories() {
        if let data = try? JSONEncoder().encode(savedStories) {
            UserDefaults.standard.set(data, forKey: Self.savedStoriesKey)
        }
    }

    func persistReadingState() {
        if let story = currentStory {
            UserDefaults.standard.set(story.id.uuidString, forKey: Self.lastStoryIDKey)
            // Save page progress back into the story in savedStories
            if let index = savedStories.firstIndex(where: { $0.id == story.id }) {
                savedStories[index].lastReadPage = currentPage
                persistSavedStories()
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Self.lastStoryIDKey)
        }
        UserDefaults.standard.set(currentPage, forKey: Self.lastPageKey)
    }

    /// Attempts to restore the last reading session. Returns `true` if successful.
    func restoreLastReading() -> Bool {
        guard let idString = UserDefaults.standard.string(forKey: Self.lastStoryIDKey),
              let id = UUID(uuidString: idString),
              let story = savedStories.first(where: { $0.id == id })
        else { return false }

        currentStory = story
        let page = UserDefaults.standard.integer(forKey: Self.lastPageKey)
        currentPage = page < story.pages.count ? page : 0
        return true
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
        case .writing: return "pencil.line"
        case .illustrating: return "paintbrush.fill"
        case .finalizing: return "sparkles"
        }
    }
}
