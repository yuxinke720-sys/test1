import SwiftUI

struct ShareView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var showShareSheet = false
    @State private var savedToPhotos = false

    var body: some View {
        VStack(spacing: 0) {
            handleBar

            if let story = storyVM.currentStory {
                Text("Share \(story.childName)'s Story")
                    .font(.system(size: 20, weight: .black)).foregroundColor(Color(hex: "1E1C1A"))
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 16)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) { previewStrip; exportOptionsGrid; quickShareRow }
            }

            bottomActions
        }
        .background(Color(hex: "FFFFFF"))
        .clipShape(RoundedCorner(radius: 28, corners: [.topLeft, .topRight]))
        .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
    }

    private var handleBar: some View {
        RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E0DBD4"))
            .frame(width: 36, height: 3.5).padding(.top, 16).padding(.bottom, 18)
    }

    private var previewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if let story = storyVM.currentStory {
                    ForEach(story.pages.prefix(4)) { page in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient(colors: [Color(hex: "FFF5A0"), Color(hex: "FFF0EC")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 80, height: 100)
                            .overlay(Text(page.emoji).font(.system(size: 32)))
                            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
                    }
                }
            }.padding(.horizontal, 20).padding(.vertical, 4)
        }
    }

    private var exportOptionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            exportOption(icon: "📄", title: "PDF", subtitle: "Full story")
            exportOption(icon: "🖼️", title: "Images", subtitle: "All pages")
            exportOption(icon: "📱", title: "Share", subtitle: "System sheet")
            exportOption(icon: "🖨️", title: "Print", subtitle: "PDF ready")
        }.padding(.horizontal, 20)
    }

    private func exportOption(icon: String, title: String, subtitle: String) -> some View {
        Button { showShareSheet = true } label: {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 32))
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "1E1C1A"))
                Text(subtitle).font(.system(size: 11)).foregroundColor(Color(hex: "7A756E"))
            }
            .frame(maxWidth: .infinity).frame(height: 80)
            .background(Color(hex: "FFFFFF")).cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        }
    }

    private var quickShareRow: some View {
        HStack(spacing: 16) {
            quickShareBtn(icon: "💬", color: Color(hex: "25D366"), label: "WhatsApp")
            quickShareBtn(icon: "✉️", color: Color(hex: "34C759"), label: "Messages")
            quickShareBtn(icon: "📡", color: Color(hex: "4D96FF"), label: "AirDrop")
            quickShareBtn(icon: "···", color: Color(hex: "7A756E"), label: "More")
        }
    }

    private func quickShareBtn(icon: String, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Text(icon).font(.system(size: 20))
                .frame(width: 56, height: 56).background(color).clipShape(Circle())
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Color(hex: "7A756E"))
        }.onTapGesture { showShareSheet = true }
    }

    private var bottomActions: some View {
        VStack(spacing: 7) {
            Button { savedToPhotos = true; storyVM.saveStory() } label: {
                Text(savedToPhotos ? "✓ Saved!" : "Save to Camera Roll")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(LinearGradient(colors: savedToPhotos ? [Color(hex: "6BCB77"), Color(hex: "6BCB77")] : [Color(hex: "FF8C6B"), Color(hex: "E86D4A")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Capsule()).shadow(color: Color(hex: "FF8C6B").opacity(0.35), radius: 10, y: 4)
            }
            Button { currentScreen = .storybook } label: {
                Text("Done").font(.system(size: 13, weight: .regular)).foregroundColor(Color(hex: "7A756E")).frame(height: 40)
            }
        }.padding(.horizontal, 20).padding(.vertical, 12)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}
