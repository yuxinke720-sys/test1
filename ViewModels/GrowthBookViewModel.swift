import SwiftUI
import UIKit

/// Owns all Growth Books for the signed-in user.
///
/// Persistence (local-only for now; per CLAUDE.md, not UserDefaults):
///   - Book JSON:  Documents/users/<uid>/growth/books.json
///   - Images:     Documents/users/<uid>/growth/<bookId>/<mediaId>.jpg
@MainActor
class GrowthBookViewModel: ObservableObject {
    @Published var books: [GrowthBook] = []
    /// The book shown on the detail / reader screens.
    @Published var selectedBookID: UUID?
    /// Media IDs currently being turned into an AI illustration.
    @Published var illustratingMediaIDs: Set<UUID> = []
    @Published var errorMessage: String?
    /// Set right after a book is completed so the detail screen plays the ceremony once.
    @Published var celebratingBookID: UUID?

    private(set) var userUID: String = ""
    private var booksFileURL: URL {
        ImageStorageService.documentsURL.appendingPathComponent("users/\(userUID)/growth/books.json")
    }

    func configure(userUID: String) {
        self.userUID = userUID
        books = []
        selectedBookID = nil
        load()
    }

    // MARK: - Derived

    var selectedBook: GrowthBook? {
        guard let id = selectedBookID else { return nil }
        return books.first { $0.id == id }
    }

    var inProgressBooks: [GrowthBook] {
        books.filter { !$0.isCompleted }.sorted { lastActivity($0) > lastActivity($1) }
    }

