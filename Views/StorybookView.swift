import SwiftUI

struct StorybookView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var showOverlay = true
    @State private var showCompletion = false
    @State private var dragOffset: CGFloat = 0
    @State private var particlePhase: CGFloat = 0

    // Palette per page — cycles through moods
    private let pagePalettes: [(top: String, bottom: String, accent: String)] = [
        ("1A1042", "0D0C18", "FFD93D"),   // deep indigo / yellow
        ("0C2340", "0A1628", "4D96FF"),   // navy / blue
        ("2D1B3D", "1A0F26", "E8A0FF"),   // plum / lavender
        ("0B2B26", "061A16", "6BCB77"),   // forest / green
        ("3B1A0A", "1E0D05", "FF8C6B"),   // warm umber / coral
        ("1A1042", "0D0C18", "FFD93D"),
        ("0C2340", "0A1628", "4D96FF"),
        ("2D1B3D", "1A0F26", "E8A0FF"),
        ("0B2B26", "061A16", "6BCB77"),
        ("3B1A0A", "1E0D05", "FF8C6B"),
        ("1A1042", "0D0C18", "FFD93D"),
        ("0C2340", "0A1628", "4D96FF"),
    ]

    private var currentPalette: (top: String, bottom: String, accent: String) {
        pagePalettes[storyVM.currentPage % pagePalettes.count]
    }

    var body: some View {
        ZStack {
            // Animated background that shifts per page
            LinearGradient(
                colors: [Color(hex: currentPalette.top), Color(hex: currentPalette.bottom)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.8), value: storyVM.currentPage)

            if let story = storyVM.currentStory {
                ZStack {
                    pageContent(story: story)

                    // Tap zones
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { storyVM.previousPage() }
                            .frame(maxWidth: .infinity)

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showOverlay.toggle()
                                }
                            }
                            .frame(width: UIScreen.main.bounds.width * 0.2)

                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if storyVM.currentPage >= story.pages.count - 1 {
                                    withAnimation(.spring(response: 0.5)) { showCompletion = true }
                                } else {
                                    storyVM.nextPage()
                                }
                            }
                            .frame(maxWidth: .infinity)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in dragOffset = value.translation.width }
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    if storyVM.currentPage >= story.pages.count - 1 {
                                        withAnimation(.spring(response: 0.5)) { showCompletion = true }
                                    } else {
                                        storyVM.nextPage()
                                    }
                                } else if value.translation.width > 50 {
                                    storyVM.previousPage()
                                }
                                dragOffset = 0
                            }
                    )

                    // Nav overlay
                    if showOverlay {
                        VStack {
                            topBar(story: story)
                            Spacer()
                            bottomBar(story: story)
                        }
                        .transition(.opacity)
                    }
                }

                if showCompletion {
                    completionOverlay(story: story)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showOverlay = false }
            }
        }
    }

    // MARK: - Page Content
    private func pageContent(story: Story) -> some View {
        VStack(spacing: 0) {
            // Illustration zone
            ZStack {
                // Ambient glow behind emoji
                if storyVM.currentPage < story.pages.count {
                    let accent = Color(hex: currentPalette.accent)
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 240, height: 240)
                        .blur(radius: 60)
                        .animation(.easeInOut(duration: 0.8), value: storyVM.currentPage)

                    // Floating sparkle particles
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(accent.opacity(Double.random(in: 0.15...0.35)))
                            .frame(width: CGFloat.random(in: 3...7))
                            .offset(
                                x: CGFloat.random(in: -120...120),
                                y: CGFloat.random(in: -100...80)
                            )
                            .blur(radius: 1)
                    }

                    let page = story.pages[storyVM.currentPage]
                    Text(page.emoji)
                        .font(.system(size: 100))
                        .shadow(color: Color(hex: currentPalette.accent).opacity(0.4), radius: 30, y: 10)
                        .id(storyVM.currentPage)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.7).combined(with: .opacity),
                            removal: .scale(scale: 1.2).combined(with: .opacity)
                        ))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: storyVM.currentPage)
                }

                // First-time tap hints
                if showOverlay && storyVM.currentPage == 0 {
                    VStack {
                        Spacer()
                        HStack {
                            tapHint(direction: "chevron.left", label: "Prev")
                            Spacer()
                            Text("Tap to turn pages")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            Spacer()
                            tapHint(direction: "chevron.right", label: "Next")
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // Text zone
            if storyVM.currentPage < story.pages.count {
                let page = story.pages[storyVM.currentPage]
                let accent = Color(hex: currentPalette.accent)

                VStack(alignment: .leading, spacing: 8) {
                    // Page badge
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent.opacity(0.6))
                            .frame(width: 12, height: 3)
                        Text("Page \(page.pageNumber) of \(story.pages.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Text(page.text)
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(.white.opacity(0.92))
                        .lineSpacing(8)
                        .id(storyVM.currentPage)
                        .transition(.push(from: .trailing))
                        .animation(.easeInOut(duration: 0.4), value: storyVM.currentPage)
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: currentPalette.bottom),
                            Color(hex: currentPalette.bottom).opacity(0.85),
                            .clear,
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .animation(.easeInOut(duration: 0.8), value: storyVM.currentPage)
                )
            }
        }
    }

    private func tapHint(direction: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: direction)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    // MARK: - Top Bar
    private func topBar(story: Story) -> some View {
        HStack {
            Button {
                currentScreen = .home
                storyVM.saveStory()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            Text(story.title)
                .font(.custom("Nunito-ExtraBold", size: 14))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color(hex: currentPalette.top).opacity(0.9), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Bottom Bar
    private func bottomBar(story: Story) -> some View {
        VStack(spacing: 12) {
            // Progress bar (replaces dots for cleaner look)
            HStack(spacing: 4) {
                ForEach(0..<story.pages.count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i <= storyVM.currentPage
                              ? Color(hex: currentPalette.accent)
                              : Color.white.opacity(0.15))
                        .frame(height: 3)
                        .animation(.easeInOut(duration: 0.3), value: storyVM.currentPage)
                }
            }
            .padding(.horizontal, 4)

            // Actions
            HStack(spacing: 0) {
                readerAction(
                    sfIcon: storyVM.currentStory?.isFavorite == true ? "heart.fill" : "heart",
                    label: "Save",
                    tint: storyVM.currentStory?.isFavorite == true ? .smCoral400 : .white
                ) {
                    withAnimation(.spring(response: 0.3)) { storyVM.toggleFavorite() }
                }
                readerAction(sfIcon: "square.and.arrow.up", label: "Share", tint: .white) {
                    currentScreen = .share
                }
                readerAction(sfIcon: "speaker.wave.2", label: "Read", tint: .white) {}
                readerAction(sfIcon: "arrow.clockwise", label: "Redo", tint: .white) {}
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
    }

    private func readerAction(sfIcon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: sfIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(tint.opacity(0.85))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Completion Overlay
    private func completionOverlay(story: Story) -> some View {
        ZStack {
            // Blurred dark bg
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                Spacer()

                // Animated sparkles
                ZStack {
                    ForEach(0..<8, id: \.self) { i in
                        Text(["✨", "🌟", "⭐", "💫"][i % 4])
                            .font(.system(size: CGFloat.random(in: 16...28)))
                            .offset(
                                x: CGFloat.random(in: -80...80),
                                y: CGFloat.random(in: -60...20)
                            )
                            .opacity(0.7)
                    }

                    Text("🎉")
                        .font(.system(size: 64))
                }
                .frame(height: 120)

                Text("The End!")
                    .font(.custom("Nunito-Black", size: 34))
                    .foregroundColor(.white)

                Text(story.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer().frame(height: 4)

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        storyVM.currentPage = 0
                        withAnimation { showCompletion = false }
                    } label: {
                        Text("Read Again")
                            .font(.custom("Nunito-ExtraBold", size: 15))
                            .foregroundColor(.smTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.smYellow400)
                            .clipShape(Capsule())
                            .shadow(color: .smYellow400.opacity(0.3), radius: 12, y: 4)
                    }

                    Button {
                        storyVM.saveStory()
                        currentScreen = .share
                    } label: {
                        Text("Save & Share")
                            .font(.custom("Nunito-ExtraBold", size: 15))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [.smCoral400, .smCoral500],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .smCoral400.opacity(0.4), radius: 12, y: 4)
                    }

                    Button {
                        storyVM.resetForNewStory()
                        currentScreen = .home
                    } label: {
                        Text("Create Another Story")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }
}
