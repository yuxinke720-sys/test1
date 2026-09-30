import SwiftUI

/// Edits the one child profile: name, gender, birthday.
/// Edits are held in local @State and only written back on Save, so backing out
/// of the screen leaves the stored profile untouched.
struct ChildProfileView: View {
    @ObservedObject var childVM: ChildProfileViewModel
    @Binding var currentScreen: AppScreen

    @State private var name: String = ""
    @State private var gender: ChildGender = .unspecified
    @State private var birthday: Date = Self.defaultBirthday
    @State private var hasBirthday: Bool = false
    @State private var didLoad = false

    /// Picture books here target 3-6 year olds, so the wheel opens near that age
    /// instead of today's date.
    private static var defaultBirthday: Date {
        Calendar.current.date(byAdding: .year, value: -4, to: Date()) ?? Date()
    }

    private var birthdayRange: ClosedRange<Date> {
        let earliest = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
        return earliest...Date()
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        nameSection
                        genderSection
                        birthdaySection
                        saveButton
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear(perform: loadOnce)
    }

    // MARK: - Sections

    private var navBar: some View {
        HStack {
            Button { currentScreen = .profile } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "FF8C6B"))
                    .frame(width: 36)
            }
            Spacer()
            Text("My Child").font(.system(size: 17, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
            Spacer()
            Color.clear.frame(width: 36)
        }
        .frame(height: 48)
        .padding(.horizontal, 18)
    }

    private var nameSection: some View {
        section("NAME") {
            TextField("What does your child go by?", text: $name)
                .font(.system(size: 15))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
        }
    }

    private var genderSection: some View {
        section("GENDER") {
            VStack(spacing: 0) {
                ForEach(Array(ChildGender.allCases.enumerated()), id: \.element.id) { index, option in
                    Button { gender = option } label: {
                        HStack(spacing: 12) {
                            Text(option.label)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "1E1C1A"))
                            Spacer()
                            Image(systemName: gender == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundColor(gender == option ? Color(hex: "E8705A") : Color(hex: "D0CBC4"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)

                    if index < ChildGender.allCases.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
        }
    }

    private var birthdaySection: some View {
        section("BIRTHDAY") {
            VStack(spacing: 0) {
                Toggle(isOn: $hasBirthday) {
                    Text("Set a birthday")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "1E1C1A"))
                }
                .tint(Color(hex: "FFD93D"))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)

                if hasBirthday {
                    Divider().padding(.leading, 14)
                    DatePicker("", selection: $birthday, in: birthdayRange, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Color(hex: "E8705A"))
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(canSave ? Color(hex: "1E1C1A") : Color(hex: "B8B3AC"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color(hex: "FFD93D") : Color(hex: "EDE8E1"))
                .cornerRadius(18)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    // MARK: - Building blocks

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "7A756E"))
                .tracking(0.7)
                .padding(.horizontal, 20)

            VStack(spacing: 0) { content() }
                .background(Color(hex: "FFFFFF"))
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                .padding(.horizontal, 18)
        }
        .padding(.top, 16)
    }

    // MARK: - Actions

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        let child = childVM.child
        name = child.name
        gender = child.gender
        if let stored = child.birthday {
            birthday = stored
            hasBirthday = true
        }
    }

    private func save() {
        childVM.update(name: name, gender: gender, birthday: hasBirthday ? birthday : nil)
        currentScreen = .profile
    }
}
