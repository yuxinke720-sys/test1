import SwiftUI

// MARK: - Onboarding Page Model

/// A single slide in the first-launch walkthrough.
/// The audience here is the *parent*, not the 3-6 year old child, so the copy
/// explains value and expectations rather than instructing a young reader.
struct OnboardingPage: Identifiable {
    let id = UUID()
    let sfSymbol: String
    let accent: Color
    let title: String
    let description: String
}

extension OnboardingPage {
    static let all: [OnboardingPage] = [
        OnboardingPage(
            sfSymbol: "camera.fill",
            accent: .smYellow400,
            title: "Standard Book: minutes",
            description: "Upload a photo, pick a theme, and AI writes and paints a story with your child as the hero."
        ),
        OnboardingPage(
            sfSymbol: "leaf.fill",
            accent: .smGreen400,
            title: "Growth Book: over time",
            description: "Follow one milestone, like getting dressed alone. Add a chapter each time it happens: photos, notes and AI illustrations."
        ),
        OnboardingPage(
            sfSymbol: "party.popper.fill",
            accent: .smCoral400,
            title: "Finish it, keep it forever",
            description: "When your child makes it, tap Complete. The chapters become a real book you can read together or export as a PDF."
        ),
        OnboardingPage(
            sfSymbol: "lock.fill",
            accent: .smBlue400,
            title: "Private until you share",
            description: "Growth books stay private by default. A Book Circle to share with other families is coming soon, and you choose who sees what."
        )
    ]
}

// MARK: - Onboarding Container

struct OnboardingView: View {
    /// Called once the parent finishes or skips the walkthrough.
    let onFinish: () -> Void

    @State private var selection = 0

    private let pages = OnboardingPage.all

    private var isLastPage: Bool { selection == pages.count - 1 }

    var body: some View {
        ZStack {
            Color.smBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                skipButton

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.bottom, 28)

                primaryButton

                privacyNotice
            }
        }
    }

    // MARK: Subviews

    private var skipButton: some View {
        HStack {
            Spacer()
            Button("Skip") { finish() }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.smTextSecondary)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .opacity(isLastPage ? 0 : 1)
                .disabled(isLastPage)
                .animation(.easeInOut(duration: 0.2), value: isLastPage)
                .accessibilityLabel("Skip introduction")
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selection ? Color.smCoral400 : Color.smNeutral100)
                    .frame(width: index == selection ? 24 : 8, height: 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
        .accessibilityHidden(true)
    }

    private var primaryButton: some View {
        Button(action: advance) {
            Text(isLastPage ? "Get Started" : "Continue")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isLastPage ? Color.smCoral400 : Color.smYellow400)
                .foregroundColor(isLastPage ? .white : .smTextPrimary)
                .cornerRadius(14)
        }
        .padding(.horizontal, 24)
    }

    private var privacyNotice: some View {
        Text("Made for parents. By continuing you agree to our Privacy Policy.")
            .font(.system(size: 11))
            .foregroundColor(.smTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.top, 14)
            .padding(.bottom, 24)
    }

    // MARK: Actions

    private func advance() {
        if isLastPage {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { selection += 1 }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            print("[Onboarding] advanced to page \(selection + 1)/\(pages.count)")
        }
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        print("[Onboarding] finished at page \(selection + 1)/\(pages.count)")
        onFinish()
    }
}

// MARK: - Single Page

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.accent)
                    .frame(width: 140, height: 140)
                Image(systemName: page.sfSymbol)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.smCoral400)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.system(size: 15))
                    .foregroundColor(.smTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Onboarding") {
    OnboardingView(onFinish: {})
}
