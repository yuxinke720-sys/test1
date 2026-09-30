import Foundation

// The app is built around one child at a time. Name, gender and birthday are the
// three things the story prompts need: the name goes into the narrative, the
// gender picks pronouns, and the birthday sets the reading level.
struct Child: Codable, Equatable {
    var name: String
    var gender: ChildGender
    /// `nil` until the parent picks a date — age-dependent copy falls back to a
    /// neutral label rather than guessing.
    var birthday: Date?

    init(name: String = "", gender: ChildGender = .unspecified, birthday: Date? = nil) {
        self.name = name
        self.gender = gender
        self.birthday = birthday
    }

    var isComplete: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Whole years since `birthday`, or `nil` when no birthday is set.
    var ageInYears: Int? {
        guard let birthday else { return nil }
        let years = Calendar.current.dateComponents([.year], from: birthday, to: Date()).year
        guard let years, years >= 0 else { return nil }
        return years
    }

    /// Short label for the profile row, e.g. "Age 4" or "Age set up pending".
    var ageLabel: String {
        guard let ageInYears else { return "Birthday not set" }
        return ageInYears == 0 ? "Under 1" : "Age \(ageInYears)"
    }

    /// Fed to the story prompt alongside the photo-derived appearance note, so the
    /// model gets age-appropriate vocabulary and the right pronouns.
    /// Empty when nothing useful is known, so no filler reaches the prompt.
    var promptDescriptor: String {
        guard isComplete else { return "" }
        let who = ageInYears.map { "a \($0)-year-old \(gender.noun)" } ?? "a \(gender.noun)"
        return "\(name) is \(who); refer to \(name) as \(gender.storyPronoun)"
    }
}

enum ChildGender: String, Codable, CaseIterable, Identifiable {
    case girl
    case boy
    case unspecified

    var id: String { rawValue }

    var label: String {
        switch self {
        case .girl: return "Girl"
        case .boy: return "Boy"
        case .unspecified: return "Prefer not to say"
        }
    }

    var sfSymbol: String {
        switch self {
        case .girl: return "figure.child"
        case .boy: return "figure.child"
        case .unspecified: return "person.fill.questionmark"
        }
    }

    /// Pronoun handed to the story prompt. Unspecified stays neutral on purpose.
    var storyPronoun: String {
        switch self {
        case .girl: return "she"
        case .boy: return "he"
        case .unspecified: return "they"
        }
    }

    var noun: String {
        switch self {
        case .girl: return "girl"
        case .boy: return "boy"
        case .unspecified: return "child"
        }
    }
}
