import SwiftUI

enum TabBarItem: String {
    case home, storyTemplates, myBooks, profile

    var sfSymbol: String {
        switch self {
        case .home: return "house.fill"
        case .storyTemplates: return "sparkles"
        case .myBooks: return "books.vertical.fill"
        case .profile: return "person.fill"
        }
    }

    var label: String {
        switch self {
        case .home: return "Home"
        case .storyTemplates: return "Templates"
        case .myBooks: return "My Books"
        case .profile: return "Profile"
        }
    }

    var screen: AppScreen {
        switch self {
        case .home: return .home
        case .storyTemplates: return .storyLibrary
        case .myBooks: return .myBooks
        case .profile: return .profile
        }
    }
}

func smTabBar(active: TabBarItem, currentScreen: Binding<AppScreen>) -> some View {
    HStack {
        ForEach([TabBarItem.home, .storyTemplates, .myBooks, .profile], id: \.self) { item in
            Button {
                if item != active {
                    currentScreen.wrappedValue = item.screen
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: item.sfSymbol)
                        .font(.system(size: 22))
                        .foregroundColor(item == active ? Color(hex: "E8705A") : Color(hex: "B8B3AC"))
                    Text(item.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(item == active ? Color(hex: "E8705A") : Color(hex: "B8B3AC"))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    .padding(.top, 10)
    .padding(.bottom, 34)
    .background(
        Color(hex: "FFFFFF")
            .shadow(color: .black.opacity(0.05), radius: 1, y: -1)
            .ignoresSafeArea(edges: .bottom)
    )
}
