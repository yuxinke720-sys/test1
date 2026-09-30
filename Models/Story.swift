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
    var lastReadPage: Int
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
        lastReadPage: Int = 0,
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
        self.lastReadPage = lastReadPage
        self.isFavorite = isFavorite
    }
}
enum StoryStyle: String, Codable, CaseIterable, Equatable {
    case warmCozy = "Warm & Cozy"
    case adventure = "Adventure"
    case fantasy = "Fantasy"
    var emoji: String {
        switch self {
        case .warmCozy: return "heart.fill"
        case .adventure: return "airplane"
        case .fantasy: return "sparkles"
        }
    }
}
enum PageCount {
    static let min = 1
    static let max = 12
    static let defaultValue = 1

    static func readTime(for count: Int) -> String {
        let minutes = Swift.max(1, Int(ceil(Double(count) * 0.5)))
        return "~\(minutes) min"
    }
}
