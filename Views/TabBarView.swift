import SwiftUI

enum TabBarItem: String {
    case home, create, myBooks, profile

    var emoji: String {
        switch self {
        case .home: return "🏠"
        case .create: return "✨"
        case .myBooks: return "📚"
        case .profile: return "👤"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .create: return "Create"
        case .myBooks: return "My Books"
        case .profile: return "Profile"
        }
    }

    var screen: AppScreen {
        switch self {
        case .home: return .home
        case .create: return .photoUpload
        case .myBooks: return .myBooks
        case .profile: return .profile
        }
    }
}

/// Shared tab bar used across all main views. Sticks to bottom with safe area coverage.
func smTabBar(active: TabBarItem, currentScreen: Binding<AppScreen>) -> some View {
    HStack {
        ForEach([TabBarItem.home, .create, .myBooks, .profile], id: \.self) { item in
            Button {
                if item != active {
                    currentScreen.wrappedValue = item.screen
                }
            } label: {
                VStack(spacing: 4) {
                    Text(item.emoji).font(.system(size: 22))
                    Text(item.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(item == active ? .smYellow600 : .smNeutral300)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    .padding(.top, 10)
    .padding(.bottom, 34)
    .background(
        Color.white
            .shadow(color: .black.opacity(0.05), radius: 1, y: -1)
            .ignoresSafeArea(edges: .bottom)
    )
}
