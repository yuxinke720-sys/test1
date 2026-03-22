import SwiftUI

struct MyBooksView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button {
                    currentScreen = .home
                } label: {
                    Text("←")
                        .font(.system(size: 22))
                        .foregroundColor(.smCoral400)
                        .frame(width: 36)
                }
                Spacer()
                Text("My Books")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.smTextPrimary)
                Spacer()
                Color.clear.frame(width: 36)
            }
            .frame(height: 48)
            .padding(.horizontal, 18)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Stats row
                    HStack(spacing: 12) {
                        statBadge(value: "\(allBooks.count)", label: "Stories", color: .smYellow400)
                        statBadge(value: "\(allBooks.filter { $0.isFavorite }.count)", label: "Favorites", color: .smCoral400)
                        statBadge(value: totalPages, label: "Pages", color: .smGreen400)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                    if allBooks.isEmpty {
                        emptyState
                    } else {
                        // Book grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(allBooks) { book in
                                bookGridCard(book: book)
                                    .onTapGesture {
                                        storyVM.currentStory = book
                                        storyVM.currentPage = 0
                                        currentScreen = .storybook
                                    }
                            }
                        }
                        .padding(.horizontal, 18)
                    }

                    Spacer().frame(height: 20)
                }
            }

            tabBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.smBackground.ignoresSafeArea(edges: .all))
    }

    // MARK: - Tab Bar
    private var tabBar: some View {
        HStack {
            tabItem(icon: "🏠", label: "Home", isActive: false) { currentScreen = .home }
            tabItem(icon: "✨", label: "Create", isActive: false) { currentScreen = .photoUpload }
            tabItem(icon: "📚", label: "My Books", isActive: true)
            tabItem(icon: "👤", label: "Profile", isActive: false) { currentScreen = .profile }
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

    // All books: saved + demo samples
    private var allBooks: [Story] {
        if storyVM.savedStories.isEmpty {
            return sampleBooks
        }
        return storyVM.savedStories
    }

    private var totalPages: String {
        let count = allBooks.reduce(0) { $0 + $1.pages.count }
        return "\(count)"
    }

    // MARK: - Stat Badge
    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.smTextPrimary)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.smTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.15), radius: 8, y: 3)
    }

    // MARK: - Book Grid Card
    private func bookGridCard(book: Story) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: gradientForStyle(book.style),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay(
                    VStack(spacing: 6) {
                        Text(book.pages.first?.emoji ?? "📖")
                            .font(.system(size: 44))
                        if book.isFavorite {
                            Text("♥")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.smCoral400)
                                .clipShape(Circle())
                        }
                    }
                )
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.smTextPrimary)
                    .lineLimit(1)
                Text("\(book.pages.count) pages · \(book.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10))
                    .foregroundColor(.smTextSecondary)
                    .lineLimit(1)
            }
            .padding(.top, 8)
            .padding(.horizontal, 2)
        }
    }

    private func gradientForStyle(_ style: StoryStyle) -> [Color] {
        switch style {
        case .warmCozy: return [.smYellow400, .smCoral400]
        case .adventure: return [.smGreen400, .smBlue400]
        case .fantasy: return [.smCoral300, .smYellow300]
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)

            Text("📚")
                .font(.system(size: 72))

            Text("No stories yet")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.smTextPrimary)

            Text("Create your first story and it\nwill appear here!")
                .font(.system(size: 14))
                .foregroundColor(.smTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                currentScreen = .photoUpload
            } label: {
                Text("Create a Story ✨")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.smCoral400, .smCoral500],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .smCoral400.opacity(0.35), radius: 10, y: 4)
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Sample Data
    private var sampleBooks: [Story] {
        [
            Story(
                title: "Emma's Brave Day",
                childName: "Emma",
                theme: "Being brave",
                style: .warmCozy,
                pages: (1...10).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "🦁") },
                createdAt: Date().addingTimeInterval(-86400 * 2),
                isFavorite: true
            ),
            Story(
                title: "To the Stars",
                childName: "Emma",
                theme: "Space adventure",
                style: .adventure,
                pages: (1...8).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "🚀") },
                createdAt: Date().addingTimeInterval(-86400 * 7)
            ),
            Story(
                title: "Ocean Friends",
                childName: "Emma",
                theme: "Making friends",
                style: .fantasy,
                pages: (1...12).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "🌊") },
                createdAt: Date().addingTimeInterval(-86400 * 14)
            ),
            Story(
                title: "The Magic Garden",
                childName: "Emma",
                theme: "Nature",
                style: .fantasy,
                pages: (1...10).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "🌸") },
                createdAt: Date().addingTimeInterval(-86400 * 21),
                isFavorite: true
            ),
        ]
    }
}

#Preview {
    MyBooksView(
        storyVM: StoryViewModel(),
        currentScreen: .constant(.myBooks)
    )
}
