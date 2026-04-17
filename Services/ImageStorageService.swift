import UIKit

/// Manages saving / loading / deleting story illustration images
/// in the app's Documents directory.
///
/// On-disk layout:
///   Documents/users/{uid}/stories/{storyId}/page_{pageNumber}.jpg
///
/// Only **relative** paths (e.g. "stories/<uuid>/page_1.jpg") are
/// stored in the data model so sandbox path changes across app
/// updates never break file lookup.
struct ImageStorageService {
    static let shared = ImageStorageService()

    private init() {}

    // MARK: - Save

    /// Writes `imageData` to disk and returns the **relative** path.
    func save(imageData: Data, storyId: UUID, pageNumber: Int, userUID: String) async throws -> String {
        let relativePath = "users/\(userUID)/stories/\(storyId.uuidString)/page_\(pageNumber).jpg"
        let fileURL = Self.documentsURL.appendingPathComponent(relativePath)

        // Ensure directory exists
        let dirURL = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dirURL.path) {
            try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        }

        try imageData.write(to: fileURL, options: .atomic)
        print("[ImageStorage] Saved \(imageData.count) bytes → \(relativePath)")
        print("Absolute Documents path: \(dirURL.path)")
        return relativePath
    }

    // MARK: - Load

    /// Reads an image from a relative path. Returns `nil` if the file
    /// does not exist or cannot be decoded.
    func loadImage(from relativePath: String) async -> UIImage? {
        let fileURL = Self.documentsURL.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: fileURL) else {
            print("[ImageStorage] File not found: \(relativePath)")
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: - Delete

    /// Removes the entire directory for a story (all page images).
    func deleteStoryImages(storyId: UUID, userUID: String) {
        let dirURL = Self.documentsURL
            .appendingPathComponent("users")
            .appendingPathComponent(userUID)
            .appendingPathComponent("stories")
            .appendingPathComponent(storyId.uuidString)
        try? FileManager.default.removeItem(at: dirURL)
        print("[ImageStorage] Deleted images for story \(storyId.uuidString)")
    }

    // MARK: - Helpers

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
