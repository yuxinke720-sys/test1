import SwiftUI

enum AppScreen: String, Equatable {
    case home
    case photoUpload
    case storySetup
    case loading
    case storybook
    case share
    case myBooks
    case profile
    case storyCalendar
}

struct ContentView: View {
    @StateObject private var storyVM = StoryViewModel()
    @StateObject private var photoVM = PhotoViewModel()
    @AppStorage("lastScreen") private var currentScreen: AppScreen = .home
    @State private var hasRestoredState = false

    var body: some View {
        ZStack {
            // Force full-screen background so ZStack never shrinks
            Color(hex: "F7F3ED")
                .ignoresSafeArea()

            switch currentScreen {
            case .home:
                HomeView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .photoUpload:
                PhotoUploadView(storyVM: storyVM, photoVM: photoVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .storySetup:
                StorySetupView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

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
                    .transition(.opacity)

            case .profile:
                ProfileView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .storyCalendar:
                StoryCalendarView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: currentScreen)
        .onAppear {
            guard !hasRestoredState else { return }
            hasRestoredState = true

            // Transient screens should not survive a relaunch
            if currentScreen == .loading || currentScreen == .share {
                currentScreen = .home
                return
            }

            // Restore story reading state
            if currentScreen == .storybook {
                if !storyVM.restoreLastReading() {
                    currentScreen = .home
                }
            }
        }
        .onChange(of: currentScreen) { oldValue, newValue in
            if newValue == .photoUpload && oldValue != .storySetup {
                photoVM.reset()
            }
            storyVM.persistReadingState()
        }
        .onChange(of: storyVM.currentPage) {
            storyVM.persistReadingState()
        }
        .onChange(of: storyVM.currentStory) {
            storyVM.persistReadingState()
        }
    }
}

#Preview("ContentView") {
    ContentView()
}
