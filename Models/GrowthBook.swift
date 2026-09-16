import Foundation

// MARK: - Growth Book
//
// A long-term picture book that follows ONE growth event (e.g. "learning to
// get dressed") across many days. Each time point is a chapter. When the
// parent marks the event as achieved, the book is locked and becomes a
// finished, readable / exportable book.
//
// Stored locally per user (UserDefaults JSON + images in Documents), shaped so
// it can later be mirrored 1:1 into Firestore (book doc + chapters array) and
// Storage (media paths) when the app moves to the cloud.

struct GrowthBook: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    /// The milestone that ends the book, e.g. "Put on clothes all by herself".
    var goal: String
    var childName: String
    var scenario: GrowthScenario
    var chapters: [GrowthChapter]
    var createdAt: Date
    var completedAt: Date?
    var visibility: BookVisibility

    init(
        id: UUID = UUID(),
        title: String,
        goal: String,
        childName: String,
        scenario: GrowthScenario = .custom,
        chapters: [GrowthChapter] = [],
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        visibility: BookVisibility = .privateOnly
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.childName = childName
        self.scenario = scenario
        self.chapters = chapters
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.visibility = visibility
    }

    var isCompleted: Bool { completedAt != nil }

    /// Chapters in timeline order (oldest first).
    var sortedChapters: [GrowthChapter] {
        chapters.sorted { $0.date < $1.date }
    }

    /// Whole days from the first chapter (or creation) to completion / today.
    var dayCount: Int {
        let start = sortedChapters.first?.date ?? createdAt
        let end = completedAt ?? Date()
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start),
                                                   to: Calendar.current.startOfDay(for: end)).day ?? 0
        return max(1, days + 1)
    }

    var mediaCount: Int { chapters.reduce(0) { $0 + $1.media.count } }

    /// Cover picture: the first image of the last chapter (the "I did it!" moment).
    var coverMedia: ChapterMedia? {
        sortedChapters.last(where: { !$0.media.isEmpty })?.media.first
    }
}

// MARK: - Chapter

struct GrowthChapter: Identifiable, Codable, Equatable {
    let id: UUID
    /// The time point this chapter records. Defaults to "now" and drives the timeline order.
    var date: Date
    var title: String
    var note: String
    var media: [ChapterMedia]

    init(id: UUID = UUID(), date: Date = Date(), title: String = "", note: String = "", media: [ChapterMedia] = []) {
        self.id = id
        self.date = date
        self.title = title
        self.note = note
        self.media = media
    }
}

struct ChapterMedia: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case photo
        case aiIllustration
    }

    let id: UUID
    var kind: Kind
    /// Relative path under Documents (see ImageStorageService).
    var path: String
    /// For AI illustrations: which photo it was drawn from.
    var sourceMediaID: UUID?

    init(id: UUID = UUID(), kind: Kind, path: String, sourceMediaID: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.path = path
        self.sourceMediaID = sourceMediaID
    }
}

// MARK: - Visibility

enum BookVisibility: String, Codable, CaseIterable, Identifiable {
    case privateOnly = "private"
    case friends
    case everyone = "public"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .privateOnly: return "Only me"
        case .friends: return "Friends"
        case .everyone: return "Everyone"
        }
    }

    var sfSymbol: String {
        switch self {
        case .privateOnly: return "lock.fill"
        case .friends: return "person.2.fill"
        case .everyone: return "globe"
        }
    }
}

// MARK: - Scenario presets

enum GrowthScenario: String, Codable, CaseIterable, Identifiable {
    case dressing, walking, biking, teeth, daycare, potty, custom

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .dressing: return "tshirt.fill"
        case .walking: return "figure.walk"
        case .biking: return "bicycle"
        case .teeth: return "mouth.fill"
        case .daycare: return "backpack.fill"
        case .potty: return "toilet.fill"
        case .custom: return "star.fill"
        }
    }

    var label: String {
        switch self {
        case .dressing: return "Getting dressed"
        case .walking: return "First steps"
        case .biking: return "Riding a bike"
        case .teeth: return "Losing a tooth"
        case .daycare: return "Daycare days"
        case .potty: return "Potty training"
        case .custom: return "Something else"
        }
    }

    /// Suggested title / goal, with "{name}" replaced by the child's name.
    func suggestion(for name: String) -> (title: String, goal: String) {
        switch self {
        case .dressing: return ("\(name) Gets Dressed!", "Puts on clothes without help")
        case .walking: return ("\(name)'s First Steps", "Walks across the room alone")
        case .biking: return ("\(name) Rides a Bike", "Rides without training wheels")
        case .teeth: return ("\(name)'s Wiggly Tooth", "The first tooth falls out")
        case .daycare: return ("\(name) Goes to Daycare", "Waves goodbye with a smile")
        case .potty: return ("\(name) Uses the Potty", "A whole day without diapers")
        case .custom: return ("", "")
        }
    }

    /// Gradient used for covers and cards.
    var gradientHex: (String, String) {
        switch self {
        case .dressing: return ("FFD93D", "FF8C6B")
        case .walking: return ("6BCB77", "4DB6AC")
        case .biking: return ("4D96FF", "6BCB77")
        case .teeth: return ("FFBFA8", "E86D4A")
        case .daycare: return ("FFE94A", "6BCB77")
        case .potty: return ("B39DDB", "4D96FF")
        case .custom: return ("FFD93D", "E86D4A")
        }
    }
}
