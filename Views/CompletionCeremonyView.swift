import SwiftUI

/// Full-screen celebration played once when a Growth Book is finished:
/// the book closes with a stamp, confetti falls, and the stats count up.
struct CompletionCeremonyView: View {
    let book: GrowthBook
    let onOpenBook: () -> Void

    @State private var phase = 0          // 0 start · 1 book in · 2 stamp · 3 text · 4 button
    @State private var confettiStart = Date()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "FFF6D6"), Color(hex: "FFE3D6")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Soft rotating rays behind the book
            RaysView()
                .opacity(phase >= 2 ? 0.55 : 0)
                .scaleEffect(phase >= 2 ? 1 : 0.4)
                .animation(.easeOut(duration: 1.0), value: phase)

            VStack(spacing: 26) {
                Spacer()

                ZStack(alignment: .topTrailing) {
                    GrowthCoverThumb(book: book)
                        .frame(width: 190, height: 240)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white, lineWidth: 6)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 20, y: 12)
                        .rotation3DEffect(.degrees(phase >= 1 ? 0 : 80), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.6)
                        .scaleEffect(phase >= 1 ? 1 : 0.6)
                        .opacity(phase >= 1 ? 1 : 0)

                    // "Completed" stamp
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color(hex: "6BCB77"))
                        .background(Circle().fill(Color.white).padding(6))
                        .offset(x: 30, y: -30)
                        .rotationEffect(.degrees(phase >= 2 ? -12 : 20))
                        .scaleEffect(phase >= 2 ? 1 : 3)
                        .opacity(phase >= 2 ? 1 : 0)
                }

                VStack(spacing: 10) {
                    Text("\(book.childName) did it!")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.smTextPrimary)
                    Text(book.goal)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.smTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(phase >= 3 ? 1 : 0)
                .offset(y: phase >= 3 ? 0 : 20)

                HStack(spacing: 28) {
                    CountUpStat(value: book.dayCount, label: book.dayCount == 1 ? "day" : "days", start: phase >= 3)
                    CountUpStat(value: book.chapters.count, label: book.chapters.count == 1 ? "chapter" : "chapters", start: phase >= 3)
                    CountUpStat(value: book.mediaCount, label: book.mediaCount == 1 ? "picture" : "pictures", start: phase >= 3)
                }
                .opacity(phase >= 3 ? 1 : 0)

                Spacer()

                Button(action: onOpenBook) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.fill")
                        Text("Open the finished book")
                    }
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Capsule().fill(Color.smCoral400))
                    .shadow(color: Color.smCoral400.opacity(0.4), radius: 12, y: 6)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 30)
                .opacity(phase >= 4 ? 1 : 0)
                .scaleEffect(phase >= 4 ? 1 : 0.9)
            }

            if phase >= 2 {
                ConfettiView(start: confettiStart)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .onAppear(perform: play)
    }

    private func play() {
        func step(_ p: Int, after delay: Double, _ anim: Animation, haptic: (() -> Void)? = nil) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(anim) { phase = p }
                haptic?()
            }
        }
        step(1, after: 0.15, .spring(response: 0.7, dampingFraction: 0.75))
        step(2, after: 1.0, .spring(response: 0.35, dampingFraction: 0.55)) {
            confettiStart = Date()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        step(3, after: 1.5, .easeOut(duration: 0.5))
        step(4, after: 2.4, .spring(response: 0.5, dampingFraction: 0.7))
    }
}

// MARK: - Pieces

private struct CountUpStat: View {
    let value: Int
    let label: String
    let start: Bool
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 2) {
            Text("\(shown)")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundColor(.smCoral500)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.smTextSecondary)
        }
        .onChange(of: start) { _, go in
            guard go, value > 0 else { return }
            let steps = min(value, 20)
            for i in 1...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                    withAnimation(.snappy) { shown = Int((Double(value) * Double(i) / Double(steps)).rounded()) }
                }
            }
        }
    }
}

private struct RaysView: View {
    var body: some View {
        TimelineView(.animation) { context in
            let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60) * 6
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
                let radius = max(size.width, size.height)
                for i in 0..<16 {
                    let a0 = Angle.degrees(Double(i) * 22.5 + angle).radians
                    let a1 = a0 + Angle.degrees(9).radians
                    var p = Path()
                    p.move(to: center)
                    p.addLine(to: CGPoint(x: center.x + cos(a0) * radius, y: center.y + sin(a0) * radius))
                    p.addLine(to: CGPoint(x: center.x + cos(a1) * radius, y: center.y + sin(a1) * radius))
                    p.closeSubpath()
                    ctx.fill(p, with: .color(Color(hex: "FFD93D").opacity(0.35)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Lightweight confetti: deterministic pieces falling with sway, drawn in a Canvas.
private struct ConfettiView: View {
    let start: Date
    private static let colors = ["FFD93D", "FF8C6B", "6BCB77", "4D96FF", "B39DDB", "E86D4A"].map { Color(hex: $0) }
    private static let pieces: [(x: Double, delay: Double, speed: Double, size: Double, spin: Double, color: Int)] =
        (0..<90).map { i in
            var g = SeededRandom(seed: UInt64(i + 1))
            return (g.next(), g.next() * 0.8, 180 + g.next() * 220, 6 + g.next() * 7, g.next() * 6 - 3, i % colors.count)
        }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            Canvas { ctx, size in
                for p in Self.pieces {
                    let time = t - p.delay
                    guard time > 0 else { continue }
                    let y = -20 + time * p.speed
                    guard y < size.height + 20 else { continue }
                    let x = p.x * size.width + sin(time * 3 + p.x * 10) * 18
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(time * p.spin))
                    c.fill(Path(CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)),
                           with: .color(Self.colors[p.color]))
                }
            }
        }
    }
}

private struct SeededRandom {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> Double {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return Double(state % 10_000) / 10_000
    }
}
