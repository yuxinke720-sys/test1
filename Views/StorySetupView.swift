import SwiftUI

struct StorySetupView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

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
                    }.frame(maxWidth: .infinity)
                }

                bottomZone
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button { currentScreen = .photoUpload } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "FF8C6B"))
                    .frame(width: 36)
            }
            Spacer()
            Text("New Story").font(.system(size: 17, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
            Spacer()
            Color.clear.frame(width: 36)
        }.frame(height: 48).padding(.horizontal, 18)
    }

    private var characterPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "FFD93D"), Color(hex: "FF8C6B")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .overlay(Image(systemName: "figure.child").font(.system(size: 22, weight: .medium)).foregroundColor(.white))
                    .shadow(color: Color(hex: "FF8C6B").opacity(0.3), radius: 6, y: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Meet your story hero!").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
                    Text("Based on your photos").font(.system(size: 10)).foregroundColor(Color(hex: "7A756E"))
                }
            }
            Text("\"\(storyVM.childName) is a warm-hearted little girl with bright eyes, always curious about the world around her…\"")
                .font(.system(size: 11.5)).foregroundColor(Color(hex: "7A756E")).lineSpacing(4)
                .padding(11).background(Color(hex: "FFFFFF").opacity(0.7)).cornerRadius(9)
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .bold))
                Text("Regenerate description")
            }
            .font(.system(size: 11, weight: .bold)).foregroundColor(Color(hex: "FF8C6B"))
        }
        .padding(14)
        .background(LinearGradient(colors: [Color(hex: "FFFEF5"), Color(hex: "FFFEF8")], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "FFF5A0"), lineWidth: 1.5))
        .cornerRadius(16).padding(.horizontal, 18).padding(.bottom, 14)
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("What's the story about?").font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
            Text("Type a theme or pick one below").font(.system(size: 11)).foregroundColor(Color(hex: "7A756E"))
            TextEditor(text: $storyVM.theme)
                .font(.system(size: 13)).foregroundColor(Color(hex: "1E1C1A"))
                .frame(minHeight: 72).padding(12)
                .scrollContentBackground(.hidden).background(Color(hex: "FAF8F5"))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(storyVM.theme.isEmpty ? Color(hex: "E0DBD4") : Color(hex: "FFD93D"), lineWidth: 1.5))
                .cornerRadius(13)
            HStack { Spacer(); Text("\(storyVM.theme.count)/100").font(.system(size: 9)).foregroundColor(Color(hex: "B8B3AC")) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(storyVM.themeChips, id: \.1) { emoji, name in
                        let isActive = storyVM.selectedThemeChip == name
                        Text("\(emoji) \(name)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isActive ? Color(hex: "1E1C1A") : Color(hex: "C89F00"))
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(isActive ? Color(hex: "FFD93D") : Color(hex: "FFFBD4"))
                            .clipShape(Capsule())
                            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { storyVM.selectThemeChip(name) } }
                    }
                }
            }
        }.padding(.horizontal, 18).padding(.bottom, 14)
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Story vibe").font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "1E1C1A")).padding(.horizontal, 18)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(StoryStyle.allCases, id: \.self) { style in
                    let sel = storyVM.selectedStyle == style
                    VStack(spacing: 4) {
                        Image(systemName: sfIconForStyle(style))
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(sel ? Color(hex: "FF8C6B") : Color(hex: "7A756E"))
                        Text(style.rawValue).font(.system(size: 10, weight: .bold)).foregroundColor(Color(hex: "3D3A36"))
                    }
                    .padding(.vertical, 11).padding(.horizontal, 7).frame(maxWidth: .infinity)
                    .background(sel ? Color(hex: "FFFEF5") : Color(hex: "FFFFFF")).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? Color(hex: "FFD93D") : Color(hex: "E0DBD4"), lineWidth: 2))
                    .onTapGesture { storyVM.selectedStyle = style }
                }
            }.padding(.horizontal, 18)
        }.padding(.bottom, 14)
    }

    private func sfIconForStyle(_ style: StoryStyle) -> String {
        switch style {
        case .warmCozy: return "heart.fill"
        case .adventure: return "airplane"
        case .fantasy: return "sparkles"
        }
    }

    private var pageCountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How many pages?").font(.system(size: 15, weight: .bold)).foregroundColor(Color(hex: "1E1C1A")).padding(.horizontal, 18)
            HStack(spacing: 2) {
                ForEach(PageCount.allCases, id: \.self) { count in
                    let active = storyVM.pageCount == count
                    Text("\(count.rawValue) pages").font(.system(size: 12, weight: .bold))
                        .foregroundColor(active ? Color(hex: "C89F00") : Color(hex: "7A756E"))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(active ? Color(hex: "FFFFFF") : Color.clear).cornerRadius(9)
                        .shadow(color: active ? .black.opacity(0.06) : .clear, radius: 4, y: 2)
                        .onTapGesture { storyVM.pageCount = count }
                }
            }.padding(3).background(Color(hex: "F5F2EE")).cornerRadius(11).padding(.horizontal, 18)
            Text(storyVM.pageCount.readTime + " to read aloud")
                .font(.system(size: 11)).foregroundColor(Color(hex: "7A756E")).frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var bottomZone: some View {
        VStack(spacing: 7) {
            Button {
                currentScreen = .loading
                Task { await storyVM.generateStory(); if storyVM.currentStory != nil { storyVM.previousScreen = .home; currentScreen = .storybook } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 14, weight: .bold))
                    Text("Generate My Story")
                }
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(LinearGradient(colors: [Color(hex: "FF8C6B"), Color(hex: "E86D4A")], startPoint: .topLeading, endPoint: .bottomTrailing))
                .clipShape(Capsule()).shadow(color: Color(hex: "FF8C6B").opacity(0.35), radius: 10, y: 4)
            }.disabled(!storyVM.canGenerate).opacity(storyVM.canGenerate ? 1 : 0.4)
        }.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 34)
    }
}
