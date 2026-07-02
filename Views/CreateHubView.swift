import SwiftUI

/// "Create" tab: choose between a one-off AI story (Standard) and a long-term
/// Growth Book. Shows a spotlight guide the first time it is opened.
struct CreateHubView: View {
    @ObservedObject var storyVM: StoryViewModel
    @ObservedObject var growthVM: GrowthBookViewModel
    @Binding var currentScreen: AppScreen

    enum Mode: String { case standard, growth }

    @AppStorage("createHubMode") private var mode: Mode = .standard
    @AppStorage("hasSeenCreateGuide") private var hasSeenCreateGuide = false
    @State private var showNewBook = false
    @State private var showGuide = false

    var body: some View {
        ZStack {
            Color.smBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                modePicker
                    .padding(.horizontal, 18)
                    .padding(.bottom, 14)

                ScrollView(showsIndicators: false) {
                    Group {
                        switch mode {
                        case .standard: standardContent
                        case .growth: growthContent
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                }

                smTabBar(active: .create, currentScreen: $currentScreen)
            }
        }
        .overlayPreferenceValue(CoachMarkTargetKey.self) { anchors in
            if showGuide {
                CoachMarkOverlay(steps: guideSteps, anchors: anchors) {
                    withAnimation { showGuide = false }
                    hasSeenCreateGuide = true
                }
            }
        }
        .sheet(isPresented: $showNewBook) {
            NewGrowthBookSheet(childName: storyVM.childName) { title, goal, scenario in
                let book = growthVM.createBook(title: title, goal: goal, childName: storyVM.childName, scenario: scenario)
                growthVM.selectedBookID = book.id
                currentScreen = .growthBook
            }
        }
        .onAppear {
            if !hasSeenCreateGuide {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { showGuide = true } }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Create")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.smTextPrimary)
            Spacer()
            Button {
                withAnimation { showGuide = true }
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.smTextSecondary)
            }
            .accessibilityLabel("Show guide")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            modeButton(.standard, title: "Standard Book", icon: "book.fill")
            modeButton(.growth, title: "Growth Book", icon: "leaf.fill")
        }
        .padding(4)
        .background(Capsule().fill(Color.white))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .coachMarkTarget("create.modePicker")
    }

