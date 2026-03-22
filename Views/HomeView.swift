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
            }

            tabBar
        }
        .background(Color.smBackground.ignoresSafeArea())
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good morning \u{1F44B}")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.smTextPrimary)
                Text("What story shall we create?")
                    .font(.system(size: 12))
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
                .frame(width: 42, height: 42)
                .overlay(Text("👩").font(.system(size: 20)))
                .shadow(color: .smYellow400.opacity(0.4), radius: 8, y: 3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [.smYellow400, .smYellow300, .smYellow200],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .smYellow400.opacity(0.35), radius: 12, y: 4)

            // Decorative book emoji
            HStack {
                Spacer()
                Text("📖")
                    .font(.system(size: 80))
                    .opacity(0.25)
                    .offset(x: -8)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Ready to create ✨")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.smTextPrimary.opacity(0.6))

                Text("A new story\nfor little \(storyVM.childName)")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.smTextPrimary)
                    .lineSpacing(2)

                Spacer().frame(height: 8)

                Button {
                    currentScreen = .photoUpload
                } label: {
                    HStack(spacing: 6) {
                        Text("Create Now")
                            .font(.system(size: 13, weight: .heavy))
                        Text("→")
                    }
                    .foregroundColor(.smCoral500)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
            }
            .padding(20)
        }
        .frame(height: 160)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    // MARK: - Templates
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "📚 Story Templates", action: "See all →")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    templateChip(emoji: "🏫", name: "First Day", isFree: true)
                    templateChip(emoji: "🦁", name: "Be Brave", isFree: true)
                    templateChip(emoji: "🌙", name: "Bedtime", isFree: false)
                    templateChip(emoji: "🎂", name: "Birthday", isFree: false)
                    templateChip(emoji: "🌈", name: "Rainbow", isFree: false)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 12)
    }

    private func templateChip(emoji: String, name: String, isFree: Bool) -> some View {
        VStack(spacing: 5) {
            Text(emoji).font(.system(size: 26))
            Text(name)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.smTextPrimary)
            Text(isFree ? "Free" : "Pro")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isFree ? .smGreen600 : .smYellow600)
        }
        .frame(minWidth: 82)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .opacity(isFree ? 1 : 0.7)
        .overlay(
            Group {
                if !isFree {
                    Text("🔒")
                        .font(.system(size: 7, weight: .heavy))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.smYellow400)
                        .cornerRadius(5)
                        .offset(x: 4, y: -4)
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
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Recent Books", action: "See all →")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if storyVM.savedStories.isEmpty {
                        // Sample books for demo — tappable to open reader
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
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.smNeutral200, style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(width: 120, height: 152)
                            .overlay(
                                VStack(spacing: 5) {
                                    Text("➕").font(.system(size: 26))
                                    Text("New Story")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.smNeutral300)
                                }
                            )
                    }
                    .onTapGesture {
                        currentScreen = .photoUpload
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 12)
    }

    /// Open a demo sample story in the reader
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
                .overlay(Text(emoji).font(.system(size: 48)))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.smTextPrimary)
                .lineLimit(1)
                .padding(.top, 7)

            Text(meta)
                .font(.system(size: 10))
                .foregroundColor(.smTextSecondary)
                .padding(.top, 1)
        }
        .frame(width: 120)
    }

    // MARK: - Themes
    private var themesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Explore Themes")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(storyVM.themeChips, id: \.1) { emoji, name in
                        Text("\(emoji) \(name)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.smYellow600)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.smYellow100)
                            .clipShape(Capsule())
                            .onTapGesture {
                                storyVM.selectThemeChip(name)
                                currentScreen = .photoUpload
                            }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, action: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.smTextPrimary)
            Spacer()
            if let action {
                Text(action)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.smCoral400)
            }
        }
        .padding(.horizontal, 18)
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
        .padding(.bottom, 24)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.05), radius: 1, y: -1)
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
