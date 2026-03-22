import SwiftUI

struct LoadingView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var bookOffset: CGFloat = 0
    @State private var funFactIndex = 0

    private let funFacts = [
        "Children read to daily develop vocabularies 3x larger by age 5 ✨",
        "Personalized stories increase reading engagement by 40% 📖",
        "Kids who see themselves in stories build stronger self-confidence 💪",
        "Reading together is one of the best ways to bond with your child 💛",
        "Stories help children understand emotions and build empathy 🌟",
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Status bar area
            Color.clear.frame(height: 44)

            VStack(spacing: 16) {
                Spacer()

                // Floating book animation
                Text("📖")
                    .font(.system(size: 80))
                    .offset(y: bookOffset)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            bookOffset = -10
                        }
                    }

                // Stage text
                VStack(spacing: 4) {
                    Text("\(storyVM.generationStage.label) \(storyVM.generationStage.icon)")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.smTextPrimary)

                    Text("Creating illustrations for \(storyVM.childName)")
                        .font(.system(size: 12))
                        .foregroundColor(.smTextSecondary)
                }

                // Progress steps
                VStack(spacing: 10) {
                    stepRow(
                        status: storyVM.generationStage == .writing ? .current : .done,
                        text: "Story written · \(storyVM.childName)'s Adventure"
                    )
                    stepRow(
                        status: storyVM.generationStage == .illustrating ? .current :
                            (storyVM.generationStage == .writing ? .pending : .done),
                        text: storyVM.generationStage == .illustrating ?
                            "Illustrating pages (\(storyVM.illustrationProgress) / \(storyVM.pageCount.rawValue))" :
                            "Illustrating pages"
                    )
                    stepRow(
                        status: storyVM.generationStage == .finalizing ? .current : .pending,
                        text: "Final polish & assembly"
                    )
                }
                .padding(.horizontal, 20)

                // Lock notice
                VStack(spacing: 1) {
                    Text("✅ Safe to lock your screen")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.smGreen600)
                    Text("We'll notify you when it's ready")
                        .font(.system(size: 10))
                        .foregroundColor(.smTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(9)
                .background(Color.white.opacity(0.75))
                .cornerRadius(11)
                .padding(.horizontal, 20)

                // Fun fact card
                VStack(alignment: .leading, spacing: 3) {
                    Text("📖 DID YOU KNOW?")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.smTextSecondary)
                        .tracking(0.6)
                    Text(funFacts[funFactIndex])
                        .font(.system(size: 12))
                        .foregroundColor(.smNeutral700)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color.white.opacity(0.85))
                .cornerRadius(13)
                .padding(.horizontal, 20)

                Spacer()

                Text("Usually takes 30–60 seconds")
                    .font(.system(size: 11))
                    .foregroundColor(.smNeutral300)
                    .padding(.bottom, 20)
            }
        }
        .background(
            LinearGradient(
                colors: [.smYellow50, .smYellow100, Color(hex: "FFFEF5")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            startFunFactRotation()
        }
        .onChange(of: storyVM.currentStory) {
            if storyVM.currentStory != nil {
                currentScreen = .storybook
            }
        }
    }

    // MARK: - Step Row
    private enum StepStatus { case done, current, pending }

    private func stepRow(status: StepStatus, text: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(stepColor(status))
                .frame(width: 24, height: 24)
                .overlay(
                    Group {
                        switch status {
                        case .done:
                            Text("✓")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.white)
                        case .current:
                            ProgressView()
                                .scaleEffect(0.5)
                                .tint(.smTextPrimary)
                        case .pending:
                            Text("○")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.smNeutral300)
                        }
                    }
                )

            Text(text)
                .font(.system(size: 12, weight: status == .done ? .bold : .medium))
                .foregroundColor(stepTextColor(status))

            Spacer()
        }
    }

    private func stepColor(_ status: StepStatus) -> Color {
        switch status {
        case .done: return .smGreen400
        case .current: return .smYellow400
        case .pending: return .smNeutral200
        }
    }

    private func stepTextColor(_ status: StepStatus) -> Color {
        switch status {
        case .done: return .smGreen600
        case .current: return .smNeutral700
        case .pending: return .smNeutral300
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
#Preview {
    LoadingView(
        storyVM: {
            let vm = StoryViewModel()
            vm.generationStage = .illustrating
            vm.illustrationProgress = 4
            return vm
        }(),
        currentScreen: .constant(.loading)
    )
}
