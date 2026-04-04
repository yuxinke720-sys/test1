import Foundation

struct StoryPage: Identifiable, Codable, Equatable {
    let id: UUID
    var pageNumber: Int
    var text: String
    var imageDescription: String
    var emoji: String
    var imageData: Data?

    init(
        id: UUID = UUID(),
        pageNumber: Int = 0,
        text: String = "",
        imageDescription: String = "",
        emoji: String = "book.fill",
        imageData: Data? = nil
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.text = text
        self.imageDescription = imageDescription
        self.emoji = emoji
        self.imageData = imageData
    }
}