    private func modeButton(_ value: Mode, title: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { mode = value }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(mode == value ? .white : .smTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Capsule().fill(mode == value ? Color.smCoral400 : Color.clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Standard

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("One story, made in minutes. AI writes it and paints it with your child as the hero.")
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(.smTextSecondary)

            bigCard(
                icon: "camera.fill", colors: ["FFD93D", "FF8C6B"],
                title: "From a photo", subtitle: "Upload a photo, pick a theme, get a book"
            ) { currentScreen = .photoUpload }

            bigCard(
                icon: "square.grid.2x2.fill", colors: ["4D96FF", "6BCB77"],
                title: "From a template", subtitle: "Ready-made stories for everyday moments"
            ) { currentScreen = .storyLibrary }
        }
    }

    private func bigCard(icon: String, colors: [String], title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundColor(.smTextPrimary)
                    Text(subtitle).font(.system(size: 12, design: .rounded)).foregroundColor(.smTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "B8B3AC"))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Growth

    private var growthContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            growthIntro

            if !growthVM.inProgressBooks.isEmpty {
                sectionTitle("IN PROGRESS", count: growthVM.inProgressBooks.count)
                ForEach(growthVM.inProgressBooks) { book in bookRow(book) }
            }
            if !growthVM.completedBooks.isEmpty {
                sectionTitle("COMPLETED", count: growthVM.completedBooks.count)
                ForEach(growthVM.completedBooks) { book in bookRow(book) }
            }
            if growthVM.books.isEmpty {
                ideas
            }
        }
    }

    private var growthIntro: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").foregroundColor(.smGreen400)
                Text("Record one milestone, chapter by chapter")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.smTextPrimary)
            }
            Text("Add a chapter each time something happens — photos, notes, AI illustrations. When your child makes it, finish the book and keep it forever.")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.smTextSecondary)
                .lineSpacing(2)
            Button {
                showNewBook = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .heavy))
                    Text("New Growth Book").font(.system(size: 15, weight: .heavy, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(LinearGradient(colors: [Color(hex: "6BCB77"), Color(hex: "4DB6AC")], startPoint: .leading, endPoint: .trailing)))
            }
            .coachMarkTarget("create.newGrowth")
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10))
                Text("Growth books are private by default")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.smTextSecondary)
            .coachMarkTarget("create.privacy")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        Text("\(title) · \(count)")
            .font(.system(size: 10, weight: .bold))
            .tracking(0.7)
            .foregroundColor(.smTextSecondary)
            .padding(.top, 4)
    }

    private func bookRow(_ book: GrowthBook) -> some View {
        Button {
            growthVM.selectedBookID = book.id
            currentScreen = book.isCompleted ? .growthReader : .growthBook
        } label: {
            HStack(spacing: 14) {
                GrowthCoverThumb(book: book).frame(width: 58, height: 72)
                VStack(alignment: .leading, spacing: 5) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.smTextPrimary)
                        .lineLimit(1)
                    Text(book.goal)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.smTextSecondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        if book.isCompleted {
                            tag("Completed", icon: "checkmark.seal.fill", color: .smGreen400)
                        } else {
                            tag("Day \(book.dayCount)", icon: "calendar", color: .smCoral400)
                        }
                        tag("\(book.chapters.count) ch.", icon: "book.pages", color: .smBlue400)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "B8B3AC"))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    private func tag(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var ideas: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("IDEAS TO START WITH")
                .font(.system(size: 10, weight: .bold)).tracking(0.7)
                .foregroundColor(.smTextSecondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(GrowthScenario.allCases.filter { $0 != .custom }) { s in
                    Button { showNewBook = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: s.sfSymbol).font(.system(size: 14, weight: .bold)).foregroundColor(Color(hex: s.gradientHex.1))
                            Text(s.label).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.smTextPrimary)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Guide

    private var guideSteps: [CoachMarkStep] {
        [
            CoachMarkStep(
                targetID: "create.modePicker", icon: "book.fill",
                title: "Two kinds of books",
                message: "Standard Book: one AI story, finished in minutes.\nGrowth Book: follows one milestone over days or weeks, one chapter at a time.",
                onAppear: { withAnimation { mode = .standard } }
            ),
            CoachMarkStep(
                targetID: "create.newGrowth", icon: "leaf.fill",
                title: "Start a Growth Book",
                message: "Pick a milestone like getting dressed. Then add chapters as it happens: photos, a short note, and an AI illustration if you like. Tap \"Complete\" when your child makes it.",
                onAppear: { withAnimation { mode = .growth } }
            ),
            CoachMarkStep(
                targetID: "tab.community", icon: "person.2.wave.2.fill",
                title: "Share with the Community",
                message: "Soon you'll be able to post finished books here, and like and follow other families. Coming in a future update."
            ),
            CoachMarkStep(
                targetID: "create.privacy", icon: "lock.fill",
                title: "Your photos stay private",
                message: "Growth books hold many photos of your child, so they are private by default. You decide if and when anything is shared.",
                onAppear: { withAnimation { mode = .growth } }
            )
        ]
    }
}

// MARK: - Cover thumbnail

struct GrowthCoverThumb: View {
    let book: GrowthBook

    var body: some View {
        let (a, b) = book.scenario.gradientHex
        ZStack {
            LinearGradient(colors: [Color(hex: a), Color(hex: b)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let media = book.coverMedia, let image = ImageStorageService.shared.loadImageSync(from: media.path) {
                Image(uiImage: GrowthBookViewModel.resized(image, maxSide: 300)).resizable().scaledToFill()
            } else {
                Image(systemName: book.scenario.sfSymbol)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - New book sheet

struct NewGrowthBookSheet: View {
    let childName: String
    let onCreate: (_ title: String, _ goal: String, _ scenario: GrowthScenario) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scenario: GrowthScenario = .dressing
    @State private var title = ""
    @State private var goal = ""

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !goal.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        label("What is \(childName) working on?")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                            ForEach(GrowthScenario.allCases) { s in
                                Button { pick(s) } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: s.sfSymbol).font(.system(size: 20, weight: .bold))
                                        Text(s.label).font(.system(size: 11, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
                                    }
                                    .foregroundColor(scenario == s ? .white : .smTextPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 72)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(scenario == s ? Color(hex: s.gradientHex.1) : Color.white))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    field("Book title", text: $title, placeholder: "e.g. I Can Dress Myself!")
                    field("The goal — when it's done, the book is finished", text: $goal, placeholder: "e.g. Puts on clothes without help")

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 12))
                        Text("This book is private. Only you can see it unless you choose to share it later.")
                            .font(.system(size: 12, design: .rounded))
                    }
                    .foregroundColor(.smTextSecondary)
                }
                .padding(20)
            }
            .background(Color.smBackground.ignoresSafeArea())
            .navigationTitle("New Growth Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(title, goal, scenario)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!canCreate)
                }
            }
            .onAppear { pick(scenario) }
        }
    }

    private func pick(_ s: GrowthScenario) {
        let old = scenario.suggestion(for: childName)
        scenario = s
        let new = s.suggestion(for: childName)
        // Only overwrite fields the parent hasn't customised.
        if title.isEmpty || title == old.title { title = new.title }
        if goal.isEmpty || goal == old.goal { goal = new.goal }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundColor(.smTextSecondary)
    }

    private func field(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label(title)
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        }
    }
}
