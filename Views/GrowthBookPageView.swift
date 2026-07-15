import SwiftUI

// MARK: - Page model

/// One printed page of a finished Growth Book. The same pages feed the
/// in-app reader and the PDF / image export, so what you see is what you export.
enum GrowthBookPage: Identifiable {
    case cover
    /// `number` is 1-based. Chapters with more than 4 pictures continue on extra pages.
    case chapter(GrowthChapter, number: Int, media: [ChapterMedia], isContinuation: Bool)
    case ending

    var id: String {
        switch self {
        case .cover: return "cover"
        case .ending: return "ending"
        case let .chapter(ch, _, media, _): return "\(ch.id.uuidString)-\(media.first?.id.uuidString ?? "text")"
        }
    }

    static let mediaPerPage = 4

    static func pages(for book: GrowthBook) -> [GrowthBookPage] {
        var pages: [GrowthBookPage] = [.cover]
        for (i, chapter) in book.sortedChapters.enumerated() {
            let media = displayMedia(for: chapter)
            let chunks = stride(from: 0, to: max(media.count, 1), by: mediaPerPage).map {
                Array(media[min($0, media.count)..<min($0 + mediaPerPage, media.count)])
            }
            for (j, chunk) in chunks.enumerated() {
                pages.append(.chapter(chapter, number: i + 1, media: chunk, isContinuation: j > 0))
            }
        }
        pages.append(.ending)
        return pages
    }

    /// Prefer the AI illustration over the photo it was drawn from, so a page
    /// doesn't show the same moment twice.
    static func displayMedia(for chapter: GrowthChapter) -> [ChapterMedia] {
        let illustratedSources = Set(chapter.media.compactMap(\.sourceMediaID))
        return chapter.media.filter { !illustratedSources.contains($0.id) }
    }
}

// MARK: - Page view

struct GrowthBookPageView: View {
    let book: GrowthBook
    let page: GrowthBookPage

    /// Fixed design size; the reader scales it to fit, the exporter renders it 1:1.
    static let pageSize = CGSize(width: 600, height: 800)

    var body: some View {
        Group {
            switch page {
            case .cover: cover
            case let .chapter(chapter, number, media, isContinuation):
                chapterPage(chapter, number: number, media: media, isContinuation: isContinuation)
            case .ending: ending
            }
        }
        .frame(width: Self.pageSize.width, height: Self.pageSize.height)
        .clipped()
    }

    private var gradient: LinearGradient {
        let (a, b) = book.scenario.gradientHex
        return LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Cover

    private var cover: some View {
        ZStack {
            gradient
            VStack(spacing: 28) {
                Text("A GROWTH STORY")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.85))

                Group {
                    if let media = book.coverMedia, let image = ImageStorageService.shared.loadImageSync(from: media.path) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Color.white.opacity(0.25)
                            Image(systemName: book.scenario.sfSymbol)
                                .font(.system(size: 120, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .frame(width: 380, height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).stroke(.white, lineWidth: 8))
                .shadow(color: .black.opacity(0.15), radius: 16, y: 8)

                Text(book.title)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 48)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)

                Text(dateRange)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private var dateRange: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        let start = book.sortedChapters.first?.date ?? book.createdAt
        guard let end = book.completedAt else { return "Started \(f.string(from: start))" }
        return "\(f.string(from: start)) – \(f.string(from: end))"
    }

    // MARK: Chapter

    private func chapterPage(_ chapter: GrowthChapter, number: Int, media: [ChapterMedia], isContinuation: Bool) -> some View {
        ZStack(alignment: .top) {
            Color(hex: "FFFDF7")
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text(isContinuation ? "CHAPTER \(number) · CONTINUED" : "CHAPTER \(number)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .tracking(2)
                        .foregroundColor(Color(hex: "E86D4A"))
                    Spacer()
                    Text(chapterDate(chapter.date))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "7A756E"))
                }

                if !isContinuation, !chapter.title.isEmpty {
                    Text(chapter.title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "1E1C1A"))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }

                mediaGrid(media)

                if !isContinuation, !chapter.note.isEmpty {
                    Text(chapter.note)
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "3A342E"))
                        .lineSpacing(6)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
            .padding(48)

            Text("Day \(dayNumber(chapter.date))")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "FF8C6B")))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(32)
        }
    }

    @ViewBuilder
    private func mediaGrid(_ media: [ChapterMedia]) -> some View {
        let images = media.compactMap { ImageStorageService.shared.loadImageSync(from: $0.path) }
        switch images.count {
        case 0:
            EmptyView()
        case 1:
            tile(images[0]).frame(height: 420)
        case 2:
            HStack(spacing: 14) { ForEach(0..<2, id: \.self) { tile(images[$0]) } }.frame(height: 340)
        default:
            let rows = [Array(images.prefix(2)), Array(images.dropFirst(2))]
            VStack(spacing: 14) {
                ForEach(0..<rows.count, id: \.self) { r in
                    HStack(spacing: 14) { ForEach(0..<rows[r].count, id: \.self) { tile(rows[r][$0]) } }
                }
            }
            .frame(height: 440)
        }
    }

    private func tile(_ image: UIImage) -> some View {
        Color.clear
            .overlay(Image(uiImage: image).resizable().scaledToFill())
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func chapterDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    private func dayNumber(_ date: Date) -> Int {
        let start = Calendar.current.startOfDay(for: book.sortedChapters.first?.date ?? book.createdAt)
        let days = Calendar.current.dateComponents([.day], from: start, to: Calendar.current.startOfDay(for: date)).day ?? 0
        return days + 1
    }

    // MARK: Ending

    private var ending: some View {
        ZStack {
            Color(hex: "FFFDF7")
            gradient.opacity(0.14)
            VStack(spacing: 26) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(Color(hex: "FFD93D"), Color(hex: "E86D4A"))
                Text("\(book.childName) did it!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "1E1C1A"))
                Text(book.goal)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "3A342E"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                HStack(spacing: 40) {
                    stat("\(book.dayCount)", book.dayCount == 1 ? "day" : "days")
                    stat("\(book.chapters.count)", book.chapters.count == 1 ? "chapter" : "chapters")
                    stat("\(book.mediaCount)", book.mediaCount == 1 ? "picture" : "pictures")
                }
                .padding(.top, 10)
                Text("The End")
                    .font(.system(size: 22, weight: .heavy, design: .serif))
                    .italic()
                    .foregroundColor(Color(hex: "7A756E"))
                    .padding(.top, 30)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 40, weight: .black, design: .rounded)).foregroundColor(Color(hex: "E86D4A"))
            Text(label).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(Color(hex: "7A756E"))
        }
    }
}
