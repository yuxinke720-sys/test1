import Foundation

struct StoryPage: Identifiable, Equatable {
    let id: UUID
    var pageNumber: Int
    var text: String
    var imageDescription: String
    var emoji: String
    var imageStoragePath: String?

    /// Legacy field — only populated during migration decoding.
    /// Never encoded back to JSON.
    var legacyImageData: Data?

    init(
        id: UUID = UUID(),
        pageNumber: Int = 0,
        text: String = "",
        imageDescription: String = "",
        emoji: String = "book.fill",
        imageStoragePath: String? = nil
    ) {
        self.id = id
        self.pageNumber = pageNumber
        self.text = text
        self.imageDescription = imageDescription
        self.emoji = emoji
        self.imageStoragePath = imageStoragePath
    }
}

// MARK: - Codable (with legacy imageData migration support)

extension StoryPage: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, pageNumber, text, imageDescription, emoji
        case imageStoragePath
        case imageData // legacy key — decode only
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self, forKey: .id)
        pageNumber       = try c.decode(Int.self, forKey: .pageNumber)
        text             = try c.decode(String.self, forKey: .text)
        imageDescription = try c.decodeIfPresent(String.self, forKey: .imageDescription) ?? ""
        emoji            = try c.decodeIfPresent(String.self, forKey: .emoji) ?? "book.fill"
        imageStoragePath = try c.decodeIfPresent(String.self, forKey: .imageStoragePath)

        // If the new path is missing, try to read old binary data for migration.
        // Wrapped in try? so a malformed imageData blob can never kill the
        // entire [Story] decode — the page simply loads without an image.
        if imageStoragePath == nil {
            legacyImageData = try? c.decodeIfPresent(Data.self, forKey: .imageData)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(pageNumber, forKey: .pageNumber)
        try c.encode(text, forKey: .text)
        try c.encode(imageDescription, forKey: .imageDescription)
        try c.encode(emoji, forKey: .emoji)
        try c.encodeIfPresent(imageStoragePath, forKey: .imageStoragePath)
        // NOTE: legacyImageData is intentionally never encoded
    }
}
