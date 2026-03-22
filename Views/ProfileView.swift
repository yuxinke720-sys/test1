import SwiftUI

struct ProfileView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                profileHeader

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        childrenSection

                        settingsSection(title: "APP", rows: [
                            SettingsRow(icon: "🔔", label: "Notifications", iconBg: Color(hex: "FFFBD4")),
                            SettingsRow(icon: "🎨", label: "Story Preferences", iconBg: Color(hex: "FFF0EC")),
                            SettingsRow(icon: "🌐", label: "Language", value: "English", iconBg: Color(hex: "EBF3FF")),
                        ])

                        settingsSection(title: "ACCOUNT", rows: [
                            SettingsRow(icon: "🔒", label: "Privacy & Data", iconBg: Color(hex: "E8F8EE")),
                            SettingsRow(icon: "📧", label: "Email", value: "emma@mom.com", iconBg: Color(hex: "EBF3FF")),
                            SettingsRow(icon: "⭐", label: "Rate StoryMe", iconBg: Color(hex: "FFFBD4")),
                            SettingsRow(icon: "❓", label: "Help & Support", iconBg: Color(hex: "F5F2EE")),
                        ])

                        settingsSection(title: "", rows: [
                            SettingsRow(icon: "🚪", label: "Sign Out", isDestructive: true, iconBg: Color(hex: "FFECEC")),
                        ])

                        Text("StoryMe v1.0.0").font(.system(size: 11)).foregroundColor(Color(hex: "B8B3AC"))
                            .padding(.top, 8).padding(.bottom, 20)
                    }.frame(maxWidth: .infinity)
                }

                smTabBar(active: .profile, currentScreen: $currentScreen)
            }
        }
    }

    private var profileHeader: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFD93D"), Color(hex: "FFE94A")], startPoint: .topLeading, endPoint: .bottomTrailing)

            HStack {
                Spacer()
                Text("✦").font(.system(size: 40)).foregroundColor(Color(hex: "1E1C1A").opacity(0.15)).offset(x: -20, y: -10)
            }

            VStack(spacing: 0) {
                Spacer().frame(height: 56)
                Circle().fill(Color(hex: "FFFFFF")).frame(width: 72, height: 72)
                    .overlay(Text("👩").font(.system(size: 36)))
                    .shadow(color: Color(hex: "FFD93D").opacity(0.5), radius: 10, y: 4)
                Spacer().frame(height: 12)
                Text("Emma's Mom").font(.system(size: 20, weight: .black)).foregroundColor(Color(hex: "1E1C1A"))
                Text("3 stories created").font(.system(size: 12)).foregroundColor(Color(hex: "1E1C1A").opacity(0.6)).padding(.top, 3)

                HStack(spacing: 5) {
                    Text("⭐").font(.system(size: 11))
                    Text("Free Plan").font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "C89F00"))
                }
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Color(hex: "FFFFFF")).clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2).padding(.top, 10)

                Spacer().frame(height: 20)
            }
        }.frame(height: 240)
    }

    private var childrenSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("MY CHILDREN").font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "7A756E")).tracking(0.7)
                Spacer()
                Text("+ Add").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "FF8C6B"))
            }.padding(.horizontal, 20)

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "FFD93D"), Color(hex: "FFBFA8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50).overlay(Text("👧").font(.system(size: 24)))
                    Circle().stroke(Color(hex: "FFD93D"), lineWidth: 3).frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(storyVM.childName).font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
                    Text("Age 4 · \(storyVM.savedStories.count) stories").font(.system(size: 11)).foregroundColor(Color(hex: "7A756E"))
                }
                Spacer()
                Text("›").font(.system(size: 16)).foregroundColor(Color(hex: "B8B3AC"))
            }
            .padding(14).background(Color(hex: "FFFFFF")).cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3).padding(.horizontal, 18)
        }.padding(.top, 8)
    }

    private struct SettingsRow: Identifiable {
        let id = UUID()
        let icon: String
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
                        Text(row.icon).font(.system(size: 16)).frame(width: 32, height: 32).background(row.iconBg).cornerRadius(9)
                        Text(row.label).font(.system(size: 13, weight: .regular))
                            .foregroundColor(row.isDestructive ? Color(hex: "FF5252") : Color(hex: "1E1C1A"))
                        Spacer()
                        if let value = row.value { Text(value).font(.system(size: 12)).foregroundColor(Color(hex: "7A756E")) }
                        if !row.isDestructive { Text("›").font(.system(size: 14)).foregroundColor(Color(hex: "B8B3AC")) }
                    }.padding(.horizontal, 14).padding(.vertical, 13)
                    if index < rows.count - 1 { Divider().padding(.leading, 58) }
                }
            }
            .background(Color(hex: "FFFFFF")).cornerRadius(16)
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2).padding(.horizontal, 18)
        }
    }
}
