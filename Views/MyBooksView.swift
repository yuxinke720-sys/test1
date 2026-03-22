import SwiftUI

struct MyBooksView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button { currentScreen = .home } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(Color(hex: "FF8C6B"))
                            .frame(width: 36)
                    }
                    Spacer()
                    Text("My Books").font(.system(size: 17, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
                    Spacer()
                    Color.clear.frame(width: 36)
                }.frame(height: 48).padding(.horizontal, 18)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Stats
                        HStack(spacing: 12) {
                            statBadge(icon: "book.fill", value: "\(allBooks.count)", label: "Stories", color: Color(hex: "FFD93D"))
                            statBadge(icon: "heart.fill", value: "\(allBooks.filter { $0.isFavorite }.count)", label: "Favorites", color: Color(hex: "FF8C6B"))
                            statBadge(icon: "doc.text.fill", value: totalPages, label: "Pages", color: Color(hex: "6BCB77"))
                        }.padding(.horizontal, 18).padding(.top, 8)

                        if allBooks.isEmpty { emptyState }
                        else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(allBooks) { book in
                                    bookGridCard(book: book).onTapGesture {
                                        storyVM.currentStory = book; storyVM.currentPage = 0; currentScreen = .storybook
                                    }
                                }
                            }.padding(.horizontal, 18)
                        }
                        Spacer().frame(height: 20)
                    }.frame(maxWidth: .infinity)
                }

                smTabBar(active: .myBooks, currentScreen: $currentScreen)
            }
        }
    }

    private var allBooks: [Story] { storyVM.savedStories.isEmpty ? sampleBooks : storyVM.savedStories }
    private var totalPages: String { "\(allBooks.reduce(0) { $0 + $1.pages.count })" }

    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
            Text(value).font(.system(size: 22, weight: .black)).foregroundColor(Color(hex: "1E1C1A"))
            Text(label).font(.system(size: 11, weight: .regular)).foregroundColor(Color(hex: "7A756E"))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color(hex: "FFFFFF")).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.3), lineWidth: 1.5))
        .shadow(color: color.opacity(0.15), radius: 8, y: 3)
    }

    private func bookGridCard(book: Story) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: gradientForStyle(book.style), startPoint: .topLeading, endPoint: .bottomTrailing))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay(VStack(spacing: 6) {
                    Image(systemName: sfIconForStyle(book.style))
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    if book.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color(hex: "FF8C6B"))
                            .clipShape(Circle())
                    }
                })
                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title).font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "1E1C1A")).lineLimit(1)
                Text("\(book.pages.count) pages · \(book.createdAt.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 10)).foregroundColor(Color(hex: "7A756E")).lineLimit(1)
            }.padding(.top, 8).padding(.horizontal, 2)
        }
    }

    private func sfIconForStyle(_ style: StoryStyle) -> String {
        switch style {
        case .warmCozy: return "pawprint.fill"
        case .adventure: return "airplane"
        case .fantasy: return "sparkles"
        }
    }

    private func gradientForStyle(_ style: StoryStyle) -> [Color] {
        switch style {
        case .warmCozy: return [Color(hex: "FFD93D"), Color(hex: "FF8C6B")]
        case .adventure: return [Color(hex: "6BCB77"), Color(hex: "4D96FF")]
        case .fantasy: return [Color(hex: "FFBFA8"), Color(hex: "FFE94A")]
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(Color(hex: "FFD93D"))
            Text("No stories yet").font(.system(size: 22, weight: .black)).foregroundColor(Color(hex: "1E1C1A"))
            Text("Create your first story and it\nwill appear here!")
                .font(.system(size: 14)).foregroundColor(Color(hex: "7A756E")).multilineTextAlignment(.center).lineSpacing(4)
            Button { currentScreen = .photoUpload } label: {
                HStack(spacing: 6) {
                    Text("Create a Story")
                    Image(systemName: "sparkles")
                }
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 32).frame(height: 50)
                .background(LinearGradient(colors: [Color(hex: "FF8C6B"), Color(hex: "E86D4A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Capsule()).shadow(color: Color(hex: "FF8C6B").opacity(0.35), radius: 10, y: 4)
            }.padding(.top, 8)
            Spacer()
        }
    }

    private var sampleBooks: [Story] {
        [
            Story(title: "Emma's Brave Day", childName: "Emma", theme: "Being brave", style: .warmCozy,
                  pages: (1...10).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "pawprint.fill") },
                  createdAt: Date().addingTimeInterval(-86400 * 2), isFavorite: true),
            Story(title: "To the Stars", childName: "Emma", theme: "Space adventure", style: .adventure,
                  pages: (1...8).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "airplane") },
                  createdAt: Date().addingTimeInterval(-86400 * 7)),
            Story(title: "Ocean Friends", childName: "Emma", theme: "Making friends", style: .fantasy,
                  pages: (1...12).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "water.waves") },
                  createdAt: Date().addingTimeInterval(-86400 * 14)),
            Story(title: "The Magic Garden", childName: "Emma", theme: "Nature", style: .fantasy,
                  pages: (1...10).map { StoryPage(pageNumber: $0, text: "Page \($0)", emoji: "leaf.fill") },
                  createdAt: Date().addingTimeInterval(-86400 * 21), isFavorite: true),
        ]
    }
}
