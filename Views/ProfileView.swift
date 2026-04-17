import SwiftUI

struct ProfileView: View {
    @ObservedObject var storyVM: StoryViewModel
    @ObservedObject var authVM: AuthViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileHeader
                        childrenSection

                    settingsSection(title: "APP", rows: [
                        SettingsRow(sfIcon: "bell.fill", label: "Notifications", iconBg: Color(hex: "FFFBD4")),
                        SettingsRow(sfIcon: "paintbrush.fill", label: "Story Preferences", iconBg: Color(hex: "FFF0EC")),
                        SettingsRow(sfIcon: "globe", label: "Language", value: "English", iconBg: Color(hex: "EBF3FF")),
                    ])

                    settingsSection(title: "ACCOUNT", rows: [
                        SettingsRow(sfIcon: "lock.fill", label: "Privacy & Data", iconBg: Color(hex: "E8F8EE")),
                        SettingsRow(sfIcon: "envelope.fill", label: "Email", value: "emma@mom.com", iconBg: Color(hex: "EBF3FF")),
                        SettingsRow(sfIcon: "star.fill", label: "Rate StoryMe", iconBg: Color(hex: "FFFBD4")),
                        SettingsRow(sfIcon: "questionmark.circle.fill", label: "Help & Support", iconBg: Color(hex: "F5F2EE")),
                    ])

                    signOutSection

                    Text("StoryMe v1.0.0").font(.system(size: 11)).foregroundColor(Color(hex: "B8B3AC"))
                        .padding(.top, 8).padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
                }

                smTabBar(active: .profile, currentScreen: $currentScreen)
            }
        }
    }

    // MARK: - Profile Header (scrolls with content)
    private var profileHeader: some View {
        ZStack {
            Color(hex: "FFC933")
                .ignoresSafeArea(edges: .top)

            HStack {
                Spacer()
                Image(systemName: "sparkle")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(Color(hex: "1E1C1A").opacity(0.12))
                    .offset(x: -20, y: -10)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                Circle().fill(Color(hex: "FFFFFF")).frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: "FFD93D"))
                    )
                    .shadow(color: Color(hex: "FFD93D").opacity(0.5), radius: 12, y: 4)

                Spacer().frame(height: 14)

                Text("Emma's Mom")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Color(hex: "1E1C1A"))

                Text("3 stories created")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "1E1C1A").opacity(0.6))
                    .padding(.top, 3)

                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "C89F00"))
                    Text("Free Plan")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "C89F00"))
                }
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(Color(hex: "FFFFFF")).clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                .padding(.top, 12)

                Spacer().frame(height: 24)
            }
        }
        .frame(height: 260)
    }

    // MARK: - Children Section
    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("MY CHILDREN").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "7A756E")).tracking(0.7)
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                    Text("Add").font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(Color(hex: "FF8C6B"))
            }.padding(.horizontal, 20)

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "FFD93D"), Color(hex: "FFBFA8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "figure.child").font(.system(size: 22, weight: .medium)).foregroundColor(.white))
                    Circle().stroke(Color(hex: "FFD93D"), lineWidth: 3).frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(storyVM.childName).font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
                    Text("Age 2 · \(storyVM.savedStories.count) stories").font(.system(size: 11)).foregroundColor(Color(hex: "7A756E"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "B8B3AC"))
            }
            .padding(14).background(Color(hex: "FFFFFF")).cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3).padding(.horizontal, 18)
        }
        .padding(.top, 16).padding(.bottom, 14)
    }

    // MARK: - Sign Out Section
    private var signOutSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(spacing: 0) {
                Button {
                    authVM.signOut()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "FF5252"))
                            .frame(width: 32, height: 32).background(Color(hex: "FFECEC")).cornerRadius(9)
                        Text("Sign Out").font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(hex: "FF5252"))
                        Spacer()
                    }.padding(.horizontal, 14).padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
            .background(Color(hex: "FFFFFF")).cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2).padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Settings
    private struct SettingsRow: Identifiable {
        let id = UUID()
        let sfIcon: String
        let label: String
        var value: String? = nil
        var isDestructive: Bool = false
        var iconBg: Color = Color(hex: "F5F2EE")
    }

    private func settingsSection(title: String, rows: [SettingsRow]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if !title.isEmpty {
                Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "7A756E")).tracking(0.7).padding(.horizontal, 20)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 12) {
                        Image(systemName: row.sfIcon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(row.isDestructive ? Color(hex: "FF5252") : Color(hex: "7A756E"))
                            .frame(width: 32, height: 32).background(row.iconBg).cornerRadius(9)
                        Text(row.label).font(.system(size: 13, weight: .regular))
                            .foregroundColor(row.isDestructive ? Color(hex: "FF5252") : Color(hex: "1E1C1A"))
                        Spacer()
                        if let value = row.value { Text(value).font(.system(size: 12)).foregroundColor(Color(hex: "7A756E")) }
                        if !row.isDestructive {
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundColor(Color(hex: "B8B3AC"))
                        }
                    }.padding(.horizontal, 14).padding(.vertical, 13)
                    if index < rows.count - 1 { Divider().padding(.leading, 58) }
                }
            }
            .background(Color(hex: "FFFFFF")).cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2).padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }
}
#Preview("ContentView") {
    ContentView()
        .previewDevice("iPhone 15 Pro")
}
