import Foundation
struct Story: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var childName: String
    var theme: String
    var style: StoryStyle
    var pages: [StoryPage]
    var createdAt: Date
    var lastReadAt: Date?
    var isFavorite: Bool
    init(
        id: UUID = UUID(),
        title: String = "",
        childName: String = "",
        theme: String = "",
        style: StoryStyle = .warmCozy,
        pages: [StoryPage] = [],
        createdAt: Date = Date(),
        lastReadAt: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.childName = childName
        self.theme = theme
        self.style = style
        self.pages = pages
        self.createdAt = createdAt
        self.lastReadAt = lastReadAt
        self.isFavorite = isFavorite
    }
}
enum StoryStyle: String, Codable, CaseIterable, Equatable {
    case warmCozy = "Warm & Cozy"
    case adventure = "Adventure"
    case fantasy = "Fantasy"
    var emoji: String {
        switch self {
        case .warmCozy: return "🌸"
        case .adventure: return "🚀"
        case .fantasy: return "✨"
        }
    }
}
enum PageCount: Int, CaseIterable {
    case eight = 8
    case ten = 10
    case twelve = 12
    var readTime: String {
        switch self {
        case .eight: return "~4 min"
        case .ten: return "~5 min"
        case .twelve: return "~6 min"
        }
    }
}
