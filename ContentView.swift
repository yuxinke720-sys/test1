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
    case storyLibrary
    case templatePreview
    case templatePhotoUpload
    case aiTest
    case create
    case community
    case growthBook
    case growthReader
}

struct ContentView: View {
    @StateObject private var storyVM = StoryViewModel()
    @StateObject private var photoVM = PhotoViewModel()
    @StateObject private var settingsVM = SettingsViewModel()
    @StateObject private var growthVM = GrowthBookViewModel()
    @StateObject private var authVM = AuthViewModel()
    @AppStorage("lastScreen") private var currentScreen: AppScreen = .home
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var hasRestoredState = false

    var body: some View {
        ZStack {
            // Force full-screen background so ZStack never shrinks
            Color(hex: "F7F3ED")
                .ignoresSafeArea()

            rootContent
        }
        .preferredColorScheme(settingsVM.isDarkMode ? .dark : .light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: currentScreen)
        .animation(.easeInOut(duration: 0.3), value: authVM.currentUser == nil)
        .animation(.easeInOut(duration: 0.3), value: hasSeenOnboarding)
        .onChange(of: authVM.currentUser) { _, newUser in
            if let user = newUser {
                storyVM.configure(userUID: user.uid)
                growthVM.configure(userUID: user.uid)
                #if DEBUG
                applyDebugLaunchArguments()
                #endif
            } else {
                storyVM.configure(userUID: "")
                growthVM.configure(userUID: "")
                currentScreen = .home
            }
        }
        .onAppear {
            guard !hasRestoredState else { return }
            hasRestoredState = true

            // Transient screens should not survive a relaunch
            if currentScreen == .loading || currentScreen == .share
                || currentScreen == .templatePreview || currentScreen == .templatePhotoUpload
                || currentScreen == .storySetup || currentScreen == .photoUpload
                || currentScreen == .aiTest {
                currentScreen = .home
                return
            }

            // Growth screens need a selected book, which isn't restored across launches.
            if currentScreen == .growthBook || currentScreen == .growthReader {
                currentScreen = .create
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
            if (newValue == .photoUpload && oldValue != .storySetup)
                || newValue == .templatePhotoUpload {
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

    #if DEBUG
    /// Dev/QA shortcut: launch with `-debugOpenScreen growthBook` (any AppScreen raw value)
    /// and optionally `-debugCelebrate YES` to jump straight to a screen for screenshots.
    /// Growth screens open the first in-progress (or completed, for the reader) book.
    private func applyDebugLaunchArguments() {
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: "debugOpenScreen"), let screen = AppScreen(rawValue: raw) else { return }
        if screen == .growthBook || screen == .growthReader {
            let celebrate = defaults.bool(forKey: "debugCelebrate")
            let book = (screen == .growthReader || celebrate) ? growthVM.completedBooks.first : growthVM.inProgressBooks.first
            growthVM.selectedBookID = book?.id
            if celebrate, let id = book?.id { growthVM.celebratingBookID = id }
        }
        currentScreen = screen
    }
    #endif

    /// Top-level routing: first-launch walkthrough -> auth -> app.
    /// The walkthrough runs before login so parents understand what the app does
    /// (and accept the privacy terms) before creating an account.
    @ViewBuilder
    private var rootContent: some View {
        if !hasSeenOnboarding {
            OnboardingView { hasSeenOnboarding = true }
                .transition(.opacity)
        } else if authVM.currentUser == nil {
            LoginView(authVM: authVM)
                .transition(.opacity)
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
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
                ProfileView(storyVM: storyVM, authVM: authVM, settingsVM: settingsVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .storyCalendar:
                StoryCalendarView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .storyLibrary:
                StoryTemplateView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .templatePreview:
                TemplatePreviewView(storyVM: storyVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .templatePhotoUpload:
                TemplatePhotoUploadView(storyVM: storyVM, photoVM: photoVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .aiTest:
                AITestView(currentScreen: $currentScreen)
                    .transition(.opacity)

            case .create:
                CreateHubView(storyVM: storyVM, growthVM: growthVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .community:
                CommunityView(currentScreen: $currentScreen)
                    .transition(.opacity)

            case .growthBook:
                GrowthBookDetailView(growthVM: growthVM, currentScreen: $currentScreen)
                    .transition(.opacity)

            case .growthReader:
                GrowthBookReaderView(growthVM: growthVM, currentScreen: $currentScreen)
                    .transition(.move(edge: .bottom))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: currentScreen)
        .onAppear {
            guard !hasRestoredState else { return }
            hasRestoredState = true

            // Transient screens should not survive a relaunch
            if currentScreen == .loading || currentScreen == .share
                || currentScreen == .templatePreview || currentScreen == .templatePhotoUpload
                || currentScreen == .storySetup || currentScreen == .photoUpload {
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
            if (newValue == .photoUpload && oldValue != .storySetup)
                || newValue == .templatePhotoUpload {
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
