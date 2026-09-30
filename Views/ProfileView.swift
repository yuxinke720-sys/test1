import SwiftUI

struct ProfileView: View {
    @ObservedObject var storyVM: StoryViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    @AppStorage("hasSeenCreateGuide") private var hasSeenCreateGuide = true
    @ObservedObject var authVM: AuthViewModel
    @ObservedObject var settingsVM: SettingsViewModel
    @ObservedObject var childVM: ChildProfileViewModel
    @Binding var currentScreen: AppScreen

    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        profileHeader
                        childrenSection

                        // MARK: - STORY
                        sectionTitle("STORY")
                        cardSection {
                            SettingsRow(sfIcon: "figure.child", label: "Child Profile",
                                        value: childVM.child.isComplete ? childVM.child.name : "Not set",
                                        iconBg: Color(hex: "FFF5A0")) {
                                currentScreen = .childProfile
                            }
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "paintbrush.fill", label: "Story Preferences", iconBg: Color(hex: "FFF0EC"))
                        }

                        #if DEBUG
                        // MARK: - DEVELOPER (Debug builds only)
                        sectionTitle("DEVELOPER")
                        cardSection {
                            SettingsRow(sfIcon: "wand.and.stars", label: "Skip Illustrations (Dev)", iconBg: Color(hex: "FFF5A0"), toggle: $settingsVM.skipImageGeneration, showChevron: false)
                        }
                        #endif

                        // MARK: - NOTIFICATIONS
                        sectionTitle("NOTIFICATIONS")
                        cardSection {
                            SettingsRow(sfIcon: "bell.fill", label: "Push Notifications", iconBg: Color(hex: "FFFBD4"), toggle: $settingsVM.notificationsEnabled, showChevron: false)
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "moon.stars.fill", label: "Daily Reminder", iconBg: Color(hex: "EBF3FF"), toggle: $settingsVM.dailyReminderEnabled, showChevron: false)
                                .opacity(settingsVM.notificationsEnabled ? 1 : 0.4)
                                .disabled(!settingsVM.notificationsEnabled)
                        }

                        // MARK: - APP
                        sectionTitle("APP")
                        cardSection {
                            SettingsRow(sfIcon: "globe", label: "Language", value: settingsVM.selectedLanguage, iconBg: Color(hex: "EBF3FF"))
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "circle.lefthalf.filled", label: "Appearance", iconBg: Color(hex: "F5F2EE"), toggle: $settingsVM.isDarkMode, showChevron: false)
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "star.fill", label: "Rate StoryMe", iconBg: Color(hex: "FFFBD4"))
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "graduationcap.fill", label: "Beginner Tutorial", iconBg: Color(hex: "E8F8EE")) {
                                // Replays the intro walkthrough now and the Create-page guide on next visit.
                                hasSeenCreateGuide = false
                                hasSeenOnboarding = false
                                currentScreen = .create
                            }
                        }

                        // MARK: - ACCOUNT
                        sectionTitle("ACCOUNT")
                        cardSection {
                            SettingsRow(sfIcon: "lock.fill", label: "Privacy & Data", iconBg: Color(hex: "E8F8EE"))
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "envelope.fill", label: "Email", value: authVM.currentUser?.email ?? "—", iconBg: Color(hex: "EBF3FF"))
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "questionmark.circle.fill", label: "Help & Support", iconBg: Color(hex: "F5F2EE"))
                        }

                        // MARK: - SIGN OUT / DELETE
                        cardSection {
                            SettingsRow(sfIcon: "rectangle.portrait.and.arrow.right", label: "Sign Out", isDestructive: true, showChevron: false) {
                                authVM.signOut()
                            }
                            Divider().padding(.leading, 58)
                            SettingsRow(sfIcon: "trash.fill", label: "Delete Account", isDestructive: true, showChevron: false) {
                                showDeleteAlert = true
                            }
                        }

                        Text("StoryMe v1.0.0")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "B8B3AC"))
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                    }
                    .frame(maxWidth: .infinity)
                }

                smTabBar(active: .profile, currentScreen: $currentScreen)
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                // TODO: implement account deletion
            }
        } message: {
            Text("Are you sure you want to permanently delete your account? This action cannot be undone.")
        }
    }

    // MARK: - Section Helpers

    // MARK: - Derived copy

    /// The header name comes from the child profile. "Family" rather than a
    /// parent role, since the app never asks who the account holder is.
    private var displayName: String {
        childVM.child.isComplete ? "\(childVM.child.name)'s Family" : "Set up your child"
    }

    private var childSubtitle: String {
        let stories = storyVM.savedStories.count
        let unit = stories == 1 ? "story" : "stories"
        guard childVM.child.isComplete else { return "Name, gender and birthday" }
        return "\(childVM.child.ageLabel) · \(stories) \(unit)"
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "7A756E"))
                .tracking(0.7)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 7)
    }

    private func cardSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color(hex: "FFFFFF"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
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

                Text(displayName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Color(hex: "1E1C1A"))

                Text("\(storyVM.savedStories.count) stories created")
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
                Button { currentScreen = .childProfile } label: {
                    HStack(spacing: 3) {
                        Image(systemName: childVM.child.isComplete ? "pencil" : "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(childVM.child.isComplete ? "Edit" : "Add").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "FF8C6B"))
                }
                .buttonStyle(.plain)
            }.padding(.horizontal, 20)

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: "FFD93D"), Color(hex: "FFBFA8")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "figure.child").font(.system(size: 22, weight: .medium)).foregroundColor(.white))
                    Circle().stroke(Color(hex: "FFD93D"), lineWidth: 3).frame(width: 56, height: 56)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(childVM.child.isComplete ? childVM.child.name : "Add your child")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
                    Text(childSubtitle).font(.system(size: 11)).foregroundColor(Color(hex: "7A756E"))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundColor(Color(hex: "B8B3AC"))
            }
            .padding(14).background(Color(hex: "FFFFFF")).cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3).padding(.horizontal, 18)
            .contentShape(Rectangle())
            .onTapGesture { currentScreen = .childProfile }
        }
        .padding(.top, 16).padding(.bottom, 14)
    }
}

#Preview("ContentView") {
    ContentView()
        .previewDevice("iPhone 15 Pro")
}