    var completedBooks: [GrowthBook] {
        books.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private func lastActivity(_ book: GrowthBook) -> Date {
        book.chapters.map(\.date).max() ?? book.createdAt
    }

    // MARK: - Books

    @discardableResult
    func createBook(title: String, goal: String, childName: String, scenario: GrowthScenario) -> GrowthBook {
        let book = GrowthBook(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: goal.trimmingCharacters(in: .whitespacesAndNewlines),
            childName: childName,
            scenario: scenario
        )
        books.insert(book, at: 0)
        persist()
        print("[GrowthVM] Created book \"\(book.title)\"")
        return book
    }

    func deleteBook(_ bookID: UUID) {
        books.removeAll { $0.id == bookID }
        ImageStorageService.shared.deleteItem(at: bookFolder(bookID))
        if selectedBookID == bookID { selectedBookID = nil }
        persist()
    }

    func setVisibility(_ visibility: BookVisibility, for bookID: UUID) {
        mutate(bookID) { $0.visibility = visibility }
    }

    /// Locks the book: no more chapters. Triggers the completion ceremony.
    func completeBook(_ bookID: UUID) {
        mutate(bookID) { $0.completedAt = Date() }
        celebratingBookID = bookID
        print("[GrowthVM] Completed book \(bookID)")
    }

    // MARK: - Chapters

    /// Inserts or replaces a chapter. Ignored once the book is completed.
    func saveChapter(_ chapter: GrowthChapter, in bookID: UUID) {
        mutate(bookID) { book in
            guard !book.isCompleted else { return }
            if let i = book.chapters.firstIndex(where: { $0.id == chapter.id }) {
                book.chapters[i] = chapter
            } else {
                book.chapters.append(chapter)
            }
        }
    }

    func deleteChapter(_ chapterID: UUID, in bookID: UUID) {
        guard let chapter = books.first(where: { $0.id == bookID })?.chapters.first(where: { $0.id == chapterID }) else { return }
        chapter.media.forEach { ImageStorageService.shared.deleteItem(at: $0.path) }
        mutate(bookID) { $0.chapters.removeAll { $0.id == chapterID } }
    }

    // MARK: - Media

    /// Compresses and stores a picked photo. Returns the media entry (not yet attached to a chapter).
    func storePhoto(_ data: Data, bookID: UUID) -> ChapterMedia? {
        guard let image = UIImage(data: data),
              let jpeg = Self.resized(image, maxSide: 1600).jpegData(compressionQuality: 0.82) else { return nil }
        let media = ChapterMedia(kind: .photo, path: "")
        let path = "\(bookFolder(bookID))/\(media.id.uuidString).jpg"
        do {
            try ImageStorageService.shared.save(data: jpeg, relativePath: path)
            return ChapterMedia(id: media.id, kind: .photo, path: path)
        } catch {
            errorMessage = "Couldn't save the photo. Please try again."
            return nil
        }
    }

    /// Discards media files that were picked in the editor but never saved.
    func discardMedia(_ media: [ChapterMedia]) {
        media.forEach { ImageStorageService.shared.deleteItem(at: $0.path) }
    }

    /// Turns a chapter photo into a picture-book illustration with the AI image model.
    /// Returns the new media entry, or nil on failure (errorMessage is set).
    func illustrate(photo: ChapterMedia, chapterNote: String, book: GrowthBook) async -> ChapterMedia? {
        guard let image = ImageStorageService.shared.loadImageSync(from: photo.path),
              let refData = Self.resized(image, maxSide: 512).jpegData(compressionQuality: 0.8) else {
            errorMessage = "Couldn't read this photo."
            return nil
        }
        illustratingMediaIDs.insert(photo.id)
        defer { illustratingMediaIDs.remove(photo.id) }

        let scene = chapterNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        Children's picture book illustration based on the reference photo. \
        SUBJECT: a young child named \(book.childName); keep the child's hairstyle, outfit and the setting from the photo. \
        STORY: \(book.title) — goal: \(book.goal). \
        SCENE: \(scene.isEmpty ? "the moment shown in the photo" : scene). \
        ART DIRECTION: soft watercolor and colored pencil, warm gentle colors, rounded cute shapes, \
        cozy and encouraging mood, for toddlers aged 2-4, no text.
        """
        do {
            let data = try await AIService.shared.generateImage(prompt: prompt, referenceImageB64: refData.base64EncodedString())
            let media = ChapterMedia(kind: .aiIllustration, path: "", sourceMediaID: photo.id)
            let path = "\(bookFolder(book.id))/\(media.id.uuidString).jpg"
            try ImageStorageService.shared.save(data: data, relativePath: path)
            return ChapterMedia(id: media.id, kind: .aiIllustration, path: path, sourceMediaID: photo.id)
        } catch {
            print("[GrowthVM] illustrate failed: \(error)")
            errorMessage = "The illustration couldn't be created right now. Your photo is kept — try again later."
            return nil
        }
    }

    // MARK: - Export

    /// Renders every page of a book into a PDF file in the temp folder.
    func exportPDF(for book: GrowthBook) -> URL? {
        let pages = GrowthBookPage.pages(for: book)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.safeFileName(book.title)).pdf")
        let size = GrowthBookPageView.pageSize
        var box = CGRect(origin: .zero, size: size)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }

        for page in pages {
            let renderer = ImageRenderer(content: GrowthBookPageView(book: book, page: page).frame(width: size.width, height: size.height))
            renderer.proposedSize = ProposedViewSize(size)
            pdf.beginPDFPage(nil)
            renderer.render { _, draw in draw(pdf) }
            pdf.endPDFPage()
        }
        pdf.closePDF()
        print("[GrowthVM] Exported PDF with \(pages.count) pages → \(url.lastPathComponent)")
        return url
    }

    /// Renders every page as a JPEG file (for saving to Photos / sharing).
    func exportImages(for book: GrowthBook) -> [URL] {
        let size = GrowthBookPageView.pageSize
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("growth-export-\(book.id.uuidString)")
        try? FileManager.default.removeItem(at: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        return GrowthBookPage.pages(for: book).enumerated().compactMap { index, page in
            let renderer = ImageRenderer(content: GrowthBookPageView(book: book, page: page).frame(width: size.width, height: size.height))
            renderer.scale = 2
            guard let data = renderer.uiImage?.jpegData(compressionQuality: 0.9) else { return nil }
            let url = folder.appendingPathComponent(String(format: "%@-%02d.jpg", Self.safeFileName(book.title), index + 1))
            try? data.write(to: url)
            return url
        }
    }

    // MARK: - Persistence

    private func mutate(_ bookID: UUID, _ change: (inout GrowthBook) -> Void) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        change(&books[i])
        persist()
    }

    private func load() {
        guard !userUID.isEmpty, let data = try? Data(contentsOf: booksFileURL) else { return }
        do {
            books = try JSONDecoder().decode([GrowthBook].self, from: data)
            print("[GrowthVM] Loaded \(books.count) growth books")
        } catch {
            print("[GrowthVM] ERROR decoding growth books: \(error)")
        }
    }

    private func persist() {
        guard !userUID.isEmpty, let data = try? JSONEncoder().encode(books) else { return }
        do {
            try FileManager.default.createDirectory(at: booksFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: booksFileURL, options: .atomic)
        } catch {
            print("[GrowthVM] ERROR saving growth books: \(error)")
        }
    }

    private func bookFolder(_ bookID: UUID) -> String {
        "users/\(userUID)/growth/\(bookID.uuidString)"
    }

    // MARK: - Helpers

    static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func safeFileName(_ title: String) -> String {
        let cleaned = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined()
        return cleaned.isEmpty ? "Growth Book" : cleaned
    }
}
