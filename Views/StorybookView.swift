import SwiftUI

struct StorybookView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var showOverlay = true
    @State private var showCompletion = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(hex: "F5EDD6").ignoresSafeArea()

                if let story = storyVM.currentStory {
                    ZStack {
                        pageContent(story: story, geo: geo)

                        HStack(spacing: 0) {
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture { storyVM.previousPage() }
                                .frame(maxWidth: .infinity)
                            Color.clear.contentShape(Rectangle())
                                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showOverlay.toggle() } }
                                .frame(width: geo.size.width * 0.2)
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
                            VStack(spacing: 0) {
                                topBar(story: story, geo: geo)
                                Spacer()
                                bottomBar(story: story)
                            }
                            .transition(.opacity)
                            .ignoresSafeArea(edges: .top)
                        }
                    }

                    if showCompletion {
                        completionOverlay(story: story, geo: geo).transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { withAnimation { showOverlay = false } }
        }
    }

    // MARK: - Exit Helper

    private func exitReading() {
        storyVM.resetPageIfFinished()
        storyVM.saveStory()
        currentScreen = storyVM.previousScreen
    }

    // MARK: - Page Content

    private func pageContent(story: Story, geo: GeometryProxy) -> some View {
        let imageHeight = geo.size.height * 0.55
        let textHeight = geo.size.height * 0.45

        return VStack(spacing: 0) {
            // — Image area (55%) —
            ZStack {
                LinearGradient(colors: [Color(hex: "EDE0C4"), Color(hex: "F5EDD6")], startPoint: .top, endPoint: .bottom)

                if storyVM.currentPage < story.pages.count {
                    let page = story.pages[storyVM.currentPage]
                    Group {
                        if let data = page.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .interpolation(.high)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: imageHeight)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [.clear, Color(hex: "F5EDD6").opacity(0.2), Color(hex: "F5EDD6").opacity(0.95)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    LinearGradient(
                                        colors: [Color(hex: "F5EDD6").opacity(0.6), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        } else {
                            Image(systemName: page.emoji)
                                .font(.system(size: 72, weight: .light))
                                .foregroundColor(Color(hex: "2C2417").opacity(0.5))
                        }
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
                    .id(storyVM.currentPage)
                }

                if showOverlay && storyVM.currentPage == 0 {
                    HStack {
                        VStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 20, weight: .medium)).foregroundColor(Color(hex: "2C2417").opacity(0.4)); Text("Prev").font(.system(size: 9)).foregroundColor(Color(hex: "2C2417").opacity(0.3)) }
                        Spacer()
                        Text("Tap to turn pages").font(.system(size: 10, weight: .regular)).foregroundColor(Color(hex: "2C2417").opacity(0.5))
                            .padding(.horizontal, 14).padding(.vertical, 5).background(Color(hex: "2C2417").opacity(0.08)).clipShape(Capsule())
                        Spacer()
                        VStack(spacing: 4) { Image(systemName: "chevron.right").font(.system(size: 20, weight: .medium)).foregroundColor(Color(hex: "2C2417").opacity(0.4)); Text("Next").font(.system(size: 9)).foregroundColor(Color(hex: "2C2417").opacity(0.3)) }
                    }.padding(.horizontal, 20)
                }
            }
            .frame(height: imageHeight)

            // — Text panel (45%) —
            if storyVM.currentPage < story.pages.count {
                let page = story.pages[storyVM.currentPage]
                VStack(alignment: .leading, spacing: 0) {
                    Text("Page \(page.pageNumber) of \(story.pages.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "2C2417").opacity(0.6))
                    Spacer().frame(height: 10)
                    ScrollView(.vertical, showsIndicators: false) {
                        Text(page.text)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "2C2417"))
                            .lineSpacing(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(storyVM.currentPage)
                            .transition(.opacity)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 28)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, minHeight: textHeight * 0.5, maxHeight: textHeight, alignment: .topLeading)
                .background(
                    ZStack {
                        Color(hex: "F5EDD6")
                        LinearGradient(
                            colors: [Color(hex: "EDE0C4").opacity(0.4), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
            }
        }
        .padding(.top, geo.safeAreaInsets.top + 8)
    }

    // MARK: - Reader Top Bar

    private func topBar(story: Story, geo: GeometryProxy) -> some View {
        HStack {
            Button { exitReading() } label: {
                Image(systemName: "xmark").font(.system(size: 14, weight: .medium)).foregroundColor(Color(hex: "2C2417"))
                    .frame(width: 32, height: 32).background(Color(hex: "2C2417").opacity(0.08)).clipShape(Circle())
            }
            Spacer()
            Text(story.title).font(.system(size: 14, weight: .bold)).foregroundColor(Color(hex: "2C2417"))
            Spacer()
            Image(systemName: "ellipsis").font(.system(size: 18, weight: .medium)).foregroundColor(Color(hex: "2C2417").opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.top, geo.safeAreaInsets.top + 8)
        .padding(.bottom, 12)
        .background(
            LinearGradient(colors: [Color(hex: "EDE0C4").opacity(0.9), .clear], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Reader Bottom Bar

    private func bottomBar(story: Story) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<story.pages.count, id: \.self) { i in
                    if i == storyVM.currentPage {
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "FFD93D")).frame(width: 18, height: 6)
                    } else {
                        Circle().fill(Color(hex: "2C2417").opacity(0.15)).frame(width: 6, height: 6)
                    }
                }
            }
            HStack(spacing: 24) {
                readerAction(icon: storyVM.currentStory?.isFavorite == true ? "heart.fill" : "heart", label: "Save") { storyVM.toggleFavorite() }
                readerAction(icon: "square.and.arrow.up", label: "Share") { currentScreen = .share }
                readerAction(icon: "speaker.wave.2.fill", label: "Read") {}
                readerAction(icon: "arrow.counterclockwise", label: "Redo") {}
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .background(Color(hex: "F5EDD6").opacity(0.97))
    }

    private func readerAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundColor(Color(hex: "2C2417"))
                Text(label).font(.system(size: 8)).foregroundColor(Color(hex: "2C2417").opacity(0.4))
            }
        }
    }

    // MARK: - Completion Overlay ("The End")

    private func completionOverlay(story: Story, geo: GeometryProxy) -> some View {
        ZStack(alignment: .topTrailing) {
            // — Background —
            if let lastPage = story.pages.last,
               let data = lastPage.imageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color(hex: "FFFEF5").opacity(0.0), Color(hex: "FFFEF5").opacity(0.97)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [Color(hex: "FFF8E7"), Color(hex: "FFFEF5")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // — Close button (top right) —
            Button {
                showCompletion = false
                exitReading()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "5A5550"))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: "1E1C1A").opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(.top, geo.safeAreaInsets.top + 8)
            .padding(.trailing, 20)

            // — Center content —
            VStack(spacing: 0) {
                Spacer()

                // Icon stack
                ZStack {
                    Image(systemName: "book.fill").font(.system(size: 44, weight: .light)).foregroundColor(Color(hex: "FFD93D").opacity(0.5)).offset(x: -18, y: 8)
                    Image(systemName: "sparkles").font(.system(size: 52, weight: .medium)).foregroundColor(Color(hex: "FF8C6B"))
                    Image(systemName: "star.fill").font(.system(size: 22, weight: .medium)).foregroundColor(Color(hex: "FFD93D").opacity(0.8)).offset(x: 28, y: -20)
                }
                .padding(.bottom, 20)

                // Title
                Text("The End")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "1E1C1A"))
                    .padding(.bottom, 8)

                // Subtitle
                Text("Every story makes you a little braver.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(Color(hex: "7A756E"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Breathing room
                Spacer().frame(height: 60)

                // Buttons
                VStack(spacing: 12) {
                    // Read Again
                    Button { storyVM.currentPage = 0; showCompletion = false } label: {
                        Text("Read Again")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color(hex: "FF8C6B"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Save & Share
                    Button { storyVM.saveStory(); currentScreen = .share } label: {
                        Text("Save & Share")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color(hex: "4A7C59"))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Create Another Story
                    Button {
                        storyVM.resetForNewStory()
                        currentScreen = .home
                    } label: {
                        Text("Create Another Story")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundColor(Color(hex: "7A756E"))
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}
