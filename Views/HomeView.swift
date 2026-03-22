import SwiftUI

struct HomeView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

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

                smTabBar(active: .home, currentScreen: $currentScreen)
            }
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Good morning! 👋")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(Color(hex: "1E1C1A"))
                Text("What story shall we create?")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "7A756E"))
            }
            Spacer()
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD93D"), Color(hex: "FFBFA8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(Text("👩").font(.system(size: 20)))
                .shadow(color: Color(hex: "FFD93D").opacity(0.4), radius: 8, y: 3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD93D"), Color(hex: "FFE94A"), Color(hex: "FFF5A0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "FFD93D").opacity(0.35), radius: 12, y: 4)

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
                    .foregroundColor(Color(hex: "1E1C1A").opacity(0.6))

                Text("A new story\nfor little \(storyVM.childName)")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(Color(hex: "1E1C1A"))
                    .lineSpacing(2)

                Spacer().frame(height: 8)

                Button {
                    currentScreen = .photoUpload
                } label: {
                    HStack(spacing: 6) {
                        Text("Create Now")
                            .font(.system(size: 13, weight: .bold))
                        Text("→")
                    }
                    .foregroundColor(Color(hex: "E86D4A"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFFFFF"))
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
                .foregroundColor(Color(hex: "1E1C1A"))
            Text(isFree ? "Free" : "Pro")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(isFree ? Color(hex: "2A8A40") : Color(hex: "C89F00"))
        }
        .frame(minWidth: 82)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(hex: "FFFFFF"))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .opacity(isFree ? 1 : 0.7)
        .overlay(
            Group {
                if !isFree {
                    Text("🔒")
                        .font(.system(size: 7, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(hex: "FFD93D"))
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
                        bookCard(emoji: "🦁", title: "Emma's Brave Day", meta: "2 days ago",
                                 gradient: [Color(hex: "FFD93D"), Color(hex: "FF8C6B")])
                            .onTapGesture { openSampleStory(emoji: "🦁", title: "Emma's Brave Day", theme: "Being brave") }
                        bookCard(emoji: "🚀", title: "To the Stars", meta: "1 week ago",
                                 gradient: [Color(hex: "6BCB77"), Color(hex: "4D96FF")])
                            .onTapGesture { openSampleStory(emoji: "🚀", title: "To the Stars", theme: "Space adventure") }
                        bookCard(emoji: "🌊", title: "Ocean Friends", meta: "2 weeks ago",
                                 gradient: [Color(hex: "FFBFA8"), Color(hex: "FF5252")])
                            .onTapGesture { openSampleStory(emoji: "🌊", title: "Ocean Friends", theme: "Making friends") }
                    } else {
                        ForEach(storyVM.savedStories) { story in
                            bookCard(
                                emoji: story.pages.first?.emoji ?? "📖",
                                title: story.title,
                                meta: story.createdAt.formatted(.relative(presentation: .named)),
                                gradient: [Color(hex: "FFD93D"), Color(hex: "FF8C6B")]
                            )
                            .onTapGesture {
                                storyVM.currentStory = story
                                storyVM.currentPage = 0
                                currentScreen = .storybook
                            }
                        }
                    }

                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(hex: "E0DBD4"), style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(width: 120, height: 152)
                            .overlay(
                                VStack(spacing: 5) {
                                    Text("➕").font(.system(size: 26))
                                    Text("New Story")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color(hex: "B8B3AC"))
                                }
                            )
                    }
                    .onTapGesture { currentScreen = .photoUpload }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 12)
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
            "\"I was brave today,\" \(storyVM.childName) whispered. The stars twinkled.",
        ]
        let emojis = ["🌅", "🦋", "💪", "🪜", "🌳", "😄", "⭐", "🌙"]
        let pages = (0..<8).map { i in
            StoryPage(pageNumber: i + 1, text: sampleTexts[i], emoji: emojis[i])
        }
        storyVM.currentStory = Story(title: title, childName: storyVM.childName, theme: theme, pages: pages)
        storyVM.currentPage = 0
        currentScreen = .storybook
    }

    private func bookCard(emoji: String, title: String, meta: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 152)
                .overlay(Text(emoji).font(.system(size: 48)))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "1E1C1A"))
                .lineLimit(1)
                .padding(.top, 7)

            Text(meta)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "7A756E"))
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
                            .foregroundColor(Color(hex: "C89F00"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(hex: "FFFBD4"))
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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(hex: "1E1C1A"))
            Spacer()
            if let action {
                Text(action)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "FF8C6B"))
            }
        }
        .padding(.horizontal, 18)
    }
}

#Preview("HomeView") {
    HomeView(storyVM: StoryViewModel(), currentScreen: .constant(.home))
        .previewDevice("iPhone 15 Pro")
}
