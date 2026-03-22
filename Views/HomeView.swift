import SwiftUI

struct HomeView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    heroBanner
                    templatesSection
                    recentBooksSection
                    themesSection
                }
                .frame(maxWidth: .infinity)
            }

            tabBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "FFF9F0").ignoresSafeArea())
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Good morning!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.smTextPrimary)
                Text("What story shall we create?")
                    .font(.system(size: 13))
                    .foregroundColor(.smTextSecondary)
            }
            Spacer()
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.smYellow400, .smCoral300],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(Text("👩").font(.system(size: 18)))
                .shadow(color: .smYellow400.opacity(0.3), radius: 6, y: 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [.smYellow400, .smYellow300, .smYellow200],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .smYellow400.opacity(0.25), radius: 10, y: 4)

            HStack {
                Spacer()
                Text("📖")
                    .font(.system(size: 70))
                    .opacity(0.2)
                    .offset(x: -12, y: -8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to create ✨")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.smTextPrimary.opacity(0.55))

                Text("A new story\nfor little \(storyVM.childName)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.smTextPrimary)
                    .lineSpacing(3)

                Spacer().frame(height: 6)

                Button {
                    currentScreen = .photoUpload
                } label: {
                    HStack(spacing: 5) {
                        Text("Create Now")
                            .font(.system(size: 13, weight: .semibold))
                        Text("→")
                    }
                    .foregroundColor(.smCoral500)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
            }
            .padding(20)
        }
        .frame(height: 165)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Templates
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "📚 Story Templates", action: "See all →")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    templateChip(emoji: "🏫", name: "First Day", isFree: true)
                    templateChip(emoji: "🦁", name: "Be Brave", isFree: true)
                    templateChip(emoji: "🌙", name: "Bedtime", isFree: false)
                    templateChip(emoji: "🎂", name: "Birthday", isFree: false)
                    templateChip(emoji: "🌈", name: "Rainbow", isFree: false)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 16)
    }

    private func templateChip(emoji: String, name: String, isFree: Bool) -> some View {
        VStack(spacing: 6) {
            Text(emoji).font(.system(size: 26))
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.smTextPrimary)
            Text(isFree ? "Free" : "Pro")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(isFree ? .smGreen600 : .smNeutral300)
        }
        .frame(minWidth: 82)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .opacity(isFree ? 1 : 0.65)
        .overlay(
            Group {
                if !isFree {
                    Text("🔒")
                        .font(.system(size: 8))
                        .padding(4)
                        .background(Color.smNeutral100)
                        .clipShape(Circle())
                        .offset(x: -4, y: 4)
                }
            },
            alignment: .topTrailing
        )
        .onTapGesture {
            if isFree {
                storyVM.theme = "\(storyVM.childName) and the \(name) story"
                currentScreen = .photoUpload
            }
        }
    }

    // MARK: - Recent Books
    private var recentBooksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Recent Books", action: "See all →")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if storyVM.savedStories.isEmpty {
                        bookCard(emoji: "🦁", title: "Emma's Brave Day", meta: "2 days ago", gradient: [.smYellow400, .smCoral400])
                            .onTapGesture { openSampleStory(emoji: "🦁", title: "Emma's Brave Day", theme: "Being brave") }
                        bookCard(emoji: "🚀", title: "To the Stars", meta: "1 week ago", gradient: [.smGreen400, .smBlue400])
                            .onTapGesture { openSampleStory(emoji: "🚀", title: "To the Stars", theme: "Space adventure") }
                        bookCard(emoji: "🌊", title: "Ocean Friends", meta: "2 weeks ago", gradient: [.smCoral300, .smRed400])
                            .onTapGesture { openSampleStory(emoji: "🌊", title: "Ocean Friends", theme: "Making friends") }
                    } else {
                        ForEach(storyVM.savedStories) { story in
                            bookCard(
                                emoji: story.pages.first?.emoji ?? "📖",
                                title: story.title,
                                meta: story.createdAt.formatted(.relative(presentation: .named)),
                                gradient: [.smYellow400, .smCoral400]
                            )
                            .onTapGesture {
                                storyVM.currentStory = story
                                storyVM.currentPage = 0
                                currentScreen = .storybook
                            }
                        }
                    }

                    // Add new card
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.smNeutral200, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .frame(width: 120, height: 152)
                        .overlay(
                            VStack(spacing: 6) {
                                Text("➕").font(.system(size: 20))
                                Text("New Story")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.smNeutral300)
                            }
                        )
                        .onTapGesture {
                            currentScreen = .photoUpload
                        }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 16)
    }

    private func openSampleStory(emoji: String, title: String, theme: String) {
        let sampleTexts = [
            "Once upon a time, \(storyVM.childName) woke up to a beautiful sunny morning.",
            "\(storyVM.childName) felt butterflies in their tummy. Today was going to be special!",
            "\"I can do this!\" \(storyVM.childName) said, taking a deep breath.",
            "Step by step, \(storyVM.childName) moved forward with a big smile.",
            "The world around them was full of color and wonder.",
            "\(storyVM.childName) laughed out loud — this was the best day ever!",
            "When the adventure was over, \(storyVM.childName) felt proud.",
            "\"I was brave today,\" \(storyVM.childName) whispered. The stars twinkled as if to say, \"Yes, you were.\"",
        ]
        let emojis = ["🌅", "🦋", "💪", "🪜", "🌳", "😄", "⭐", "🌙"]
        let pages = (0..<8).map { i in
            StoryPage(pageNumber: i + 1, text: sampleTexts[i], emoji: emojis[i])
        }
        storyVM.currentStory = Story(
            title: title,
            childName: storyVM.childName,
            theme: theme,
            pages: pages
        )
        storyVM.currentPage = 0
        currentScreen = .storybook
    }

    private func bookCard(emoji: String, title: String, meta: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 120, height: 152)
                .overlay(Text(emoji).font(.system(size: 44)))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.smTextPrimary)
                .lineLimit(1)
                .padding(.top, 8)

            Text(meta)
                .font(.system(size: 10))
                .foregroundColor(.smTextSecondary)
                .padding(.top, 2)
        }
        .frame(width: 120)
    }

    // MARK: - Themes
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Explore Themes")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(storyVM.themeChips, id: \.1) { emoji, name in
                        Text("\(emoji) \(name)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.smYellow600)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.smYellow100)
                            .clipShape(Capsule())
                            .onTapGesture {
                                storyVM.selectThemeChip(name)
                                currentScreen = .photoUpload
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, action: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.smTextPrimary)
            Spacer()
            if let action {
                Text(action)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.smCoral400)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack {
            tabItem(icon: "🏠", label: "Home", isActive: true)
            tabItem(icon: "✨", label: "Create", isActive: false) {
                currentScreen = .photoUpload
            }
            tabItem(icon: "📚", label: "My Books", isActive: false) {
                currentScreen = .myBooks
            }
            tabItem(icon: "👤", label: "Profile", isActive: false) {
                currentScreen = .profile
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 34)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.05), radius: 1, y: -1)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabItem(icon: String, label: String, isActive: Bool, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 3) {
                Text(icon).font(.system(size: 22))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isActive ? .smYellow600 : .smNeutral300)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    HomeView(
        storyVM: StoryViewModel(),
        currentScreen: .constant(.home)
    )
}
