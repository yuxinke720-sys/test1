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
}

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var storyVM = StoryViewModel()
    @StateObject private var photoVM = PhotoViewModel()
    @AppStorage("lastScreen") private var currentScreen: AppScreen = .home
    @State private var hasRestoredState = false

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED")
                .ignoresSafeArea()

            if authVM.currentUser == nil {
                LoginView(authVM: authVM)
                    .transition(.opacity)
            } else {
                mainContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: currentScreen)
        .animation(.easeInOut(duration: 0.3), value: authVM.currentUser == nil)
        .onChange(of: authVM.currentUser) { _, newUser in
            if let user = newUser {
                storyVM.configure(userUID: user.uid)
            } else {
                storyVM.configure(userUID: "")
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
                LoadingView(storyVM: storyVM, photoVM: photoVM, currentScreen: $currentScreen)
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
                ProfileView(storyVM: storyVM, authVM: authVM, currentScreen: $currentScreen)
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
            }
        }
    }
}

// MARK: - AI Test View

struct AITestView:  View {
    @Binding var currentScreen: AppScreen

    @State private var textPrompt = "Tell me a short bedtime story for a 4 year old."
    @State private var imagePrompt = "A cute cartoon bunny reading a book under a tree, children's illustration style"
    @State private var textResult = ""
    @State private var hasTextResponse = false
    @State private var generatedImage: UIImage?
    @State private var isLoadingText = false
    @State private var isLoadingImage = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Text Generation
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Text Generation", systemImage: "text.bubble")
                            .font(.headline)

                        TextField("Enter prompt...", text: $textPrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)

                        Button {
                            Task { await testText() }
                        } label: {
                            HStack {
                                if isLoadingText {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text("Generate Text")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoadingText || textPrompt.trimmingCharacters(in: .whitespaces).isEmpty)

                        if hasTextResponse {
                            Text(textResult.isEmpty ? "(empty response — check Xcode console for raw JSON)" : textResult)
                                .font(.body)
                                .foregroundStyle(textResult.isEmpty ? .secondary : .primary)
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Image Generation
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Image Generation", systemImage: "photo.artframe")
                            .font(.headline)

                        TextField("Enter image prompt...", text: $imagePrompt, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)

                        Button {
                            Task { await testImage() }
                        } label: {
                            HStack {
                                if isLoadingImage {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "photo.fill")
                                }
                                Text("Generate Image")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoadingImage || imagePrompt.trimmingCharacters(in: .whitespaces).isEmpty)

                        if let img = generatedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Error display
                    if let err = errorMessage {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color(hex: "F7F3ED"))
            .navigationTitle("AI Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        currentScreen = .home
                    } label: {
                        Image(systemName: "chevron.left")
                        Text("Home")
                    }
                }
            }
        }
    }

    @MainActor
    private func testText() async {
        isLoadingText = true
        errorMessage = nil
        textResult = ""
        hasTextResponse = false
        do {
            let result = try await AIService.shared.generateText(prompt: textPrompt)
            textResult = result
            hasTextResponse = true
            print("[AITestView] textResult length = \(result.count)")
        } catch {
            errorMessage = error.localizedDescription
            print("[AITestView] testText error: \(error)")
        }
        isLoadingText = false
    }

    @MainActor
    private func testImage() async {
        isLoadingImage = true
        errorMessage = nil
        generatedImage = nil
        do {
            let data = try await AIService.shared.generateImage(prompt: imagePrompt)
            print("[AITestView] image bytes = \(data.count)")
            if let img = UIImage(data: data) {
                generatedImage = img
            } else {
                errorMessage = "Received \(data.count) bytes but could not decode image."
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[AITestView] testImage error: \(error)")
        }
        isLoadingImage = false
    }
}

#Preview("ContentView") {
    ContentView()
}
