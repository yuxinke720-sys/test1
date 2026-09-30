import SwiftUI

/// Owns the single child profile. Persisted per user in UserDefaults, matching
/// the keying StoryViewModel uses, so switching accounts on one device never
/// leaks one family's details into another.
@MainActor
class ChildProfileViewModel: ObservableObject {
    @Published var child = Child()

    private(set) var userUID: String = ""
    private var storageKey: String { "childProfile_\(userUID)" }

    func configure(userUID: String) {
        self.userUID = userUID
        load()
    }

    // MARK: - Editing

    func update(name: String, gender: ChildGender, birthday: Date?) {
        child = Child(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            gender: gender,
            birthday: birthday
        )
        persist()
    }

    // MARK: - Persistence

    private func load() {
        guard !userUID.isEmpty,
              let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Child.self, from: data)
        else {
            child = Child()
            return
        }
        child = decoded
    }

    private func persist() {
        guard !userUID.isEmpty, let data = try? JSONEncoder().encode(child) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
