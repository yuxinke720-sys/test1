import SwiftUI

struct StorySetupView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        VStack(spacing: 0) {
            navBar
            progressBar(step: 2, total: 2, fill: 1.0)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    characterPreview
                    themeSection
                    styleSection
                    pageCountSection
                    Spacer().frame(height: 20)
                }
            }

            bottomZone
        }
        .background(Color.white.ignoresSafeArea())
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button {
                currentScreen = .photoUpload
            } label: {
                Text("←")
                    .font(.system(size: 22))
                    .foregroundColor(.smCoral400)
                    .frame(width: 36)
            }
            Spacer()
            Text("New Story")
                .font(.custom("Nunito-ExtraBold", size: 17))
                .foregroundColor(.smTextPrimary)
            Spacer()
            Color.clear.frame(width: 36)
        }
        .frame(height: 48)
        .padding(.horizontal, 18)
    }

    // MARK: - Character Preview
    private var characterPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.smYellow400, .smCoral400],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(Text("👧").font(.system(size: 26)))
                    .shadow(color: .smCoral400.opacity(0.3), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Meet your story hero! 👋")
                        .font(.custom("Nunito-ExtraBold", size: 13))
                        .foregroundColor(.smTextPrimary)
                    Text("Based on your photos")
                        .font(.system(size: 10))
                        .foregroundColor(.smTextSecondary)
                }
            }

            Text("\"\(storyVM.childName) is a warm-hearted little girl with bright eyes, always curious about the world around her…\"")
                .font(.system(size: 11.5))
                .foregroundColor(.smTextSecondary)
                .lineSpacing(4)
                .padding(11)
                .background(Color.white.opacity(0.7))
                .cornerRadius(9)

            HStack(spacing: 4) {
                Text("↻")
                Text("Regenerate description")
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.smCoral400)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [.smYellow50, Color(hex: "FFFEF8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.smYellow200, lineWidth: 1.5)
        )
        .cornerRadius(16)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Theme Section
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("What's the story about?")
                .font(.custom("Nunito-ExtraBold", size: 15))
                .foregroundColor(.smTextPrimary)

            Text("Type a theme or pick one below")
                .font(.system(size: 11))
                .foregroundColor(.smTextSecondary)

            TextEditor(text: $storyVM.theme)
                .font(.system(size: 13))
                .foregroundColor(.smTextPrimary)
                .frame(minHeight: 72)
                .padding(12)
                .background(Color.smNeutral50)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(storyVM.theme.isEmpty ? Color.smNeutral200 : Color.smYellow400, lineWidth: 1.5)
                )
                .cornerRadius(13)

            HStack {
                Spacer()
                Text("\(storyVM.theme.count)/100")
                    .font(.system(size: 9))
                    .foregroundColor(.smNeutral300)
            }

            // Theme chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(storyVM.themeChips, id: \.1) { emoji, name in
                        let isActive = storyVM.selectedThemeChip == name
                        Text("\(emoji) \(name)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isActive ? .smTextPrimary : .smYellow600)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(isActive ? Color.smYellow400 : Color.smYellow100)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isActive ? Color.smYellow500 : Color.clear, lineWidth: 1.5)
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    storyVM.selectThemeChip(name)
                                }
                            }
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    // MARK: - Style Section
    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Story vibe")
                .font(.custom("Nunito-ExtraBold", size: 15))
                .foregroundColor(.smTextPrimary)
                .padding(.horizontal, 18)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(StoryStyle.allCases, id: \.self) { style in
                    let isSelected = storyVM.selectedStyle == style
                    VStack(spacing: 4) {
                        Text(style.emoji).font(.system(size: 22))
                        Text(style.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.smNeutral700)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 7)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Color.smYellow50 : Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.smYellow400 : Color.smNeutral200, lineWidth: 2)
                    )
                    .onTapGesture {
                        storyVM.selectedStyle = style
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Page Count Section
    private var pageCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How many pages?")
                .font(.custom("Nunito-ExtraBold", size: 15))
                .foregroundColor(.smTextPrimary)
                .padding(.horizontal, 18)

            HStack(spacing: 2) {
                ForEach(PageCount.allCases, id: \.self) { count in
                    let isActive = storyVM.pageCount == count
                    Text("\(count.rawValue) pages")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isActive ? .smYellow600 : .smTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(isActive ? Color.white : Color.clear)
                        .cornerRadius(9)
                        .shadow(color: isActive ? .black.opacity(0.06) : .clear, radius: 4, y: 2)
                        .onTapGesture {
                            storyVM.pageCount = count
                        }
                }
            }
            .padding(3)
            .background(Color.smNeutral100)
            .cornerRadius(11)
            .padding(.horizontal, 18)

            Text(storyVM.pageCount.readTime + " to read aloud")
                .font(.system(size: 11))
                .foregroundColor(.smTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Bottom
    private var bottomZone: some View {
        VStack(spacing: 7) {
            Button {
                currentScreen = .loading
                Task {
                    await storyVM.generateStory()
                    if storyVM.currentStory != nil {
                        currentScreen = .storybook
                    }
                }
            } label: {
                Text("✨ Generate My Story")
                    .font(.custom("Nunito-ExtraBold", size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
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
            .disabled(!storyVM.canGenerate)
            .opacity(storyVM.canGenerate ? 1 : 0.4)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
