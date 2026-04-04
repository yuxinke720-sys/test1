import SwiftUI

struct LoadingView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var bookOffset: CGFloat = 0
    @State private var funFactIndex = 0

    private let funFacts = [
        "Children read to daily develop vocabularies 3x larger by age 5",
        "Personalized stories increase reading engagement by 40%",
        "Kids who see themselves in stories build stronger self-confidence",
        "Reading together is one of the best ways to bond with your child",
        "Stories help children understand emotions and build empathy",
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFFEF5"), Color(hex: "FFFBD4"), Color(hex: "FFFEF5")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                if storyVM.errorMessage != nil {
                    errorContent
                } else {
                    loadingContent
                }

                Spacer()
                Text("Usually takes 30–60 seconds")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "B8B3AC"))
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startFunFactRotation()
            if !storyVM.isGenerating && storyVM.currentStory == nil && storyVM.errorMessage == nil {
                Task { await storyVM.generateStory() }
            }
        }
        .onChange(of: storyVM.currentStory) {
            if storyVM.currentStory != nil {
                storyVM.previousScreen = .home
                currentScreen = .storybook
            }
        }
    }

    // MARK: - Loading Content

    private var loadingContent: some View {
        Group {
            Image(systemName: "book.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(Color(hex: "FFD93D"))
                .offset(y: bookOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { bookOffset = -10 }
                }

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(storyVM.generationStage.label)
                    Image(systemName: storyVM.generationStage.icon)
                }
                .font(.system(size: 18, weight: .black))
                .foregroundColor(Color(hex: "1E1C1A"))

                Text("Creating a story for \(storyVM.childName)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "7A756E"))
            }

            VStack(spacing: 10) {
                stepRow(
                    status: storyVM.generationStage == .writing ? .current : .done,
                    text: "Writing story text"
                )
                stepRow(
                    status: storyVM.generationStage == .illustrating ? .current :
                        (storyVM.generationStage == .writing ? .pending : .done),
                    text: storyVM.generationStage == .illustrating ?
                        "Illustrating (\(storyVM.illustrationProgress)/\(storyVM.pageCount.rawValue))" :
                        "Illustrating pages"
                )
                stepRow(
                    status: storyVM.generationStage == .finalizing ? .current : .pending,
                    text: "Final polish"
                )
            }
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "book.fill").font(.system(size: 9, weight: .bold))
                    Text("DID YOU KNOW?")
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(hex: "7A756E"))
                .tracking(0.6)

                Text(funFacts[funFactIndex])
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "3D3A36"))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(Color(hex: "FFFFFF").opacity(0.85))
            .cornerRadius(13)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Error Content

    private var errorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color(hex: "E8705A"))

            Text("Something went wrong")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1E1C1A"))

            Text(storyVM.errorMessage ?? "Please try again")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(Color(hex: "7A756E"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button {
                    storyVM.errorMessage = nil
                    Task { await storyVM.generateStory() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 13, weight: .bold))
                        Text("Try Again")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(LinearGradient(colors: [Color(hex: "FF8C6B"), Color(hex: "E86D4A")],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Capsule())
                }

                Button {
                    storyVM.errorMessage = nil
                    storyVM.isGenerating = false
                    currentScreen = .home
                } label: {
                    Text("Go Back")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "7A756E"))
                        .frame(height: 40)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private enum StepStatus { case done, current, pending }

    private func stepRow(status: StepStatus, text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(status == .done ? Color(hex: "6BCB77") :
                      status == .current ? Color(hex: "FFD93D") :
                      Color(hex: "E0DBD4"))
                .frame(width: 24, height: 24)
                .overlay(Group {
                    switch status {
                    case .done:
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    case .current:
                        ProgressView().scaleEffect(0.5).tint(Color(hex: "1E1C1A"))
                    case .pending:
                        Image(systemName: "circle")
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(Color(hex: "B8B3AC"))
                    }
                })
            Text(text)
                .font(.system(size: 12, weight: status == .done ? .bold : .regular))
                .foregroundColor(status == .done ? Color(hex: "2A8A40") :
                                 status == .current ? Color(hex: "3D3A36") :
                                 Color(hex: "B8B3AC"))
            Spacer()
        }
    }

    private func startFunFactRotation() {
        Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                funFactIndex = (funFactIndex + 1) % funFacts.count
            }
        }
    }
}
