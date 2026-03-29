import Foundation

struct StoryPage: Identifiable, Codable, Equatable {
    let id: UUID
    var pageNumber: Int
    var text: String
    var imageDescription: String
    var emoji: String // SF Symbol name, placeholder for AI-generated illustration

    init(
        id: UUID = UUID(),
        pageNumber: Int = 0,
        text: String = "",
        imageDescription: String = "",
        emoji: String = "book.fill"
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.text = text
        self.imageDescription = imageDescription
        self.emoji = emoji
    }
}
