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
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                )
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

            // Decorative SF Symbol
            HStack {
                Spacer()
                Image(systemName: "book.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.smTextPrimary.opacity(0.1))
                    .offset(x: -16, y: -10)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to create")
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
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .semibold))
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
            sectionHeader(title: "Story Templates", sfIcon: "books.vertical.fill", action: "See all")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    templateChip(sfIcon: "building.columns", name: "First Day", isFree: true)
                    templateChip(sfIcon: "flame.fill", name: "Be Brave", isFree: true)
                    templateChip(sfIcon: "moon.stars.fill", name: "Bedtime", isFree: false)
                    templateChip(sfIcon: "gift.fill", name: "Birthday", isFree: false)
                    templateChip(sfIcon: "rainbow", name: "Rainbow", isFree: false)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 16)
    }

    private func templateChip(sfIcon: String, name: String, isFree: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: sfIcon)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(isFree ? .smCoral400 : .smNeutral300)
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
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.smNeutral500)
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
            sectionHeader(title: "Recent Books", sfIcon: nil, action: "See all")

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
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.smNeutral300)
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
            sectionHeader(title: "Explore Themes", sfIcon: nil)

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
    private func sectionHeader(title: String, sfIcon: String? = nil, action: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let sfIcon {
                Image(systemName: sfIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.smCoral400)
            }
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.smTextPrimary)
            Spacer()
            if let action {
                HStack(spacing: 3) {
                    Text(action)
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.smCoral400)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack {
            tabItem(sfIcon: "house.fill", label: "Home", isActive: true)
            tabItem(sfIcon: "sparkles", label: "Create", isActive: false) {
                currentScreen = .photoUpload
            }
            tabItem(sfIcon: "books.vertical.fill", label: "My Books", isActive: false) {
                currentScreen = .myBooks
            }
            tabItem(sfIcon: "person.fill", label: "Profile", isActive: false) {
                currentScreen = .profile
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 26)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.04), radius: 1, y: -1)
        )
    }

    private func tabItem(sfIcon: String, label: String, isActive: Bool, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: sfIcon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .smYellow600 : .smNeutral300)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
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
