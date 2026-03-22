import SwiftUI

struct ProfileView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        VStack(spacing: 0) {
            // Profile header
            profileHeader

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    // Children section
                    childrenSection

                    // Settings sections
                    settingsSection(title: "APP", rows: [
                        SettingsRow(icon: "🔔", label: "Notifications", iconBg: .smYellow100),
                        SettingsRow(icon: "🎨", label: "Story Preferences", iconBg: .smCoral100),
                        SettingsRow(icon: "🌐", label: "Language", value: "English", iconBg: .smBlue100),
                    ])

                    settingsSection(title: "ACCOUNT", rows: [
                        SettingsRow(icon: "🔒", label: "Privacy & Data", iconBg: .smGreen100),
                        SettingsRow(icon: "📧", label: "Email", value: "emma@mom.com", iconBg: .smBlue100),
                        SettingsRow(icon: "⭐", label: "Rate StoryMe", iconBg: .smYellow100),
                        SettingsRow(icon: "❓", label: "Help & Support", iconBg: .smNeutral100),
                    ])

                    settingsSection(title: "", rows: [
                        SettingsRow(icon: "🚪", label: "Sign Out", isDestructive: true, iconBg: .smRed100),
                    ])

                    // App version
                    Text("StoryMe v1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(.smNeutral300)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                }
            }

            smTabBar(active: .profile, currentScreen: $currentScreen)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "FFF9F0").ignoresSafeArea())
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        ZStack {
            LinearGradient(
                colors: [.smYellow400, .smYellow300],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative
            HStack {
                Spacer()
                Text("✦")
                    .font(.system(size: 40))
                    .foregroundColor(.smTextPrimary.opacity(0.15))
                    .offset(x: -20, y: -10)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                // Avatar
                Circle()
                    .fill(Color.white)
                    .frame(width: 72, height: 72)
                    .overlay(Text("👩").font(.system(size: 36)))
                    .shadow(color: .smYellow400.opacity(0.5), radius: 10, y: 4)

                Spacer().frame(height: 12)

                Text("Emma's Mom")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.smTextPrimary)

                Text("3 stories created")
                    .font(.system(size: 12))
                    .foregroundColor(.smTextPrimary.opacity(0.6))
                    .padding(.top, 3)

                // Subscription badge
                HStack(spacing: 5) {
                    Text("⭐")
                        .font(.system(size: 11))
                    Text("Free Plan")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.smYellow600)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                .padding(.top, 10)

                Spacer().frame(height: 20)
            }
        }
        .frame(height: 240)
    }

    // MARK: - Children Section
    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("MY CHILDREN")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.smTextSecondary)
                    .tracking(0.7)
                Spacer()
                Text("+ Add")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.smCoral400)
            }
            .padding(.horizontal, 20)

            // Child card
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.smYellow400, .smCoral300],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(Text("👧").font(.system(size: 24)))

                    // Active ring
                    Circle()
                        .stroke(Color.smYellow400, lineWidth: 3)
                        .frame(width: 56, height: 56)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(storyVM.childName)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.smTextPrimary)
                    Text("Age 4 · \(storyVM.savedStories.count) stories")
                        .font(.system(size: 11))
                        .foregroundColor(.smTextSecondary)
                }

                Spacer()

                Text("›")
                    .font(.system(size: 16))
                    .foregroundColor(.smNeutral300)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            .padding(.horizontal, 18)
        }
        .padding(.top, 8)
    }

    // MARK: - Settings Section
    private struct SettingsRow: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        var value: String? = nil
        var isDestructive: Bool = false
        var iconBg: Color = .smNeutral100
    }

    private func settingsSection(title: String, rows: [SettingsRow]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.smTextSecondary)
                    .tracking(0.7)
                    .padding(.horizontal, 20)
            }

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: 12) {
                        Text(row.icon)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(row.iconBg)
                            .cornerRadius(9)

                        Text(row.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(row.isDestructive ? .smRed400 : .smTextPrimary)

                        Spacer()

                        if let value = row.value {
                            Text(value)
                                .font(.system(size: 12))
                                .foregroundColor(.smTextSecondary)
                        }

                        if !row.isDestructive {
                            Text("›")
                                .font(.system(size: 14))
                                .foregroundColor(.smNeutral300)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 58)
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
            .padding(.horizontal, 18)
        }
    }

}

#Preview("ProfileView") {
    ProfileView(
        storyVM: StoryViewModel(),
        currentScreen: .constant(.profile)
    )
    .previewDevice("iPhone 15 Pro")
}
