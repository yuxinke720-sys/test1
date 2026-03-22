import Foundation

struct StoryPage: Identifiable, Codable, Equatable {
    let id: UUID
    var pageNumber: Int
    var text: String
    var imageDescription: String
    var emoji: String // Placeholder for AI-generated illustration

    init(
        id: UUID = UUID(),
        pageNumber: Int = 0,
        text: String = "",
        imageDescription: String = "",
        emoji: String = "📖"
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.text = text
        self.imageDescription = imageDescription
        self.emoji = emoji
    }
}
