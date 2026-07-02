import SwiftUI

// MARK: - Targets
//
// Mark any view with `.coachMarkTarget("id")`; a screen that shows a guide
// reads all target frames through `CoachMarkTargetKey` and cuts a spotlight
// hole around the one the current step points at.

struct CoachMarkTargetKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func coachMarkTarget(_ id: String) -> some View {
        anchorPreference(key: CoachMarkTargetKey.self, value: .bounds) { [id: $0] }
    }
}

struct CoachMarkStep: Identifiable {
    let id = UUID()
    /// Target id to spotlight; nil shows a centered card with no hole.
    let targetID: String?
    let icon: String
    let title: String
    let message: String
    /// Runs when the step appears (e.g. switch to the tab it talks about).
    var onAppear: (() -> Void)? = nil
}

// MARK: - Overlay

struct CoachMarkOverlay: View {
    let steps: [CoachMarkStep]
    let anchors: [String: Anchor<CGRect>]
    let onFinish: () -> Void

    @State private var index = 0

    private var step: CoachMarkStep { steps[index] }
    private var isLast: Bool { index == steps.count - 1 }

    var body: some View {
        GeometryReader { proxy in
            let hole = step.targetID.flatMap { anchors[$0] }.map { proxy[$0].insetBy(dx: -8, dy: -8) }

            ZStack(alignment: .topLeading) {
                // Dim layer with a spotlight hole. Drawn in the same (safe-area) coordinate
                // space as the anchors; the oversized rect spills past the safe area to cover it.
                Path { p in
                    p.addRect(CGRect(origin: .zero, size: proxy.size).insetBy(dx: -200, dy: -200))
                    if let hole { p.addRoundedRect(in: hole, cornerSize: CGSize(width: 18, height: 18)) }
                }
                .fill(Color.black.opacity(0.62), style: FillStyle(eoFill: true))
                .contentShape(Rectangle())
                .onTapGesture(perform: advance)

                if let hole {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.smYellow400, lineWidth: 3)
                        .frame(width: hole.width, height: hole.height)
                        .offset(x: hole.minX, y: hole.minY)
                        .allowsHitTesting(false)
                }

                card
                    .frame(width: min(proxy.size.width - 40, 360))
                    .position(cardPosition(hole: hole, in: proxy.size))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: index)
        }
        .transition(.opacity)
        .onAppear { step.onAppear?() }
    }

    private func cardPosition(hole: CGRect?, in size: CGSize) -> CGPoint {
        let x = size.width / 2
        guard let hole else { return CGPoint(x: x, y: size.height / 2) }
        // Put the card on whichever side of the hole has more room.
        let cardHalf: CGFloat = 105
        if hole.midY > size.height / 2 {
            return CGPoint(x: x, y: max(cardHalf + 60, hole.minY - cardHalf - 18))
        }
        return CGPoint(x: x, y: min(size.height - cardHalf - 40, hole.maxY + cardHalf + 18))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: step.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.smCoral500)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.smCoral100))
                Text(step.title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.smTextPrimary)
                Spacer()
                Text("\(index + 1)/\(steps.count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.smTextSecondary)
            }
            Text(step.message)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.smTextSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Skip guide", action: finish)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.smTextSecondary)
                    .opacity(isLast ? 0 : 1)
                    .disabled(isLast)
                Spacer()
                Button(action: advance) {
                    Text(isLast ? "Got it" : "Next")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 22).padding(.vertical, 9)
                        .background(Capsule().fill(Color.smCoral400))
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
    }

    private func advance() {
        guard !isLast else { return finish() }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        index += 1
        step.onAppear?()
    }

    private func finish() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish()
    }
}
