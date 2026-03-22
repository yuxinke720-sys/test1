import SwiftUI

struct ShareView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var showShareSheet = false
    @State private var savedToPhotos = false

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            handleBar

            // Title
            if let story = storyVM.currentStory {
                Text("Share \(story.childName)'s Story")
                    .font(.custom("Nunito-Black", size: 20))
                    .foregroundColor(.smTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    previewStrip
                    exportOptionsGrid
                    quickShareRow
                }
            }

            bottomActions
        }
        .background(Color.white)
        .clipShape(
            RoundedCorner(radius: 28, corners: [.topLeft, .topRight])
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
    }

    // MARK: - Handle Bar
    private var handleBar: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.smNeutral200)
                .frame(width: 36, height: 3.5)
                .padding(.top, 16)
                .padding(.bottom, 18)
        }
    }

    // MARK: - Preview Strip
    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let story = storyVM.currentStory {
                    ForEach(story.pages.prefix(4)) { page in
                        VStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [.smYellow200, .smCoral100],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 100)
                                .overlay(
                                    Text(page.emoji)
                                        .font(.system(size: 32))
                                )
                                .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Export Options Grid
    private var exportOptionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            exportOption(icon: "📄", title: "PDF", subtitle: "Full story") {
                showShareSheet = true
            }
            exportOption(icon: "🖼️", title: "Images", subtitle: "All pages") {
                showShareSheet = true
            }
            exportOption(icon: "📱", title: "Share", subtitle: "System sheet") {
                showShareSheet = true
            }
            exportOption(icon: "🖨️", title: "Print", subtitle: "PDF ready") {
                showShareSheet = true
            }
        }
        .padding(.horizontal, 20)
    }

    private func exportOption(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 32))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.smTextPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.smTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
    }

    // MARK: - Quick Share Row
    private var quickShareRow: some View {
        HStack(spacing: 16) {
            quickShareButton(icon: "💬", color: Color(hex: "25D366"), label: "WhatsApp")
            quickShareButton(icon: "✉️", color: Color(hex: "34C759"), label: "Messages")
            quickShareButton(icon: "📡", color: .smBlue400, label: "AirDrop")
            quickShareButton(icon: "···", color: .smNeutral500, label: "More")
        }
    }

    private func quickShareButton(icon: String, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 20))
                .frame(width: 56, height: 56)
                .background(color)
                .clipShape(Circle())

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.smTextSecondary)
        }
        .onTapGesture {
            showShareSheet = true
        }
    }

    // MARK: - Bottom Actions
    private var bottomActions: some View {
        VStack(spacing: 7) {
            Button {
                savedToPhotos = true
                storyVM.saveStory()
            } label: {
                HStack(spacing: 6) {
                    if savedToPhotos {
                        Text("✓ Saved!")
                    } else {
                        Text("Save to Camera Roll")
                    }
                }
                .font(.custom("Nunito-ExtraBold", size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: savedToPhotos ? [.smGreen400, .smGreen400] : [.smCoral400, .smCoral500],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .smCoral400.opacity(0.35), radius: 10, y: 4)
            }

            Button {
                currentScreen = .storybook
            } label: {
                Text("Done")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.smTextSecondary)
                    .frame(height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Rounded Corner Helper
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#Preview {
    ShareView(
        storyVM: {
            let vm = StoryViewModel()
            vm.currentStory = Story(
                title: "Emma's Brave Day",
                childName: "Emma",
                theme: "Being brave",
                pages: [
                    StoryPage(pageNumber: 1, text: "Once upon a time...", emoji: "🦁"),
                    StoryPage(pageNumber: 2, text: "Emma was brave!", emoji: "💪"),
                    StoryPage(pageNumber: 3, text: "She climbed high.", emoji: "🏔️"),
                    StoryPage(pageNumber: 4, text: "The end!", emoji: "⭐"),
                ]
            )
            return vm
        }(),
        currentScreen: .constant(.share)
    )
}
