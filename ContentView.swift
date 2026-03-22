import SwiftUI

enum AppScreen: Equatable {
    case home
    case photoUpload
    case storySetup
    case loading
    case storybook
    case share
    case myBooks
    case profile
}

struct ContentView: View {
    @StateObject private var storyVM = StoryViewModel()
    @StateObject private var photoVM = PhotoViewModel()
    @State private var currentScreen: AppScreen = .home

    var body: some View {
        ZStack {
            switch currentScreen {
            case .home:
                HomeView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .opacity
                    ))

            case .photoUpload:
                PhotoUploadView(storyVM: storyVM, photoVM: photoVM, currentScreen: $currentScreen)
                    .transition(.move(edge: .trailing))

            case .storySetup:
                StorySetupView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.move(edge: .trailing))

            case .loading:
                LoadingView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .storybook:
                StorybookView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .share:
                ZStack {
                    StorybookView(storyVM: storyVM, currentScreen: $currentScreen)
                        .opacity(0.3)

                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            currentScreen = .storybook
                        }

                    VStack {
                        Spacer()
                        ShareView(storyVM: storyVM, currentScreen: $currentScreen)
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.75)
                    }
                    .transition(.move(edge: .bottom))
                }

            case .myBooks:
                MyBooksView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.move(edge: .trailing))

            case .profile:
                ProfileView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentScreen)
        .onChange(of: currentScreen) { oldValue, newValue in
            // Reset photo state when entering creation flow fresh (not going back from setup)
            if newValue == .photoUpload && oldValue != .storySetup {
                photoVM.reset()
            }
        }
    }
}

#Preview {
    ContentView()
}
