import SwiftUI

struct StorybookView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var showOverlay = true
    @State private var showCompletion = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color(hex: "0D0C18").ignoresSafeArea()

            if let story = storyVM.currentStory {
                ZStack {
                    pageContent(story: story)

                    HStack(spacing: 0) {
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { storyVM.previousPage() }
                            .frame(maxWidth: .infinity)
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showOverlay.toggle() } }
                            .frame(width: UIScreen.main.bounds.width * 0.2)
                        Color.clear.contentShape(Rectangle())
                            .onTapGesture {
                                if storyVM.currentPage >= story.pages.count - 1 { withAnimation { showCompletion = true } }
                                else { storyVM.nextPage() }
                            }
                            .frame(maxWidth: .infinity)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { dragOffset = $0.translation.width }
                            .onEnded { v in
                                if v.translation.width < -50 {
                                    if storyVM.currentPage >= story.pages.count - 1 { withAnimation { showCompletion = true } }
                                    else { storyVM.nextPage() }
                                } else if v.translation.width > 50 { storyVM.previousPage() }
                                dragOffset = 0
                            }
                    )

                    if showOverlay {
                        VStack {
                            topBar(story: story)
                            Spacer()
                            bottomBar(story: story)
                        }.transition(.opacity)
                    }
                }

                if showCompletion {
                    completionOverlay(story: story).transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showOverlay = false } }
        }
    }

    private func pageContent(story: Story) -> some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [Color(hex: "1A1042"), Color(hex: "0D0C18")], startPoint: .top, endPoint: .bottom)

                if storyVM.currentPage < story.pages.count {
                    Text(story.pages[storyVM.currentPage].emoji)
                        .font(.system(size: 90))
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                        .id(storyVM.currentPage)
                }

                if showOverlay && storyVM.currentPage == 0 {
                    HStack {
                        VStack(spacing: 4) { Text("◀").font(.system(size: 22)).foregroundColor(.white.opacity(0.5)); Text("Prev").font(.system(size: 9)).foregroundColor(.white.opacity(0.35)) }
                        Spacer()
                        Text("Tap to turn pages").font(.system(size: 10, weight: .regular)).foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 14).padding(.vertical, 5).background(Color.white.opacity(0.15)).clipShape(Capsule())
                        Spacer()
                        VStack(spacing: 4) { Text("▶").font(.system(size: 22)).foregroundColor(.white.opacity(0.5)); Text("Next").font(.system(size: 9)).foregroundColor(.white.opacity(0.35)) }
                    }.padding(.horizontal, 20)
                }
            }.frame(maxHeight: .infinity)

            if storyVM.currentPage < story.pages.count {
                let page = story.pages[storyVM.currentPage]
                VStack(alignment: .leading, spacing: 6) {
                    Text("Page \(page.pageNumber) of \(story.pages.count)")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.4))
                    Text(page.text).font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineSpacing(6)
                        .id(storyVM.currentPage).transition(.opacity)
                }
                .padding(.horizontal, 18).padding(.top, 20).padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [Color(hex: "0D0C18").opacity(0.96), Color(hex: "0D0C18").opacity(0.7), .clear],
                                           startPoint: .bottom, endPoint: .top))
            }
        }
    }

    private func topBar(story: Story) -> some View {
        HStack {
            Button { currentScreen = .home; storyVM.saveStory() } label: {
                Text("✕").font(.system(size: 16)).foregroundColor(.white)
                    .frame(width: 32, height: 32).background(Color.white.opacity(0.15)).clipShape(Circle())
            }
            Spacer()
            Text(story.title).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Spacer()
            Text("···").font(.system(size: 18)).foregroundColor(.white.opacity(0.7))
        }
        .padding(.horizontal, 16).padding(.top, 50).padding(.bottom, 12)
        .background(LinearGradient(colors: [Color(hex: "0D0C18").opacity(0.85), .clear], startPoint: .top, endPoint: .bottom))
    }

    private func bottomBar(story: Story) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<story.pages.count, id: \.self) { i in
                    if i == storyVM.currentPage {
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "FFD93D")).frame(width: 18, height: 6)
                    } else {
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 6, height: 6)
                    }
                }
            }
            HStack(spacing: 24) {
                readerAction(icon: storyVM.currentStory?.isFavorite == true ? "♥" : "♡", label: "Save") { storyVM.toggleFavorite() }
                readerAction(icon: "↗", label: "Share") { currentScreen = .share }
                readerAction(icon: "🔊", label: "Read") {}
                readerAction(icon: "⟳", label: "Redo") {}
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(Color(hex: "0D0C18").opacity(0.9))
    }

    private func readerAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(icon).font(.system(size: 20))
                Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private func completionOverlay(story: Story) -> some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("✨").font(.system(size: 48))
                Text("The End!").font(.system(size: 32, weight: .black)).foregroundColor(.white)
                Text(story.title).font(.system(size: 16)).foregroundColor(.white.opacity(0.7))
                Spacer().frame(height: 8)
                Button { storyVM.currentPage = 0; showCompletion = false } label: {
                    Text("Read Again").font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "FF8C6B"))
                        .frame(maxWidth: .infinity).frame(height: 50).background(Color.white).clipShape(Capsule())
                }
                Button { storyVM.saveStory(); currentScreen = .share } label: {
                    Text("Save & Share").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(LinearGradient(colors: [Color(hex: "FF8C6B"), Color(hex: "E86D4A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(Capsule()).shadow(color: Color(hex: "FF8C6B").opacity(0.4), radius: 10, y: 4)
                }
                Button { storyVM.resetForNewStory(); currentScreen = .home } label: {
                    Text("Create Another Story").font(.system(size: 13, weight: .regular)).foregroundColor(.white.opacity(0.6)).frame(height: 40)
                }
            }.padding(.horizontal, 40)
        }
    }
}
