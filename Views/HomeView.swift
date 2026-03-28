import SwiftUI

struct HomeView: View {
    @ObservedObject var storyVM: StoryViewModel
    @Binding var currentScreen: AppScreen

    @State private var tappedDay: Int?

    private let calendar = Calendar.current
    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ZStack {
            Color(hex: "F7F3ED").ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        topBar
                        heroBanner
                        miniCalendarStrip
                        recentBooksSection
                    }
                    .frame(maxWidth: .infinity)
                }

                smTabBar(active: .home, currentScreen: $currentScreen)
            }
        }
    }

    // MARK: - Greeting Logic

    private var greetingText: String {
        if let holiday = currentHoliday() {
            return holiday
        }
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var greetingIcon: String {
        if currentHoliday() != nil {
            return "eye.fill"
        }
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "sun.max.fill"
        case 12..<17: return "cloud.sun.fill"
        default:      return "moon.fill"
        }
    }

    private var greetingIconColor: Color {
        if currentHoliday() != nil {
            return Color(hex: "E8705A")
        }
        let hour = calendar.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return Color(hex: "FFD93D")
        case 12..<17: return Color(hex: "FFB347")
        default:      return Color(hex: "A78BFA")
        }
    }

    private func currentHoliday() -> String? {
        let now = Date()
        let month = calendar.component(.month, from: now)
        let day = calendar.component(.day, from: now)

        // Christmas: Dec 24-25
        if month == 12 && (day == 24 || day == 25) { return "Merry Christmas" }
        // Halloween: Oct 31
        if month == 10 && day == 31 { return "Happy Halloween" }
        // Thanksgiving: 4th Thursday of November
        if month == 11, let thanksgivingDay = thanksgivingDay(year: calendar.component(.year, from: now)), day == thanksgivingDay {
            return "Happy Thanksgiving"
        }
        // Spring: Mar 20 (vernal equinox)
        if month == 3 && day == 20 { return "Happy Spring" }

        return nil
    }

    private func thanksgivingDay(year: Int) -> Int? {
        var comps = DateComponents()
        comps.year = year
        comps.month = 11
        comps.day = 1
        guard let nov1 = calendar.date(from: comps) else { return nil }
        let weekday = calendar.component(.weekday, from: nov1) // 1=Sun
        // First Thursday: weekday 5
        let firstThursday = weekday <= 5 ? (5 - weekday + 1) : (12 - weekday + 5)
        return firstThursday + 21 // 4th Thursday
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(greetingText)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(Color(hex: "1E1C1A"))
                    Image(systemName: greetingIcon)
                        .font(.system(size: 16))
                        .foregroundColor(greetingIconColor)
                }
                Text("What story shall we create?")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "7A756E"))
            }
            Spacer()
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD93D"), Color(hex: "FFBFA8")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                )
                .shadow(color: Color(hex: "FFD93D").opacity(0.4), radius: 8, y: 3)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Hero Banner
    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "FFD93D"), Color(hex: "FFE94A"), Color(hex: "FFF5A0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "FFD93D").opacity(0.35), radius: 12, y: 4)

            HStack {
                Spacer()
                Image(systemName: "book.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(Color(hex: "1E1C1A").opacity(0.12))
                    .offset(x: -12, y: -8)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Ready to create")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                }
                .foregroundColor(Color(hex: "1E1C1A").opacity(0.6))

                Text("A new story\nfor little \(storyVM.childName)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "1E1C1A"))
                    .lineSpacing(2)

                Spacer().frame(height: 8)

                Button {
                    currentScreen = .photoUpload
                } label: {
                    HStack(spacing: 6) {
                        Text("Create Now")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "E86D4A"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFFFFF"))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                }
            }
            .padding(20)
        }
        .frame(height: 160)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    // MARK: - Mini Calendar Strip
    private var miniCalendarStrip: some View {
        let now = Date()
        let todayDay = calendar.component(.day, from: now)
        let storyDaysMap = storyVM.storyDays(for: now)
        let days = monthDays(for: now)
        let storyCount = storyDaysMap.count

        return VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "E8705A"))
                    Text(monthYearString(now))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1A1814"))
                }

                if storyCount > 0 {
                    Text("\(storyCount) \(storyCount == 1 ? "story" : "stories")")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "E8705A"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "FFF0EC").cornerRadius(8))
                }

                Spacer()

                Button {
                    currentScreen = .storyCalendar
                } label: {
                    HStack(spacing: 3) {
                        Text("View all")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "E8705A"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Weekday labels (Sunday-first)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(label == "Sun" || label == "Sat"
                                         ? Color(hex: "D4A07A") : Color(hex: "A09890"))
                        .frame(height: 16)
                }
            }
            .padding(.horizontal, 10)

            // Day grid
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(days) { item in
                    if let day = item.day {
                        let isToday = day == todayDay
                        let hasStory = storyDaysMap[day] != nil
                        let isTapped = tappedDay == day

                        miniDayCell(day: day, isToday: isToday, hasStory: hasStory)
                            .scaleEffect(isTapped ? 0.88 : 1.0)
                            .opacity(isTapped ? 0.7 : 1.0)
                            .animation(.easeOut(duration: 0.12), value: isTapped)
                            .onTapGesture {
                                tappedDay = day
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    tappedDay = nil
                                    currentScreen = .storyCalendar
                                }
                            }
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)

            // Legend
            HStack(spacing: 14) {
                legendItem(color: Color(hex: "E8705A"), label: "Has story")
                legendItem(color: Color(hex: "1A1814"), label: "Today")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: Color(hex: "E8D9C8").opacity(0.4), radius: 12, y: 5)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private func miniDayCell(day: Int, isToday: Bool, hasStory: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 11, weight: isToday ? .black : hasStory ? .bold : .medium,
                              design: .rounded))
                .foregroundColor(
                    isToday ? .white :
                    hasStory ? Color(hex: "7A6200") :
                    Color(hex: "5C5750")
                )

            // Story badge dot
            Circle()
                .fill(
                    isToday && hasStory ? Color.white.opacity(0.9) :
                    hasStory ? Color(hex: "E8705A") :
                    Color.clear
                )
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isToday
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "FF8C6B"), Color(hex: "E8705A")],
                            startPoint: .top, endPoint: .bottom))
                        : hasStory
                            ? AnyShapeStyle(Color(hex: "FFF8E7"))
                            : AnyShapeStyle(Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(hasStory && !isToday ? Color(hex: "FFE4B5").opacity(0.6) : Color.clear,
                        lineWidth: 1)
        )
        .shadow(
            color: isToday ? Color(hex: "E8705A").opacity(0.3) : .clear,
            radius: isToday ? 4 : 0, y: isToday ? 2 : 0
        )
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "A09890"))
        }
    }

    private func holidayDecoIcon(for date: Date) -> String? {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        if month == 12 && (day == 24 || day == 25) { return "eye.fill" }
        if month == 10 && day == 31 { return "eye.fill" }
        if month == 3 && day == 20 { return "eye.fill" }
        if month == 11, let td = thanksgivingDay(year: calendar.component(.year, from: date)), day == td {
            return "eye.fill"
        }
        return nil
    }

    // MARK: - Recent Books
    private var recentBooksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Recent Books", action: "See all") { currentScreen = .myBooks }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    let recent = recentBooks()

                    if recent.isEmpty {
                        bookCard(sfIcon: "pawprint.fill", title: "Emma's Brave Day", meta: "2 days ago",
                                 gradient: [Color(hex: "FFD93D"), Color(hex: "FF8C6B")])
                            .onTapGesture { openSampleStory(title: "Emma's Brave Day", theme: "Being brave") }
                        bookCard(sfIcon: "airplane", title: "To the Stars", meta: "1 week ago",
                                 gradient: [Color(hex: "6BCB77"), Color(hex: "4D96FF")])
                            .onTapGesture { openSampleStory(title: "To the Stars", theme: "Space adventure") }
                        bookCard(sfIcon: "water.waves", title: "Ocean Friends", meta: "2 weeks ago",
                                 gradient: [Color(hex: "FFBFA8"), Color(hex: "FF5252")])
                            .onTapGesture { openSampleStory(title: "Ocean Friends", theme: "Making friends") }
                    } else {
                        ForEach(recent) { story in
                            bookCard(
                                sfIcon: "book.fill",
                                title: story.title.isEmpty ? "Untitled Story" : story.title,
                                meta: (story.lastReadAt ?? story.createdAt).formatted(.relative(presentation: .named)),
                                gradient: [Color(hex: "FFD93D"), Color(hex: "FF8C6B")]
                            )
                            .onTapGesture {
                                storyVM.currentStory = story
                                storyVM.currentPage = min(story.lastReadPage, max(story.pages.count - 1, 0))
                                storyVM.markAsRead(story)
                                storyVM.previousScreen = .home
                                currentScreen = .storybook
                            }
                        }
                    }

                    // Add new card
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color(hex: "E0DBD4"), style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .frame(width: 120, height: 152)
                            .overlay(
                                VStack(spacing: 5) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundColor(Color(hex: "B8B3AC"))
                                    Text("New Story")
                                        .font(.system(size: 12, weight: .regular, design: .rounded))
                                        .foregroundColor(Color(hex: "B8B3AC"))
                                }
                            )
                    }
                    .onTapGesture { currentScreen = .photoUpload }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
        }
        .padding(.bottom, 12)
    }

    private func recentBooks() -> [Story] {
        let byLastRead = storyVM.recentlyReadStories
        if !byLastRead.isEmpty {
            return byLastRead
        }
        return Array(
            storyVM.savedStories
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(3)
        )
    }

    private func openSampleStory(title: String, theme: String) {
        let sampleTexts = [
            "Once upon a time, \(storyVM.childName) woke up to a beautiful sunny morning.",
            "\(storyVM.childName) felt butterflies in their tummy. Today was going to be special!",
            "\"I can do this!\" \(storyVM.childName) said, taking a deep breath.",
            "Step by step, \(storyVM.childName) moved forward with a big smile.",
            "The world around them was full of color and wonder.",
            "\(storyVM.childName) laughed out loud — this was the best day ever!",
            "When the adventure was over, \(storyVM.childName) felt proud.",
            "\"I was brave today,\" \(storyVM.childName) whispered. The stars twinkled.",
        ]
        let emojis = ["sun.max.fill", "leaf.fill", "flame.fill", "figure.walk", "tree.fill", "face.smiling", "star.fill", "moon.fill"]
        let pages = (0..<8).map { i in
            StoryPage(pageNumber: i + 1, text: sampleTexts[i], emoji: emojis[i])
        }
        storyVM.currentStory = Story(title: title, childName: storyVM.childName, theme: theme, pages: pages)
        storyVM.currentPage = 0
        storyVM.previousScreen = .home
        currentScreen = .storybook
    }

    private func bookCard(sfIcon: String, title: String, meta: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 152)
                .overlay(
                    Image(systemName: sfIcon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                )
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1E1C1A"))
                .lineLimit(1)
                .padding(.top, 7)

            Text(meta)
                .font(.system(size: 10, design: .rounded))
                .foregroundColor(Color(hex: "7A756E"))
                .padding(.top, 1)
        }
        .frame(width: 120)
    }

    // MARK: - Section Header
    private func sectionHeader(icon: String? = nil, title: String, action: String? = nil, onAction: (() -> Void)? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "FF8C6B"))
            }
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "1E1C1A"))
            Spacer()
            if let action {
                Button {
                    onAction?()
                } label: {
                    HStack(spacing: 3) {
                        Text(action)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "FF8C6B"))
                }
            }
        }
        .padding(.horizontal, 18)
    }

    // MARK: - Calendar Helpers

    private struct IndexedDay: Identifiable {
        let offset: Int
        let day: Int?
        var id: Int { offset }
    }

    /// Builds the full month grid with Sunday as the first day of the week.
    private func monthDays(for date: Date) -> [IndexedDay] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else { return [] }

        // calendar.component(.weekday) returns 1=Sunday ... 7=Saturday
        // For a Sunday-first grid, leading empties = weekday - 1
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingEmpty = weekday - 1

        var result: [IndexedDay] = []
        for i in 0..<leadingEmpty {
            result.append(IndexedDay(offset: i, day: nil))
        }
        for day in range {
            result.append(IndexedDay(offset: leadingEmpty + day - 1, day: day))
        }
        // Pad trailing to fill last row
        let remainder = result.count % 7
        if remainder > 0 {
            let start = result.count
            for i in 0..<(7 - remainder) {
                result.append(IndexedDay(offset: start + i, day: nil))
            }
        }
        return result
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

#Preview("HomeView") {
    HomeView(storyVM: StoryViewModel(), currentScreen: .constant(.home))
}
