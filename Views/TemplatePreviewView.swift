import SwiftUI

struct TemplatePreviewView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var selectedPageIndex = 0
    @State private var isBookmarked = false

    private var template: StoryTemplate? { storyVM.selectedTemplate }

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            if let template = template {
                VStack(spacing: 0) {
                    navBar(template: template)
                    scrollContent(template: template)
                    bottomBar
                }
            }
        }
    }

    // MARK: - Nav Bar

    private func navBar(template: StoryTemplate) -> some View {
        HStack {
            Button {
                currentScreen = .storyLibrary
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "E8705A"))
                    .frame(width: 36, height: 36)
            }
            Spacer()
            Text("Preview")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1A1814"))
            Spacer()
            Button {
                isBookmarked.toggle()
            } label: {
                Image(systemName: isBookmarked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "E8705A"))
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
    }

    // MARK: - Scroll Content

    private func scrollContent(template: StoryTemplate) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                coverDisplay(template: template)
                pageStrip(template: template)
                previewTextArea(template: template)
                if !template.learningTakeaway.isEmpty {
                    learningCard(template: template)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Cover Display

    private func coverDisplay(template: StoryTemplate) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: template.coverGradient.map { Color(hex: $0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 180)
                .overlay(
                    Image(systemName: template.coverIcon)
                        .font(.system(size: 52, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                )

            // Info overlay
            HStack(spacing: 6) {
                Text(template.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "1A1814"))
                    .lineLimit(1)
                Text("·")
                    .foregroundColor(Color(hex: "A09890"))
                Text("\(template.pages.count)p")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "A09890"))
                Text(template.category)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "A09890"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "F0EBE4"))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .padding(10)
        }
        .cornerRadius(18)
        .padding(.horizontal, 18)
    }

    // MARK: - Page Strip

    private func pageStrip(template: StoryTemplate) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<template.pages.count, id: \.self) { i in
                    let label = i == 0 ? "Cover" : "P\(i + 1)"
                    let isSelected = selectedPageIndex == i

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedPageIndex = i }
                    } label: {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(isSelected ? Color(hex: "E8705A") : Color(hex: "5C5750"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color.white : Color(hex: "F0EBE4"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color(hex: "E8705A") : Color.clear, lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    // MARK: - Preview Text Area

    private func previewTextArea(template: StoryTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAGE \(selectedPageIndex + 1) PREVIEW")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "A09890"))
                .tracking(0.5)

            Text(template.pages[selectedPageIndex])
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "1A1814"))
                .lineSpacing(6)
                .id(selectedPageIndex)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: selectedPageIndex)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFF8F0"))
        .cornerRadius(16)
        .shadow(color: Color(hex: "E8D9C8").opacity(0.2), radius: 6, y: 3)
        .padding(.horizontal, 18)
    }

    // MARK: - Learning Takeaway Card

    private func learningCard(template: StoryTemplate) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: "4CAF82"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text("Learning Takeaway")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "2D6A4F"))
                Text(template.learningTakeaway)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "2D6A4F"))
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "E8F5EE"))
        .cornerRadius(16)
        .padding(.horizontal, 18)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Primary button
            Button {
                currentScreen = .templatePhotoUpload
            } label: {
                let name = storyVM.childName.trimmingCharacters(in: .whitespaces)
                let label = name.isEmpty ? "Use this story" : "Use this story for \(name)"

                HStack(spacing: 6) {
                    Text(label)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "1A1814"))
                .clipShape(Capsule())
            }

            // Secondary button
            Button {
                currentScreen = .storyLibrary
            } label: {
                Text("Save for later")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "1A1814"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "E0D9D0"), lineWidth: 1)
                    )
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 34)
        .background(
            Color(hex: "F7F3ED")
                .shadow(color: Color(hex: "E8D9C8").opacity(0.3), radius: 8, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
#Preview("ContentView") {
    ContentView()
}

