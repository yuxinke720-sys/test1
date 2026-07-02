import SwiftUI

/// Placeholder for the Book Circle (community) tab. Shows what's coming so the
/// feature is visible in the app before the social backend exists.
struct CommunityView: View {
    @Binding var currentScreen: AppScreen

    @AppStorage("communityNotifyMe") private var notifyMe = false

    private let features: [(icon: String, color: String, title: String, text: String)] = [
        ("square.and.arrow.up.fill", "FF8C6B", "Share your books", "Post finished books, single pages or drawing moments, with a caption and tags like #GrowthBook."),
        ("heart.fill", "E86D4A", "Like, comment, save", "Cheer on other families and keep favourites for bedtime ideas."),
        ("person.crop.circle.badge.plus", "4D96FF", "Follow creators", "See new books from families you love in your feed."),
        ("lock.shield.fill", "6BCB77", "You choose who sees it", "Everyone, friends only, or just you. Growth books stay private unless you change it."),
        ("pencil.and.outline", "B39DDB", "Draw along", "Use a book as a reference for your own — with credit to the original creator.")
    ]

    var body: some View {
        ZStack {
            Color.smBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        hero
                        VStack(spacing: 12) {
                            ForEach(features, id: \.title) { f in featureRow(f) }
                        }
                        notifyButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                smTabBar(active: .community, currentScreen: $currentScreen)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.smYellow200).frame(width: 110, height: 110)
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.smCoral500)
            }
            Text("Book Circle")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.smTextPrimary)
            Text("COMING SOON")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(Capsule().fill(Color.smCoral400))
            Text("A friendly place for families to share the picture books they make together.")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.smTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }

    private func featureRow(_ f: (icon: String, color: String, title: String, text: String)) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: f.icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(hex: f.color))
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: f.color).opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(f.title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundColor(.smTextPrimary)
                Text(f.text).font(.system(size: 12, design: .rounded)).foregroundColor(.smTextSecondary).lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
    }

    private var notifyButton: some View {
        Button {
            withAnimation(.spring(response: 0.3)) { notifyMe.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: notifyMe ? "checkmark.circle.fill" : "bell.fill")
                Text(notifyMe ? "We'll let you know" : "Tell me when it's ready")
            }
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundColor(notifyMe ? .smGreen400 : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(notifyMe ? Color.smGreen400.opacity(0.14) : Color.smCoral400))
        }
    }
}
